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

mic_permission_js =
    "navigator.permissions.query({ name: 'microphone' }).then((p) => p.state)"

main! : List(OsStr) => Try({}, _)
main! = |_args| {
    url = worker_url!({})

    # Verify the two launch options reach the browser:
    #   * `args`: a custom `--user-agent` flag is observable from JS.
    #   * `permissions`: a granted microphone permission shows as "granted".
    # `Chromium(Full)` also exercises the channel launch path (a `launch`
    # message that carries a `channel` field).
    { browser, page } = Playwright.launch_page_with!(
        { new: Cmd.new_str, spawn!: Cmd.spawn! },
        {
            browser_type: Chromium(Full),
            timeout: TimeoutMilliseconds(10000),
            args: ["--user-agent=roc-playwright-args-test"],
            permissions: ["microphone"],
        },
    )?

    page.navigate!(Url.to_str(url))?

    user_agent = page.evaluate!("navigator.userAgent")?
    Assert.eq(user_agent, "roc-playwright-args-test") ? |e| UserAgent(e)

    mic_state = page.evaluate!(mic_permission_js)?
    Assert.eq(mic_state, "granted") ? |e| MicrophoneGranted(e)

    browser.close!()?

    # Without the grant, the same query is not "granted", confirming the
    # state above came from our `permissions` option rather than a default.
    { browser: browser2, page: page2 } = Playwright.launch_page_with!(
        { new: Cmd.new_str, spawn!: Cmd.spawn! },
        {
            browser_type: Chromium(Full),
            timeout: TimeoutMilliseconds(10000),
        },
    )?

    page2.navigate!(Url.to_str(url))?

    default_state = page2.evaluate!(mic_permission_js)?
    Assert.not_eq(default_state, "granted") ? |e| MicrophoneNotGrantedByDefault(e)

    browser2.close!()
}
