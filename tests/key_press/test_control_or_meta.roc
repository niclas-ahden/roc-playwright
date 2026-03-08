app [main!] {
    pf: platform "https://github.com/growthagent/basic-cli/releases/download/0.27.0/G-A6F5ny0IYDx4hmF3t_YPHUSR28c9ZXMBnh0FEJjwk.tar.br",
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

## Test: ControlOrMeta+A selects all text on any platform.
## Uses 3 separate browser instances to test Control+A, Meta+A, and ControlOrMeta+A.
## Asserts that exactly 2 of the 3 select all text, with ControlOrMeta always being one.
main! : List Arg.Arg => Result {} _
main! = |_args|
    TestEnvironment.with!(|worker_url|
        url = "${worker_url}/keyboard-select"

        # Test Control+A
        control_selects = test_select_all!(url, Control)?

        # Test Meta+A
        meta_selects = test_select_all!(url, Meta)?

        # Test ControlOrMeta+A
        control_or_meta_selects = test_select_all!(url, ControlOrMeta)?

        # ControlOrMeta must always work
        Assert.true(control_or_meta_selects) ? ControlOrMetaDidNotSelectAll

        # Exactly one of Control or Meta should work (platform-dependent)
        exactly_one_native = control_selects != meta_selects
        Assert.true(exactly_one_native) ? ExpectedExactlyOneNativeModifierToWork

        Ok({})
    )

## Launch a fresh browser, navigate to the page, press modifier+A, check if all text selected.
test_select_all! : Str, Playwright.Modifier => Result Bool _
test_select_all! = |url, modifier|
    { browser, page } = Playwright.launch_page_with!({ browser_type: Chromium, headless: Bool.true, timeout: TimeoutMilliseconds(5000) })?
    Playwright.navigate!(page, url)?
    Playwright.click!(page, "#text-area")?
    Playwright.key_press_targetless!(page, KeyA, [modifier])?

    selection = Playwright.text_content!(page, "#selection-info")?
    Playwright.close!(browser)?
    Ok(selection == "Selection: 58 characters")
