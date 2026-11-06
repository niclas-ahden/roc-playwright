app [main!] {
    pf: platform "https://github.com/niclas-ahden/basic-cli/releases/download/0.30.0/6XAUy48Jp34GANurMrMf74DtF7NdpkhnqFLHE4gHNzJy.tar.zst",
    playwright: "../../package/main.roc",
    url: "https://github.com/niclas-ahden/roc-url/releases/download/0.7.1/AuBv5v9TGGUS4yRtC8tLEVyEr7MkaReZCeuu2sYANn8F.tar.zst",
    spec: "https://github.com/niclas-ahden/roc-spec/releases/download/0.7.0/BGjQKbG9U3V8cH6mRbypUAFVqFoVEu6n9bsA3QmFL1f4.tar.zst",
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

## Back and Forward move through the page's history and Reload loads the
## page again, each waiting until its page has loaded, so the next check
## finds it. Forward with nothing to go forward to does nothing.
main! : List(OsStr) => Try({}, _)
main! = |_args| {
    url = worker_url!({})
    { browser, page } = Playwright.launch_page!(
        { new: Cmd.new, os_str: OsStr.from_str, spawn!: Cmd.Command.spawn_leashed!, millis: Duration.millis },
        Chromium(DefaultChannel),
    )?
    at = |path| Url.to_str(Url.append_path(url, [path]).ok_or(url))

    # Nothing to go forward to: the page stays where it is.
    page.navigate!(at("page1"))?
    page.go_forward!()?
    Playwright.assert!(page.has_url(at("page1")))?

    page.navigate!(at("page2"))?
    page.go_back!()?
    Playwright.assert!(page.has_url(at("page1")))?
    Assert.eq(page.text_content!("h1")?, "Page 1") ? |e| BackNotOnPage1(e)

    page.go_forward!()?
    Playwright.assert!(page.has_url(at("page2")))?
    Assert.eq(page.text_content!("h1")?, "Page 2") ? |e| ForwardNotOnPage2(e)

    # Reload loads a fresh document: a mark left on the old one is gone.
    _ = page.evaluate!("(window.__mark = 'old', 'set')")?
    page.reload!()?
    Playwright.assert!(page.has_url(at("page2")))?
    Assert.eq(page.evaluate!("String(window.__mark)")?, "undefined") ? |e| ReloadKeptDocument(e)

    browser.close!()
}
