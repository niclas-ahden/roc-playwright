# roc-playwright

Browser automation in Roc using Playwright. We communicate with Playwright using the same protocol as their Python and Java clients, so the behaviour should be similar, but our API may differ a bit to align better with Roc.

## Example usage

```roc
app [main!] {
	pf: platform "https://github.com/niclas-ahden/basic-cli/releases/download/0.24.0/2mx1EsQx1HEG7HdbW2CwUpexvmJZW4nSCpjbur5GXyRe.tar.zst",
	playwright: "https://github.com/niclas-ahden/roc-playwright/releases/download/0.8.0/EBvLYFMoGzZyXLBz5f8fonBbfgp5QhXDaRMULKKX5tJo.tar.zst",
}

import pf.Cmd
import pf.OsStr exposing [OsStr]
import playwright.Playwright exposing [assert!]

main! : List(OsStr) => Try({}, _)
main! = |_args| {
	# The record wires the package to the host platform's process-spawning
	# API, here basic-cli's Cmd module. Everything after launch goes through
	# the returned browser and page.
	{ browser, page } =
		Playwright.launch_page!(
			{ new: Cmd.new_str, spawn!: Cmd.spawn! },
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

- A platform that exposes process spawning with stdio pipes, like [niclas-ahden/basic-cli](https://github.com/niclas-ahden/basic-cli) (the `Cmd.spawn!`/`Cmd.Child` surface)
- Playwright installed and available in PATH (e.g., `pkgs.playwright-test` using Nix)

## Playwright version support

We use Playwright's internal driver protocol, which upstream treats as private and may change in any release. We are currently developing and testing against Playwright 1.61. Other versions are untested and nothing checks the version at runtime. We'll decide on version support as we learn how volatile the Playwright driver protocol is.

## Synchronous design

Unlike other Playwright clients we use a synchronous, blocking design. This means that each command is sent to the Playwright driver and we wait for its response before proceeding to the next command. This should not affect most uses of Playwright, but is good to know.

We may switch to an async design in the future, but starting out like this makes things easier to get off the ground. If you dig into the code you'll find that we completely disregard message IDs, for example, because they don't matter when we're synchronous.

## Documentation

View the full API documentation at [https://niclas-ahden.github.io/roc-playwright/](https://niclas-ahden.github.io/roc-playwright/).
