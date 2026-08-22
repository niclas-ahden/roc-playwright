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
    # --- Success case: element appears within timeout ---

    # Launch with 5 second timeout - element appears after 500ms, so this should succeed
    { browser: browser1, page: page1 } = Playwright.launch_page_with!(
        { new: Cmd.new_str, spawn!: Cmd.spawn! },
        { timeout: TimeoutMilliseconds(5000) },
    )?

    page1.navigate!(Url.to_str(Url.append_path(url, ["delayed-element"]).ok_or(url)))?

    # This should succeed because 5000ms > 500ms delay
    delayed_text = page1.text_content!("#delayed")?
    Assert.eq(delayed_text, "I appeared!") ? |e| DelayedElementFound(e)

    browser1.close!()?

    # --- Failure case: timeout expires before element appears ---

    # Launch with 100ms timeout - element appears after 500ms, so this should fail
    { browser: browser2, page: page2 } = Playwright.launch_page_with!(
        { new: Cmd.new_str, spawn!: Cmd.spawn! },
        { timeout: TimeoutMilliseconds(100) },
    )?

    page2.navigate!(Url.to_str(Url.append_path(url, ["delayed-element"]).ok_or(url)))?

    # This should fail because 100ms < 500ms delay
    timeout_result = page2.text_content!("#delayed")
    _ = Assert.err(timeout_result) ? |e| TimeoutBeforeElementAppears(e)

    browser2.close!()
}
