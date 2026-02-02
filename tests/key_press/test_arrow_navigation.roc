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

pg_connect_stub! = |_| Err(NotImplemented)
pg_cmd_new_stub = |_| {}
pg_client_command_stub! = |_, _| Err(NotImplemented)

main! : List Arg.Arg => Result {} _
main! = |_args|
    TestEnvironment.with!(|worker_url|
        { browser, page } = Playwright.launch_page_with!({ browser_type: Chromium, headless: Bool.true, timeout: TimeoutMilliseconds(5000) })?

        Playwright.navigate!(page, "$(worker_url)/keyboard-navigation")?

        # Verify initial state - Item 1 is selected
        initial = Playwright.text_content!(page, "#selected")?
        Assert.eq(initial, "Selected: Item 1") ? InitialItemShouldBeSelected

        # Press ArrowDown to select Item 2
        Playwright.key_press_targetless!(page, ArrowDown, [])?
        after_down = Playwright.text_content!(page, "#selected")?
        Assert.eq(after_down, "Selected: Item 2") ? Item2ShouldBeSelected

        # Press ArrowDown again to select Item 3
        Playwright.key_press_targetless!(page, ArrowDown, [])?
        after_down2 = Playwright.text_content!(page, "#selected")?
        Assert.eq(after_down2, "Selected: Item 3") ? Item3ShouldBeSelected

        # Press ArrowUp to go back to Item 2
        Playwright.key_press_targetless!(page, ArrowUp, [])?
        after_up = Playwright.text_content!(page, "#selected")?
        Assert.eq(after_up, "Selected: Item 2") ? BackToItem2

        Playwright.close!(browser)
    )
