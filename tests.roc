#!/usr/bin/env roc
## Runs the full Playwright suite by handing every argument through to
## tests/run.roc, which spawns one node test server per worker and runs every
## tests/**/*_test.roc through roc-spec. Accepts a filename pattern
## (substring) and --fail-fast, e.g. `./tests.roc click`.
##
## Run from the repository root. CI runs this via `nix develop -c ./tests.roc`.
##
## Nothing here corrals child processes: the test servers exit on stdin EOF
## and the Playwright driver does the same, so they follow the runner down
## however it dies. tests/leak/ is the check that this holds on every OS.
app [main!] {
    pf: platform "https://github.com/niclas-ahden/basic-cli/releases/download/0.24.0/2mx1EsQx1HEG7HdbW2CwUpexvmJZW4nSCpjbur5GXyRe.tar.zst",
}

import pf.Cmd
import pf.OsStr exposing [OsStr]
import pf.Stderr
import pf.Stdout

main! : List(OsStr) => Try({}, _)
main! = |os_args| {
    forwarded = os_args.drop_first(1)

    Stdout.line!("Running Playwright tests in parallel...")?

    code =
        Cmd.new(OsStr.utf8("roc"))
            .args([OsStr.utf8("tests/run.roc"), OsStr.utf8("--")].concat(forwarded))
            .exec_exit_code!()?

    if code == 0 {
        Ok({})
    } else {
        Stderr.line!("Playwright tests failed with exit code ${code.to_str()}")?
        Err(TestsFailed(code))
    }
}
