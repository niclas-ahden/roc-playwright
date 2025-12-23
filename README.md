# roc-playwright

Browser automation in Roc using Playwright. We communicate with Playwright using the same protocol as their Python and Java clients, so the behaviour should be similar, but our API may differ a bit to align better with Roc.

## Example usage

```roc
app [main!] {
    pf: platform "https://github.com/growthagent/basic-cli/releases/download/0.25.0/2Qj7ggHJdVV9jAspIjvskp_cUWvAyh7B9I-Ma_sY4zk.tar.br",
    playwright: "https://github.com/niclas-ahden/roc-playwright/releases/download/0.1.0/XXXXXX.tar.br",
}

import pf.Cmd

import playwright.Playwright {
    cmd_new: Cmd.new,
    cmd_args: Cmd.args,
    cmd_spawn_grouped!: Cmd.spawn_grouped!,
}

main! = |_args|
    { browser, page } = Playwright.launch_page!(Chromium)?

    Playwright.navigate!(page, "https://example.com")?
    title = Playwright.get_title!(page)?
    Playwright.click!(page, "button")?

    Playwright.close!(browser)
```

## Requirements

- A platform that exposes process spawning with stdio pipes (like [`growthagent/basic-cli`](https://github.com/growthagent/basic-cli))
- Playwright installed and available in PATH (e.g., `pkgs.playwright-test` using Nix)

## Documentation

View the full API documentation at [https://niclas-ahden.github.io/roc-playwright/](https://niclas-ahden.github.io/roc-playwright/).

## Synchronous design

Unlike other Playwright clients we use a synchronous, blocking design. This means that each command is sent to the Playwright driver and we wait for its response before proceeding to the next command. This should not affect most uses of Playwright, but is good to know.

We may switch to an async design in the future, but starting out like this makes things easier to get off the ground. If you dig into the code you'l find that we completely disregard message IDs, for example.

## Status

`roc-playwright` is usable but far from complete. Please expect breaking changes and missing features as it's early days. We're also using the old Rust-based Roc compiler, and will move to the new Zig-based one when possible.
