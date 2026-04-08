app [main!] {
    pf: platform "https://github.com/growthagent/basic-cli/releases/download/0.27.0/G-A6F5ny0IYDx4hmF3t_YPHUSR28c9ZXMBnh0FEJjwk.tar.br",
    playwright: "../../package/main.roc",
    spec: "https://github.com/niclas-ahden/roc-spec/releases/download/0.2.0/Cv22_pXKIt82Cz5qzFxdm47SNo81RDx6j4gahQIJvME.tar.br",
}

import pf.Arg
import pf.Cmd
import pf.Env
import pf.File
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
        path_a = "/tmp/roc_pw_test_a.txt"
        path_b = "/tmp/roc_pw_test_b.txt"
        File.write_utf8!("aaa", path_a)?
        File.write_utf8!("bbb", path_b)?

        { browser, page } = Playwright.launch_page!(Chromium)?
        Playwright.navigate!(page, "$(worker_url)/file-upload")?

        Playwright.set_input_files!(page, "#multi", Paths([path_a, path_b]))?

        file_count = Playwright.evaluate!(page, "String(document.querySelector('#multi').files.length)")?
        first_name = Playwright.evaluate!(page, "document.querySelector('#multi').files[0].name")?
        second_name = Playwright.evaluate!(page, "document.querySelector('#multi').files[1].name")?

        Playwright.close!(browser)?
        File.delete!(path_a) |> Result.with_default({})
        File.delete!(path_b) |> Result.with_default({})

        Assert.eq(file_count, "2") ? WrongFileCount(file_count)
        Assert.eq(first_name, "roc_pw_test_a.txt") ? WrongFirstName(first_name)
        Assert.eq(second_name, "roc_pw_test_b.txt") ? WrongSecondName(second_name)

        Ok({})
    )
