app [main!] {
    pf: platform "https://github.com/niclas-ahden/basic-cli/releases/download/0.24.0/2mx1EsQx1HEG7HdbW2CwUpexvmJZW4nSCpjbur5GXyRe.tar.zst",
    playwright: "../../package/main.roc",
    url: "https://github.com/niclas-ahden/roc-url/releases/download/0.6.1/95CwyLo97aKZ5twTy6VtkmmhF6MFKMr7hvPeMi6U7bAF.tar.zst",
    spec: "https://github.com/niclas-ahden/roc-spec/releases/download/0.3.0/2v2CV8CLXRJmQRvfoHtPngAUGgE8jL6DDgXbugZhFVf5.tar.zst",
}

import pf.Cmd
import pf.Env
import pf.OsStr exposing [OsStr]
import playwright.Playwright
import url.Url
import spec.Assert
import spec.TestEnvironment

## The per-worker test-server URL, from the env the runner sets:
## http://$ROC_SPEC_HOST:($ROC_SPEC_BASE_PORT + $WORKER_INDEX)
worker_url! : {} => Url
worker_url! = |{}| {
    env = { env_var!: Env.var_str! }
    url_str =
        match TestEnvironment.worker_url!(env) {
            Ok(s) => s
            Err(_) => { crash "worker_url: ROC_SPEC_BASE_PORT or WORKER_INDEX missing or invalid (run via tests/run.roc)" }
        }
    match Url.parse(url_str) {
        Ok(u) => u
        Err(_) => { crash "worker_url: unparseable server url" }
    }
}

## Every string the driver returns is JSON-escaped on the wire. Quotes,
## backslashes, newlines, tabs and non-ASCII must survive the round trip
## byte for byte, on every accessor that returns text.
main! : List(OsStr) => Try({}, _)
main! = |_args| {
    url = worker_url!({})
    { browser, page } = Playwright.launch_page!(
        { new: Cmd.new_str, spawn!: Cmd.spawn! },
        Chromium(DefaultChannel),
    )?
    page.navigate!(Url.to_str(Url.append_path(url, ["escapes-test"]).ok_or(url)))?

    quoted = page.text_content!("#quoted")?
    Assert.eq(quoted, "He said \"hi\"") ? |e| QuotesShouldSurviveTextContent(e)

    backslash = page.text_content!("#backslash")?
    Assert.eq(backslash, "C:\\Users\\test") ? |e| BackslashesShouldSurvive(e)

    multiline = page.text_content!("#multiline")?
    Assert.eq(multiline, "line one\nline two") ? |e| NewlinesShouldSurvive(e)

    unicode = page.text_content!("#unicode")?
    Assert.eq(unicode, "café · naïve · 日本語") ? |e| UnicodeShouldSurvive(e)

    # The title carries quotes too.
    title = page.get_title!()?
    Assert.eq(title, "He said \"hi\"") ? |e| QuotesShouldSurviveTitle(e)

    # ...as does an input value.
    value = page.input_value!("#quoted-input")?
    Assert.eq(value, "a \"quoted\" value") ? |e| QuotesShouldSurviveInputValue(e)

    # ...and an attribute.
    href = page.get_attribute!("#link", "href")?
    Assert.eq(href, "/path?q=\"x\"&r=y") ? |e| QuotesShouldSurviveAttribute(e)

    # ...and an evaluate! result, including a tab.
    tabbed = page.evaluate!("'a' + String.fromCharCode(9) + 'b'")?
    Assert.eq(tabbed, "a\tb") ? |e| TabsShouldSurviveEvaluate(e)

    # Values whose *content* mimics the wire format's serialized-string ("s":)
    # and null ("v":) markers must not be misrouted by the response decoder,
    # e.g. read as null or fail to decode.
    json_text = page.text_content!("#json-content")?
    Assert.eq(json_text, "{\"s\": \"sniff\", \"v\": \"bait\"}") ? |e| JsonTextShouldNotConfuseDecoder(e)

    json_attr = page.get_attribute!("#json-attr", "data-state")?
    Assert.eq(json_attr, "{\"s\": \"sniff\", \"v\": \"bait\"}") ? |e| JsonAttrShouldNotConfuseDecoder(e)

    json_eval = page.evaluate!("JSON.stringify({s: 1, v: 2})")?
    Assert.eq(json_eval, "{\"s\":1,\"v\":2}") ? |e| JsonEvalShouldNotConfuseDecoder(e)

    browser.close!()
}
