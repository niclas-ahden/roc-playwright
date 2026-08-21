## The process under test for tests/leak/check.roc: launches one browser,
## reports READY, then ends the way the second argument says. Nothing in
## here cleans up deliberately except the `exit` mode; the point is to see
## what survives when the program does not get the chance.
##
##     roc build tests/leak/leak.roc --output=tests/leak/leak-bin
##     tests/leak/leak-bin chromium|chromium-full|firefox|webkit exit|abandon|hang
##
## `chromium-full` is the full Chromium build rather than the headless shell
## the other Chromium runs use. It is a browser of its own here because it is
## the one that does not exit when its pipe to the driver closes, so it is the
## one that catches a cleanup route that only works by accident.
##
## * `exit`: Playwright.close! then a normal return.
## * `abandon`: a normal return without close!, so only stdin EOF tells the
##   driver the program is gone.
## * `hang`: sleep forever, for the caller to kill (Ctrl+C, kill -9,
##   TerminateProcess).
app [main!] {
    pf: platform "https://github.com/niclas-ahden/basic-cli/releases/download/0.24.0/2mx1EsQx1HEG7HdbW2CwUpexvmJZW4nSCpjbur5GXyRe.tar.zst",
    playwright: "../../package/main.roc",
}

import pf.Cmd
import pf.OsStr exposing [OsStr]
import pf.Sleep
import pf.Stdout
import playwright.Playwright

main! : List(OsStr) => Try({}, _)
main! = |os_args| {
    args = os_args.map(OsStr.display)

    browser_type =
        match args.get(1) {
            Ok("firefox") => Firefox
            Ok("webkit") => WebKit
            Ok("chromium") => Chromium(DefaultChannel)
            Ok("chromium-full") => Chromium(Full)
            _ => return Err(Usage("expected browser: chromium|chromium-full|firefox|webkit"))
        }
    mode =
        match args.get(2) {
            Ok("exit") => Exit
            Ok("abandon") => Abandon
            Ok("hang") => Hang
            _ => return Err(Usage("expected mode: exit|abandon|hang"))
        }

    # Plain Cmd.spawn!, on purpose: the package must not need a leash from
    # the platform for its processes to follow the program down.
    { browser, page } = Playwright.launch_page!(
        { new: Cmd.new_str, args: Cmd.args_str, spawn!: Cmd.spawn!, write_stdin!: Cmd.Child.write_stdin!, read_stdout!: Cmd.Child.read_stdout!, kill!: Cmd.Child.kill! },
        browser_type,
    )?
    Playwright.navigate!(page, "about:blank")?

    # check.roc waits for this line before it acts, so the browser is really
    # up when the process goes down.
    Stdout.line!("READY")?

    match mode {
        Exit => Playwright.close!(browser)
        Abandon => Ok({})
        Hang => hang!({})
    }
}

hang! : {} => Try({}, _)
hang! = |{}| {
    Sleep.millis!(1000)
    hang!({})
}
