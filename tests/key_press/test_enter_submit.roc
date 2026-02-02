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

        Playwright.navigate!(page, "$(worker_url)/keyboard-form")?

        # Verify initial state
        initial_status = Playwright.text_content!(page, "#status")?
        Assert.eq(initial_status, "Form not submitted") ? InitialStateShouldNotBeSubmitted

        # Fill the input with a name
        Playwright.fill!(page, "#name-input", "John Doe")?

        # Verify fill worked
        filled_value = Playwright.input_value!(page, "#name-input")?
        Assert.eq(filled_value, "John Doe") ? FillShouldWork

        # Press Enter on the input to submit the form (targeted)
        Playwright.key_press!(page, "#name-input", Enter, [])?

        # Verify form was submitted
        status = Playwright.text_content!(page, "#status")?
        Assert.eq(status, "Form submitted with: John Doe") ? FormShouldBeSubmitted

        Playwright.close!(browser)
    )
