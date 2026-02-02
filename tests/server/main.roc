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
        "/disappearing-element" -> Ok(html(disappearing_element_page))
        "/never-appears" -> Ok(html(never_appears_page))
        "/bounding-box-test" -> Ok(html(bounding_box_test_page))
        "/touch-test" -> Ok(html(touch_test_page))
        "/keyboard-modal" -> Ok(html(keyboard_modal_page))
        "/keyboard-form" -> Ok(html(keyboard_form_page))
        "/keyboard-navigation" -> Ok(html(keyboard_navigation_page))
        "/keyboard-select" -> Ok(html(keyboard_select_page))
        "/hover-test" -> Ok(html(hover_test_page))
        "/mouse-test" -> Ok(html(mouse_test_page))
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

disappearing_element_page : Str
disappearing_element_page =
    """
    <!DOCTYPE html>
    <html>
    <head>
        <title>Disappearing Element Test</title>
    </head>
    <body>
        <h1>Disappearing Element Test</h1>
        <p>The element below will disappear after 500ms.</p>
        <div id="vanishing">I will disappear!</div>
        <script>
            setTimeout(function() {
                var el = document.getElementById('vanishing');
                el.parentNode.removeChild(el);
            }, 500);
        </script>
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

keyboard_modal_page : Str
keyboard_modal_page =
    """
    <!DOCTYPE html>
    <html>
    <head>
        <title>Keyboard Modal Test</title>
        <style>
            #modal {
                position: fixed;
                top: 50%;
                left: 50%;
                transform: translate(-50%, -50%);
                background: white;
                border: 2px solid #333;
                padding: 20px;
                z-index: 1000;
            }
            #overlay {
                position: fixed;
                top: 0;
                left: 0;
                width: 100%;
                height: 100%;
                background: rgba(0,0,0,0.5);
                z-index: 999;
            }
            .hidden { display: none; }
        </style>
    </head>
    <body>
        <h1>Keyboard Modal Test</h1>
        <button id="open-modal">Open Modal</button>
        <p id="status">Modal is closed</p>
        <div id="overlay" class="hidden"></div>
        <div id="modal" class="hidden">
            <h2>Modal Dialog</h2>
            <p>Press Escape to close this modal.</p>
            <button id="close-btn">Close</button>
        </div>
        <script>
            document.getElementById('open-modal').addEventListener('click', function() {
                document.getElementById('modal').classList.remove('hidden');
                document.getElementById('overlay').classList.remove('hidden');
                document.getElementById('status').textContent = 'Modal is open';
            });

            document.getElementById('close-btn').addEventListener('click', function() {
                document.getElementById('modal').classList.add('hidden');
                document.getElementById('overlay').classList.add('hidden');
                document.getElementById('status').textContent = 'Modal closed by Escape';
            });

            document.addEventListener('keydown', function(e) {
                if (e.key === 'Escape' && !document.getElementById('modal').classList.contains('hidden')) {
                    document.getElementById('modal').classList.add('hidden');
                    document.getElementById('overlay').classList.add('hidden');
                    document.getElementById('status').textContent = 'Modal closed by Escape';
                }
            });
        </script>
    </body>
    </html>
    """

keyboard_form_page : Str
keyboard_form_page =
    """
    <!DOCTYPE html>
    <html>
    <head>
        <title>Keyboard Form Test</title>
    </head>
    <body>
        <h1>Keyboard Form Test</h1>
        <form id="test-form">
            <input type="text" id="name-input" placeholder="Enter your name">
            <button type="submit">Submit</button>
        </form>
        <p id="status">Form not submitted</p>
        <script>
            document.getElementById('test-form').addEventListener('submit', function(e) {
                e.preventDefault();
                document.getElementById('status').textContent = 'Form submitted with: ' + document.getElementById('name-input').value;
            });
        </script>
    </body>
    </html>
    """

keyboard_navigation_page : Str
keyboard_navigation_page =
    """
    <!DOCTYPE html>
    <html>
    <head>
        <title>Keyboard Navigation Test</title>
        <style>
            .item { padding: 10px; margin: 5px; background: #f0f0f0; }
            .item.selected { background: #4CAF50; color: white; }
        </style>
    </head>
    <body>
        <h1>Keyboard Navigation Test</h1>
        <p>Use arrow keys to navigate the list.</p>
        <div id="list">
            <div class="item selected" data-index="0">Item 1</div>
            <div class="item" data-index="1">Item 2</div>
            <div class="item" data-index="2">Item 3</div>
            <div class="item" data-index="3">Item 4</div>
        </div>
        <p id="selected">Selected: Item 1</p>
        <script>
            var items = document.querySelectorAll('.item');
            var selectedIndex = 0;
            var selectedDisplay = document.getElementById('selected');

            function updateSelection(newIndex) {
                if (newIndex < 0) newIndex = 0;
                if (newIndex >= items.length) newIndex = items.length - 1;

                items[selectedIndex].classList.remove('selected');
                selectedIndex = newIndex;
                items[selectedIndex].classList.add('selected');
                selectedDisplay.textContent = 'Selected: ' + items[selectedIndex].textContent;
            }

            document.addEventListener('keydown', function(e) {
                if (e.key === 'ArrowDown') {
                    e.preventDefault();
                    updateSelection(selectedIndex + 1);
                } else if (e.key === 'ArrowUp') {
                    e.preventDefault();
                    updateSelection(selectedIndex - 1);
                }
            });
        </script>
    </body>
    </html>
    """

keyboard_select_page : Str
keyboard_select_page =
    """
    <!DOCTYPE html>
    <html>
    <head>
        <title>Keyboard Select Test</title>
    </head>
    <body>
        <h1>Keyboard Select Test</h1>
        <p>Click in the textarea and use Ctrl+A to select all text.</p>
        <textarea id="text-area" rows="5" cols="40">This is some sample text that can be selected with Ctrl+A.</textarea>
        <p id="selection-info">Selection: none</p>
        <script>
            var textarea = document.getElementById('text-area');
            var selectionInfo = document.getElementById('selection-info');

            textarea.addEventListener('select', function() {
                var start = textarea.selectionStart;
                var end = textarea.selectionEnd;
                var selectedText = textarea.value.substring(start, end);
                if (selectedText.length > 0) {
                    selectionInfo.textContent = 'Selection: ' + selectedText.length + ' characters';
                } else {
                    selectionInfo.textContent = 'Selection: none';
                }
            });

            // Also update on keyup to catch Ctrl+A
            textarea.addEventListener('keyup', function() {
                var start = textarea.selectionStart;
                var end = textarea.selectionEnd;
                var selectedText = textarea.value.substring(start, end);
                if (selectedText.length > 0) {
                    selectionInfo.textContent = 'Selection: ' + selectedText.length + ' characters';
                }
            });
        </script>
    </body>
    </html>
    """

hover_test_page : Str
hover_test_page =
    """
    <!DOCTYPE html>
    <html>
    <head>
        <title>Hover Test</title>
    </head>
    <body>
        <h1>Hover Test</h1>
        <div id="hover-target" style="width:200px;height:100px;background:#f0f0f0;">Hover over me</div>
        <p id="status">Not hovered</p>
        <script>
            var target = document.getElementById('hover-target');
            target.addEventListener('mouseenter', function() {
                document.getElementById('status').textContent = 'Hovered';
            });
            target.addEventListener('mouseleave', function() {
                document.getElementById('status').textContent = 'Not hovered';
            });
        </script>
    </body>
    </html>
    """

mouse_test_page : Str
mouse_test_page =
    """
    <!DOCTYPE html>
    <html>
    <head>
        <title>Mouse Test</title>
    </head>
    <body style="margin:0;padding:0;">
        <div id="mouse-area" style="position:absolute;top:0;left:0;width:400px;height:300px;background:#f0f0f0;"></div>
        <p id="events" style="position:absolute;top:310px;">none</p>
        <p id="move-count" style="position:absolute;top:340px;">0</p>
        <p id="last-position" style="position:absolute;top:370px;">0,0</p>
        <script>
            var area = document.getElementById('mouse-area');
            var events = [];
            var moveCount = 0;

            area.addEventListener('mousedown', function() {
                events.push('down');
                document.getElementById('events').textContent = events.join(',');
            });
            area.addEventListener('mousemove', function(e) {
                moveCount++;
                document.getElementById('move-count').textContent = String(moveCount);
                document.getElementById('last-position').textContent = Math.round(e.clientX) + ',' + Math.round(e.clientY);
            });
            area.addEventListener('mouseup', function() {
                events.push('up');
                document.getElementById('events').textContent = events.join(',');
            });
        </script>
    </body>
    </html>
    """
