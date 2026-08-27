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

# A rule with a method applies to that method alone: the same URL fetched
# with another one reaches the server. AnyMethod applies to all of them.
# The page fetches /api/greeting with GET on one button and POST on the
# other, and shows "<status> <body>".
main! : List(OsStr) => Try({}, _)
main! = |_args| {
    url = worker_url!({})
    { browser, page } = Playwright.launch_page_with!(
        { new: Cmd.new_str, spawn!: Cmd.spawn! },
        { timeout: TimeoutMilliseconds(5000) },
    )?

    page.navigate!(Url.to_str(Url.append_path(url, ["route-test"]).ok_or(url)))?

    # Writes are refused, reads still get through.
    page.with_routes!([{ pattern: "**/api/greeting", method: POST, action: Fulfill({ status: 500, headers: [], body: Str.to_utf8("no writes") }) }], |routed| {
        routed.find("#post").click!()?
        assert!(routed.find("#result").has_text("500 no writes")) ? |e| PostShouldBeRefused(Str.inspect(e))
        routed.find("#fetch").click!()?
        assert!(routed.find("#result").has_text("200 hello from the server")) ? |e| GetShouldReachTheServer(Str.inspect(e))
        Ok({})
    })?

    # Any method: both are answered by the rule.
    page.with_routes!([{ pattern: "**/api/greeting", method: AnyMethod, action: Fulfill({ status: 503, headers: [], body: Str.to_utf8("nothing at all") }) }], |routed| {
        routed.find("#post").click!()?
        assert!(routed.find("#result").has_text("503 nothing at all")) ? |e| AnyMethodShouldAnswerThePost(Str.inspect(e))
        routed.find("#fetch").click!()?
        assert!(routed.find("#result").has_text("503 nothing at all")) ? |e| AnyMethodShouldAnswerTheGet(Str.inspect(e))
        Ok({})
    })?

    # With the blocks over the server answers both.
    page.find("#post").click!()?
    assert!(page.find("#result").has_text("200 greeting posted")) ? |e| ServerShouldAnswerThePost(Str.inspect(e))

    browser.close!()
}
