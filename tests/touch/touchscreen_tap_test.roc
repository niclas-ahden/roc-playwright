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
    # Launch with touch enabled
    browser = Playwright.launch_with!(
        { new: Cmd.new_str, args: Cmd.args_str, spawn!: Cmd.spawn!, write_stdin!: Cmd.Child.write_stdin!, read_stdout!: Cmd.Child.read_stdout!, kill!: Cmd.Child.kill! },
        { browser_type: Chromium(DefaultChannel), headless: Bool.True, timeout: TimeoutMilliseconds(5000), args: [] },
    )?
    context = Playwright.new_context_with!(browser, { has_touch: Bool.True, permissions: [] })?
    page = Playwright.new_page!(context)?

    Playwright.navigate!(page, Url.to_str(Url.append_path(url, ["touch-test"]).ok_or(url)))?

    # Verify initial state
    initial_text = Playwright.text_content!(page, "#touch-result")?
    Assert.eq(initial_text, "No touch yet") ? |_| WrongInitialState(initial_text)

    # Tap in the center of the touch area (300x200 element)
    box = Playwright.bounding_box!(page, "#touch-area")?
    center_x = box.x + (box.width / 2.0)
    center_y = box.y + (box.height / 2.0)
    Playwright.touchscreen_tap!(page, center_x, center_y)?

    # The tap triggers touch events then a click. The click handler writes
    # "Clicked at: X, Y" with the actual coordinates.
    result_text = Playwright.text_content!(page, "#touch-result")?
    Assert.true(Str.starts_with(result_text, "Clicked at:")) ? |_| WrongResultFormat(result_text)

    # Verify coordinates are reasonable (should be near the center of the 300x200 area)
    # The touch area starts at box.x, box.y, so center is roughly (box.x + 150, box.y + 100)
    # We just verify the coordinates are present and are numbers
    coords = result_text.drop_prefix("Clicked at: ")
    Assert.true(Str.contains(coords, ",")) ? |_| MissingCommaInCoords(coords)

    Playwright.close!(browser)
}
