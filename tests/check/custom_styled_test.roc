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

## The reason set_checked! goes through JS rather than a protocol click:
## Chromium's CDP click does not fire `change` on `appearance: none`
## checkboxes. Also covers the documented no-op cases and radio buttons.
main! : List(OsStr) => Try({}, _)
main! = |_args| {
    url = worker_url!({})
    { browser, page } = Playwright.launch_page!(
        { new: Cmd.new_str, spawn!: Cmd.spawn! },
        Chromium(DefaultChannel),
    )?
    page.navigate!(Url.to_str(Url.append_path(url, ["checkbox-test"]).ok_or(url)))?

    page.check!("#styled")?
    styled = page.evaluate!("String(document.querySelector('#styled').checked)")?
    Assert.eq(styled, "true") ? |e| StyledCheckboxShouldCheck(e)

    styled_changes = page.text_content!("#change-count")?
    Assert.eq(styled_changes, "1") ? |e| StyledCheckboxShouldFireChange(e)

    # Checking an already-checked box is documented as a no-op: no second event.
    page.check!("#styled")?
    unchanged = page.text_content!("#change-count")?
    Assert.eq(unchanged, "1") ? |e| RepeatCheckShouldBeNoOp(e)

    # Unchecking an already-unchecked box is a no-op too.
    page.uncheck!("#plain")?
    still_unchanged = page.text_content!("#change-count")?
    Assert.eq(still_unchanged, "1") ? |e| RedundantUncheckShouldBeNoOp(e)

    # A pre-checked box unchecks.
    page.uncheck!("#prechecked")?
    prechecked = page.evaluate!("String(document.querySelector('#prechecked').checked)")?
    Assert.eq(prechecked, "false") ? |e| PrecheckedShouldUncheck(e)

    # Radio buttons go through the same path.
    page.check!("#radio-b")?
    radio = page.evaluate!("String(document.querySelector('#radio-b').checked)")?
    Assert.eq(radio, "true") ? |e| RadioShouldCheck(e)

    browser.close!()
}
