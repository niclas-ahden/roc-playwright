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

## Unlike touch_scroll! (a wheel-style source on desktop), touch_swipe! sets
## gestureSourceType: "touch", so the browser fires the real pointer-event
## sequence with pointerType === "touch".
main! : List(OsStr) => Try({}, _)
main! = |_args| {
    url = worker_url!({})
    { browser, page } = Playwright.launch_page_with!(
        { new: Cmd.new_str, spawn!: Cmd.spawn! },
        {
            timeout: TimeoutMilliseconds(10000),
            has_touch: Bool.True,
        },
    )?
    page.navigate!(Url.to_str(Url.append_path(url, ["scroll-test"]).ok_or(url)))?

    before = page.text_content!("#pointer-events")?
    Assert.eq(before, "none") ? |e| ShouldStartWithNoPointerEvents(e)

    # Horizontal swipe inside #pointer-area, which sets touch-action: none so
    # the browser does not claim the gesture for scrolling.
    page.touch_swipe!({ start_x: 300.0, start_y: 200.0, end_x: 100.0, end_y: 200.0 })?

    seen = page.evaluate!(
        "new Promise(r => requestAnimationFrame(() => r(document.querySelector('#pointer-events').textContent)))",
    )?
    Assert.eq(Str.contains(seen, "pointerdown"), Bool.True) ? |e| SwipeShouldFireTouchPointerDown(e)

    browser.close!()
}
