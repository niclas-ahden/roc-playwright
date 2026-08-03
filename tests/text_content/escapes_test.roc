app [main!] {
    pf: platform "https://github.com/niclas-ahden/basic-cli/releases/download/0.23.0/7NpDhuqoqGFedmVLvmm1zjq37GCmaFGzwr5sz4ch9wTK.tar.zst",
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

hooks = {
    new: Cmd.new_str,
    args: Cmd.args_str,
    spawn_grouped!: Cmd.spawn_grouped!,
    write_stdin!: Cmd.Child.write_stdin!,
    read_stdout!: Cmd.Child.read_stdout!,
    kill!: Cmd.Child.kill!,
}

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
    { browser, page } = Playwright.launch_page!(hooks, Chromium(DefaultChannel))?
    Playwright.navigate!(page, Url.to_str(Url.append_path(url, ["escapes-test"]).ok_or(url)))?

    quoted = Playwright.text_content!(page, "#quoted")?
    Assert.eq(quoted, "He said \"hi\"") ? |e| QuotesShouldSurviveTextContent(e)

    backslash = Playwright.text_content!(page, "#backslash")?
    Assert.eq(backslash, "C:\\Users\\test") ? |e| BackslashesShouldSurvive(e)

    multiline = Playwright.text_content!(page, "#multiline")?
    Assert.eq(multiline, "line one\nline two") ? |e| NewlinesShouldSurvive(e)

    unicode = Playwright.text_content!(page, "#unicode")?
    Assert.eq(unicode, "café · naïve · 日本語") ? |e| UnicodeShouldSurvive(e)

    # The title carries quotes too.
    title = Playwright.get_title!(page)?
    Assert.eq(title, "He said \"hi\"") ? |e| QuotesShouldSurviveTitle(e)

    # ...as does an input value.
    value = Playwright.input_value!(page, "#quoted-input")?
    Assert.eq(value, "a \"quoted\" value") ? |e| QuotesShouldSurviveInputValue(e)

    # ...and an attribute.
    href = Playwright.get_attribute!(page, "#link", "href")?
    Assert.eq(href, "/path?q=\"x\"&r=y") ? |e| QuotesShouldSurviveAttribute(e)

    # ...and an evaluate! result, including a tab.
    tabbed = Playwright.evaluate!(page, "'a' + String.fromCharCode(9) + 'b'")?
    Assert.eq(tabbed, "a\tb") ? |e| TabsShouldSurviveEvaluate(e)

    # Values whose *content* mimics the wire format's serialized-string ("s":)
    # and null ("v":) markers must not be misrouted by the response decoder,
    # e.g. read as null or fail to decode.
    json_text = Playwright.text_content!(page, "#json-content")?
    Assert.eq(json_text, "{\"s\": \"sniff\", \"v\": \"bait\"}") ? |e| JsonTextShouldNotConfuseDecoder(e)

    json_attr = Playwright.get_attribute!(page, "#json-attr", "data-state")?
    Assert.eq(json_attr, "{\"s\": \"sniff\", \"v\": \"bait\"}") ? |e| JsonAttrShouldNotConfuseDecoder(e)

    json_eval = Playwright.evaluate!(page, "JSON.stringify({s: 1, v: 2})")?
    Assert.eq(json_eval, "{\"s\":1,\"v\":2}") ? |e| JsonEvalShouldNotConfuseDecoder(e)

    Playwright.close!(browser)
}
