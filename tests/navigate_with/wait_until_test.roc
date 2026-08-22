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

main! : List(OsStr) => Try({}, _)
main! = |_args| {
    url = worker_url!({})
    { browser, page } = Playwright.launch_page_with!(
        { new: Cmd.new_str, spawn!: Cmd.spawn! },
        { timeout: TimeoutMilliseconds(5000) },
    )?

    # Test navigate_with! using Load (default behavior)
    page.navigate_with!({ url: Url.to_str(url), wait_until: Load })?
    h1_load = page.text_content!("h1")?
    Assert.eq(h1_load, "Welcome to the Test Server") ? |e| LoadWaitUntil(e)

    # Test navigate_with! using DomContentLoaded (faster, doesn't wait for images/stylesheets)
    page.navigate_with!({ url: Url.to_str(Url.append_path(url, ["page1"]).ok_or(url)), wait_until: DomContentLoaded })?
    h1_dom = page.text_content!("h1")?
    Assert.eq(h1_dom, "Page 1") ? |e| DomContentLoadedWaitUntil(e)

    # Test navigate_with! using Commit (fastest, just waits for response)
    page.navigate_with!({ url: Url.to_str(Url.append_path(url, ["page2"]).ok_or(url)), wait_until: Commit })?
    h1_commit = page.text_content!("h1")?
    Assert.eq(h1_commit, "Page 2") ? |e| CommitWaitUntil(e)

    # Test navigate_with! using NetworkIdle (waits for no network activity)
    page.navigate_with!({ url: Url.to_str(url), wait_until: NetworkIdle })?
    h1_idle = page.text_content!("h1")?
    Assert.eq(h1_idle, "Welcome to the Test Server") ? |e| NetworkIdleWaitUntil(e)

    # --- Error cases ---

    # navigate_with! to unreachable URL should error
    unreachable_result = page.navigate_with!({ url: "http://localhost:99999/nonexistent", wait_until: Load })
    _ = Assert.err(unreachable_result) ? |e| UnreachableUrl(e)

    browser.close!()
}
