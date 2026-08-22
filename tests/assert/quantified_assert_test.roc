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
    # has_count and has_texts re-check until the timeout when they fail,
    # so this test of failure paths keeps the timeout short.
    { browser, page } = Playwright.launch_page_with!(
        { new: Cmd.new_str, spawn!: Cmd.spawn! },
        { timeout: TimeoutMilliseconds(1000) },
    )?

    page.navigate!(Url.to_str(url))?

    nav_links = page.find_all("nav a")
    nothing = page.find_all(".does-not-match-anything")

    # Quantified claims over every match
    assert!(nav_links.all_visible())?
    assert!(nav_links.any_has_text("Form"))?
    assert!(nav_links.any_contains_text("Page"))?
    assert!(nav_links.none_has_text("Nope"))?
    assert!(nav_links.none_hidden())?

    match assert!(nav_links.all_has_text("Form")) {
        Err(AssertionFailed(msg)) => Assert.true(Str.contains(msg, "expected every match")) ? |e| AllFailureMessage(e)
        _ => { crash "all_has_text with differing texts should fail with AssertionFailed" }
    }

    match assert!(nav_links.any_has_text("Nope")) {
        Err(AssertionFailed(msg)) => Assert.true(Str.contains(msg, "expected some match")) ? |e| AnyFailureMessage(e)
        _ => { crash "any_has_text with an absent text should fail with AssertionFailed" }
    }

    match assert!(nav_links.none_has_text("Form")) {
        Err(AssertionFailed(msg)) => Assert.true(Str.contains(msg, "expected no match")) ? |e| NoneFailureMessage(e)
        _ => { crash "none_has_text with a present text should fail with AssertionFailed" }
    }

    # An empty set fails presence claims and passes absence claims
    match assert!(nothing.all_visible()) {
        Err(AssertionFailed(msg)) => Assert.true(Str.contains(msg, "nothing matched the selector")) ? |e| AllOnEmptyMessage(e)
        _ => { crash "all_visible on an empty set should fail with AssertionFailed" }
    }

    match assert!(nothing.any_visible()) {
        Err(AssertionFailed(_)) => {}
        _ => { crash "any_visible on an empty set should fail with AssertionFailed" }
    }

    assert!(nothing.none_visible())?

    # Claims about the collection as a whole
    assert!(nav_links.has_count(5))?
    assert!(nav_links.is_not_empty())?
    assert!(nothing.is_empty())?
    assert!(nav_links.has_texts(["Page 1", "Page 2", "Form", "Click Test", "Visibility Test"]))?

    match assert!(nav_links.has_count(3)) {
        Err(AssertionFailed(msg)) => Assert.true(Str.contains(msg, "expected 3 matches, got 5")) ? |e| CountFailureMessage(e)
        _ => { crash "has_count with the wrong count should fail with AssertionFailed" }
    }

    match assert!(nav_links.has_texts(["Page 1"])) {
        Err(AssertionFailed(_)) => {}
        _ => { crash "has_texts with the wrong list should fail with AssertionFailed" }
    }

    browser.close!()
}
