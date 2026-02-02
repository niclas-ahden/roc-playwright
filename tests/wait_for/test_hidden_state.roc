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
        { browser, page } = Playwright.launch_page!(Chromium)?

        # Navigate to page with element that disappears after 500ms
        Playwright.navigate!(page, "$(worker_url)/disappearing-element")?

        # Element should be visible initially
        visible_before = Playwright.is_visible!(page, "#vanishing")?
        Assert.eq(visible_before, Bool.true) ? ElementShouldExistInitially

        # wait_for! with Hidden should wait until the element disappears
        Playwright.wait_for!(page, "#vanishing", Hidden)?

        # Element should no longer be visible
        visible_after = Playwright.is_visible!(page, "#vanishing")?
        Assert.eq(visible_after, Bool.false) ? ElementShouldHaveDisappeared

        Playwright.close!(browser)
    )
