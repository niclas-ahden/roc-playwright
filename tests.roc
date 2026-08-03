#!/usr/bin/env roc
## Runs the full Playwright suite by handing every argument through to
## tests/run.roc, which spawns one node test server per worker and runs every
## tests/**/*_test.roc through roc-spec. Accepts a filename pattern
## (substring) and --fail-fast, e.g. `./tests.roc click`.
##
## Run from the repository root. CI runs this via `nix develop -c ./tests.roc`.
app [main!] {
    pf: platform "https://github.com/niclas-ahden/basic-cli/releases/download/0.23.0/7NpDhuqoqGFedmVLvmm1zjq37GCmaFGzwr5sz4ch9wTK.tar.zst",
}

import pf.Cmd
import pf.OsStr exposing [OsStr]
import pf.Stderr
import pf.Stdout

main! : List(OsStr) => Try({}, _)
main! = |os_args| {
    forwarded = os_args.drop_first(1)

    # systemd scope when available (ensures all descendant processes die with
    # the run). Fall back to a plain spawn in CI where no user session exists.
    use_systemd =
        Cmd.new(OsStr.utf8("systemctl"))
            .args([OsStr.utf8("--user"), OsStr.utf8("show-environment")])
            .exec_output!()
            .is_ok()

    Stdout.line!("Running Playwright tests in parallel...")?

    code = run_suite!(use_systemd, forwarded)?

    if code == 0 {
        Ok({})
    } else {
        Stderr.line!("Playwright tests failed with exit code ${code.to_str()}")?
        Err(TestsFailed(code))
    }
}

run_suite! : Bool, List(OsStr) => Try(I32, _)
run_suite! = |use_systemd, forwarded| {
    runner_args = [OsStr.utf8("tests/run.roc"), OsStr.utf8("--")].concat(forwarded)
    if use_systemd {
        Cmd.new(OsStr.utf8("systemd-run"))
            .args([OsStr.utf8("--scope"), OsStr.utf8("--user"), OsStr.utf8("roc")].concat(runner_args))
            .exec_exit_code!()
    } else {
        Cmd.new(OsStr.utf8("roc"))
            .args(runner_args)
            .exec_exit_code!()
    }
}
