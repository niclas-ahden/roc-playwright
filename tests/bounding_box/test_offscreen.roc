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

## Test: bounding_box! on offscreen element returns negative coordinates
## Elements positioned outside viewport still have a bounding box
main! : List Arg.Arg => Result {} _
main! = |_args|
    TestEnvironment.with!(|worker_url|
        { browser, page } = Playwright.launch_page_with!({ browser_type: Chromium, headless: Bool.true, timeout: TimeoutMilliseconds(5000) })?

        Playwright.navigate!(page, "$(worker_url)/bounding-box-test")?

        # Offscreen element (top: -1000px, left: -1000px)
        box = Playwright.bounding_box!(page, "#offscreen")?

        # Coordinates should be negative (offscreen)
        Assert.true(box.x < 0.0) ? XShouldBeNegative
        Assert.true(box.y < 0.0) ? YShouldBeNegative

        # But dimensions should still be correct
        Assert.true(box.width > 99.0 && box.width < 101.0) ? WidthShouldBe100
        Assert.true(box.height > 49.0 && box.height < 51.0) ? HeightShouldBe50

        Playwright.close!(browser)
    )
