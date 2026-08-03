app [main!] {
    pf: platform "https://github.com/niclas-ahden/basic-cli/releases/download/0.23.0/7NpDhuqoqGFedmVLvmm1zjq37GCmaFGzwr5sz4ch9wTK.tar.zst",
    playwright: "../../package/main.roc",
    url: "https://github.com/niclas-ahden/roc-url/releases/download/0.6.1/95CwyLo97aKZ5twTy6VtkmmhF6MFKMr7hvPeMi6U7bAF.tar.zst",
    spec: "https://github.com/niclas-ahden/roc-spec/releases/download/0.3.0/2v2CV8CLXRJmQRvfoHtPngAUGgE8jL6DDgXbugZhFVf5.tar.zst",
}

import pf.Cmd
import pf.Env
import pf.OsStr exposing [OsStr]
import pf.Path
import playwright.Playwright
import url.Url
import spec.Assert
import spec.TestEnvironment

hooks = {
    new: Cmd.new_str,
    args: Cmd.args_str,
    spawn_grouped!: Cmd.spawn_grouped!,
    write_stdin!: Cmd.Child.write_stdin!,
    read_stdout!: Cmd.Child.read_stdout!,
    kill!: Cmd.Child.kill!,
}

## The per-worker test-server URL, from the env the runner sets:
## http://$ROC_SPEC_HOST:($ROC_SPEC_BASE_PORT + $WORKER_INDEX)
worker_url! : {} => Url
worker_url! = |{}| {
    env = { env_var!: Env.var_str! }
    url_str =
        match TestEnvironment.worker_url!(env) {
            Ok(s) => s
            Err(_) => { crash "worker_url: ROC_SPEC_BASE_PORT or WORKER_INDEX missing or invalid (run via tests/run.roc)" }
        }
    # The runner builds this env, so the URL always parses and an Err here is
    # impossible.
    match Url.parse(url_str) {
        Ok(u) => u
        Err(_) => { crash "worker_url: unparseable server url" }
    }
}

main! : List(OsStr) => Try({}, _)
main! = |_args| {
    url = worker_url!({})
    path_a = "/tmp/roc_pw_test_a.txt"
    path_b = "/tmp/roc_pw_test_b.txt"
    Path.write_utf8!(Path.Utf8(path_a), "aaa")?
    Path.write_utf8!(Path.Utf8(path_b), "bbb")?

    { browser, page } = Playwright.launch_page!(hooks, Chromium(DefaultChannel))?
    Playwright.navigate!(page, Url.to_str(Url.append_path(url, ["file-upload"]).ok_or(url)))?

    # Annotated so the unused Buffers payload type doesn't stay unresolved
    files : Playwright.InputFiles
    files = Paths([path_a, path_b])
    Playwright.set_input_files!(page, "#multi", files)?

    file_count = Playwright.evaluate!(page, "String(document.querySelector('#multi').files.length)")?
    first_name = Playwright.evaluate!(page, "document.querySelector('#multi').files[0].name")?
    second_name = Playwright.evaluate!(page, "document.querySelector('#multi').files[1].name")?

    Playwright.close!(browser)?
    _ = Path.delete!(Path.Utf8(path_a))
    _ = Path.delete!(Path.Utf8(path_b))

    Assert.eq(file_count, "2") ? |_| WrongFileCount(file_count)
    Assert.eq(first_name, "roc_pw_test_a.txt") ? |_| WrongFirstName(first_name)
    Assert.eq(second_name, "roc_pw_test_b.txt") ? |_| WrongSecondName(second_name)

    Ok({})
}
