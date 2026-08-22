app [main!] {
    pf: platform "https://github.com/niclas-ahden/basic-cli/releases/download/0.23.0/7NpDhuqoqGFedmVLvmm1zjq37GCmaFGzwr5sz4ch9wTK.tar.zst",
    playwright: "../../package/main.roc",
    url: "https://github.com/niclas-ahden/roc-url/releases/download/0.6.1/95CwyLo97aKZ5twTy6VtkmmhF6MFKMr7hvPeMi6U7bAF.tar.zst",
    spec: "https://github.com/niclas-ahden/roc-spec/releases/download/0.3.0/2v2CV8CLXRJmQRvfoHtPngAUGgE8jL6DDgXbugZhFVf5.tar.zst",
}

import pf.Cmd
import pf.Env
import pf.OsStr exposing [OsStr]
import playwright.Playwright exposing [assert!, assert_with!]
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
    # A failing assertion re-checks the page until the timeout expires, so
    # this test of failure paths keeps the timeout short.
    { browser, page } = Playwright.launch_page_with!(
        { new: Cmd.new_str, spawn!: Cmd.spawn! },
        { timeout: TimeoutMilliseconds(1000) },
    )?

    page.navigate!(Url.to_str(url))?

    # Passing claims
    assert!(page.find("h1").has_text("Welcome to the Test Server"))?
    assert!(page.find("h1").contains_text("Test Server"))?
    assert!(page.find("#content").is_visible())?
    assert!(page.find_all("nav a").first().has_attribute("href", "/page1"))?
    assert!(page.find_all("nav a").last().has_text("Visibility Test"))?

    # Text comparison normalizes whitespace, like Playwright's toHaveText:
    # nav's raw textContent is newlines and indentation around each link.
    assert!(page.find("nav").has_text("Page 1 Page 2 Form Click Test Visibility Test"))?

    # matches_text: the pattern is searched anywhere unless anchored, and an
    # invalid pattern is a usage error rather than a failed claim
    assert!(page.find("h1").matches_text("Test"))?
    assert!(page.find("h1").matches_text("^Welcome to the Test Server$"))?
    assert!(page.find("h1").not_matches_text("\\d{4}"))?
    match assert!(page.find("h1").matches_text("^Test$")) {
        Err(AssertionFailed(msg)) => Assert.true(Str.contains(msg, "expected text matching /^Test$/")) ? |e| MatchesFailureMessage(e)
        _ => { crash "an anchored pattern matching a fragment should fail with AssertionFailed" }
    }
    match assert!(page.find("h1").matches_text("(unclosed")) {
        Err(ExpectError(msg)) => Assert.true(Str.contains(msg, "Invalid regular expression")) ? |e| InvalidRegexMessage(e)
        _ => { crash "an invalid pattern should fail with ExpectError" }
    }

    # A missing element counts as hidden, like Playwright's toBeHidden
    assert!(page.find("#does-not-exist").is_hidden())?

    # Existence, independent of visibility
    assert!(page.find("h1").exists())?
    assert!(page.find("#does-not-exist").not_exists())?

    match assert!(page.find("#does-not-exist").exists()) {
        Err(AssertionFailed(msg)) => Assert.true(Str.contains(msg, "none exists")) ? |e| ExistsFailureMessage(e)
        _ => { crash "exists on a missing element should fail with AssertionFailed" }
    }

    match assert!(page.find("h1").not_exists()) {
        Err(AssertionFailed(msg)) => Assert.true(Str.contains(msg, "but one exists")) ? |e| NotExistsFailureMessage(e)
        _ => { crash "not_exists on a present element should fail with AssertionFailed" }
    }

    # Failing claims carry the selector, expectation, and actual value
    match assert!(page.find("h1").has_text("Nope")) {
        Err(AssertionFailed(msg)) => Assert.true(Str.contains(msg, "expected text \"Nope\"")) ? |e| WrongTextFailureMessage(e)
        _ => { crash "has_text with the wrong text should fail with AssertionFailed" }
    }

    # assert_with!: a label names the claim's intent in front of the failure
    # message, and does not disturb a passing claim
    match assert_with!(page.find("h1").has_text("Nope"), { label: "greeting" }) {
        Err(AssertionFailed(msg)) => Assert.true(msg.starts_with("greeting: h1:")) ? |e| LabelPrefix(e)
        _ => { crash "a labeled failing claim should fail with AssertionFailed" }
    }
    assert_with!(page.find("h1").has_text("Welcome to the Test Server"), { label: "greeting" })?

    # assert_with!: a per-assert timeout overrides the page's, and the
    # failure message reports the effective one
    match assert_with!(page.find("h1").has_text("Nope"), { timeout: TimeoutMilliseconds(100) }) {
        Err(AssertionFailed(msg)) => Assert.true(Str.contains(msg, "timed out after 100ms")) ? |e| TimeoutOverride(e)
        _ => { crash "has_text with the wrong text should fail with AssertionFailed" }
    }

    # A negated claim fails while the value still matches
    match assert!(page.find("h1").not_has_text("Welcome to the Test Server")) {
        Err(AssertionFailed(msg)) => Assert.true(Str.contains(msg, "other than")) ? |e| NotTextFailureMessage(e)
        _ => { crash "not_has_text with the current text should fail with AssertionFailed" }
    }

    match assert!(page.find("h1").has_attribute("href", "/x")) {
        Err(AssertionFailed(msg)) => Assert.true(Str.contains(msg, "no href attribute")) ? |e| AbsentAttributeFailureMessage(e)
        _ => { crash "has_attribute on an element without it should fail with AssertionFailed" }
    }

    match assert!(page.find("#content").is_hidden()) {
        Err(AssertionFailed(msg)) => Assert.true(Str.contains(msg, "expected to be hidden")) ? |e| VisibleElementHiddenFailureMessage(e)
        _ => { crash "is_hidden on a visible element should fail with AssertionFailed" }
    }

    # State claims fail with the state the element is actually in
    page.navigate!(Url.to_str(Url.append_path(url, ["checkbox-test"]).ok_or(url)))?
    match assert!(page.find("#plain").is_checked()) {
        Err(AssertionFailed(msg)) => Assert.true(Str.contains(msg, "expected to be checked, but it is unchecked")) ? |e| UncheckedFailureMessage(e)
        _ => { crash "is_checked on an unchecked checkbox should fail with AssertionFailed" }
    }

    page.navigate!(Url.to_str(Url.append_path(url, ["attributes-test"]).ok_or(url)))?
    match assert!(page.find("#enabled-btn").is_disabled()) {
        Err(AssertionFailed(msg)) => Assert.true(Str.contains(msg, "expected to be disabled, but it is enabled")) ? |e| EnabledFailureMessage(e)
        _ => { crash "is_disabled on an enabled button should fail with AssertionFailed" }
    }

    # Emptiness of a single element: no text, or no value for inputs
    assert!(page.find("#empty-div").is_empty())?
    assert!(page.find("#test-link").is_not_empty())?

    match assert!(page.find("#test-link").is_empty()) {
        Err(AssertionFailed(msg)) => Assert.true(Str.contains(msg, "but it has content")) ? |e| EmptyFailureMessage(e)
        _ => { crash "is_empty on an element with text should fail with AssertionFailed" }
    }

    match assert!(page.find("#empty-div").is_not_empty()) {
        Err(AssertionFailed(msg)) => Assert.true(Str.contains(msg, "but it is empty")) ? |e| NotEmptyFailureMessage(e)
        _ => { crash "is_not_empty on an empty element should fail with AssertionFailed" }
    }

    # has_class matches whole class names in any order, not substrings:
    # #test-link is class="nav-link primary"
    assert!(page.find("#test-link").has_class("primary"))?
    assert!(page.find("#test-link").has_class("primary nav-link"))?
    match assert!(page.find("#test-link").has_class("nav")) {
        Err(AssertionFailed(msg)) => Assert.true(Str.contains(msg, "got class list \"nav-link primary\"")) ? |e| ClassFailureMessage(e)
        _ => { crash "has_class with a substring of a class name should fail with AssertionFailed" }
    }

    browser.close!()
}
