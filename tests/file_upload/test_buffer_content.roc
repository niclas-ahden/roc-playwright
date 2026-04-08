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

main! : List Arg.Arg => Result {} _
main! = |_args|
    TestEnvironment.with!(|worker_url|
        { browser, page } = Playwright.launch_page!(Chromium)?
        Playwright.navigate!(page, "$(worker_url)/file-upload")?

        content = Str.to_utf8("hello world from buffer")
        Playwright.set_input_files!(page, "#any-file", Buffers([{
            name: "greeting.txt",
            mime_type: "text/plain",
            buffer: content,
        }]))?

        file_name = Playwright.evaluate!(page, "document.querySelector('#any-file').files[0].name")?
        file_size = Playwright.evaluate!(page, "String(document.querySelector('#any-file').files[0].size)")?
        file_type = Playwright.evaluate!(page, "document.querySelector('#any-file').files[0].type")?

        Playwright.close!(browser)?

        Assert.eq(file_name, "greeting.txt") ? WrongFileName(file_name)
        Assert.eq(file_size, Num.to_str(List.len(content))) ? WrongFileSize(file_size)
        Assert.eq(file_type, "text/plain") ? WrongFileType(file_type)

        Ok({})
    )
