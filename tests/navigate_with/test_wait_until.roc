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
        { browser, page } = Playwright.launch_page_with!({ browser_type: Chromium, headless: Bool.true, timeout: TimeoutMilliseconds(5000) })?

        # Test navigate_with! using Load (default behavior)
        Playwright.navigate_with!(page, { url: worker_url, wait_until: Load })?
        h1_load = Playwright.text_content!(page, "h1")?
        Assert.eq(h1_load, "Welcome to the Test Server") ? LoadWaitUntil

        # Test navigate_with! using DomContentLoaded (faster, doesn't wait for images/stylesheets)
        Playwright.navigate_with!(page, { url: "$(worker_url)/page1", wait_until: DomContentLoaded })?
        h1_dom = Playwright.text_content!(page, "h1")?
        Assert.eq(h1_dom, "Page 1") ? DomContentLoadedWaitUntil

        # Test navigate_with! using Commit (fastest, just waits for response)
        Playwright.navigate_with!(page, { url: "$(worker_url)/page2", wait_until: Commit })?
        h1_commit = Playwright.text_content!(page, "h1")?
        Assert.eq(h1_commit, "Page 2") ? CommitWaitUntil

        # Test navigate_with! using NetworkIdle (waits for no network activity)
        Playwright.navigate_with!(page, { url: worker_url, wait_until: NetworkIdle })?
        h1_idle = Playwright.text_content!(page, "h1")?
        Assert.eq(h1_idle, "Welcome to the Test Server") ? NetworkIdleWaitUntil

        # --- Error cases ---

        # navigate_with! to unreachable URL should error
        unreachable_result = Playwright.navigate_with!(page, { url: "http://localhost:99999/nonexistent", wait_until: Load })
        _ = Assert.err(unreachable_result) ? UnreachableUrl

        Playwright.close!(browser)
    )
