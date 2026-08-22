app [main!] {
    pf: platform "https://github.com/niclas-ahden/basic-cli/releases/download/0.23.0/7NpDhuqoqGFedmVLvmm1zjq37GCmaFGzwr5sz4ch9wTK.tar.zst",
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

    # Assertions auto-wait: #delayed is added to the page 500ms after load,
    # and the assertions pass without an explicit wait_for! because the
    # driver re-checks until the expectation holds.
    page.navigate!(Url.to_str(Url.append_path(url, ["delayed-element"]).ok_or(url)))?
    assert!(page.find("#delayed").has_text("I appeared!"))?
    assert!(page.find_all("#delayed").has_count(1))?

    # Checkbox state, read as the live checked property rather than the
    # checked attribute (which never changes after load)
    page.navigate!(Url.to_str(Url.append_path(url, ["checkbox-test"]).ok_or(url)))?
    assert!(page.find("#prechecked").is_checked())?
    assert!(page.find("#plain").is_unchecked())?
    page.find("#plain").check!()?
    assert!(page.find("#plain").is_checked())?

    # Enabled and disabled
    page.navigate!(Url.to_str(Url.append_path(url, ["attributes-test"]).ok_or(url)))?
    assert!(page.find("#disabled-btn").is_disabled())?
    assert!(page.find("#enabled-btn").is_enabled())?

    # Negated claims hold when the value differs
    assert!(page.find("#test-link").not_has_text("Nope"))?
    assert!(page.find("#test-link").not_has_class("secondary"))?
    assert!(page.find("#test-link").not_has_attribute("href", "/nope"))?

    # A claim is a plain value: build once, assert repeatedly
    link_is_visible = page.find("#test-link").is_visible()
    assert!(link_is_visible)?
    assert!(link_is_visible)?

    # Page-level expectations: title and URL, exact, substring, and negated
    assert!(page.has_title("Attributes Test"))?
    assert!(page.has_url(Url.to_str(Url.append_path(url, ["attributes-test"]).ok_or(url))))?
    assert!(page.title_contains("Attributes"))?
    assert!(page.url_contains("/attributes-test"))?
    assert!(page.not_has_title("Nope"))?
    assert!(page.not_url_contains("/nope"))?

    # Regex claims: the pattern is searched anywhere unless anchored
    assert!(page.title_matches("^Attributes Test$"))?
    assert!(page.title_matches("Test"))?
    assert!(page.not_title_matches("\\d"))?
    assert!(page.url_matches("/attributes-test$"))?
    assert!(page.not_url_matches("/orders/\\d+"))?

    browser.close!()
}
