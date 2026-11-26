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

## select_option! picks options by value, by label, by either, or by index,
## fires `change` like a user's selection, and returns the values of the
## selected options. A multiple select takes every match, and an empty list
## deselects everything.
main! : List(OsStr) => Try({}, _)
main! = |_args| {
    url = worker_url!({})
    { browser, page } = Playwright.launch_page_with!(
        { new: Cmd.new, os_str: OsStr.from_str, spawn!: Cmd.Command.spawn_leashed!, millis: Duration.millis },
        { timeout: TimeoutMilliseconds(5000) },
    )?
    page.navigate!(Url.to_str(Url.append_path(url, ["select-test"]).ok_or(url)))?

    color = page.find("#color")
    Assert.eq(color.select_option!(Values(["b"]))?, ["b"]) ? |e| ByValue(e)
    Playwright.assert!(color.has_value("b"))?
    Playwright.assert!(page.find("#changes").has_text("changes: 1"))?

    Assert.eq(color.select_option!(Labels(["Green"]))?, ["g"]) ? |e| ByLabel(e)
    Assert.eq(color.select_option!(ValuesOrLabels(["Red"]))?, ["r"]) ? |e| ByValueOrLabel(e)
    Assert.eq(color.select_option!(ValuesOrLabels(["g"]))?, ["g"]) ? |e| ByValueOrLabelValue(e)
    Assert.eq(color.select_option!(Indexes([2]))?, ["b"]) ? |e| ByIndex(e)

    # The page-level function, like the other actions.
    Assert.eq(Playwright.select_option!(page, "#color", Values(["r"]))?, ["r"]) ? |e| PageLevel(e)

    toppings = page.find("#toppings")
    Assert.eq(toppings.select_option!(Indexes([0, 2]))?, ["ham", "cheese"]) ? |e| Multiple(e)
    Assert.eq(toppings.select_option!(Values([]))?, []) ? |e| DeselectAll(e)

    # An option that is not there fails within the timeout instead of
    # selecting nothing.
    _ = Assert.err(color.select_option!(Values(["purple"]))) ? |e| NoSuchOption(e)

    browser.close!()
}
