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

## Test: touch_drag! fires touchstart, touchmove, and touchend events
main! : List Arg.Arg => Result {} _
main! = |_args|
    TestEnvironment.with!(|worker_url|
        browser = Playwright.launch_with!({ browser_type: Chromium, headless: Bool.true, timeout: TimeoutMilliseconds(5000) })?
        context = Playwright.new_context_with!(browser, { has_touch: Bool.true })?
        page = Playwright.new_page!(context)?

        Playwright.navigate!(page, "$(worker_url)/touch-test")?

        # Get the bounding box of the touch area to calculate coordinates
        box = Playwright.bounding_box!(page, "#touch-area")?

        # Drag from left side to right side of the touch area
        start_x = box.x + 50.0
        start_y = box.y + 100.0
        end_x = box.x + 250.0
        end_y = box.y + 100.0

        # Verify initial state
        initial_text = Playwright.text_content!(page, "#touch-result")?
        Assert.eq(initial_text, "No touch yet") ? InitialStateShouldMatch

        Playwright.touch_drag!(page, { start_x, start_y, end_x, end_y })?

        # Verify drag events were fired (touchstart, 5x touchmove, touchend)
        result_text = Playwright.text_content!(page, "#touch-result")?
        Assert.eq(result_text, "Drag events: start,move,move,move,move,move,end") ? DragEventsShouldMatch

        Playwright.close!(browser)
    )
