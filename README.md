# roc-playwright

Browser automation in Roc using Playwright. We communicate with Playwright using the same protocol as their Python and Java clients, so the behaviour should be similar, but our API may differ a bit to align better with Roc.

## Example usage

```roc
app [main!] {
    pf: platform "https://github.com/niclas-ahden/basic-cli/releases/download/0.23.0/7NpDhuqoqGFedmVLvmm1zjq37GCmaFGzwr5sz4ch9wTK.tar.zst",
    playwright: "../roc-playwright/package/main.roc",
}

import pf.Cmd
import pf.OsStr exposing [OsStr]
import playwright.Playwright

# The hooks record wires the package to the host platform's process-spawning
# API. Build it once from basic-cli's Cmd module and pass it to the launch
# functions. Everything after launch goes through the returned browser/page.
hooks = {
    new: Cmd.new_str,
    args: Cmd.args_str,
    spawn_grouped!: Cmd.spawn_grouped!,
    write_stdin!: Cmd.Child.write_stdin!,
    read_stdout!: Cmd.Child.read_stdout!,
    kill!: Cmd.Child.kill!,
}

main! : List(OsStr) => Try({}, _)
main! = |_args| {
    { browser, page } = Playwright.launch_page!(hooks, Chromium(DefaultChannel))?

    Playwright.navigate!(page, "https://example.com")?
    title = Playwright.get_title!(page)?
    Playwright.click!(page, "button")?

    Playwright.close!(browser)
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
