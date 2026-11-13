app [main!] {
    pf: platform "https://github.com/niclas-ahden/basic-cli/releases/download/0.31.0/Ff3fkK1TjYTVxMj9V21FP24ojTJXYk314Fbo1whBZ6Yf.tar.zst",
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

## Saves a passkey for the page's host and answers its raw id in base64,
## as CDP names credentials.
create_passkey : Str
create_passkey =
    \\navigator.credentials.create({ publicKey: {
    \\  rp: { id: "localhost", name: "Test" },
    \\  user: { id: new Uint8Array([1, 2, 3, 4]), name: "anna@example.com", displayName: "Anna" },
    \\  challenge: new Uint8Array(32),
    \\  pubKeyCredParams: [{ type: "public-key", alg: -7 }],
    \\  authenticatorSelection: { residentKey: "required", userVerification: "required" },
    \\} }).then((c) => btoa(String.fromCharCode(...new Uint8Array(c.rawId))))

## Signs in with any passkey of the host, without naming one, and answers
## the one used in base64, or the error's name.
use_passkey : Str
use_passkey =
    \\navigator.credentials.get({ publicKey: {
    \\  rpId: "localhost", challenge: new Uint8Array(32), userVerification: "required",
    \\} }).then((c) => btoa(String.fromCharCode(...new Uint8Array(c.rawId))), (e) => e.name)

main! : List(OsStr) => Try({}, _)
main! = |_args| {
    url = worker_url!({})
    { browser, page } = Playwright.launch_page_with!(
        { new: Cmd.new, os_str: OsStr.from_str, spawn!: Cmd.Command.spawn_leashed!, millis: Duration.millis },
        { timeout: TimeoutMilliseconds(5000) },
    )?

    page.navigate!(Url.to_str(url))?

    authenticator = page.add_virtual_authenticator!()?
    Assert.eq(authenticator.credentials!()?, []) ? |e| StartsEmpty(e)

    saved_id = page.evaluate!(create_passkey)?
    credentials = authenticator.credentials!()?
    Assert.eq(credentials.len(), 1) ? |e| HoldsTheSavedPasskey(e)
    saved = credentials.first() ? |_| NoCredential
    Assert.eq(saved.credential_id, saved_id) ? |e| SameCredentialId(e)
    Assert.eq(saved.rp_id, "localhost") ? |e| ForTheHost(e)
    Assert.eq(saved.is_resident, Bool.True) ? |e| Discoverable(e)
    Assert.eq(saved.user_handle, "AQIDBA==") ? |e| UserHandleKept(e)

    Assert.eq(page.evaluate!(use_passkey)?, saved_id) ? |e| SignsInWithIt(e)

    authenticator.remove!()?
    # With no authenticator left, headless Chromium has none to ask.
    Assert.eq(page.evaluate!(use_passkey)?, "NotSupportedError") ? |e| GoneAfterRemove(e)

    browser.close!()
}
