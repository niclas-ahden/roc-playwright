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

main! : List(OsStr) => Try({}, _)
main! = |_args| {
    url = worker_url!({})
    { browser, page } = Playwright.launch_page!(
        { new: Cmd.new_str, spawn!: Cmd.spawn! },
        Chromium(DefaultChannel),
    )?
    page.navigate!(Url.to_str(Url.append_path(url, ["checkbox-test"]).ok_or(url)))?

    before = page.evaluate!("String(document.querySelector('#plain').checked)")?
    Assert.eq(before, "false") ? |e| ShouldStartUnchecked(e)

    page.check!("#plain")?
    after_check = page.evaluate!("String(document.querySelector('#plain').checked)")?
    Assert.eq(after_check, "true") ? |e| ShouldBeCheckedAfterCheck(e)

    # check! must dispatch input + change, not just flip the property.
    changes = page.text_content!("#change-count")?
    Assert.eq(changes, "1") ? |e| CheckShouldFireChange(e)
    inputs = page.text_content!("#input-count")?
    Assert.eq(inputs, "1") ? |e| CheckShouldFireInput(e)

    page.uncheck!("#plain")?
    after_uncheck = page.evaluate!("String(document.querySelector('#plain').checked)")?
    Assert.eq(after_uncheck, "false") ? |e| ShouldBeUncheckedAfterUncheck(e)

    changes_after = page.text_content!("#change-count")?
    Assert.eq(changes_after, "2") ? |e| UncheckShouldFireChange(e)

    browser.close!()
}
