app [main!] {
    pf: platform "https://github.com/niclas-ahden/basic-cli/releases/download/0.25.0/EsdzLgcAyudLYkMqiHXGuq2xMhPhoP1GRQWb14jZxZbY.tar.zst",
    playwright: "../../package/main.roc",
    url: "https://github.com/niclas-ahden/roc-url/releases/download/0.6.1/95CwyLo97aKZ5twTy6VtkmmhF6MFKMr7hvPeMi6U7bAF.tar.zst",
    spec: "https://github.com/niclas-ahden/roc-spec/releases/download/0.5.0/AT7cTMFey3aL2SFQZcp2KTTDL82u79WepEy2yUcAtV4A.tar.zst",
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

# A Hold rule keeps the page's fetch pending, so the page stays in the state
# it shows while the request is in flight ("Fetching") for as long as the
# test looks at it, and release! then answers the request. The page fetches
# /api/greeting on a click and shows "<status> <body>".
main! : List(OsStr) => Try({}, _)
main! = |_args| {
    url = worker_url!({})
    { browser, page } = Playwright.launch_page_with!(
        { new: Cmd.new_str, spawn!: Cmd.spawn! },
        { timeout: TimeoutMilliseconds(5000) },
    )?

    page.navigate!(Url.to_str(Url.append_path(url, ["route-test"]).ok_or(url)))?

    # Held, looked at twice, then fulfilled: the in-flight state lasts across
    # commands, and the answer is whatever the test gives.
    page.with_routes!([{ pattern: "**/api/greeting", method: AnyMethod, action: Hold }], |routed| {
        routed.find("#fetch").click!()?
        assert!(routed.find("#result").has_text("Fetching")) ? |e| HeldFetchShouldStayPending(Str.inspect(e))
        assert!(routed.find("#result").has_text("Fetching")) ? |e| HeldFetchShouldStillBePending(Str.inspect(e))
        released = routed.release!(Fulfill({ status: 418, headers: [], body: Str.to_utf8("teapot") }))?
        if released != 1 { Err(ReleaseShouldAnswerOneRequest(released))? } else { {} }
        assert!(routed.find("#result").has_text("418 teapot")) ? |e| ReleaseShouldAnswerTheRequest(Str.inspect(e))
        # Released once, there is nothing left to release.
        match routed.release!(Continue) {
            Err(NoHeldRequest) => Ok({})
            Ok(_) => Err(SecondReleaseShouldFindNothingHeld)
            Err(other) => Err(other)
        }
    })?

    # Held, then let through: the real server answers.
    page.with_routes!([{ pattern: "**/api/greeting", method: AnyMethod, action: Hold }], |routed| {
        routed.find("#post").click!()?
        assert!(routed.find("#result").has_text("Fetching")) ? |e| HeldPostShouldStayPending(Str.inspect(e))
        _ = routed.release!(Continue)?
        assert!(routed.find("#result").has_text("200 greeting posted")) ? |e| ContinueShouldReachTheServer(Str.inspect(e))
        Ok({})
    })?

    # A request still held when the block ends is let through.
    page.with_routes!([{ pattern: "**/api/greeting", method: AnyMethod, action: Hold }], |routed| {
        routed.find("#fetch").click!()?
        assert!(routed.find("#result").has_text("Fetching")) ? |e| HeldFetchShouldStayPendingUntilTheBlockEnds(Str.inspect(e))
        Ok({})
    })?
    assert!(page.find("#result").has_text("200 hello from the server")) ? |e| TheBlockEndShouldLetTheRequestThrough(Str.inspect(e))

    # The same when the block ends in an error.
    gave_up = page.with_routes!([{ pattern: "**/api/greeting", method: AnyMethod, action: Hold }], |routed| {
        routed.find("#post").click!()?
        assert!(routed.find("#result").has_text("Fetching")) ? |e| HeldPostShouldStayPendingUntilTheBlockFails(Str.inspect(e))
        Err(BodyGaveUp)
    })
    match gave_up {
        Err(BodyGaveUp) => Ok({})
        Ok({}) => Err(TheBodysErrorShouldComeBack)
        Err(other) => Err(other)
    }?
    assert!(page.find("#result").has_text("200 greeting posted")) ? |e| AFailedBlockShouldLetTheRequestThrough(Str.inspect(e))

    # The page fires the request only after the click has returned, so
    # release! starts with nothing held and waits for it.
    page.with_routes!([{ pattern: "**/api/greeting", method: AnyMethod, action: Hold }], |routed| {
        routed.find("#fetch-later").click!()?
        released = routed.release!(Fulfill({ status: 418, headers: [], body: Str.to_utf8("late teapot") }))?
        if released != 1 { Err(ReleaseShouldWaitForTheLateRequest(released))? } else { {} }
        assert!(routed.find("#result").has_text("418 late teapot")) ? |e| ReleaseShouldAnswerTheLateRequest(Str.inspect(e))
        Ok({})
    })?

    # Released with an Abort, the fetch fails the way the network fails it.
    page.with_routes!([{ pattern: "**/api/greeting", method: AnyMethod, action: Hold }], |routed| {
        routed.find("#fetch").click!()?
        _ = routed.release!(Abort(Failed))?
        assert!(routed.find("#result").has_text("failed")) ? |e| AbortShouldFailTheFetch(Str.inspect(e))
        Ok({})
    })?

    # Two requests at once are both held and both answered. release! waits
    # for the first only, so the second is answered by the same release or
    # by the next one, never lost.
    page.with_routes!([{ pattern: "**/api/greeting", method: AnyMethod, action: Hold }], |routed| {
        routed.find("#fetch-twice").click!()?
        first = routed.release!(Continue)?
        second = if first == 2 { 0 } else { routed.release!(Continue)? }
        if first + second != 2 { Err(BothRequestsShouldBeAnswered(first, second))? } else { {} }
        assert!(routed.find("#result").has_text("200 hello from the server")) ? |e| BothRequestsShouldReachTheServer(Str.inspect(e))
        Ok({})
    })?

    # A block lets through what its own rules held and nothing else: the
    # GET the outer block holds stays pending through the inner block, whose
    # end lets the POST through.
    page.with_routes!([{ pattern: "**/api/greeting", method: GET, action: Hold }], |outer| {
        outer.find("#fetch").click!()?
        assert!(outer.find("#result").has_text("Fetching")) ? |e| OuterGetShouldStayPending(Str.inspect(e))
        outer.with_routes!([{ pattern: "**/api/greeting", method: POST, action: Hold }], |inner| {
            inner.find("#post").click!()?
            assert!(inner.find("#result").has_text("Fetching")) ? |e| InnerPostShouldStayPending(Str.inspect(e))
            Ok({})
        })?
        assert!(outer.find("#result").has_text("200 greeting posted")) ? |e| InnerBlockEndShouldLetThePostThrough(Str.inspect(e))
        released = outer.release!(Fulfill({ status: 418, headers: [], body: Str.to_utf8("still held") }))?
        if released != 1 { Err(OuterGetShouldStillBeHeld(released))? } else { {} }
        assert!(outer.find("#result").has_text("418 still held")) ? |e| OuterReleaseShouldAnswerTheGet(Str.inspect(e))
        Ok({})
    })?

    # Nothing held on the page: release! is an error, not a no-op.
    match page.release!(Continue) {
        Err(NoHeldRequest) => Ok({})
        Ok(_) => Err(ReleaseWithNothingHeldShouldFail)
        Err(other) => Err(other)
    }?

    # A Continue rule listed first carves an exception out of a wider rule.
    teapot = Fulfill({ status: 418, headers: [], body: Str.to_utf8("teapot") })
    page.with_routes!(
        [
            { pattern: "**/api/greeting", method: GET, action: Continue },
            { pattern: "**/api/*", method: AnyMethod, action: teapot },
        ],
        |routed| {
            routed.find("#fetch").click!()?
            assert!(routed.find("#result").has_text("200 hello from the server")) ? |e| ContinueRuleShouldLetGetThrough(Str.inspect(e))
            routed.find("#post").click!()?
            assert!(routed.find("#result").has_text("418 teapot")) ? |e| WiderRuleShouldStillAnswerPost(Str.inspect(e))
            Ok({})
        },
    )?

    browser.close!()
}
