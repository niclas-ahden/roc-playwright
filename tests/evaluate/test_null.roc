app [main!] {
    pf: platform "https://github.com/growthagent/basic-cli/releases/download/0.27.0/G-A6F5ny0IYDx4hmF3t_YPHUSR28c9ZXMBnh0FEJjwk.tar.br",
    playwright: "../../package/main.roc",
    spec: "https://github.com/niclas-ahden/roc-spec/releases/download/0.2.0/Cv22_pXKIt82Cz5qzFxdm47SNo81RDx6j4gahQIJvME.tar.br",
}

import pf.Arg
import pf.Cmd
import pf.Env
import pf.Http

import playwright.Playwright {
    cmd_new: Cmd.new,
    cmd_args: Cmd.args,
    cmd_spawn_grouped!: Cmd.spawn_grouped!,
}

import spec.TestEnvironment {
    env_var!: Env.var!,
    http_send!: Http.send!,
    http_header: Http.header,
    pg_connect!: pg_connect_stub!,
    pg_cmd_new: pg_cmd_new_stub,
    pg_client_command!: pg_client_command_stub!,
}

pg_connect_stub! = |_| Err(NotImplemented)
pg_cmd_new_stub = |_| {}
pg_client_command_stub! = |_, _| Err(NotImplemented)

## Test: evaluate! returns EvaluateReturnedNull for null/undefined
main! : List Arg.Arg => Result {} _
main! = |_args|
    TestEnvironment.with!(|worker_url|
        { browser, page } = Playwright.launch_page_with!({ browser_type: Chromium, headless: Bool.true, timeout: TimeoutMilliseconds(5000) })?

        Playwright.navigate!(page, "$(worker_url)/")?

        # Test null - should return EvaluateReturnedNull error
        null_result = Playwright.evaluate!(page, "null")
        (when null_result is
            Ok(_) -> Err(NullShouldHaveReturnedError)
            Err(EvaluateReturnedNull) -> Ok({})
            Err(_) -> Err(UnexpectedNullError))?

        # Test undefined - should return EvaluateReturnedNull error
        undefined_result = Playwright.evaluate!(page, "undefined")
        (when undefined_result is
            Ok(_) -> Err(UndefinedShouldHaveReturnedError)
            Err(EvaluateReturnedNull) -> Ok({})
            Err(_) -> Err(UnexpectedUndefinedError))?

        Playwright.close!(browser)
    )
