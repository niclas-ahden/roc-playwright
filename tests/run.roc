## Playwright test-suite runner (invoked by ./tests.roc from the repo root):
## spawns one node test server per worker, waits until they respond, then runs
## every tests/**/*_test.roc through roc-spec.
##
## Optional args: a filename pattern (substring) and --fail-fast.
## Optional env: ROC_SPEC_MAX_WORKERS (default 4), ROC_OPT (default speed).
app [main!] {
    pf: platform "https://github.com/niclas-ahden/basic-cli/releases/download/0.24.0/2mx1EsQx1HEG7HdbW2CwUpexvmJZW4nSCpjbur5GXyRe.tar.zst",
    spec: "https://github.com/niclas-ahden/roc-spec/releases/download/0.3.0/2v2CV8CLXRJmQRvfoHtPngAUGgE8jL6DDgXbugZhFVf5.tar.zst",
}

import pf.Cmd
import pf.Env
import pf.Http
import pf.OsStr exposing [OsStr]
import pf.Path
import pf.Sleep
import pf.Stderr
import pf.Stdout
import pf.Url
import pf.Utc
import spec.Spec
import spec.TestEnvironment

effects = {
    spawn_test!: |file, envs|
        Cmd.new(OsStr.utf8("roc"))
            .args_str(["--opt=${opt!({})}", file])
            .envs_str(envs)
            .spawn!(),
    poll!: Cmd.Child.poll!,
    kill_wait!: Cmd.Child.kill_wait!,
    list_dir!: |dir| Path.list!(Path.utf8(dir)).map_ok(|entries| entries.map(Path.display)),
    print!: Stdout.line!,
    utc_now!: Utc.now!,
    sleep_millis!: Sleep.millis!,
}

base_port : U16
base_port = 9000

## Environment for each test process: tests derive their server URL from
## http://$ROC_SPEC_HOST:($ROC_SPEC_BASE_PORT + $WORKER_INDEX)
worker_envs : U64 -> List((Str, Str))
worker_envs = |index| [
    ("WORKER_INDEX", index.to_str()),
    ("ROC_SPEC_BASE_PORT", base_port.to_str()),
    ("ROC_SPEC_HOST", "localhost"),
]

## Optimization level every test is built with.
opt! : {} => Str
opt! = |{}|
    match Env.var_str!(OsStr.from_str("ROC_OPT")) {
        Ok(val) if val != "" => val
        _ => "speed"
    }

max_workers! : {} => U16
max_workers! = |{}|
    match Env.var_str!(OsStr.from_str("ROC_SPEC_MAX_WORKERS")) {
        Ok(val) => U16.from_str(val).ok_or(4)
        Err(_) => 4
    }

## Parse command line args into pattern and flags
parse_args : List(Str) -> { pattern : Str, fail_fast : Bool }
parse_args = |args| {
    rest = args.drop_first(1)
    pattern = rest.keep_if(|a| !a.starts_with("--")).first().ok_or("")
    fail_fast = rest.contains("--fail-fast")
    { pattern, fail_fast }
}

## The first tests/<group>/<name>_test.roc on disk. Every test file carries the
## same dependency header, so whichever one comes back stands in for all of
## them.
first_test_file! : Str => Try(Str, [NoTestFiles])
first_test_file! = |test_dir| {
    groups = Path.list!(Path.utf8(test_dir)) ? |_| NoTestFiles
    var $found = ""
    for group in groups {
        match Path.list!(group) {
            Err(_) => {}
            Ok(entries) => {
                for entry in entries {
                    name = Path.display(entry)
                    if $found == "" and name.ends_with("_test.roc") {
                        $found = name
                    }
                }
            }
        }
    }
    if $found == "" {
        Err(NoTestFiles)
    } else {
        Ok($found)
    }
}

## Download and extract every package the tests depend on, in one process,
## before any worker starts.
##
## The compiler does not lock the package cache: the first `roc` to want a
## missing package creates its cache directory and starts extracting into it,
## while every other `roc` sees that directory, takes it for a finished
## download, and dies with "PACKAGE DOWNLOAD FAILED ... FileNotFound". On a
## cold cache that wipes out every test that loses the race.
warm_package_cache! : Str => Try({}, _)
warm_package_cache! = |test_dir|
    match first_test_file!(test_dir) {
        Err(_) => Ok({})
        Ok(file) => {
            Stdout.line!("Warming the package cache...")?
            # Whatever this reports about the file itself is the test run's
            # business, so the output and the exit code are both dropped here.
            _ = Cmd.new(OsStr.utf8("roc")).args_str(["check", file]).exec_output!()
            Ok({})
        }
    }

## Spawn one node test server for the given worker index
spawn_worker! : U16 => Try({}, _)
spawn_worker! = |index| {
    port = base_port + index
    cmd = Cmd.envs_str(Cmd.args_str(Cmd.new_str("node"), ["tests/server/main.mjs"]), [("PORT", port.to_str())])
    _child = Cmd.spawn!(cmd) ? |e| ServerSpawnFailed(index, e)
    Ok({})
}

## One readiness probe against a worker's test server: any HTTP response
## means it is up. A Tcp connect would be lighter, but it would only prove the
## port is bound, not that the server is answering requests.
check_worker! : U16 => Bool
check_worker! = |port|
    match Url.parse("http://localhost:${port.to_str()}") {
        Err(_) => Bool.False
        Ok(u) =>
            match Http.get_utf8!(u) {
                Ok(_) => Bool.True
                Err(_) => Bool.False
            }
    }

main! : List(OsStr) => Try({}, _)
main! = |os_args| {
    args = os_args.map(|a| OsStr.display(a))
    { pattern, fail_fast } = parse_args(args)
    workers = max_workers!({})

    warm_package_cache!("tests")?

    Stdout.line!("Starting ${workers.to_str()} test servers...")?

    # Spawn all test servers first, then poll them all until every one
    # answers (up to ~30s). They need no leash from the platform: each one
    # exits when its stdin pipe closes, which happens however the runner dies
    # (see tests/server/main.mjs).
    TestEnvironment.start!({ sleep!: Sleep.millis! }, {
        count: workers,
        spawn!: spawn_worker!,
        ready!: |index| check_worker!(base_port + index),
        max_attempts: 150,
        delay_ms: 200,
    })?

    Stdout.line!("All ${workers.to_str()} test servers ready")?

    results = Spec.run_filtered!(effects, "tests", {
        max_workers: workers,
        worker_envs,
        before_each!: |_index| Ok({}),
        per_test_timeout_ms: 120_000,
        quiet: Bool.True,
        fail_fast,
    }, pattern)?

    passed = results.count_if(|r| r.passed)
    total = results.len()

    Stdout.line!("")?
    Stdout.line!("${passed.to_str()}/${total.to_str()} tests passed")?

    # A pattern that matches nothing is a failure: a typo'd filter must not
    # produce a green "0/0 passed" run.
    if total == 0 {
        Stderr.line!("No tests matched the pattern '${pattern}'")?
        Err(NoTestsMatched)
    } else if passed == total {
        Ok({})
    } else {
        Err(TestsFailed)
    }
}
