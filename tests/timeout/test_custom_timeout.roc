app [main!] {
    pf: platform "https://github.com/growthagent/basic-cli/releases/download/0.25.0/2Qj7ggHJdVV9jAspIjvskp_cUWvAyh7B9I-Ma_sY4zk.tar.br",
    playwright: "../../package/main.roc",
    spec: "https://github.com/niclas-ahden/roc-spec/releases/download/0.1.0/1gNyp2QAxomebg0_bZTY4WwD6WFyLjVl6TbC7Dr7AX8.tar.br",
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

import spec.Assert
import spec.TestEnvironment {
    env_var!: Env.var!,
    http_send!: Http.send!,
    http_header: Http.header,
    pg_connect!: pg_connect_stub!,
    pg_cmd_new: pg_cmd_new_stub,
    pg_client_command!: pg_client_command_stub!,
}

# Stubs for unused pg functions
pg_connect_stub! = |_config| Err(NotImplemented)
pg_cmd_new_stub = |_sql| {}
pg_client_command_stub! = |_cmd, _db| Err(NotImplemented)

main! : List Arg.Arg => Result {} _
main! = |_args|
    TestEnvironment.with!(|worker_url|
        # --- Success case: element appears within timeout ---

        # Launch with 5 second timeout - element appears after 500ms, so this should succeed
        { browser: browser1, page: page1 } = Playwright.launch_page_with!({ browser_type: Chromium, headless: Bool.true, timeout: TimeoutMilliseconds(5000) })?

        Playwright.navigate!(page1, "$(worker_url)/delayed-element")?

        # This should succeed because 5000ms > 500ms delay
        delayed_text = Playwright.text_content!(page1, "#delayed")?
        Assert.eq(delayed_text, "I appeared!") ? DelayedElementFound

        Playwright.close!(browser1)?

        # --- Failure case: timeout expires before element appears ---

        # Launch with 100ms timeout - element appears after 500ms, so this should fail
        { browser: browser2, page: page2 } = Playwright.launch_page_with!({ browser_type: Chromium, headless: Bool.true, timeout: TimeoutMilliseconds(100) })?

        Playwright.navigate!(page2, "$(worker_url)/delayed-element")?

        # This should fail because 100ms < 500ms delay
        timeout_result = Playwright.text_content!(page2, "#delayed")
        _ = Assert.err(timeout_result) ? TimeoutBeforeElementAppears

        Playwright.close!(browser2)
    )
