app [main!] {
    pf: platform "https://github.com/growthagent/basic-cli/releases/download/0.25.0/2Qj7ggHJdVV9jAspIjvskp_cUWvAyh7B9I-Ma_sY4zk.tar.br",
    spec: "https://github.com/niclas-ahden/roc-spec/releases/download/0.1.0/1gNyp2QAxomebg0_bZTY4WwD6WFyLjVl6TbC7Dr7AX8.tar.br",
}

import pf.Arg
import pf.Cmd
import pf.Http
import pf.Sleep
import pf.Stdout

import spec.Spec {
    cmd_new: Cmd.new,
    cmd_args: Cmd.args,
    cmd_envs: Cmd.envs,
    cmd_spawn_grouped!: Cmd.spawn_grouped!,
    stdout_line!: Stdout.line!,
    dir_list!: dir_list_as_strings!,
    utc_now!: utc_now_as_millis!,
    sleep_millis!: Sleep.millis!,
}

import pf.Dir
import pf.Path
import pf.Utc

# Wrapper functions for roc-spec
dir_list_as_strings! : Str => Result (List Str) _
dir_list_as_strings! = |path|
    paths = Dir.list!(path)?
    Ok(List.map(paths, Path.display))

utc_now_as_millis! : {} => I128
utc_now_as_millis! = |{}|
    Utc.to_millis_since_epoch(Utc.now!({}))

max_workers : U16
max_workers = 16

default_base_port : U16
default_base_port = 9000

## Worker environment variables (pure function)
get_worker_envs : U64 -> List (Str, Str)
get_worker_envs = |worker_index|
    [
        ("WORKER_INDEX", Num.to_str(worker_index)),
        ("ROC_SPEC_BASE_PORT", "9000"),
        ("ROC_SPEC_HOST", "localhost"),
    ]

## No-op before_each hook (playwright tests don't need DB cleanup)
before_each_noop! : U64 => Result {} []
before_each_noop! = |_worker_index|
    Ok({})

server_binary_path = "./test-server"

## Extract pattern filter from command line args (first arg after program name)
get_pattern : List Arg.Arg -> Str
get_pattern = |args|
    when List.get(args, 1) is
        Ok(arg) -> Arg.display(arg)
        Err(_) -> ""

main! : List Arg.Arg => Result {} _
main! = |args|
    pattern = get_pattern(args)
    base_port = default_base_port

    Stdout.line!("Starting $(Num.to_str(max_workers)) workers...")?

    # Phase 1: Spawn all workers (using spawn_grouped! for proper cleanup)
    List.range({ start: At(0), end: Before(max_workers) })
        |> List.for_each_try!(|index|
            spawn_worker!(base_port, index)
        )?

    # Phase 2: Wait for all workers to be ready
    wait_for_all_workers!({
        count: max_workers,
        base_port,
        max_attempts: 150,
        delay_ms: 200,
    })?

    Stdout.line!("All $(Num.to_str(max_workers)) workers ready")?

    # Run tests
    results = Spec.run_filtered!("tests", {
        max_workers,
        worker_envs: get_worker_envs,
        before_each!: before_each_noop!,
        per_test_timeout_ms: 60000,
        quiet: Bool.true,
    }, pattern)?

    # Report results
    passed = List.count_if(results, |r| r.passed)
    total = List.len(results)

    Stdout.line!("")?
    Stdout.line!("$(Num.to_str(passed))/$(Num.to_str(total)) tests passed")?

    if passed == total then
        Ok({})
    else
        Err(TestsFailed)

## Spawn a single test server
spawn_worker! : U16, U16 => Result {} _
spawn_worker! = |base_port, index|
    port = base_port + index

    _ =
        Cmd.new(server_binary_path)
        |> Cmd.envs([
            ("ROC_BASIC_WEBSERVER_PORT", Num.to_str(port)),
        ])
        |> Cmd.spawn_grouped!()
        |> Result.map_err(|_| ServerSpawnFailed(index))?

    Ok({})

## Wait for all workers to be ready
wait_for_all_workers! : { count : U16, base_port : U16, max_attempts : U64, delay_ms : U64 } => Result {} _
wait_for_all_workers! = |config|
    initial_ready = List.repeat(Bool.false, Num.to_u64(config.count))
    poll_until_all_ready!(config, initial_ready, 0)

poll_until_all_ready! : { count : U16, base_port : U16, max_attempts : U64, delay_ms : U64 }, List Bool, U64 => Result {} _
poll_until_all_ready! = |config, ready_status, attempt|
    if attempt >= config.max_attempts then
        not_ready =
            ready_status
            |> List.map_with_index(|is_ready, idx| if is_ready then "" else Num.to_str(idx))
            |> List.keep_if(|s| !Str.is_empty(s))
            |> Str.join_with(", ")
        Err(WorkersNotReady(not_ready))
    else if List.all(ready_status, |r| r) then
        Ok({})
    else
        new_ready = poll_all_workers!(config.base_port, ready_status, 0, [])

        if List.all(new_ready, |r| r) then
            Ok({})
        else
            _ = Sleep.millis!(config.delay_ms)
            poll_until_all_ready!(config, new_ready, attempt + 1)

poll_all_workers! : U16, List Bool, U64, List Bool => List Bool
poll_all_workers! = |base_port, ready_status, idx, acc|
    when List.get(ready_status, idx) is
        Err(_) -> acc
        Ok(is_ready) ->
            new_status =
                if is_ready then
                    Bool.true
                else
                    check_worker_ready!(base_port, Num.to_u16(idx))
            poll_all_workers!(base_port, ready_status, idx + 1, List.append(acc, new_status))

check_worker_ready! : U16, U16 => Bool
check_worker_ready! = |base_port, index|
    port = base_port + index
    url = "http://localhost:$(Num.to_str(port))/"

    request = {
        method: GET,
        headers: [],
        uri: url,
        body: [],
        timeout_ms: TimeoutMilliseconds(1000),
    }

    when Http.send!(request) is
        Ok(response) -> response.status < 500
        Err(_) -> Bool.false
