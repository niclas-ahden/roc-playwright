app [main!] {
    pf: platform "https://github.com/niclas-ahden/basic-cli/releases/download/0.24.0/2mx1EsQx1HEG7HdbW2CwUpexvmJZW4nSCpjbur5GXyRe.tar.zst",
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

## An absolute, fully resolved path to `name` in the system temp directory,
## which is what Playwright demands of a local upload path. macOS and Windows
## both hand back a temp directory with a trailing separator, and the doubled
## separator that joining onto it produces is a path `path.resolve` would
## change, which Playwright rejects.
temp_path! : Str => Str
temp_path! = |name| {
    sep = if Env.platform!().os == WINDOWS { "\\" } else { "/" }
    dir = Path.display(Env.temp_dir!())
    base =
        if dir.ends_with(sep) {
            Str.from_utf8_lossy(Str.to_utf8(dir).drop_last(1))
        } else {
            dir
        }
    "${base}${sep}${name}"
}

main! : List(OsStr) => Try({}, _)
main! = |_args| {
    url = worker_url!({})
    test_path = temp_path!("roc_playwright_test_upload.txt")
    Path.write_utf8!(Path.Utf8(test_path), "hello from test")?

    { browser, page } = Playwright.launch_page!(

        { new: Cmd.new_str, spawn!: Cmd.spawn! },

        Chromium(DefaultChannel),

    )?
    page.navigate!(Url.to_str(Url.append_path(url, ["file-upload"]).ok_or(url)))?

    # Annotated so the unused Buffers payload type doesn't stay unresolved
    files : Playwright.InputFiles
    files = Paths([test_path])
    page.set_input_files!("#any-file", files)?

    file_name = page.evaluate!("document.querySelector('#any-file').files[0].name")?
    file_size = page.evaluate!("String(document.querySelector('#any-file').files[0].size)")?

    browser.close!()?
    _ = Path.delete!(Path.Utf8(test_path))

    Assert.eq(file_name, "roc_playwright_test_upload.txt") ? |_| WrongFileName(file_name)
    Assert.eq(file_size, "15") ? |_| WrongFileSize(file_size)

    Ok({})
}
