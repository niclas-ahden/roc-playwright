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

# A fulfilled rule answers the page's fetch itself, with the status and
# body given, for as long as the block runs; after it the URL reaches the
# real server again. The page fetches /api/greeting on a click and shows
# "<status> <body>".
main! : List(OsStr) => Try({}, _)
main! = |_args| {
    url = worker_url!({})
    { browser, page } = Playwright.launch_page_with!(
        { new: Cmd.new_str, spawn!: Cmd.spawn! },
        { timeout: TimeoutMilliseconds(5000) },
    )?

    page.navigate!(Url.to_str(Url.append_path(url, ["route-test"]).ok_or(url)))?

    # A rule for another URL leaves this one alone.
    page.with_routes!([{ pattern: "**/api/other", method: AnyMethod, action: Fulfill({ status: 500, headers: [], body: Str.to_utf8("wrong route") }) }], |routed| {
        routed.find("#fetch").click!()?
        assert!(routed.find("#result").has_text("200 hello from the server")) ? |e| UnmatchedRuleShouldNotInterfere(Str.inspect(e))
        Ok({})
    })?

    # The matching rule answers, and the server is never asked. Nested
    # blocks put their rules first, and ending the inner block exposes the
    # outer rule again.
    page.with_routes!([{ pattern: "**/api/greeting", method: AnyMethod, action: Fulfill({ status: 503, headers: [{ name: "content-type", value: "text/plain" }], body: Str.to_utf8("not today") }) }], |outer| {
        outer.find("#fetch").click!()?
        assert!(outer.find("#result").has_text("503 not today")) ? |e| RuleShouldFulfill(Str.inspect(e))

        outer.with_routes!([{ pattern: "**/api/*", method: AnyMethod, action: Fulfill({ status: 418, headers: [], body: Str.to_utf8("teapot") }) }], |inner| {
            inner.find("#fetch").click!()?
            assert!(inner.find("#result").has_text("418 teapot")) ? |e| InnerRuleShouldWin(Str.inspect(e))
            Ok({})
        })?

        outer.find("#fetch").click!()?
        assert!(outer.find("#result").has_text("503 not today")) ? |e| OuterRuleShouldBeBackAfterTheInnerBlock(Str.inspect(e))
        Ok({})
    })?

    # Within one block the first matching rule in the list decides.
    page.with_routes!(
        [
            { pattern: "**/api/{greeting,other}", method: AnyMethod, action: Fulfill({ status: 418, headers: [], body: Str.to_utf8("teapot") }) },
            { pattern: "**/api/greeting", method: AnyMethod, action: Fulfill({ status: 503, headers: [], body: Str.to_utf8("not today") }) },
        ],
        |routed| {
            routed.find("#fetch").click!()?
            assert!(routed.find("#result").has_text("418 teapot")) ? |e| FirstListedRuleShouldWin(Str.inspect(e))
            Ok({})
        },
    )?

    # Every block is over, so the server answers.
    page.find("#fetch").click!()?
    assert!(page.find("#result").has_text("200 hello from the server")) ? |e| ServerShouldAnswerAfterTheBlocks(Str.inspect(e))

    browser.close!()
}
