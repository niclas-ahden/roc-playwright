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
    { browser, page } = Playwright.launch_page_with!(
        { new: Cmd.new_str, spawn!: Cmd.spawn! },
        { timeout: TimeoutMilliseconds(5000) },
    )?

    page.navigate!(Url.to_str(url))?

    # find is strict: a multi-match selector errors instead of silently using
    # the first match. "nav a" matches five links on the home page.
    match page.find("nav a").text!() {
        Err(TextContentError(msg)) => Assert.true(Str.contains(msg, "strict mode violation")) ? |e| TextStrictViolation(e)
        _ => { crash "text! on a multi-match selector should be a strict mode violation" }
    }

    match page.find("nav a").click!() {
        Err(ClickError(msg)) => Assert.true(Str.contains(msg, "strict mode violation")) ? |e| ClickStrictViolation(e)
        _ => { crash "click! on a multi-match selector should be a strict mode violation" }
    }

    match page.find("nav a").is_visible!() {
        Err(IsVisibleError(msg)) => Assert.true(Str.contains(msg, "strict mode violation")) ? |e| IsVisibleStrictViolation(e)
        _ => { crash "is_visible! on a multi-match selector should be a strict mode violation" }
    }

    # The driver enforces strictness for expect-based claims itself, and
    # a violation fails immediately rather than polling until the timeout.
    match assert!(page.find("nav a").has_text("Page 1")) {
        Err(ExpectError(msg)) => Assert.true(Str.contains(msg, "strict mode violation")) ? |e| AssertStrictViolation(e)
        _ => { crash "has_text on a multi-match selector should be a strict mode violation" }
    }

    # A unique match still works, and narrowing a multi-match with nth does too
    heading = page.find("h1").text!()?
    Assert.eq(heading, "Welcome to the Test Server") ? |e| UniqueMatchText(e)
    first_link = page.find_all("nav a").first().text!()?
    Assert.eq(first_link, "Page 1") ? |e| NthMatchText(e)

    # The page-level string API keeps Playwright's page.click-style behavior
    # and reads the first match without complaint.
    page_level = page.text_content!("nav a")?
    Assert.eq(page_level, "Page 1") ? |e| PageLevelFirstMatch(e)

    # check! goes through JS rather than the driver, so its strictness is
    # enforced separately. Three checkboxes match input[type="checkbox"].
    page.navigate!(Url.to_str(Url.append_path(url, ["checkbox-test"]).ok_or(url)))?
    match page.find("input[type=\"checkbox\"]").check!() {
        Err(CheckError(msg)) => Assert.true(Str.contains(msg, "strict mode violation")) ? |e| CheckStrictViolation(e)
        _ => { crash "check! on a multi-match selector should be a strict mode violation" }
    }
    page.find("#plain").check!()?

    browser.close!()
}
