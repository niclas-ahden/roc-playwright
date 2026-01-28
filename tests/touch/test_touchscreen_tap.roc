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

## Test: touchscreen_tap! triggers a touch event at specific coordinates
main! : List Arg.Arg => Result {} _
main! = |_args|
    TestEnvironment.with!(|worker_url|
        # Launch with touch enabled
        browser = Playwright.launch_with!({ browser_type: Chromium, headless: Bool.true, timeout: TimeoutMilliseconds(5000) })?
        context = Playwright.new_context_with!(browser, { has_touch: Bool.true })?
        page = Playwright.new_page!(context)?

        Playwright.navigate!(page, "$(worker_url)/touch-test")?

        # Get bounding box of touch area to know where to tap
        box = Playwright.bounding_box!(page, "#touch-area")?

        # Tap in the center of the touch area
        center_x = box.x + (box.width / 2.0)
        center_y = box.y + (box.height / 2.0)

        Playwright.touchscreen_tap!(page, center_x, center_y)?

        # Verify touch event was received (shows coordinates)
        result_text = Playwright.text_content!(page, "#touch-result")?

        # The result should contain "Touch at:" or "Clicked at:" depending on browser
        Assert.true(Str.contains(result_text, "at:")) ? ShouldContainCoordinates

        Playwright.close!(browser)
    )
