app [main!] {
    pf: platform "https://github.com/growthagent/basic-cli/releases/download/0.25.0/2Qj7ggHJdVV9jAspIjvskp_cUWvAyh7B9I-Ma_sY4zk.tar.br",
    spec: "https://github.com/niclas-ahden/roc-spec/releases/download/0.1.0/1gNyp2QAxomebg0_bZTY4WwD6WFyLjVl6TbC7Dr7AX8.tar.br",
}

import pf.Stdout
import pf.Stderr
import pf.Cmd
import pf.Dir
import pf.Path
import pf.Utc

import spec.Spec {
    cmd_new: Cmd.new,
    cmd_args: Cmd.args,
    cmd_envs: Cmd.envs,
    cmd_spawn_grouped!: Cmd.spawn_grouped!,
    stdout_line!: Stdout.line!,
    dir_list!: dir_list!,
    utc_now!: utc_now!,
    sleep_millis!: sleep_millis!,
}

import pf.Sleep

sleep_millis! : U64 => {}
sleep_millis! = |ms| Sleep.millis!(ms)

dir_list! : Str => Result (List Str) _
dir_list! = |dir|
    Dir.list!(dir)
    |> Result.map_ok(|entries| List.map(entries, Path.display))

utc_now! : {} => I128
utc_now! = |{}|
    Utc.now!({}) |> Utc.to_millis_since_epoch

get_worker_envs : U64 -> List (Str, Str)
get_worker_envs = |_worker_index| []

before_each_noop! : U64 => Result {} []
before_each_noop! = |_worker_index| Ok({})

main! : List _ => Result {} _
main! = |_args|
    test_dir = "./tests"

    _ = Stdout.line!("Running Playwright tests from: $(test_dir)")?

    results = Spec.run!(test_dir, {
        max_workers: 1,
        worker_envs: get_worker_envs,
        before_each!: before_each_noop!,
        per_test_timeout_ms: 60000,
        quiet: Bool.true,
    })?

    passed = List.count_if(results, |r| r.passed)
    failed = List.len(results) - passed

    _ = Stdout.line!("")?
    _ = Stdout.line!("================================")?

    if failed == 0 then
        _ = Stdout.line!("\u(001b)[32m✓\u(001b)[0m $(Num.to_str(passed)) passed")?
        Ok({})
    else
        _ = Stderr.line!("\u(001b)[31m✗\u(001b)[0m $(Num.to_str(failed)) failed, $(Num.to_str(passed)) passed")?
        Err(TestsFailed({ failed }))
