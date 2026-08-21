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
    browser = Playwright.launch_with!(
        { new: Cmd.new_str, args: Cmd.args_str, spawn!: Cmd.spawn!, write_stdin!: Cmd.Child.write_stdin!, read_stdout!: Cmd.Child.read_stdout!, kill!: Cmd.Child.kill! },
        { browser_type: Chromium(DefaultChannel), headless: Bool.True, timeout: TimeoutMilliseconds(5000), args: [] },
    )?
    context = Playwright.new_context_with!(browser, { has_touch: Bool.True, permissions: [] })?
    page = Playwright.new_page!(context)?

    Playwright.navigate!(page, Url.to_str(Url.append_path(url, ["touch-test"]).ok_or(url)))?

    # Get the bounding box of the touch area to calculate coordinates
    box = Playwright.bounding_box!(page, "#touch-area")?

    # Drag from left side to right side of the touch area
    start_x = box.x + 50.0
    start_y = box.y + 100.0
    end_x = box.x + 250.0
    end_y = box.y + 100.0

    # Verify initial state
    initial_text = Playwright.text_content!(page, "#touch-result")?
    Assert.eq(initial_text, "No touch yet") ? |e| InitialStateShouldMatch(e)

    Playwright.touch_drag!(page, { start_x, start_y, end_x, end_y })?

    # Verify drag events were fired (touchstart, 5x touchmove, touchend)
    result_text = Playwright.text_content!(page, "#touch-result")?
    Assert.eq(result_text, "Drag events: start,move,move,move,move,move,end") ? |e| DragEventsShouldMatch(e)

    Playwright.close!(browser)
}
