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
        { new: Cmd.new_str, args: Cmd.args_str, spawn!: Cmd.spawn!, write_stdin!: Cmd.Child.write_stdin!, read_stdout!: Cmd.Child.read_stdout!, kill!: Cmd.Child.kill! },
        { browser_type: Chromium(DefaultChannel), headless: Bool.True, timeout: TimeoutMilliseconds(5000), args: [], has_touch: Bool.False, permissions: [] },
    )?

    Playwright.navigate!(page, Url.to_str(Url.append_path(url, ["bounding-box-test"]).ok_or(url)))?

    # Get bounding box of the fixed element (positioned at top:100, left:150, 200x100)
    box = Playwright.bounding_box!(page, "#fixed-box")?

    # Verify position (CSS says top:100, left:150)
    Assert.true(box.x > 149.0 and box.x < 151.0) ? |e| XShouldBe150(e)
    Assert.true(box.y > 99.0 and box.y < 101.0) ? |e| YShouldBe100(e)

    # Verify dimensions (CSS says width:200, height:100)
    Assert.true(box.width > 199.0 and box.width < 201.0) ? |e| WidthShouldBe200(e)
    Assert.true(box.height > 99.0 and box.height < 101.0) ? |e| HeightShouldBe100(e)

    Playwright.close!(browser)
}
