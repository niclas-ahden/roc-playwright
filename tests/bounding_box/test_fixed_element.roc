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

## Test: bounding_box! returns correct position and dimensions for a fixed element
main! : List Arg.Arg => Result {} _
main! = |_args|
    TestEnvironment.with!(|worker_url|
        { browser, page } = Playwright.launch_page_with!({ browser_type: Chromium, headless: Bool.true, timeout: TimeoutMilliseconds(5000) })?

        Playwright.navigate!(page, "$(worker_url)/bounding-box-test")?

        # Get bounding box of the fixed element (positioned at top:100, left:150, 200x100)
        box = Playwright.bounding_box!(page, "#fixed-box")?

        # Verify position (CSS says top:100, left:150)
        Assert.true(box.x > 149.0 && box.x < 151.0) ? XShouldBe150
        Assert.true(box.y > 99.0 && box.y < 101.0) ? YShouldBe100

        # Verify dimensions (CSS says width:200, height:100)
        Assert.true(box.width > 199.0 && box.width < 201.0) ? WidthShouldBe200
        Assert.true(box.height > 99.0 && box.height < 101.0) ? HeightShouldBe100

        Playwright.close!(browser)
    )
