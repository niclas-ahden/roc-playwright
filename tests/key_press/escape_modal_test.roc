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
    # The runner builds this env, so the URL always parses and an Err here is
    # impossible.
    match Url.parse(url_str) {
        Ok(u) => u
        Err(_) => { crash "worker_url: unparseable server url" }
    }
}

main! : List(OsStr) => Try({}, _)
main! = |_args| {
    url = worker_url!({})
    { browser, page } = Playwright.launch_page_with!(
        { new: Cmd.new_str, spawn!: Cmd.spawn! },
        { timeout: TimeoutMilliseconds(5000) },
    )?

    page.navigate!(Url.to_str(Url.append_path(url, ["keyboard-modal"]).ok_or(url)))?

    # Verify initial state
    initial_status = page.text_content!("#status")?
    Assert.eq(initial_status, "Modal is closed") ? |e| InitialStateShouldBeClosed(e)

    # Open the modal
    page.click!("#open-modal")?

    # Wait for modal to become visible (JavaScript must have run)
    page.wait_for!("#modal", Visible)?

    # Verify modal is open
    status = page.text_content!("#status")?
    Assert.eq(status, "Modal is open") ? |e| ModalShouldBeOpen(e)

    # Press Escape to close the modal (targetless - page level)
    page.key_press_targetless!(Escape, [])?

    # Wait for modal to become hidden
    page.wait_for!("#modal", Hidden)?

    # Verify modal is closed
    status_after = page.text_content!("#status")?
    Assert.eq(status_after, "Modal closed by Escape") ? |e| ModalShouldBeClosed(e)

    browser.close!()
}
