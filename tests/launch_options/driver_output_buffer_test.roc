app [main!] {
    pf: platform "https://github.com/niclas-ahden/basic-cli/releases/download/0.28.0/AP9SGT1yrhCKcFxKcoA5tBkNCM6ibBjBxcQGMTb6krev.tar.zst",
    playwright: "../../package/main.roc",
}

import pf.Cmd
import pf.OsStr
import playwright.Playwright

# `driver_output_buffer_bytes` reaches the driver: at 1 KiB, the driver's
# first messages (several KiB each) overflow it, the platform cancels the
# driver, and the launch fails. basic-cli reads the pipe in 8 KiB chunks, so
# a limit below one chunk trips on the first read, however fast the package
# reads.
# Every other test launches with the default.
main! : List(OsStr) => Try({}, _)
main! = |_args|
    match Playwright.launch_page_with!({ new: Cmd.new_str, spawn!: Cmd.spawn!, driver_output_buffer_bytes: 1024 }, { timeout: TimeoutMilliseconds(10000) }) {
        Err(_) => Ok({})

        Ok(launched) => {
            _ = launched.browser.close!()
            Err(TinyLimitShouldStopTheDriver)
        }
    }
