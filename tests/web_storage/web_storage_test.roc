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

## local_storage and session_storage read and write the page's storage for
## the origin it shows, separately, and what they write is what the page's
## own code reads.
main! : List(OsStr) => Try({}, _)
main! = |_args| {
    url = worker_url!({})
    { browser, page } = Playwright.launch_page_with!(
        { new: Cmd.new, os_str: OsStr.from_str, spawn!: Cmd.Command.spawn_leashed!, millis: Duration.millis },
        { timeout: TimeoutMilliseconds(5000) },
    )?
    page.navigate!(Url.to_str(Url.append_path(url, ["page1"]).ok_or(url)))?

    local = page.local_storage()
    session = page.session_storage()

    # What the page writes, the test reads.
    _ = page.evaluate!("(localStorage.setItem('theme', 'dark'), 'set')")?
    Assert.eq(local.get_item!("theme")?, "dark") ? |e| ReadsPageWrite(e)

    # What the test writes, the page reads.
    local.set_item!("token", "abc")?
    Assert.eq(page.evaluate!("localStorage.getItem('token')")?, "abc") ? |e| PageReadsWrite(e)

    session.set_item!("step", "2")?
    Assert.eq(session.get_item!("step")?, "2") ? |e| SessionRead(e)
    session_has_theme =
        match session.get_item!("theme") {
            Err(StorageItemNotFound) => Bool.False
            _ => Bool.True
        }
    Assert.eq(session_has_theme, Bool.False) ? |e| KindsSeparate(e)

    # The browser decides the order, so the check does not depend on it.
    items = local.items!()?
    Assert.eq(items.len(), 2) ? |e| ItemCount(e)
    Assert.eq(items.contains({ name: "theme", value: "dark" }), Bool.True) ? |e| ItemTheme(e)
    Assert.eq(items.contains({ name: "token", value: "abc" }), Bool.True) ? |e| ItemToken(e)

    local.remove_item!("theme")?
    theme_gone =
        match local.get_item!("theme") {
            Err(StorageItemNotFound) => Bool.True
            _ => Bool.False
        }
    Assert.eq(theme_gone, Bool.True) ? |e| Removed(e)

    local.clear!()?
    Assert.eq(local.items!()?, []) ? |e| Cleared(e)
    Assert.eq(session.get_item!("step")?, "2") ? |e| ClearOnlyLocal(e)

    browser.close!()
}
