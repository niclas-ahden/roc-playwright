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

## Test: bounding_box! returns correct position for a nested element
main! : List Arg.Arg => Result {} _
main! = |_args|
    TestEnvironment.with!(|worker_url|
        { browser, page } = Playwright.launch_page_with!({ browser_type: Chromium, headless: Bool.true, timeout: TimeoutMilliseconds(5000) })?

        Playwright.navigate!(page, "$(worker_url)/bounding-box-test")?

        # Get bounding box of the nested element (inside #fixed-box with margin:10px)
        # Parent is at 150,100, nested element has margin:10px so should be at ~160,110
        box = Playwright.bounding_box!(page, "#nested-box")?

        # Verify position accounts for parent position + margin
        Assert.true(box.x > 159.0 && box.x < 161.0) ? XShouldBe160
        Assert.true(box.y > 109.0 && box.y < 111.0) ? YShouldBe110

        # Verify dimensions (CSS says width:50, height:25)
        Assert.true(box.width > 49.0 && box.width < 51.0) ? WidthShouldBe50
        Assert.true(box.height > 24.0 && box.height < 26.0) ? HeightShouldBe25

        Playwright.close!(browser)
    )
