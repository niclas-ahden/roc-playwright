app [main!] {
    pf: platform "https://github.com/niclas-ahden/basic-cli/releases/download/0.30.0/6XAUy48Jp34GANurMrMf74DtF7NdpkhnqFLHE4gHNzJy.tar.zst",
    playwright: "../../package/main.roc",
    url: "https://github.com/niclas-ahden/roc-url/releases/download/0.7.1/AuBv5v9TGGUS4yRtC8tLEVyEr7MkaReZCeuu2sYANn8F.tar.zst",
    spec: "https://github.com/niclas-ahden/roc-spec/releases/download/0.7.0/BGjQKbG9U3V8cH6mRbypUAFVqFoVEu6n9bsA3QmFL1f4.tar.zst",
}

import pf.Cmd
import pf.Env
import pf.OsStr
import pf.Stdout
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
main! = |_args|
    match Env.var_str!(OsStr.from_str("CI")) {
        Ok(_) => {
            Stdout.line!("Skipped: WebKit requires system libraries not available in CI")?
            Ok({})
        }

        Err(_) => {
            url = worker_url!({})
            { browser, page } = Playwright.launch_page!(
                { new: Cmd.new_str, spawn!: Cmd.spawn! },
                WebKit,
            )?

            page.navigate!(Url.to_str(url))?

            title = page.get_title!()?
            Assert.eq(title, "Test Home Page") ? |e| Title(e)

            h1 = page.text_content!("h1")?
            Assert.eq(h1, "Welcome to the Test Server") ? |e| H1(e)

            browser.close!()
        }
    }
