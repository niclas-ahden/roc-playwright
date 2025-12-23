app [Model, init!, respond!] {
    pf: platform "/home/niclas/dev/growthagent/basic-webserver/platform/main.roc",
}

import pf.Http exposing [Request, Response]

Model : {}

init! : {} => Result Model []
init! = |_| Ok({})

respond! : Request, Model => Result Response [ServerErr Str]
respond! = |request, _model|
    when request.uri is
        "/" -> Ok(html(home_page))
        "/page1" -> Ok(html(page1))
        "/page2" -> Ok(html(page2))
        "/form" -> Ok(html(form_page))
        "/click-test" -> Ok(html(click_test_page))
        "/visibility-test" -> Ok(html(visibility_test_page))
        "/attributes-test" -> Ok(html(attributes_test_page))
        "/no-title" -> Ok(html(no_title_page))
        "/delayed-element" -> Ok(html(delayed_element_page))
        "/never-appears" -> Ok(html(never_appears_page))
        _ -> Ok(not_found)

html : Str -> Response
html = |body|
    {
        status: 200,
        headers: [{ name: "Content-Type", value: "text/html; charset=utf-8" }],
        body: Str.to_utf8(body),
    }

not_found : Response
not_found = {
    status: 404,
    headers: [{ name: "Content-Type", value: "text/html; charset=utf-8" }],
    body: Str.to_utf8("<html><head><title>Not Found</title></head><body><h1>404 Not Found</h1></body></html>"),
}

home_page : Str
home_page =
    """
    <!DOCTYPE html>
    <html>
    <head>
        <title>Test Home Page</title>
    </head>
    <body>
        <h1>Welcome to the Test Server</h1>
        <p>This is a test page for Playwright.</p>
        <nav>
            <a href="/page1">Page 1</a>
            <a href="/page2">Page 2</a>
            <a href="/form">Form</a>
            <a href="/click-test">Click Test</a>
            <a href="/visibility-test">Visibility Test</a>
        </nav>
        <div id="content">
            <p>Some content here.</p>
        </div>
    </body>
    </html>
    """

page1 : Str
page1 =
    """
    <!DOCTYPE html>
    <html>
    <head>
        <title>Page 1</title>
    </head>
    <body>
        <h1>Page 1</h1>
        <p>You navigated to page 1.</p>
        <a href="/">Back to Home</a>
    </body>
    </html>
    """

page2 : Str
page2 =
    """
    <!DOCTYPE html>
    <html>
    <head>
        <title>Page 2</title>
    </head>
    <body>
        <h1>Page 2</h1>
        <p>You navigated to page 2.</p>
        <a href="/">Back to Home</a>
    </body>
    </html>
    """

form_page : Str
form_page =
    """
    <!DOCTYPE html>
    <html>
    <head>
        <title>Form Test</title>
    </head>
    <body>
        <h1>Form Test</h1>
        <form id="test-form">
            <label for="username">Username:</label>
            <input type="text" id="username" name="username" placeholder="Enter username">

            <label for="password">Password:</label>
            <input type="password" id="password" name="password" placeholder="Enter password">

            <label for="email">Email:</label>
            <input type="email" id="email" name="email" placeholder="Enter email">

            <textarea id="message" name="message" placeholder="Enter message"></textarea>

            <button type="submit">Submit</button>
        </form>
    </body>
    </html>
    """

click_test_page : Str
click_test_page =
    """
    <!DOCTYPE html>
    <html>
    <head>
        <title>Click Test</title>
    </head>
    <body>
        <h1>Click Test</h1>
        <button id="click-me">Click Me</button>
        <p id="click-result">Not clicked yet</p>
        <a href="/page1" id="nav-link">Navigate to Page 1</a>
        <script>
            document.getElementById('click-me').addEventListener('click', function() {
                document.getElementById('click-result').textContent = 'Button was clicked!';
            });
        </script>
    </body>
    </html>
    """

visibility_test_page : Str
visibility_test_page =
    """
    <!DOCTYPE html>
    <html>
    <head>
        <title>Visibility Test</title>
        <style>
            .hidden { display: none; }
            .invisible { visibility: hidden; }
        </style>
    </head>
    <body>
        <h1>Visibility Test</h1>
        <div id="visible-element">I am visible</div>
        <div id="hidden-element" class="hidden">I am hidden (display: none)</div>
        <div id="invisible-element" class="invisible">I am invisible (visibility: hidden)</div>
        <input type="text" id="visible-input" placeholder="Visible input">
    </body>
    </html>
    """

attributes_test_page : Str
attributes_test_page =
    """
    <!DOCTYPE html>
    <html>
    <head>
        <title>Attributes Test</title>
    </head>
    <body>
        <h1>Attributes Test</h1>
        <a id="test-link" href="/page1" class="nav-link primary" data-testid="main-link" data-custom="custom-value">Go to Page 1</a>
        <button id="disabled-btn" disabled>Disabled Button</button>
        <button id="enabled-btn">Enabled Button</button>
        <input id="readonly-input" type="text" readonly value="readonly value">
        <input id="required-input" type="text" required placeholder="Required field">
        <div id="no-href">No href attribute</div>
        <div id="empty-div"></div>
        <span id="empty-span"></span>
    </body>
    </html>
    """

no_title_page : Str
no_title_page =
    """
    <!DOCTYPE html>
    <html>
    <head>
    </head>
    <body>
        <h1>Page Without Title</h1>
        <p>This page has no title tag.</p>
    </body>
    </html>
    """

delayed_element_page : Str
delayed_element_page =
    """
    <!DOCTYPE html>
    <html>
    <head>
        <title>Delayed Element Test</title>
    </head>
    <body>
        <h1>Delayed Element Test</h1>
        <p>The element below will appear after 500ms.</p>
        <script>
            setTimeout(function() {
                var el = document.createElement('div');
                el.id = 'delayed';
                el.textContent = 'I appeared!';
                document.body.appendChild(el);
            }, 500);
        </script>
    </body>
    </html>
    """

never_appears_page : Str
never_appears_page =
    """
    <!DOCTYPE html>
    <html>
    <head>
        <title>Never Appears Test</title>
    </head>
    <body>
        <h1>Never Appears Test</h1>
        <p>The element #never will never be added to this page.</p>
    </body>
    </html>
    """
