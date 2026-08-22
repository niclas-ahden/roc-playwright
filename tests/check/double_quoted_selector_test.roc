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

## check!/uncheck! interpolate the selector into a JS snippet. A selector
## containing double quotes (the form most people write) must survive that,
## rather than terminating the JS string literal and failing to parse.
main! : List(OsStr) => Try({}, _)
main! = |_args| {
    url = worker_url!({})
    { browser, page } = Playwright.launch_page!(
        { new: Cmd.new_str, spawn!: Cmd.spawn! },
        Chromium(DefaultChannel),
    )?
    page.navigate!(Url.to_str(Url.append_path(url, ["checkbox-test"]).ok_or(url)))?

    page.check!("input[type=\"checkbox\"]")?
    first = page.evaluate!("String(document.querySelector('#plain').checked)")?
    Assert.eq(first, "true") ? |e| DoubleQuotedSelectorShouldCheck(e)

    page.uncheck!("input[type=\"checkbox\"]")?
    after = page.evaluate!("String(document.querySelector('#plain').checked)")?
    Assert.eq(after, "false") ? |e| DoubleQuotedSelectorShouldUncheck(e)

    # Single-quoted selectors keep working too.
    page.check!("input[type='checkbox']")?
    single = page.evaluate!("String(document.querySelector('#plain').checked)")?
    Assert.eq(single, "true") ? |e| SingleQuotedSelectorShouldCheck(e)

    browser.close!()
}
