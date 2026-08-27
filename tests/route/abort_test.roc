app [main!] {
    pf: platform "https://github.com/niclas-ahden/basic-cli/releases/download/0.24.0/2mx1EsQx1HEG7HdbW2CwUpexvmJZW4nSCpjbur5GXyRe.tar.zst",
    playwright: "../../package/main.roc",
    url: "https://github.com/niclas-ahden/roc-url/releases/download/0.6.1/95CwyLo97aKZ5twTy6VtkmmhF6MFKMr7hvPeMi6U7bAF.tar.zst",
    spec: "https://github.com/niclas-ahden/roc-spec/releases/download/0.3.0/2v2CV8CLXRJmQRvfoHtPngAUGgE8jL6DDgXbugZhFVf5.tar.zst",
}

import pf.Cmd
import pf.Env
import pf.OsStr exposing [OsStr]
import playwright.Playwright exposing [assert!]
import url.Url
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

# An aborted rule fails the fetch the way the network would: the page's
# catch runs, whatever the reason given (fetch rejects the same way for all
# of them). The page fetches /api/greeting on a click and shows "failed"
# when the promise rejects.
main! : List(OsStr) => Try({}, _)
main! = |_args| {
    url = worker_url!({})
    { browser, page } = Playwright.launch_page_with!(
        { new: Cmd.new_str, spawn!: Cmd.spawn! },
        { timeout: TimeoutMilliseconds(5000) },
    )?

    page.navigate!(Url.to_str(Url.append_path(url, ["route-test"]).ok_or(url)))?

    page.with_routes!([{ pattern: "**/api/greeting", method: AnyMethod, action: Abort(ConnectionRefused) }], |routed| {
        routed.find("#fetch").click!()?
        assert!(routed.find("#result").has_text("failed")) ? |e| AbortShouldFailTheFetch(Str.inspect(e))
        Ok({})
    })?

    # Once the block is over the same fetch succeeds.
    page.find("#fetch").click!()?
    assert!(page.find("#result").has_text("200 hello from the server")) ? |e| NetworkShouldBeBackAfterTheBlock(Str.inspect(e))

    browser.close!()
}
