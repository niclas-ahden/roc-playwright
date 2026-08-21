#!/usr/bin/env roc
## Proves that no browser, Playwright driver or helper process outlives a
## program that used roc-playwright, however that program ends. Runs on
## Linux, macOS and Windows. From the repository root:
##
##     roc tests/leak/check.roc                       # every browser
##     roc tests/leak/check.roc -- chromium webkit    # some browsers
##     roc tests/leak/check.roc -- none               # see below
##
## For every browser and every way to die (clean exit, exit without close!,
## Ctrl+C, hard kill) it starts tests/leak/leak.roc, takes it down, and then
## asserts that the process table holds nothing of Playwright's that was not
## there before. Detection is by command line rather than by install path, so
## it works wherever the browsers live: the driver is `run-driver`, and each
## browser carries the flag for the pipe it talks to Playwright over.
##
## Comparing against a baseline lets this run on a developer machine that
## already has strays from other work. That is also why it cannot tell when
## the test suite itself leaks: `none` is the absolute form for a CI runner,
## which starts clean, and fails if anything of Playwright's or any test
## server is alive at all. Run it right after `roc tests.roc`.
app [main!] {
    pf: platform "https://github.com/niclas-ahden/basic-cli/releases/download/0.24.0/2mx1EsQx1HEG7HdbW2CwUpexvmJZW4nSCpjbur5GXyRe.tar.zst",
}

import pf.Cmd
import pf.Env
import pf.OsStr exposing [OsStr]
import pf.Sleep
import pf.Stderr
import pf.Stdout

## What Playwright's processes say on their command lines.
playwright_marks : List(Str)
playwright_marks = ["run-driver", "remote-debugging-pipe", "juggler-pipe", "inspector-pipe"]

## The same, plus the suite's node test servers.
suite_marks : List(Str)
suite_marks = playwright_marks.append("tests/server/main.mjs")

main! : List(OsStr) => Try({}, _)
main! = |os_args| {
    args = os_args.drop_first(1).map(OsStr.display)
    windows = Env.platform!().os == WINDOWS

    if args == ["none"] {
        assert_none!(windows)
    } else {
        browsers = if args.is_empty() { ["chromium", "chromium-full", "firefox", "webkit"] } else { args }
        run_matrix!(windows, browsers)
    }
}

## `roc tests/leak/check.roc -- none`
assert_none! : Bool => Try({}, _)
assert_none! = |windows| {
    alive = table!(windows, suite_marks)?
    if alive.is_empty() {
        Stdout.line!("Nothing from the suite is still running.")
    } else {
        Stderr.line!("::error::processes outlived the suite:")?
        Stderr.line!(Str.join_with(alive, "\n"))?
        Err(SuiteLeaked)
    }
}

run_matrix! : Bool, List(Str) => Try({}, _)
run_matrix! = |windows, browsers| {
    bin = if windows { "tests/leak/leak-bin.exe" } else { "tests/leak/leak-bin" }
    build_code =
        Cmd.new_str("roc")
            .args_str(["build", "tests/leak/leak.roc", "--output=${bin}"])
            .exec_exit_code!()?
    if build_code != 0 {
        return Err(BuildFailed(build_code))
    }

    # A console Ctrl+C cannot be delivered to a child from a Windows CI job
    # (no console to generate it on). TerminateProcess below is the honest
    # Windows equivalent, and the pipes the cleanup rides on cannot tell the
    # two apart anyway.
    ends = if windows { [Exit, Abandon, Kill] } else { [Exit, Abandon, CtrlC, Kill] }

    for browser in browsers {
        for how in ends {
            scenario!(windows, bin, browser, how)?
        }
    }

    Stdout.line!("No Playwright processes outlived any scenario.")
}

## One browser, one way to die.
scenario! : Bool, Str, Str, [Exit, Abandon, CtrlC, Kill] => Try({}, _)
scenario! = |windows, bin, browser, how| {
    name = "${browser} / ${how_str(how)}"
    Stdout.line!("==> ${name}")?

    baseline = pids!(windows, playwright_marks)?

    child =
        Cmd.new_str(bin)
            .args_str([browser, mode_str(how)])
            .spawn!()?

    # leak.roc prints READY once its browser is up, so the process really
    # has something to leave behind when it goes down. A launch failure ends
    # the child first, and the read fails instead of hanging.
    match child.read_stdout!(6) {
        Ok(bytes) if bytes == "READY\n".to_utf8() => {}
        _ => {
            ended = child.kill_wait!()?
            Stderr.line!(Str.from_utf8_lossy(ended.stderr))?
            return Err(NeverReady(name))
        }
    }

    match how {
        Exit | Abandon => {
            ended = child.wait!()?
            if ended.exit_code != 0 {
                Stderr.line!(Str.from_utf8_lossy(ended.stderr))?
                return Err(ExitedNonZero(name, ended.exit_code))
            }
        }
        CtrlC => {
            # The child type does not carry a pid, so find it by its own
            # command line. Unix only; Windows skips this scenario.
            pid = pids!(windows, ["${bin} ${browser} hang"])?.first() ? |_| NoPidFor(name)
            _ = Cmd.new_str("kill").args_str(["-INT", pid]).exec_exit_code!()?
            _ = child.wait!()?
        }
        Kill => {
            # SIGKILL on Unix, TerminateProcess on Windows: what a crash or
            # Task Manager's End Task does.
            child.kill!()?
        }
    }

    # The driver exits on stdin EOF and browsers on their pipe closing,
    # which is quick but not instant, so give the table a moment to settle.
    survivors = wait_clear!(windows, baseline, 100)?
    if survivors.is_empty() {
        Stdout.line!("    clean")
    } else {
        Stderr.line!("::error::leak: ${name}: Playwright processes survived the program")?
        Stderr.line!("--- processes that appeared during the scenario ---")?
        rows = table!(windows, playwright_marks)?
        for line in rows.keep_if(|line| survivors.any(|pid| line.trim().starts_with(pid))) {
            Stderr.line!(line)?
        }
        Err(Leaked(name))
    }
}

## Pids matching now that were not in the baseline, polled until none are
## left or the attempts run out. Returns the ones that stayed.
wait_clear! : Bool, List(Str), U64 => Try(List(Str), _)
wait_clear! = |windows, baseline, attempts| {
    fresh = pids!(windows, playwright_marks)?.keep_if(|pid| !baseline.contains(pid))
    if fresh.is_empty() or attempts == 0 {
        Ok(fresh)
    } else {
        Sleep.millis!(200)
        wait_clear!(windows, baseline, attempts - 1)
    }
}

## The pids of every process whose command line holds one of the marks.
pids! : Bool, List(Str) => Try(List(Str), _)
pids! = |windows, marks| {
    table!(windows, marks).map_ok(|lines| {
        lines.map(|line| line.trim().split_on(" ").first().ok_or(""))
    })
}

## The process table, one `pid ppid command` line per process whose command
## line holds one of the marks. An empty match is a normal answer, not an
## error, so a non-zero exit from the lister is read as "none".
table! : Bool, List(Str) => Try(List(Str), _)
table! = |windows, marks| {
    cmd =
        if windows {
            Cmd.new_str("powershell").args_str([
                "-NoProfile",
                "-NonInteractive",
                "-Command",
                "Get-CimInstance Win32_Process | ForEach-Object { \"$($_.ProcessId) $($_.ParentProcessId) $($_.CommandLine)\" }",
            ])
        } else {
            Cmd.new_str("ps").args_str(["-eo", "pid,ppid,args"])
        }
    out =
        match cmd.exec_output!() {
            Ok(streams) => streams.stdout_utf8
            Err(NonZeroExitCode(failure)) => failure.stdout_utf8_lossy
            Err(other) => return Err(ListingFailed(other))
        }
    Ok(
        out
            .split_on("\n")
            .map(|line| line.trim_end())
            .keep_if(|line| marks.any(|mark| line.contains(mark)) and !line.contains("tests/leak/check.roc")),
    )
}

how_str : [Exit, Abandon, CtrlC, Kill] -> Str
how_str = |how|
    match how {
        Exit => "exit"
        Abandon => "abandon"
        CtrlC => "ctrl-c"
        Kill => "kill"
    }

## The mode leak.roc is started in for each way to die.
mode_str : [Exit, Abandon, CtrlC, Kill] -> Str
mode_str = |how|
    match how {
        Exit => "exit"
        Abandon => "abandon"
        CtrlC | Kill => "hang"
    }
