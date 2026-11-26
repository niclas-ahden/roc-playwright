app [main!] {
    pf: platform "https://github.com/niclas-ahden/basic-cli/releases/download/0.32.0/3MnQnCrtfe6XS5qx58MnAGU6iWk8i1N24MYfoejcWeax.tar.zst",
    playwright: "../../package/main.roc",
    url: "https://github.com/niclas-ahden/roc-url/releases/download/0.7.1/AuBv5v9TGGUS4yRtC8tLEVyEr7MkaReZCeuu2sYANn8F.tar.zst",
    spec: "https://github.com/niclas-ahden/roc-spec/releases/download/0.7.1/GXr8UJ7VDaJ8HYykmVYtTjLs7X4bZeE9YDTzAHoVXFJ9.tar.zst",
}

import pf.Cmd
import pf.Duration
import pf.Env
import pf.OsStr
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

## A clock installed before the page loads gives the page a fake time and
## fake timers. pause_at! pauses it, run_for! fires every timer due on the
## way, fast_forward! fires each due timer once, and set_system_time! and
## set_fixed_time! change what `Date` says.
main! : List(OsStr) => Try({}, _)
main! = |_args| {
    url = worker_url!({})
    { browser, page } = Playwright.launch_page_with!(
        { new: Cmd.new, os_str: OsStr.from_str, spawn!: Cmd.Command.spawn_leashed!, millis: Duration.millis },
        { timeout: TimeoutMilliseconds(5000) },
    )?
    clock = page.clock()
    clock.install_at!(DateString("2024-02-02T08:00:00Z"))?
    # An installed clock keeps advancing with real time. A paused clock
    # advances only when the test advances it, so every time below is exact.
    clock.pause_at!(DateString("2024-02-02T08:00:01Z"))?
    page.navigate!(Url.to_str(Url.append_path(url, ["clock-test"]).ok_or(url)))?

    Playwright.assert!(page.find("#loaded-at").has_text("2024-02-02T08:00:01.000Z"))?
    Playwright.assert!(page.find("#timeout").has_text("waiting"))?

    # The interval fires three times on the way; the 5 s timeout is not due
    # yet.
    clock.run_for!(3000)?
    Playwright.assert!(page.find("#ticks").has_text("3"))?
    Playwright.assert!(page.find("#timeout").has_text("waiting"))?

    clock.run_for!(2000)?
    Playwright.assert!(page.find("#timeout").has_text("fired"))?
    Playwright.assert!(page.find("#ticks").has_text("5"))?

    # Fast-forwarding ten seconds fires the interval only once.
    clock.fast_forward!(10000)?
    Playwright.assert!(page.find("#ticks").has_text("6"))?

    # pause_at! moves the clock ahead and pauses it there.
    clock.pause_at!(DateString("2024-02-02T08:00:30Z"))?
    Assert.eq(page.evaluate!("new Date().toISOString()")?, "2024-02-02T08:00:30.000Z") ? |e| PausedAt(e)
    clock.set_system_time!(EpochMillis(1_893_456_000_000))?
    Assert.eq(page.evaluate!("new Date().toISOString()")?, "2030-01-01T00:00:00.000Z") ? |e| SystemTime(e)
    clock.resume!()?

    clock.set_fixed_time!(EpochMillis(0))?
    Assert.eq(page.evaluate!("String(Date.now())")?, "0") ? |e| FixedTime(e)

    browser.close!()
}
