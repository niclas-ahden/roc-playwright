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
        "/bounding-box-test" -> Ok(html(bounding_box_test_page))
        "/touch-test" -> Ok(html(touch_test_page))
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

bounding_box_test_page : Str
bounding_box_test_page =
    """
    <!DOCTYPE html>
    <html>
    <head>
        <title>Bounding Box Test</title>
        <style>
            #fixed-box {
                position: absolute;
                top: 100px;
                left: 150px;
                width: 200px;
                height: 100px;
                background: #4CAF50;
            }
            #nested-box {
                width: 50px;
                height: 25px;
                background: #2196F3;
                margin: 10px;
            }
            #zero-size {
                width: 0;
                height: 0;
            }
            #hidden-display {
                display: none;
                width: 100px;
                height: 50px;
            }
            #hidden-visibility {
                visibility: hidden;
                width: 100px;
                height: 50px;
            }
            #offscreen {
                position: absolute;
                top: -1000px;
                left: -1000px;
                width: 100px;
                height: 50px;
                background: #FF5722;
            }
        </style>
    </head>
    <body>
        <h1>Bounding Box Test</h1>
        <div id="fixed-box">
            <div id="nested-box">Nested</div>
        </div>
        <button id="regular-button" style="margin-top: 250px;">A Button</button>
        <!-- Edge case elements -->
        <div id="zero-size"></div>
        <div id="hidden-display">Hidden with display:none</div>
        <div id="hidden-visibility">Hidden with visibility:hidden</div>
        <div id="offscreen">Offscreen element</div>
    </body>
    </html>
    """

touch_test_page : Str
touch_test_page =
    """
    <!DOCTYPE html>
    <html>
    <head>
        <title>Touch Test</title>
        <style>
            #touch-area {
                width: 300px;
                height: 200px;
                background: #f0f0f0;
                border: 2px solid #333;
                display: flex;
                align-items: center;
                justify-content: center;
                font-size: 18px;
                user-select: none;
            }
            #tap-button {
                margin-top: 20px;
                padding: 20px 40px;
                font-size: 18px;
            }
        </style>
    </head>
    <body>
        <h1>Touch Test</h1>
        <div id="touch-area">Touch area</div>
        <p id="touch-result">No touch yet</p>
        <button id="tap-button">Tap Me</button>
        <p id="tap-result">Not tapped yet</p>
        <script>
            var touchArea = document.getElementById('touch-area');
            var touchResult = document.getElementById('touch-result');
            var tapButton = document.getElementById('tap-button');
            var tapResult = document.getElementById('tap-result');

            var dragEvents = [];

            touchArea.addEventListener('touchstart', function(e) {
                var touch = e.touches[0];
                dragEvents = ['start'];
                touchResult.textContent = 'Touch at: ' + Math.round(touch.clientX) + ', ' + Math.round(touch.clientY);
            });

            touchArea.addEventListener('touchmove', function(e) {
                dragEvents.push('move');
            });

            touchArea.addEventListener('touchend', function(e) {
                dragEvents.push('end');
                touchResult.textContent = 'Drag events: ' + dragEvents.join(',');
            });

            touchArea.addEventListener('click', function(e) {
                touchResult.textContent = 'Clicked at: ' + Math.round(e.clientX) + ', ' + Math.round(e.clientY);
            });

            tapButton.addEventListener('touchstart', function(e) {
                tapResult.textContent = 'Button was tapped!';
                e.preventDefault();
            });

            tapButton.addEventListener('click', function() {
                tapResult.textContent = 'Button was clicked!';
            });
        </script>
    </body>
    </html>
    """
