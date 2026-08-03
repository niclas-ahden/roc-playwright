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
    { browser: browser1, page: page1 } = Playwright.launch_page_with!(hooks, { browser_type: Chromium(DefaultChannel), headless: Bool.True, timeout: TimeoutMilliseconds(5000), args: [], has_touch: Bool.False, permissions: [] })?

    Playwright.navigate!(page1, Url.to_str(Url.append_path(url, ["delayed-element"]).ok_or(url)))?

    # This should succeed because 5000ms > 500ms delay
    delayed_text = Playwright.text_content!(page1, "#delayed")?
    Assert.eq(delayed_text, "I appeared!") ? |e| DelayedElementFound(e)

    Playwright.close!(browser1)?

    # --- Failure case: timeout expires before element appears ---

    # Launch with 100ms timeout - element appears after 500ms, so this should fail
    { browser: browser2, page: page2 } = Playwright.launch_page_with!(hooks, { browser_type: Chromium(DefaultChannel), headless: Bool.True, timeout: TimeoutMilliseconds(100), args: [], has_touch: Bool.False, permissions: [] })?

    Playwright.navigate!(page2, Url.to_str(Url.append_path(url, ["delayed-element"]).ok_or(url)))?

    # This should fail because 100ms < 500ms delay
    timeout_result = Playwright.text_content!(page2, "#delayed")
    _ = Assert.err(timeout_result) ? |e| TimeoutBeforeElementAppears(e)

    Playwright.close!(browser2)
}
