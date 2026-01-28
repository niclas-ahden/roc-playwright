module
    {
        cmd_new,
        cmd_args,
        cmd_spawn_grouped!,
    } -> [
        Browser,
        Context,
        Page,
        BrowserType,
        Timeout,
        BoundingBox,
        launch!,
        launch_with!,
        launch_page!,
        launch_page_with!,
        new_context!,
        new_context_with!,
        new_page!,
        navigate!,
        navigate_with!,
        WaitUntil,
        get_title!,
        text_content!,
        input_value!,
        get_attribute!,
        click!,
        tap!,
        fill!,
        press_sequentially!,
        hover!,
        is_visible!,
        wait_for_selector!,
        query_count!,
        bounding_box!,
        mouse_move!,
        mouse_move_with_steps!,
        mouse_down!,
        mouse_up!,
        touchscreen_tap!,
        touch_drag!,
        evaluate!,
        close!,
    ]

import json.Json
import json.Option exposing [Option]

# Protocol message types for JSON decoding

ResponseMessage : {
    id : Option U64,
    guid : Option Str,
    method : Option Str,
    result : Option ResponseResult,
    error : Option ResponseError,
}

IdCheckMessage : {
    id : Option U64,
}

ResponseResult : {
    response : Option ResponseRef,
    value : Option SerializedStringValue,
}

SerializedStringValue : {
    s : Str,
}

PlainStringResponseMessage : {
    id : Option U64,
    result : Option PlainStringResult,
    error : Option ResponseError,
}

PlainStringResult : {
    value : Option Str,
}

BoolResponseMessage : {
    id : Option U64,
    result : Option BoolResult,
    error : Option ResponseError,
}

BoolResult : {
    value : Bool,
}

IntResponseMessage : {
    id : Option U64,
    result : Option IntResult,
    error : Option ResponseError,
}

IntResult : {
    value : U64,
}

ResponseRef : {
    guid : Str,
}

ResponseError : {
    error : ErrorDetails,
}

ErrorDetails : {
    message : Str,
}

CreateMessage : {
    guid : Str,
    method : Str,
    params : CreateParams,
}

CreateParams : {
    type : Str,
    guid : Str,
}

BrowserTypeCreateMessage : {
    method : Option Str,
    params : Option BrowserTypeCreateParams,
}

BrowserTypeCreateParams : {
    type : Option Str,
    guid : Option Str,
    initializer : Option BrowserTypeInitializer,
}

BrowserTypeInitializer : {
    name : Option Str,
}

# Protocol messages for encoding (sending to driver)

InitializeMessage : {
    id : U64,
    guid : Str,
    method : Str,
    params : InitializeParams,
    metadata : {},
}

InitializeParams : {
    sdkLanguage : Str,
}

LaunchMessage : {
    id : U64,
    guid : Str,
    method : Str,
    params : LaunchParams,
    metadata : {},
}

LaunchParams : {
    headless : Bool,
    timeout : U64,
}

SimpleMessage : {
    id : U64,
    guid : Str,
    method : Str,
    params : {},
    metadata : {},
}

GotoMessage : {
    id : U64,
    guid : Str,
    method : Str,
    params : GotoParams,
    metadata : {},
}

GotoParams : {
    url : Str,
    timeout : U64,
}

GotoWithWaitUntilMessage : {
    id : U64,
    guid : Str,
    method : Str,
    params : GotoWithWaitUntilParams,
    metadata : {},
}

GotoWithWaitUntilParams : {
    url : Str,
    timeout : U64,
    waitUntil : Str,
}

SelectorMessage : {
    id : U64,
    guid : Str,
    method : Str,
    params : SelectorParams,
    metadata : {},
}

SelectorParams : {
    selector : Str,
    timeout : U64,
}

WaitForSelectorMessage : {
    id : U64,
    guid : Str,
    method : Str,
    params : WaitForSelectorParams,
    metadata : {},
}

WaitForSelectorParams : {
    selector : Str,
    timeout : U64,
    state : Str,
}

FillMessage : {
    id : U64,
    guid : Str,
    method : Str,
    params : FillParams,
    metadata : {},
}

FillParams : {
    selector : Str,
    value : Str,
    timeout : U64,
}

PressSequentiallyMessage : {
    id : U64,
    guid : Str,
    method : Str,
    params : PressSequentiallyParams,
    metadata : {},
}

PressSequentiallyParams : {
    selector : Str,
    text : Str,
    timeout : U64,
}

SelectorOnlyMessage : {
    id : U64,
    guid : Str,
    method : Str,
    params : SelectorOnlyParams,
    metadata : {},
}

SelectorOnlyParams : {
    selector : Str,
}

GetAttributeMessage : {
    id : U64,
    guid : Str,
    method : Str,
    params : GetAttributeParams,
    metadata : {},
}

GetAttributeParams : {
    selector : Str,
    name : Str,
    timeout : U64,
}

MouseMoveMessage : {
    id : U64,
    guid : Str,
    method : Str,
    params : MouseMoveParams,
    metadata : {},
}

MouseMoveParams : {
    x : F64,
    y : F64,
    steps : U64,
}

MouseButtonMessage : {
    id : U64,
    guid : Str,
    method : Str,
    params : MouseButtonParams,
    metadata : {},
}

MouseButtonParams : {
    button : Str,
    clickCount : U64,
}

TouchTapMessage : {
    id : U64,
    guid : Str,
    method : Str,
    params : TouchTapParams,
    metadata : {},
}

TouchTapParams : {
    x : F64,
    y : F64,
}

EvaluateMessage : {
    id : U64,
    guid : Str,
    method : Str,
    params : EvaluateParams,
    metadata : {},
}

EvaluateParams : {
    expression : Str,
    isFunction : Bool,
    arg : EvaluateArg,
}

EvaluateArg : {
    value : SerializedUndefined,
    handles : List {},
}

SerializedUndefined : {
    v : Str,
}

NewContextMessage : {
    id : U64,
    guid : Str,
    method : Str,
    params : NewContextParams,
    metadata : {},
}

NewContextParams : {
    hasTouch : Bool,
}

ElementSimpleMessage : {
    id : U64,
    guid : Str,
    method : Str,
    params : {},
    metadata : {},
}

ElementHandleResponseMessage : {
    id : Option U64,
    result : Option ElementHandleResult,
    error : Option ResponseError,
}

ElementHandleResult : {
    element : Option ResponseRef,
}

## Bounding box of an element in CSS pixels, relative to the main frame viewport.
BoundingBox : {
    x : F64,
    y : F64,
    width : F64,
    height : F64,
}

BoundingBoxResponseMessage : {
    id : Option U64,
    result : Option BoundingBoxResult,
    error : Option ResponseError,
}

BoundingBoxResult : {
    value : Option BoundingBoxValue,
}

BoundingBoxValue : {
    x : F64,
    y : F64,
    width : F64,
    height : F64,
}

## Which browser engine to use.
BrowserType : [Chromium, Firefox, WebKit]

## Timeout for operations. `NoTimeout` means wait indefinitely.
Timeout : [TimeoutMilliseconds U64, NoTimeout]

timeout_to_ms : Timeout -> U64
timeout_to_ms = |t|
    when t is
        TimeoutMilliseconds(ms) -> ms
        NoTimeout -> 0

## Handle to a browser instance. Returned by `launch!`.
Browser : {
    write_stdin! : List U8 => Result {} [WriteFailed],
    read_stdout! : U64 => Result (List U8) [ReadFailed],
    kill! : {} => Result {} [KillFailed],
    browser_guid : Str,
    timeout : Timeout,
}

## A browser context with isolated session state.
Context : {
    browser : Browser,
    context_guid : Str,
    has_touch : Bool,
}

## A page (browser tab) where automation happens.
Page : {
    context : Context,
    page_guid : Str,
    frame_guid : Str,
}

## When to consider navigation complete.
WaitUntil : [
    Load,
    DomContentLoaded,
    NetworkIdle,
    Commit,
]

# Message ID used for all commands.
#
# The Playwright protocol uses message IDs to match responses to requests,
# designed for async/parallel usage where multiple commands are in flight.
#
# We use a constant ID because our usage is fully synchronous:
# - We send one command and wait for its response before sending the next
# - We use `read_until_response!` which blocks until the matching response arrives
# - TCP guarantees message ordering
# - Event messages (which we skip) don't have matching IDs
#
# This simplifies the API by not requiring callers to thread Browser state.
# If async/parallel commands are needed in the future, this would need to change
# to use unique incrementing IDs per command.
msg_id : U64
msg_id = 1000

encode_u32_le : U32 -> List U8
encode_u32_le = |n| [
    Num.to_u8(Num.bitwise_and(n, 0xFF)),
    Num.to_u8(Num.bitwise_and(Num.shift_right_by(n, 8), 0xFF)),
    Num.to_u8(Num.bitwise_and(Num.shift_right_by(n, 16), 0xFF)),
    Num.to_u8(Num.bitwise_and(Num.shift_right_by(n, 24), 0xFF)),
]

decode_u32_le : List U8 -> U32
decode_u32_le = |bytes|
    b0 = List.get(bytes, 0) |> Result.with_default(0) |> Num.to_u32
    b1 = List.get(bytes, 1) |> Result.with_default(0) |> Num.to_u32
    b2 = List.get(bytes, 2) |> Result.with_default(0) |> Num.to_u32
    b3 = List.get(bytes, 3) |> Result.with_default(0) |> Num.to_u32
    Num.bitwise_or(
        Num.bitwise_or(b0, Num.shift_left_by(b1, 8)),
        Num.bitwise_or(Num.shift_left_by(b2, 16), Num.shift_left_by(b3, 24)),
    )

send_message! = |write_stdin!, message_bytes|
    length = List.len(message_bytes) |> Num.to_u32
    length_bytes = encode_u32_le(length)

    # Send length prefix
    write_stdin!(length_bytes)?

    # Send message
    write_stdin!(message_bytes)

receive_message_bytes! = |read_stdout!|
    # Read 4-byte length prefix
    length_bytes = read_stdout!(4)?
    length = decode_u32_le(length_bytes) |> Num.to_u64

    # Read message body
    read_stdout!(length)

decode_create_message : List U8 -> Result CreateMessage [DecodeError]
decode_create_message = |bytes|
    Decode.from_bytes(bytes, Json.utf8)
    |> Result.map_err(|_| DecodeError)

decode_response_message : List U8 -> Result ResponseMessage [DecodeError]
decode_response_message = |bytes|
    Decode.from_bytes(bytes, Json.utf8)
    |> Result.map_err(|_| DecodeError)

decode_bool_response : List U8 -> Result BoolResponseMessage [DecodeError]
decode_bool_response = |bytes|
    Decode.from_bytes(bytes, Json.utf8)
    |> Result.map_err(|_| DecodeError)

decode_int_response : List U8 -> Result IntResponseMessage [DecodeError]
decode_int_response = |bytes|
    Decode.from_bytes(bytes, Json.utf8)
    |> Result.map_err(|_| DecodeError)

decode_plain_string_response : List U8 -> Result PlainStringResponseMessage [DecodeError]
decode_plain_string_response = |bytes|
    Decode.from_bytes(bytes, Json.utf8)
    |> Result.map_err(|_| DecodeError)

decode_id_check : List U8 -> Result IdCheckMessage [DecodeError]
decode_id_check = |bytes|
    Decode.from_bytes(bytes, Json.utf8)
    |> Result.map_err(|_| DecodeError)

decode_browser_type_create : List U8 -> Result BrowserTypeCreateMessage [DecodeError]
decode_browser_type_create = |bytes|
    Decode.from_bytes(bytes, Json.utf8)
    |> Result.map_err(|_| DecodeError)

decode_bounding_box_response : List U8 -> Result BoundingBoxResponseMessage [DecodeError]
decode_bounding_box_response = |bytes|
    Decode.from_bytes(bytes, Json.utf8)
    |> Result.map_err(|_| DecodeError)

decode_element_handle_response : List U8 -> Result ElementHandleResponseMessage [DecodeError]
decode_element_handle_response = |bytes|
    Decode.from_bytes(bytes, Json.utf8)
    |> Result.map_err(|_| DecodeError)

## Launch a browser with default settings (headless, 30s timeout).
##
## ```
## browser = Playwright.launch!(Chromium)?
## ```
launch! : BrowserType => Result Browser _
launch! = |browser_type|
    launch_with!({ browser_type, headless: Bool.true, timeout: TimeoutMilliseconds(30000) })

## Launch a browser with custom options.
##
## ```
## browser = Playwright.launch_with!({
##     browser_type: Chromium,
##     headless: Bool.false,
##     timeout: TimeoutMilliseconds(60000),
## })?
## ```
launch_with! : { browser_type : BrowserType, headless : Bool, timeout : Timeout } => Result Browser _
launch_with! = |{ browser_type, headless, timeout }|
    playwright_cmd = "playwright"
    child =
        cmd_new(playwright_cmd)
        |> cmd_args(["run-driver"])
        |> cmd_spawn_grouped!()
        |> Result.map_err(
            |err|
                when err is
                    SpawnFailed(_) ->
                        PlaywrightNotFound(
                            """
                            Could not find '${playwright_cmd}' command. Make sure Playwright is installed and available in your PATH.
                            If using Nix, add 'pkgs.playwright-test' to your devShell.
                            """,
                        )

                    other -> other,
        )?

    # Initialization is wrapped to ensure cleanup on failure.
    # We need separate wrappers for init vs the Browser record because Roc unifies
    # error types across all uses of a closure. Init wrappers get unified with
    # BrowserTypeNotFound etc, but Browser record needs narrow [WriteFailed] types.
    init_result = initialize_browser!(child, browser_type, headless, timeout)
    when init_result is
        Ok(browser) -> Ok(browser)
        Err(err) ->
            # Kill the process before returning the error
            when child.kill!({}) is
                _ -> Err(err)

initialize_browser! = |child, browser_type, headless, timeout|
    # Wrappers for initialization (their error types will be unified with other errors)
    init_write = |bytes| child.write_stdin!(bytes) |> Result.map_err(|_| WriteFailed)
    init_read = |n| child.read_stdout!(n) |> Result.map_err(|_| ReadFailed)

    # Send initial message to initialize the connection
    init_msg : InitializeMessage
    init_msg = { id: 1, guid: "", method: "initialize", params: { sdkLanguage: "javascript" }, metadata: {} }
    send_message!(init_write, Encode.to_bytes(init_msg, Json.utf8))?

    # Read initialization responses until we get the id:1 response
    browser_type_name = browser_type_to_name(browser_type)
    browser_type_guid = read_init_and_find_browser_type!(init_read, browser_type_name)?

    # Now launch the browser
    launch_msg : LaunchMessage
    launch_msg = { id: 2, guid: browser_type_guid, method: "launch", params: { headless, timeout: timeout_to_ms(timeout) }, metadata: {} }
    send_message!(init_write, Encode.to_bytes(launch_msg, Json.utf8))?

    # Read browser creation response
    browser_guid = read_until_browser_guid!(init_read)?

    # Read the launch response (id:2)
    _launch_response = read_until_response!(init_read, 2)?

    # Fresh wrappers for Browser record (with narrow error types, not yet used anywhere)
    Ok({
        write_stdin!: |bytes| child.write_stdin!(bytes) |> Result.map_err(|_| WriteFailed),
        read_stdout!: |n| child.read_stdout!(n) |> Result.map_err(|_| ReadFailed),
        kill!: |{}| child.kill!({}) |> Result.map_err(|_| KillFailed),
        browser_guid,
        timeout,
    })

## Launch a browser and create a page in one step.
##
## ```
## { browser, page } = Playwright.launch_page!(Chromium)?
## ```
launch_page! = |browser_type|
    launch_page_with!({ browser_type, headless: Bool.true, timeout: TimeoutMilliseconds(30000) })

## Launch a browser with custom options and create a page.
##
## ```
## { browser, page } = Playwright.launch_page_with!({
##     browser_type: Chromium,
##     headless: Bool.false,
##     timeout: TimeoutMilliseconds(5000),
## })?
## ```
launch_page_with! = |options|
    browser = launch_with!(options)?
    context = new_context!(browser)?
    page = new_page!(context)?
    Ok({ browser, page })

## Create a new browser context with isolated session state.
##
## ```
## context = Playwright.new_context!(browser)?
## ```
new_context! = |browser|
    new_context_with!(browser, { has_touch: Bool.false })

## Create a new browser context with options.
##
## ```
## context = Playwright.new_context_with!(browser, { has_touch: Bool.true })?
## ```
new_context_with! = |browser, options|
    context_msg : NewContextMessage
    context_msg = { id: msg_id, guid: browser.browser_guid, method: "newContext", params: { hasTouch: options.has_touch }, metadata: {} }
    send_message!(browser.write_stdin!, Encode.to_bytes(context_msg, Json.utf8))?

    context_guid = read_until_context_guid!(browser.read_stdout!)?
    response = read_until_response!(browser.read_stdout!, msg_id)?

    when Option.get(response.error) is
        Some(err) ->
            Err(NewContextError(err.error.message))

        None ->
            Ok({ browser, context_guid, has_touch: options.has_touch })

## Create a new page (tab) in the browser context.
##
## ```
## page = Playwright.new_page!(context)?
## ```
new_page! = |context|
    browser = context.browser
    page_msg : SimpleMessage
    page_msg = { id: msg_id, guid: context.context_guid, method: "newPage", params: {}, metadata: {} }
    send_message!(browser.write_stdin!, Encode.to_bytes(page_msg, Json.utf8))?

    { page_guid, frame_guid } = read_until_page_and_frame!(browser.read_stdout!)?
    response = read_until_response!(browser.read_stdout!, msg_id)?

    when Option.get(response.error) is
        Some(err) ->
            Err(NewPageError(err.error.message))

        None ->
            Ok({ context, page_guid, frame_guid })

browser_type_to_name : BrowserType -> Str
browser_type_to_name = |browser_type|
    when browser_type is
        Chromium -> "chromium"
        Firefox -> "firefox"
        WebKit -> "webkit"

read_init_and_find_browser_type! = |read_stdout!, browser_type_name|
    read_init_loop!(read_stdout!, browser_type_name, "")

read_init_loop! = |read_stdout!, browser_type_name, found_guid|
    bytes = receive_message_bytes!(read_stdout!)?

    # Check if this is the final id:1 response
    when decode_id_check(bytes) is
        Ok(id_msg) ->
            when Option.get(id_msg.id) is
                Some(1) ->
                    # We're done - return the browser type GUID we found
                    if Str.is_empty(found_guid) then
                        Err(BrowserTypeNotFound(browser_type_name))
                    else
                        Ok(found_guid)

                _ ->
                    # Not the id:1 response, check if it's a BrowserType create message
                    new_guid = extract_browser_type_guid(bytes, browser_type_name, found_guid)
                    read_init_loop!(read_stdout!, browser_type_name, new_guid)

        Err(_) ->
            # Couldn't decode id, check if it's a BrowserType create message
            new_guid = extract_browser_type_guid(bytes, browser_type_name, found_guid)
            read_init_loop!(read_stdout!, browser_type_name, new_guid)

extract_browser_type_guid : List U8, Str, Str -> Str
extract_browser_type_guid = |bytes, browser_type_name, default|
    when decode_browser_type_create(bytes) is
        Ok(msg) ->
            is_create = Option.get(msg.method) == Some("__create__")
            when Option.get(msg.params) is
                Some(params) ->
                    is_browser_type = Option.get(params.type) == Some("BrowserType")
                    name_matches =
                        when Option.get(params.initializer) is
                            Some(init) -> Option.get(init.name) == Some(browser_type_name)
                            None -> Bool.false

                    if is_create and is_browser_type and name_matches then
                        when Option.get(params.guid) is
                            Some(guid) -> guid
                            None -> default
                    else
                        default

                None -> default

        Err(_) -> default

read_until_browser_guid! = |read_stdout!|
    bytes = receive_message_bytes!(read_stdout!)?

    when decode_create_message(bytes) is
        Ok(msg) ->
            if msg.params.type == "Browser" then
                Ok(msg.params.guid)
            else
                read_until_browser_guid!(read_stdout!)

        Err(_) ->
            # Not a create message, keep reading
            read_until_browser_guid!(read_stdout!)

read_until_context_guid! = |read_stdout!|
    bytes = receive_message_bytes!(read_stdout!)?

    when decode_create_message(bytes) is
        Ok(msg) ->
            if msg.params.type == "BrowserContext" then
                Ok(msg.params.guid)
            else
                read_until_context_guid!(read_stdout!)

        Err(_) ->
            # Not a create message, keep reading
            read_until_context_guid!(read_stdout!)

read_until_page_and_frame! = |read_stdout!|
    read_page_frame_loop!(read_stdout!, "", "")

read_page_frame_loop! = |read_stdout!, found_page, found_frame|
    # If we have both, we're done
    if !(Str.is_empty(found_page)) and !(Str.is_empty(found_frame)) then
        Ok({ page_guid: found_page, frame_guid: found_frame })
    else
        bytes = receive_message_bytes!(read_stdout!)?

        when decode_create_message(bytes) is
            Ok(msg) ->
                new_page =
                    if msg.params.type == "Page" then
                        msg.params.guid
                    else
                        found_page

                new_frame =
                    if msg.params.type == "Frame" then
                        msg.params.guid
                    else
                        found_frame

                read_page_frame_loop!(read_stdout!, new_page, new_frame)

            Err(_) ->
                # Not a create message, keep reading
                read_page_frame_loop!(read_stdout!, found_page, found_frame)

## Navigate to a URL.
##
## ```
## Playwright.navigate!(page, "https://example.com")?
## ```
navigate! = |page, url|
    context = page.context
    browser = context.browser

    goto_msg : GotoMessage
    goto_msg = { id: msg_id, guid: page.frame_guid, method: "goto", params: { url, timeout: timeout_to_ms(browser.timeout) }, metadata: {} }
    send_message!(browser.write_stdin!, Encode.to_bytes(goto_msg, Json.utf8))?

    response = read_until_response!(browser.read_stdout!, msg_id)?

    when Option.get(response.error) is
        Some(err) ->
            Err(NavigateError(err.error.message))

        None ->
            Ok({})

## Navigate to a URL with options.
##
## ```
## Playwright.navigate_with!(page, { url: "https://example.com", wait_until: NetworkIdle })?
## ```
navigate_with! = |page, { url, wait_until }|
    context = page.context
    browser = context.browser

    goto_msg : GotoWithWaitUntilMessage
    goto_msg = { id: msg_id, guid: page.frame_guid, method: "goto", params: { url, timeout: timeout_to_ms(browser.timeout), waitUntil: wait_until_to_str(wait_until) }, metadata: {} }
    send_message!(browser.write_stdin!, Encode.to_bytes(goto_msg, Json.utf8))?

    response = read_until_response!(browser.read_stdout!, msg_id)?

    when Option.get(response.error) is
        Some(err) ->
            Err(NavigateError(err.error.message))

        None ->
            Ok({})

wait_until_to_str : WaitUntil -> Str
wait_until_to_str = |wait_until|
    when wait_until is
        Load -> "load"
        DomContentLoaded -> "domcontentloaded"
        NetworkIdle -> "networkidle"
        Commit -> "commit"

## Get the page title.
##
## ```
## title = Playwright.get_title!(page)?
## ```
get_title! = |page|
    context = page.context
    browser = context.browser
    title_msg : SimpleMessage
    title_msg = { id: msg_id, guid: page.frame_guid, method: "title", params: {}, metadata: {} }
    send_message!(browser.write_stdin!, Encode.to_bytes(title_msg, Json.utf8))?

    response = read_until_plain_string_response!(browser.read_stdout!, msg_id)?

    when Option.get(response.error) is
        Some(err) ->
            Err(TitleError(err.error.message))

        None ->
            when Option.get(response.result) is
                Some(result) ->
                    when Option.get(result.value) is
                        Some(title) -> Ok(title)
                        None -> Err(TitleNotFound)

                None ->
                    Err(TitleNotFound)

## Get the text content of an element.
##
## ```
## text = Playwright.text_content!(page, "h1")?
## ```
text_content! = |page, selector|
    context = page.context
    browser = context.browser
    msg : SelectorMessage
    msg = { id: msg_id, guid: page.frame_guid, method: "textContent", params: { selector, timeout: timeout_to_ms(browser.timeout) }, metadata: {} }
    send_message!(browser.write_stdin!, Encode.to_bytes(msg, Json.utf8))?

    when read_until_nullable_string_response!(browser.read_stdout!, msg_id)? is
        Ok(value) -> Ok(value)
        Err(ValueIsNull) -> Err(TextContentNotFound)

## Get the value of an input or textarea.
##
## ```
## value = Playwright.input_value!(page, "#email")?
## ```
input_value! = |page, selector|
    context = page.context
    browser = context.browser
    msg : SelectorMessage
    msg = { id: msg_id, guid: page.frame_guid, method: "inputValue", params: { selector, timeout: timeout_to_ms(browser.timeout) }, metadata: {} }
    send_message!(browser.write_stdin!, Encode.to_bytes(msg, Json.utf8))?

    response = read_until_plain_string_response!(browser.read_stdout!, msg_id)?

    when Option.get(response.error) is
        Some(err) ->
            Err(InputValueError(err.error.message))

        None ->
            when Option.get(response.result) is
                Some(result) ->
                    when Option.get(result.value) is
                        Some(value) -> Ok(value)
                        None -> Err(InputValueNotFound)

                None ->
                    Err(InputValueNotFound)

## Get an attribute value from an element.
##
## ```
## href = Playwright.get_attribute!(page, "a.nav-link", "href")?
## ```
get_attribute! = |page, selector, attribute_name|
    context = page.context
    browser = context.browser
    msg : GetAttributeMessage
    msg = { id: msg_id, guid: page.frame_guid, method: "getAttribute", params: { selector, name: attribute_name, timeout: timeout_to_ms(browser.timeout) }, metadata: {} }
    send_message!(browser.write_stdin!, Encode.to_bytes(msg, Json.utf8))?

    when read_until_nullable_string_response!(browser.read_stdout!, msg_id)? is
        Ok(value) -> Ok(value)
        Err(ValueIsNull) -> Err(AttributeNotFound)

## Click an element.
##
## ```
## Playwright.click!(page, "button#submit")?
## ```
click! = |page, selector|
    context = page.context
    browser = context.browser
    msg : SelectorMessage
    msg = { id: msg_id, guid: page.frame_guid, method: "click", params: { selector, timeout: timeout_to_ms(browser.timeout) }, metadata: {} }
    send_message!(browser.write_stdin!, Encode.to_bytes(msg, Json.utf8))?

    response = read_until_response!(browser.read_stdout!, msg_id)?

    when Option.get(response.error) is
        Some(err) ->
            Err(ClickError(err.error.message))

        None ->
            Ok({})

## Fill an input or textarea with text.
##
## ```
## Playwright.fill!(page, "#email", "user@example.com")?
## ```
##
## > For WASM apps that rely on keyboard events, use [press_sequentially!] instead.
fill! = |page, selector, value|
    context = page.context
    browser = context.browser
    msg : FillMessage
    msg = { id: msg_id, guid: page.frame_guid, method: "fill", params: { selector, value, timeout: timeout_to_ms(browser.timeout) }, metadata: {} }
    send_message!(browser.write_stdin!, Encode.to_bytes(msg, Json.utf8))?

    response = read_until_response!(browser.read_stdout!, msg_id)?

    when Option.get(response.error) is
        Some(err) ->
            Err(FillError(err.error.message))

        None ->
            Ok({})

## Type text character by character, triggering key events.
##
## ```
## Playwright.press_sequentially!(page, "#search", "hello")?
## ```
press_sequentially! = |page, selector, text|
    context = page.context
    browser = context.browser
    msg : PressSequentiallyMessage
    msg = { id: msg_id, guid: page.frame_guid, method: "type", params: { selector, text, timeout: timeout_to_ms(browser.timeout) }, metadata: {} }
    send_message!(browser.write_stdin!, Encode.to_bytes(msg, Json.utf8))?

    response = read_until_response!(browser.read_stdout!, msg_id)?

    when Option.get(response.error) is
        Some(err) ->
            Err(PressSequentiallyError(err.error.message))

        None ->
            Ok({})

## Move the mouse to the center of an element.
##
## ```
## Playwright.hover!(page, ".dropdown-trigger")?
## ```
hover! = |page, selector|
    context = page.context
    browser = context.browser
    msg : SelectorMessage
    msg = { id: msg_id, guid: page.frame_guid, method: "hover", params: { selector, timeout: timeout_to_ms(browser.timeout) }, metadata: {} }
    send_message!(browser.write_stdin!, Encode.to_bytes(msg, Json.utf8))?

    response = read_until_response!(browser.read_stdout!, msg_id)?

    when Option.get(response.error) is
        Some(err) ->
            Err(HoverError(err.error.message))

        None ->
            Ok({})

## Check if an element is visible. Returns immediately without waiting.
##
## ```
## is_shown = Playwright.is_visible!(page, "#modal")?
## ```
is_visible! = |page, selector|
    context = page.context
    browser = context.browser

    msg : SelectorOnlyMessage
    msg = { id: msg_id, guid: page.frame_guid, method: "isVisible", params: { selector }, metadata: {} }
    send_message!(browser.write_stdin!, Encode.to_bytes(msg, Json.utf8))?

    response = read_until_bool_response!(browser.read_stdout!, msg_id)?

    when Option.get(response.error) is
        Some(err) ->
            Err(IsVisibleError(err.error.message))

        None ->
            when Option.get(response.result) is
                Some(result) -> Ok(result.value)
                None -> Err(IsVisibleNoResult)

## Wait for an element to appear and be visible.
##
## ```
## Playwright.wait_for_selector!(page, "#dynamic-content")?
## ```
wait_for_selector! = |page, selector|
    context = page.context
    browser = context.browser

    msg : WaitForSelectorMessage
    msg = { id: msg_id, guid: page.frame_guid, method: "waitForSelector", params: { selector, timeout: timeout_to_ms(browser.timeout), state: "visible" }, metadata: {} }
    send_message!(browser.write_stdin!, Encode.to_bytes(msg, Json.utf8))?

    response = read_until_response!(browser.read_stdout!, msg_id)?

    when Option.get(response.error) is
        Some(err) ->
            Err(WaitForSelectorTimeout(err.error.message))

        None ->
            Ok({})

# Response readers: read messages until we find one with the expected id.
# Nullable responses (element_handle, bounding_box, nullable_string) check raw JSON
# for the expected field before decoding because roc-json can't decode empty objects {}.

read_until_bool_response! = |read_stdout!, expected_id|
    bytes = receive_message_bytes!(read_stdout!)?

    when decode_id_check(bytes) is
        Ok(id_msg) ->
            when Option.get(id_msg.id) is
                Some(id) ->
                    if id == expected_id then
                        # This is our response - bool responses always have a value
                        when decode_bool_response(bytes) is
                            Ok(msg) -> Ok(msg)
                            Err(_) ->
                                # Bool responses should never fail to decode - this is a bug
                                raw = Str.from_utf8(bytes) |> Result.with_default("<invalid utf8>")
                                Err(UnexpectedBoolResponse(raw))
                    else
                        read_until_bool_response!(read_stdout!, expected_id)

                None ->
                    read_until_bool_response!(read_stdout!, expected_id)

        Err(_) ->
            read_until_bool_response!(read_stdout!, expected_id)

## Count elements matching a selector. Returns `0` if none match.
##
## ```
## count = Playwright.query_count!(page, "ul.results li")?
## ```
query_count! = |page, selector|
    context = page.context
    browser = context.browser
    msg : SelectorOnlyMessage
    msg = { id: msg_id, guid: page.frame_guid, method: "queryCount", params: { selector }, metadata: {} }
    send_message!(browser.write_stdin!, Encode.to_bytes(msg, Json.utf8))?

    response = read_until_int_response!(browser.read_stdout!, msg_id)?

    when Option.get(response.error) is
        Some(err) ->
            Err(QueryCountError(err.error.message))

        None ->
            when Option.get(response.result) is
                Some(result) -> Ok(result.value)
                None -> Err(QueryCountNoResult)

read_until_int_response! = |read_stdout!, expected_id|
    bytes = receive_message_bytes!(read_stdout!)?

    when decode_id_check(bytes) is
        Ok(id_msg) ->
            when Option.get(id_msg.id) is
                Some(id) ->
                    if id == expected_id then
                        # This is our response - int responses always have a value
                        when decode_int_response(bytes) is
                            Ok(msg) -> Ok(msg)
                            Err(_) ->
                                # Int responses should never fail to decode - this is a bug
                                raw = Str.from_utf8(bytes) |> Result.with_default("<invalid utf8>")
                                Err(UnexpectedIntResponse(raw))
                    else
                        read_until_int_response!(read_stdout!, expected_id)

                None ->
                    read_until_int_response!(read_stdout!, expected_id)

        Err(_) ->
            read_until_int_response!(read_stdout!, expected_id)

read_until_plain_string_response! = |read_stdout!, expected_id|
    bytes = receive_message_bytes!(read_stdout!)?

    when decode_id_check(bytes) is
        Ok(id_msg) ->
            when Option.get(id_msg.id) is
                Some(id) ->
                    if id == expected_id then
                        when decode_plain_string_response(bytes) is
                            Ok(msg) -> Ok(msg)
                            Err(_) ->
                                raw = Str.from_utf8(bytes) |> Result.with_default("<invalid utf8>")
                                Err(UnexpectedStringResponse(raw))
                    else
                        read_until_plain_string_response!(read_stdout!, expected_id)

                None ->
                    read_until_plain_string_response!(read_stdout!, expected_id)

        Err(_) ->
            read_until_plain_string_response!(read_stdout!, expected_id)

read_until_response! = |read_stdout!, expected_id|
    bytes = receive_message_bytes!(read_stdout!)?

    # Check if this message has our id using IdCheckMessage first
    when decode_id_check(bytes) is
        Ok(id_msg) ->
            when Option.get(id_msg.id) is
                Some(id) ->
                    if id == expected_id then
                        # This is our response - try to decode the full message
                        when decode_response_message(bytes) is
                            Ok(msg) -> Ok(msg)
                            Err(_) ->
                                # Decoding failed but this was our response - return empty response
                                # This happens for commands like goto to data: URLs where result is {}
                                Ok({
                                    id: Option.some(id),
                                    guid: Option.none({}),
                                    method: Option.none({}),
                                    result: Option.none({}),
                                    error: Option.none({}),
                                })
                    else
                        # Different id, keep reading
                        read_until_response!(read_stdout!, expected_id)

                None ->
                    # No id field (probably an event), keep reading
                    read_until_response!(read_stdout!, expected_id)

        Err(_) ->
            # Decode failed (probably an event), keep reading
            read_until_response!(read_stdout!, expected_id)

read_until_nullable_string_response! = |read_stdout!, expected_id|
    bytes = receive_message_bytes!(read_stdout!)?

    # Use JSON decoding to check if this message has our id
    when decode_id_check(bytes) is
        Ok(id_msg) ->
            when Option.get(id_msg.id) is
                Some(id) ->
                    if id == expected_id then
                        # This is our response - check if it has a value
                        # We check the raw string because roc-json can't decode empty objects {}
                        msg_str = Str.from_utf8(bytes) |> Result.with_default("")
                        if Str.contains(msg_str, "\"value\"") then
                            # Has a value field - check format and decode accordingly
                            if Str.contains(msg_str, "\"s\":") then
                                # Serialized string format: {"value": {"s": "text"}}
                                when decode_response_message(bytes) is
                                    Ok(response) ->
                                        when Option.get(response.error) is
                                            Some(err) -> Err(PlaywrightError(err.error.message))
                                            None ->
                                                when Option.get(response.result) is
                                                    Some(result) ->
                                                        when Option.get(result.value) is
                                                            Some(serialized) -> Ok(Ok(serialized.s))
                                                            None -> Ok(Err(ValueIsNull))
                                                    None -> Ok(Err(ValueIsNull))
                                    Err(_) -> Err(DecodeError)
                            else if Str.contains(msg_str, "\"v\":") then
                                # Serialized null/undefined: {"value": {"v": "null"}} or {"v": "undefined"}
                                Ok(Err(ValueIsNull))
                            else
                                # Plain string format: {"value": "text"}
                                when decode_plain_string_response(bytes) is
                                    Ok(response) ->
                                        when Option.get(response.error) is
                                            Some(err) -> Err(PlaywrightError(err.error.message))
                                            None ->
                                                when Option.get(response.result) is
                                                    Some(result) ->
                                                        when Option.get(result.value) is
                                                            Some(value) -> Ok(Ok(value))
                                                            None -> Ok(Err(ValueIsNull))
                                                    None -> Ok(Err(ValueIsNull))
                                    Err(_) -> Err(DecodeError)
                        else
                            # No value field - it's null
                            Ok(Err(ValueIsNull))
                    else
                        # Different id, keep reading
                        read_until_nullable_string_response!(read_stdout!, expected_id)

                None ->
                    # No id field (probably an event), keep reading
                    read_until_nullable_string_response!(read_stdout!, expected_id)

        Err(_) ->
            # Decode failed (probably an event), keep reading
            read_until_nullable_string_response!(read_stdout!, expected_id)

## Move the mouse to coordinates.
##
## ```
## Playwright.mouse_move!(page, 100.0, 200.0)?
## ```
mouse_move! = |page, x, y|
    mouse_move_with_steps!(page, x, y, 1)

## Move the mouse to coordinates with interpolated steps.
##
## ```
## Playwright.mouse_move_with_steps!(page, 100.0, 200.0, 10)?
## ```
mouse_move_with_steps! = |page, x, y, steps|
    context = page.context
    browser = context.browser
    msg : MouseMoveMessage
    msg = { id: msg_id, guid: page.page_guid, method: "mouseMove", params: { x, y, steps }, metadata: {} }
    send_message!(browser.write_stdin!, Encode.to_bytes(msg, Json.utf8))?

    response = read_until_response!(browser.read_stdout!, msg_id)?

    when Option.get(response.error) is
        Some(err) ->
            Err(MouseMoveError(err.error.message))

        None ->
            Ok({})

## Press the left mouse button at current position.
##
## ```
## Playwright.mouse_down!(page)?
## ```
mouse_down! = |page|
    context = page.context
    browser = context.browser
    msg : MouseButtonMessage
    msg = { id: msg_id, guid: page.page_guid, method: "mouseDown", params: { button: "left", clickCount: 1 }, metadata: {} }
    send_message!(browser.write_stdin!, Encode.to_bytes(msg, Json.utf8))?

    response = read_until_response!(browser.read_stdout!, msg_id)?

    when Option.get(response.error) is
        Some(err) ->
            Err(MouseDownError(err.error.message))

        None ->
            Ok({})

## Release the left mouse button at current position.
##
## ```
## Playwright.mouse_up!(page)?
## ```
mouse_up! = |page|
    context = page.context
    browser = context.browser
    msg : MouseButtonMessage
    msg = { id: msg_id, guid: page.page_guid, method: "mouseUp", params: { button: "left", clickCount: 1 }, metadata: {} }
    send_message!(browser.write_stdin!, Encode.to_bytes(msg, Json.utf8))?

    response = read_until_response!(browser.read_stdout!, msg_id)?

    when Option.get(response.error) is
        Some(err) ->
            Err(MouseUpError(err.error.message))

        None ->
            Ok({})

## Get the bounding box of an element. Waits for the element to be visible.
##
## ```
## box = Playwright.bounding_box!(page, ".swiper")?
## center_x = box.x + box.width / 2.0
## center_y = box.y + box.height / 2.0
## ```
bounding_box! = |page, selector|
    context = page.context
    browser = context.browser

    # Wait for element to be visible first (matches Playwright's auto-wait behavior)
    wait_for_selector!(page, selector)?

    # Query for the element to get its element handle guid
    query_msg : SelectorOnlyMessage
    query_msg = { id: msg_id, guid: page.frame_guid, method: "querySelector", params: { selector }, metadata: {} }
    send_message!(browser.write_stdin!, Encode.to_bytes(query_msg, Json.utf8))?

    element_response = read_until_element_handle_response!(browser.read_stdout!, msg_id)?

    when Option.get(element_response.error) is
        Some(err) ->
            Err(BoundingBoxError(err.error.message))

        None ->
            when Option.get(element_response.result) is
                Some(result) ->
                    when Option.get(result.element) is
                        Some(element_ref) ->
                            # Step 2: Call boundingBox on the element handle
                            box_msg : ElementSimpleMessage
                            box_msg = { id: msg_id, guid: element_ref.guid, method: "boundingBox", params: {}, metadata: {} }
                            send_message!(browser.write_stdin!, Encode.to_bytes(box_msg, Json.utf8))?

                            box_response = read_until_bounding_box_response!(browser.read_stdout!, msg_id)?

                            when Option.get(box_response.error) is
                                Some(box_err) ->
                                    Err(BoundingBoxError(box_err.error.message))

                                None ->
                                    when Option.get(box_response.result) is
                                        Some(box_result) ->
                                            when Option.get(box_result.value) is
                                                Some(box) -> Ok({ x: box.x, y: box.y, width: box.width, height: box.height })
                                                None -> Err(ElementNotVisible)

                                        None -> Err(ElementNotVisible)

                        None -> Err(ElementNotFound)

                None -> Err(ElementNotFound)

read_until_element_handle_response! = |read_stdout!, expected_id|
    bytes = receive_message_bytes!(read_stdout!)?

    when decode_id_check(bytes) is
        Ok(id_msg) ->
            when Option.get(id_msg.id) is
                Some(id) ->
                    if id == expected_id then
                        # This is our response - check if it has an element field
                        msg_str = Str.from_utf8(bytes) |> Result.with_default("")
                        if Str.contains(msg_str, "\"element\"") then
                            # Has an element field - decode it
                            when decode_element_handle_response(bytes) is
                                Ok(msg) -> Ok(msg)
                                Err(_) ->
                                    # Decode failed unexpectedly - return element not found
                                    Ok({
                                        id: Option.some(id),
                                        result: Option.some({ element: Option.none({}) }),
                                        error: Option.none({}),
                                    })
                        else
                            # No element field - Playwright returned {"result": {}}
                            # This means querySelector found no matching element
                            Ok({
                                id: Option.some(id),
                                result: Option.some({ element: Option.none({}) }),
                                error: Option.none({}),
                            })
                    else
                        read_until_element_handle_response!(read_stdout!, expected_id)

                None ->
                    # No id field (probably an event), keep reading
                    read_until_element_handle_response!(read_stdout!, expected_id)

        Err(_) ->
            # Decode failed (probably an event), keep reading
            read_until_element_handle_response!(read_stdout!, expected_id)

read_until_bounding_box_response! = |read_stdout!, expected_id|
    bytes = receive_message_bytes!(read_stdout!)?

    when decode_id_check(bytes) is
        Ok(id_msg) ->
            when Option.get(id_msg.id) is
                Some(id) ->
                    if id == expected_id then
                        # This is our response - check if it has a value field
                        msg_str = Str.from_utf8(bytes) |> Result.with_default("")
                        if Str.contains(msg_str, "\"value\"") then
                            # Has a value field - decode it
                            when decode_bounding_box_response(bytes) is
                                Ok(msg) -> Ok(msg)
                                Err(_) ->
                                    # Decode failed unexpectedly - return no bounding box
                                    Ok({
                                        id: Option.some(id),
                                        result: Option.some({ value: Option.none({}) }),
                                        error: Option.none({}),
                                    })
                        else
                            # No value field - Playwright returned {"result": {}}
                            # This means the element has no bounding box (not visible)
                            Ok({
                                id: Option.some(id),
                                result: Option.some({ value: Option.none({}) }),
                                error: Option.none({}),
                            })
                    else
                        read_until_bounding_box_response!(read_stdout!, expected_id)

                None ->
                    # No id field (probably an event), keep reading
                    read_until_bounding_box_response!(read_stdout!, expected_id)

        Err(_) ->
            # Decode failed (probably an event), keep reading
            read_until_bounding_box_response!(read_stdout!, expected_id)

## Tap an element. Requires `has_touch: Bool.true` context.
##
## ```
## Playwright.tap!(page, "button#submit")?
## ```
tap! = |page, selector|
    context = page.context
    browser = context.browser
    msg : SelectorMessage
    msg = { id: msg_id, guid: page.frame_guid, method: "tap", params: { selector, timeout: timeout_to_ms(browser.timeout) }, metadata: {} }
    send_message!(browser.write_stdin!, Encode.to_bytes(msg, Json.utf8))?

    response = read_until_response!(browser.read_stdout!, msg_id)?

    when Option.get(response.error) is
        Some(err) ->
            Err(TapError(err.error.message))

        None ->
            Ok({})

## Tap at coordinates. Requires `has_touch: Bool.true` context.
##
## ```
## Playwright.touchscreen_tap!(page, 100.0, 200.0)?
## ```
touchscreen_tap! = |page, x, y|
    context = page.context
    browser = context.browser
    msg : TouchTapMessage
    msg = { id: msg_id, guid: page.page_guid, method: "touchscreenTap", params: { x, y }, metadata: {} }
    send_message!(browser.write_stdin!, Encode.to_bytes(msg, Json.utf8))?

    response = read_until_response!(browser.read_stdout!, msg_id)?

    when Option.get(response.error) is
        Some(err) ->
            Err(TouchscreenTapError(err.error.message))

        None ->
            Ok({})

## Execute JavaScript and return the string result.
##
## ```
## title = Playwright.evaluate!(page, "document.title")?
## ```
##
## Only string results are supported. Convert other types in JS:
##
## ```
## count = Playwright.evaluate!(page, "String(document.querySelectorAll('li').length)")?
## ```
evaluate! = |page, expression|
    context = page.context
    browser = context.browser
    msg : EvaluateMessage
    msg = {
        id: msg_id,
        guid: page.frame_guid,
        method: "evaluateExpression",
        params: {
            expression,
            isFunction: Bool.false,
            arg: { value: { v: "undefined" }, handles: [] },
        },
        metadata: {},
    }
    send_message!(browser.write_stdin!, Encode.to_bytes(msg, Json.utf8))?

    when read_until_nullable_string_response!(browser.read_stdout!, msg_id)? is
        Ok(value) -> Ok(value)
        Err(ValueIsNull) -> Err(EvaluateReturnedNull)

## Drag from one point to another. Requires `has_touch: Bool.true` context.
##
## ```
## Playwright.touch_drag!(page, { start_x: 100.0, start_y: 200.0, end_x: 300.0, end_y: 200.0 })?
## ```
touch_drag! = |page, { start_x, start_y, end_x, end_y }|
    # Use JavaScript to dispatch synthetic touch events
    # This is the standard approach for touch drag gestures in Playwright
    js =
        """
        (() => {
            const startX = $(Num.to_str(start_x));
            const startY = $(Num.to_str(start_y));
            const endX = $(Num.to_str(end_x));
            const endY = $(Num.to_str(end_y));

            const el = document.elementFromPoint(startX, startY);
            if (!el) return 'no element';

            let touchId = 1;

            function dispatchTouchEvent(type, x, y, hasTouches) {
                const touch = new Touch({
                    identifier: touchId,
                    target: el,
                    clientX: x,
                    clientY: y,
                    pageX: x,
                    pageY: y,
                    screenX: x,
                    screenY: y,
                });

                const evt = new TouchEvent(type, {
                    bubbles: true,
                    cancelable: true,
                    view: window,
                    touches: hasTouches ? [touch] : [],
                    targetTouches: hasTouches ? [touch] : [],
                    changedTouches: [touch],
                });

                el.dispatchEvent(evt);
            }

            dispatchTouchEvent('touchstart', startX, startY, true);

            // Intermediate move events
            const steps = 5;
            for (let i = 1; i <= steps; i++) {
                const x = startX + (endX - startX) * (i / steps);
                const y = startY + (endY - startY) * (i / steps);
                dispatchTouchEvent('touchmove', x, y, true);
            }

            dispatchTouchEvent('touchend', endX, endY, false);

            return 'done';
        })()
        """
    when evaluate!(page, js) is
        Ok(_result) -> Ok({})
        Err(PlaywrightError(msg)) -> Err(TouchDragError(msg))
        Err(EvaluateReturnedNull) -> Err(TouchDragError("No element at coordinates"))
        Err(_) -> Err(TouchDragError("Unknown error"))

kill_process! = |kill!|
    kill!({})
    |> Result.map_err(|_| CloseFailed)

## Close the browser and terminate the driver process.
##
## ```
## Playwright.close!(browser)?
## ```
close! = |browser|
    # Kill the driver process, which terminates the browser.
    # No need to send a close message first - the driver is designed to be terminated.
    kill_process!(browser.kill!)
