app [main!] {
    pf: platform "https://github.com/niclas-ahden/basic-cli/releases/download/0.28.0/AP9SGT1yrhCKcFxKcoA5tBkNCM6ibBjBxcQGMTb6krev.tar.zst",
    playwright: "../../package/main.roc",
    url: "https://github.com/niclas-ahden/roc-url/releases/download/0.7.0/DCKNTirZCLugy1ZydPLrYpefR71RYq1HFUpgQVSNvaFy.tar.zst",
    spec: "https://github.com/niclas-ahden/roc-spec/releases/download/0.6.0/9ThTkhd7zrviwQpM3LvGd7pvzGhr4ZXNmWJV7pTJc9AJ.tar.zst",
}

import pf.Cmd
import pf.Env
import pf.OsStr
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

# A routed request reaches the test as one driver message that carries its
# whole body. The page posts 8 MiB, which basic-cli's default budget for
# unread driver output (1 MiB) would not hold: the driver would be cancelled
# and the next command would find its stdout closed. The hooks are the plain
# ones, so the budget is the package's own.
main! : List(OsStr) => Try({}, _)
main! = |_args| {
    url = worker_url!({})
    { browser, page } = Playwright.launch_page_with!(
        { new: Cmd.new_str, spawn!: Cmd.spawn! },
        { timeout: TimeoutMilliseconds(10000) },
    )?

    page.navigate!(Url.to_str(Url.append_path(url, ["route-test"]).ok_or(url)))?

    # Held, then let through to the server.
    page.with_routes!([{ pattern: "**/api/greeting", method: POST, action: Hold }], |routed| {
        routed.find("#post-large").click!()?
        assert!(routed.find("#result").has_text("Fetching")) ? |e| HeldLargePostShouldStayPending(Str.inspect(e))
        released = routed.release!(Continue)?
        if released != 1 { Err(ReleaseShouldAnswerTheLargePost(released))? } else { {} }
        assert!(routed.find("#result").has_text("200 greeting posted")) ? |e| LargePostShouldReachTheServer(Str.inspect(e))
        Ok({})
    })?

    # Answered by a rule straight away.
    teapot = Fulfill({ status: 418, headers: [], body: Str.to_utf8("large teapot") })
    page.with_routes!([{ pattern: "**/api/greeting", method: POST, action: teapot }], |routed| {
        routed.find("#post-large").click!()?
        assert!(routed.find("#result").has_text("418 large teapot")) ? |e| RuleShouldAnswerTheLargePost(Str.inspect(e))
        Ok({})
    })?

    # The driver is still there for the next command.
    assert!(page.find("h1").has_text("Route Test")) ? |e| DriverShouldOutliveTheLargePosts(Str.inspect(e))

    browser.close!()
}
