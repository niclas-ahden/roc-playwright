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
    pf: platform "https://github.com/niclas-ahden/basic-cli/releases/download/0.30.0/6XAUy48Jp34GANurMrMf74DtF7NdpkhnqFLHE4gHNzJy.tar.zst",
}

import pf.Cmd
import pf.OsStr
import pf.Stderr
import pf.Stdout

main! : List(OsStr) => Try({}, _)
main! = |os_args| {
    Stdout.line!("Running Playwright tests in parallel...")?

    status =
        Cmd.new(OsStr.from_str("roc"))
            .args([OsStr.from_str("tests/run.roc")].concat(os_args))
            .inherit_stdio()
            .run!()?
            .status

    if status == Exited(0) {
        Ok({})
    } else {
        Stderr.line!("Playwright tests failed: ${Str.inspect(status)}")?
        Err(TestsFailed(status))
    }
}
