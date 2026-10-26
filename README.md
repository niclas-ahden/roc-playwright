# roc-playwright

Browser automation in Roc using Playwright. We communicate with Playwright using the same protocol as their Python and Java clients, so the behaviour should be similar, but our API may differ a bit to align better with Roc.

## Example usage

```roc
app [main!] {
	pf: platform "https://github.com/niclas-ahden/basic-cli/releases/download/0.30.0/6XAUy48Jp34GANurMrMf74DtF7NdpkhnqFLHE4gHNzJy.tar.zst",
	playwright: "https://github.com/niclas-ahden/roc-playwright/releases/download/0.13.0/8iK8s82U5DKssLBGrbztTPWN7ymkroW3KtAtCLo7EnJQ.tar.zst",
}

import pf.Cmd
import pf.Duration
import pf.OsStr
import playwright.Playwright exposing [assert!]

main! : List(OsStr) => Try({}, _)
main! = |_args| {
	# The record wires the package to the host platform's process-spawning
	# API, here basic-cli's own functions, passed as they are. The leashed
	# spawn takes the driver and its browsers down with the program however it
	# ends. Everything after launch goes through the returned browser and page.
	{ browser, page } =
		Playwright.launch_page!(
			{ new: Cmd.new, os_str: OsStr.from_str, spawn!: Cmd.Command.spawn_leashed!, millis: Duration.millis },
			Chromium(DefaultChannel),
		)?

	page.navigate!("https://example.com")?

	# Claims re-check the page until they hold or the timeout expires, like
	# every official Playwright client's assertions.
	assert!(page.has_title("Example Domain"))?
	assert!(page.find("h1").has_text("Example Domain"))?
	assert!(page.find_all("p a").is_not_empty())?

	page.find("a").click!()?

	browser.close!()
}
```

## Requirements

- A platform that exposes process spawning with piped stdio, like [niclas-ahden/basic-cli](https://github.com/niclas-ahden/basic-cli) 0.30 (`Cmd.new`, `OsStr.from_str`, `Duration.millis` and `Cmd.Command.spawn_leashed!` or `Cmd.Command.spawn!` as the hooks, and the `Cmd.Command` and `Cmd.Child` methods `args`, `stdin`, `stdout`, `pending_limit`, `write_bytes!`, `read!` and `close!`)
- Playwright, in a version the roc-playwright release you use supports, installed and available in PATH (e.g., `pkgs.playwright-test` using Nix). See [Playwright version support](#playwright-version-support)

## Playwright version support

We use Playwright's internal driver protocol, which upstream treats as private and may change in any release. So check the [release](https://github.com/niclas-ahden/roc-playwright/releases) you're using for its Playwright compatibility: each one names the Playwright version it was tested with in its notes, and other versions are untested.

Since 0.13.0, roc-playwright needs Playwright 1.64 or newer. Playwright 1.64 moved every call's timeout from the call's parameters into its metadata, so an older Playwright cannot work with it, and launching against one fails with `UnsupportedDriver` instead of hanging.

## Synchronous design

Unlike other Playwright clients we use a synchronous, blocking design. This means that each command is sent to the Playwright driver and we wait for its response before proceeding to the next command. This should not affect most uses of Playwright, but is good to know.

We may switch to an async design in the future, but starting out like this makes things easier to get off the ground. If you dig into the code you'll find that we completely disregard message IDs, for example, because they don't matter when we're synchronous.

## Request routing

`page.with_routes!(rules, body!)` answers matching requests from the page itself, so a test can make a save fail with a 500 or drop the connection without any cooperation from the server under test. The rules hold while `body!` runs and are removed when it returns, so a failing test cannot leave the network broken for the next one. Blocks nest, and the innermost first-listed matching rule decides:

```roc
refused = Fulfill({ status: 500, headers: [], body: Str.to_utf8("on fire") })
page.with_routes!([{ pattern: "**/todos", method: POST, action: refused }], |routed| {
    routed.find("#save").click!()?
    assert!(routed.find(".notice").has_text("Could not save"))
})?
```

The action is a `Fulfill` with a status, headers, and a body of bytes, an `Abort(reason)` that fails the request the way the network would (`Abort(Failed)` for the generic case, `Abort(TimedOut)` etc. for a specific one), a `Continue` that lets it through (listed first, it carves an exception out of a wider rule after it), or a `Hold`.

A `Hold` keeps the request pending in the browser, so the page stays in whatever it shows while the request is in flight (a disabled button, a "Saving..." label, a progress row) for as long as the test looks at it, without racing the server. `page.release!(answer)` then answers every held request with a `Fulfill`, an `Abort` or `Continue`, waiting first for one to be held if the page has not fired it yet, and returns how many it answered. A request still held when the block ends is let through.

```roc
page.with_routes!([{ pattern: "**/todos", method: POST, action: Hold }], |routed| {
    routed.find("#save").click!()?
    assert!(routed.find("#save").is_disabled())?
    _ = routed.release!(Fulfill({ status: 500, headers: [], body: Str.to_utf8("on fire") }))?
    assert!(routed.find(".notice").has_text("Could not save"))
})?
```

Patterns are Playwright's URL globs (`*`, `**/`, `{a,b}` with `\` to escape) matched against the whole URL, query string included: a request for `/reviews.json?limit=20` needs `**/reviews.json*`.

## Documentation

View the full API documentation at [https://niclas-ahden.github.io/roc-playwright/](https://niclas-ahden.github.io/roc-playwright/).
