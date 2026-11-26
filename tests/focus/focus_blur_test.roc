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

## focus! moves focus to an element, firing `blur` on the one that had it,
## and blur! removes it. is_focused and is_not_focused assert either
## state.
main! : List(OsStr) => Try({}, _)
main! = |_args| {
    url = worker_url!({})
    { browser, page } = Playwright.launch_page_with!(
        { new: Cmd.new, os_str: OsStr.from_str, spawn!: Cmd.Command.spawn_leashed!, millis: Duration.millis },
        { timeout: TimeoutMilliseconds(5000) },
    )?
    page.navigate!(Url.to_str(Url.append_path(url, ["focus-test"]).ok_or(url)))?

    name = page.find("#name")
    email = page.find("#email")
    Playwright.assert!(name.is_not_focused())?

    name.focus!()?
    Playwright.assert!(name.is_focused())?
    Playwright.assert!(page.find("#log").has_text("focus name"))?

    # The page-level function, like the other actions.
    Playwright.focus!(page, "#email")?
    Playwright.assert!(email.is_focused())?
    Playwright.assert!(name.is_not_focused())?
    Playwright.assert!(page.find("#log").has_text("focus name, blur name, focus email"))?

    email.blur!()?
    Playwright.assert!(email.is_not_focused())?
    Playwright.assert!(page.find("#log").has_text("focus name, blur name, focus email, blur email"))?

    # Blurring an element without focus fires nothing.
    Playwright.blur!(page, "#name")?
    Assert.eq(page.text_content!("#log")?, "focus name, blur name, focus email, blur email") ? |e| BlurWithoutFocus(e)

    # A failed assertion names the state the driver saw.
    match Playwright.assert_with!(name.is_focused(), { timeout: TimeoutMilliseconds(200) }) {
        Err(AssertionFailed(msg)) => Assert.eq(msg.contains("expected to be focused, but it is inactive"), Bool.True) ? |e| FailureMessage(e)
        _ => Err(IsFocusedShouldFail)?
    }

    browser.close!()
}
