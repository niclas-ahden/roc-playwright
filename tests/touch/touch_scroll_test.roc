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

## Settle two animation frames so the compositor's scroll has been committed
## and the scroll listener has run. evaluate! awaits returned promises.
scroll_y! = |page|
    page.evaluate!(
        "new Promise(r => requestAnimationFrame(() => requestAnimationFrame(() => r(String(Math.round(window.scrollY))))))",
    )

## touch_scroll! goes through the compositor and triggers native scrolling.
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

    before = scroll_y!(page)?
    Assert.eq(before, "0") ? |e| ShouldStartAtTop(e)

    # Finger travels upward, so the page scrolls down.
    page.touch_scroll!({ start_x: 200.0, start_y: 500.0, end_x: 200.0, end_y: 200.0 })?

    after = scroll_y!(page)?
    scrolled = U64.from_str(after).ok_or(0)
    Assert.eq(scrolled > 0, Bool.True) ? |e| ScrollShouldMovePage(e)

    browser.close!()
}
