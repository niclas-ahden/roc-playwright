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
    select_url = Url.to_str(Url.append_path(url, ["keyboard-select"]).ok_or(url))

    # Test Control+A
    control_selects = test_select_all!(select_url, Control)?

    # Test Meta+A
    meta_selects = test_select_all!(select_url, Meta)?

    # Test ControlOrMeta+A
    control_or_meta_selects = test_select_all!(select_url, ControlOrMeta)?

    # ControlOrMeta must always work
    Assert.true(control_or_meta_selects) ? |e| ControlOrMetaDidNotSelectAll(e)

    # Exactly one of Control or Meta should work (platform-dependent)
    exactly_one_native = control_selects != meta_selects
    Assert.true(exactly_one_native) ? |e| ExpectedExactlyOneNativeModifierToWork(e)

    Ok({})
}

## Launch a fresh browser, navigate to the page, press modifier+A, check if all text selected.
test_select_all! : Str, Playwright.Modifier => Try(Bool, _)
test_select_all! = |page_url, modifier| {
    { browser, page } = Playwright.launch_page_with!(
        { new: Cmd.new_str, spawn!: Cmd.spawn! },
        { timeout: TimeoutMilliseconds(5000) },
    )?
    page.navigate!(page_url)?
    page.click!("#text-area")?
    page.key_press_targetless!(KeyA, [modifier])?

    selection = page.text_content!("#selection-info")?
    browser.close!()?
    Ok(selection == "Selection: 58 characters")
}
