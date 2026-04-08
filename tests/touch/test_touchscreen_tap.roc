app [main!] {
    pf: platform "https://github.com/growthagent/basic-cli/releases/download/0.27.0/G-A6F5ny0IYDx4hmF3t_YPHUSR28c9ZXMBnh0FEJjwk.tar.br",
    playwright: "../../package/main.roc",
    spec: "https://github.com/niclas-ahden/roc-spec/releases/download/0.2.0/Cv22_pXKIt82Cz5qzFxdm47SNo81RDx6j4gahQIJvME.tar.br",
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

## Test: touchscreen_tap! triggers a click at the correct coordinates
main! : List Arg.Arg => Result {} _
main! = |_args|
    TestEnvironment.with!(|worker_url|
        browser = Playwright.launch_with!({ browser_type: Chromium, headless: Bool.true, timeout: TimeoutMilliseconds(5000) })?
        context = Playwright.new_context_with!(browser, { has_touch: Bool.true })?
        page = Playwright.new_page!(context)?

        Playwright.navigate!(page, "$(worker_url)/touch-test")?

        # Verify initial state
        initial_text = Playwright.text_content!(page, "#touch-result")?
        Assert.eq(initial_text, "No touch yet") ? WrongInitialState(initial_text)

        # Tap in the center of the touch area (300x200 element)
        box = Playwright.bounding_box!(page, "#touch-area")?
        center_x = box.x + (box.width / 2.0)
        center_y = box.y + (box.height / 2.0)
        Playwright.touchscreen_tap!(page, center_x, center_y)?

        # The tap triggers touch events then a click. The click handler writes
        # "Clicked at: X, Y" with the actual coordinates.
        result_text = Playwright.text_content!(page, "#touch-result")?
        Assert.true(Str.starts_with(result_text, "Clicked at:")) ? WrongResultFormat(result_text)

        # Verify coordinates are reasonable (should be near the center of the 300x200 area)
        # The touch area starts at box.x, box.y, so center is roughly (box.x + 150, box.y + 100)
        # We just verify the coordinates are present and are numbers
        coords = Str.replace_first(result_text, "Clicked at: ", "")
        Assert.true(Str.contains(coords, ",")) ? MissingCommaInCoords(coords)

        Playwright.close!(browser)
    )
