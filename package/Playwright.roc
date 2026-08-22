## A Roc library for browser automation, powered by [Playwright](https://playwright.dev/).
##
## ```
## { browser, page } = Playwright.launch_page!({ new: Cmd.new_str, spawn!: Cmd.spawn! }, Chromium(DefaultChannel))?
## Playwright.navigate!(page, "https://example.com")?
## title = Playwright.get_title!(page)?
## browser.close!()
## ```
##
## The [PlatformHooks] record wires the package to the host platform's process-spawning
## API, here [`niclas-ahden/basic-cli`](https://www.github.com/niclas-ahden/basic-cli)'s `Cmd` module. Everything after launch goes
## through the [Browser] and [Page] values it returns.
import base64.Base64

Playwright :: [].{

	## The host platform's process-spawning API, wired in at launch. Roc has no
	## parameterized modules, so the entry points arrive as plain function
	## values, from [`niclas-ahden/basic-cli`](https://www.github.com/niclas-ahden/basic-cli)'s `Cmd` module:
	##
	## ```
	## { new: Cmd.new_str, spawn!: Cmd.spawn! }
	## ```
	##
	## Only these two are fields because they are genuine choices: which
	## constructor builds a command, and which spawn flavor starts the driver
	## (`Cmd.spawn!`, or `Cmd.spawn_leashed!` to tie the driver's lifetime to
	## the calling process). Everything past the spawn is reached through
	## methods on the platform's own types instead: the launch functions
	## require `cmd.args_str`, `child.write_stdin!`, `child.read_stdout!` and
	## `child.kill!`, which basic-cli's `Cmd` and `Cmd.Child` carry under
	## exactly those names.
	##
	## `driver` names the Playwright CLI to spawn, and defaults to `playwright`
	## — what an install puts on PATH. Set it only when yours lives somewhere a
	## PATH lookup will not find it. It belongs here rather than in
	## [LaunchOptions] because it describes the installation, not the browser
	## session: every launch in a program goes through one Playwright, so a
	## per-launch setting could only ever drift between two launches that meant
	## to share it.
	##
	## Because the field carries a default, a hooks record written inline at the
	## call — as the examples here and in the tests do — may leave it out. A
	## record bound to a name first is a committed argument by then, and has to
	## either spell the field or carry a `PlatformHooks` annotation.
	##
	## `cmd` and `child` are whatever the platform's command and child-process
	## types are. `err` is its I/O error type. All three stay generic so the
	## package does not depend on any one platform.
	##
	## The platform's `read_stdout!` must return exactly the requested number
	## of bytes or fail. Returning fewer would desync the message framing.
	PlatformHooks(cmd, child, err) : {
		new : Str -> cmd,
		spawn! : cmd => Try(child, err),
		driver : Str ?? "playwright",
	}

	## A running browser, returned by [launch!]. The three closures are built
	## once at launch with the spawned driver process bound inside, so every
	## call downstream is unary. `err` is the platform's I/O error type.
	Browser(err) := {
		write_stdin! : List(U8) => Try({}, err),
		read_stdout! : U64 => Try(List(U8), err),
		kill! : {} => Try({}, err),
		browser_guid : Str,
		timeout : Timeout,
	}

	## A browser context with isolated session state (cookies, storage,
	## permissions). Returned by [new_context!].
	Context(err) := {
		browser : Browser(err),
		context_guid : Str,
		has_touch : Bool,
	}

	## A page (browser tab), where automation happens. Returned by [new_page!]
	## or [launch_page!]. Almost every function in this module takes one.
	Page(err) := {
		context : Context(err),
		page_guid : Str,
		frame_guid : Str,
	}.{
		## The one element matching `selector`, for acting on or asserting
		## against. Lazy: nothing is sent to the driver until you use it.
		##
		## Strict, like Playwright's locators: if the selector turns out to
		## match more than one element, actions and assertions on it fail
		## instead of silently picking the first match. Use [find_all] when
		## several matches are expected.
		##
		## ```
		## page.find("#username").fill!("alice")?
		## assert!(page.find("h1").has_text("Welcome"))?
		## ```
		find : Page(err), Str -> Element(err)
		find = |page, selector| Element.{ page, selector, which: Only }

		## Every element matching `selector`, possibly none. Has no actions.
		## Narrow to a single one with [Elements.first], [Elements.last] or
		## [Elements.nth].
		##
		## ```
		## assert!(page.find_all("nav a").has_count(5))?
		## page.find_all("nav a").first().click!()?
		## ```
		find_all : Page(err), Str -> Elements(err)
		find_all = |page, selector| Elements.{ page, selector }

		## Claims about the page itself, for [assert!]. Asserting one
		## re-checks the page until it holds or the timeout expires (the
		## page's [Timeout], unless [assert_with!] overrides it), like the
		## claims on [Element].

		## The document title is exactly `want`, after normalizing whitespace.
		has_title : Page(AssertError(e)), Str -> Claim(AssertError(e))
		has_title = |page, want| Claim.{
			run!: |t| expect_page_text_impl!(page, t, "to.have.title", want, Bool.False, Bool.True, Bool.False, |r| match r {
				Received(got) => "expected page title \"${want}\", got \"${got}\""
				_ => "expected page title \"${want}\""
			}),
		}

		not_has_title : Page(AssertError(e)), Str -> Claim(AssertError(e))
		not_has_title = |page, want| Claim.{
			run!: |t| expect_page_text_impl!(page, t, "to.have.title", want, Bool.False, Bool.True, Bool.True, |_r|
				"expected page title other than \"${want}\""),
		}

		## The document title contains `want` as a substring, after
		## normalizing whitespace.
		title_contains : Page(AssertError(e)), Str -> Claim(AssertError(e))
		title_contains = |page, want| Claim.{
			run!: |t| expect_page_text_impl!(page, t, "to.have.title", want, Bool.True, Bool.True, Bool.False, |r| match r {
				Received(got) => "expected page title containing \"${want}\", got \"${got}\""
				_ => "expected page title containing \"${want}\""
			}),
		}

		not_title_contains : Page(AssertError(e)), Str -> Claim(AssertError(e))
		not_title_contains = |page, want| Claim.{
			run!: |t| expect_page_text_impl!(page, t, "to.have.title", want, Bool.True, Bool.True, Bool.True, |r| match r {
				Received(got) => "expected page title not containing \"${want}\", got \"${got}\""
				_ => "expected page title not containing \"${want}\""
			}),
		}

		## The document title matches the regular expression, which may be
		## found anywhere in the title: anchor with `^` and `$` to claim all
		## of it. An invalid pattern fails immediately with [ExpectError].
		title_matches : Page(AssertError(e)), Str -> Claim(AssertError(e))
		title_matches = |page, regex| Claim.{
			run!: |t| expect_page_regex_impl!(page, t, "to.have.title", regex, Bool.False, |r| match r {
				Received(got) => "expected page title matching /${regex}/, got \"${got}\""
				_ => "expected page title matching /${regex}/"
			}),
		}

		not_title_matches : Page(AssertError(e)), Str -> Claim(AssertError(e))
		not_title_matches = |page, regex| Claim.{
			run!: |t| expect_page_regex_impl!(page, t, "to.have.title", regex, Bool.True, |r| match r {
				Received(got) => "expected page title not matching /${regex}/, got \"${got}\""
				_ => "expected page title not matching /${regex}/"
			}),
		}

		## The page URL is exactly `want`, as the browser reports it, so
		## normally with a trailing slash after a bare host.
		has_url : Page(AssertError(e)), Str -> Claim(AssertError(e))
		has_url = |page, want| Claim.{
			run!: |t| expect_page_text_impl!(page, t, "to.have.url", want, Bool.False, Bool.False, Bool.False, |r| match r {
				Received(got) => "expected page url \"${want}\", got \"${got}\""
				_ => "expected page url \"${want}\""
			}),
		}

		not_has_url : Page(AssertError(e)), Str -> Claim(AssertError(e))
		not_has_url = |page, want| Claim.{
			run!: |t| expect_page_text_impl!(page, t, "to.have.url", want, Bool.False, Bool.False, Bool.True, |_r|
				"expected page url other than \"${want}\""),
		}

		## The page URL contains `want` as a substring. The usual claim when
		## the URL carries a generated id: `url_contains("/orders/")` accepts
		## any order page.
		url_contains : Page(AssertError(e)), Str -> Claim(AssertError(e))
		url_contains = |page, want| Claim.{
			run!: |t| expect_page_text_impl!(page, t, "to.have.url", want, Bool.True, Bool.False, Bool.False, |r| match r {
				Received(got) => "expected page url containing \"${want}\", got \"${got}\""
				_ => "expected page url containing \"${want}\""
			}),
		}

		not_url_contains : Page(AssertError(e)), Str -> Claim(AssertError(e))
		not_url_contains = |page, want| Claim.{
			run!: |t| expect_page_text_impl!(page, t, "to.have.url", want, Bool.True, Bool.False, Bool.True, |r| match r {
				Received(got) => "expected page url not containing \"${want}\", got \"${got}\""
				_ => "expected page url not containing \"${want}\""
			}),
		}

		## The page URL matches the regular expression, which may be found
		## anywhere in the URL: anchor with `^` and `$` to claim all of it.
		## The usual claim when the URL carries a generated id:
		## `url_matches("/orders/\\d+")` accepts any order page but not the
		## order index. An invalid pattern fails immediately with
		## [ExpectError].
		url_matches : Page(AssertError(e)), Str -> Claim(AssertError(e))
		url_matches = |page, regex| Claim.{
			run!: |t| expect_page_regex_impl!(page, t, "to.have.url", regex, Bool.False, |r| match r {
				Received(got) => "expected page url matching /${regex}/, got \"${got}\""
				_ => "expected page url matching /${regex}/"
			}),
		}

		not_url_matches : Page(AssertError(e)), Str -> Claim(AssertError(e))
		not_url_matches = |page, regex| Claim.{
			run!: |t| expect_page_regex_impl!(page, t, "to.have.url", regex, Bool.True, |r| match r {
				Received(got) => "expected page url not matching /${regex}/, got \"${got}\""
				_ => "expected page url not matching /${regex}/"
			}),
		}
	}

	## Which of a selector's matches an [Element] refers to. `Only` is what
	## [Page.find] produces. `Nth` comes from [Elements.nth] and friends.
	Which : [Only, Nth(I64)]

	## A single element: a page plus the selector that finds it, resolved fresh
	## on every call rather than held as a handle. Produced by [Page.find].
	Element(err) := {
		page : Page(err),
		selector : Str,
		which : Which,
	}.{
		click! : Element([ClickError(Str), ..e]) => Try({}, [ClickError(Str), ..e])
		click! = |el| click_impl!(el.page, Playwright.resolve(el), Bool.True)

		fill! : Element([FillError(Str), ..e]), Str => Try({}, [FillError(Str), ..e])
		fill! = |el, value| fill_impl!(el.page, Playwright.resolve(el), value, Bool.True)

		hover! : Element([HoverError(Str), ..e]) => Try({}, [HoverError(Str), ..e])
		hover! = |el| hover_impl!(el.page, Playwright.resolve(el), Bool.True)

		check! : Element([CheckError(Str), DecodeError, EvaluateReturnedNull, EvaluateError(Str), ..e]) => Try({}, [CheckError(Str), DecodeError, EvaluateReturnedNull, EvaluateError(Str), ..e])
		check! = |el| set_checked_impl!(el.page, Playwright.resolve(el), Bool.True, Bool.True)

		uncheck! : Element([CheckError(Str), DecodeError, EvaluateReturnedNull, EvaluateError(Str), ..e]) => Try({}, [CheckError(Str), DecodeError, EvaluateReturnedNull, EvaluateError(Str), ..e])
		uncheck! = |el| set_checked_impl!(el.page, Playwright.resolve(el), Bool.False, Bool.True)

		text! : Element([TextContentNotFound, TextContentError(Str), DecodeError, ..e]) => Try(Str, [TextContentNotFound, TextContentError(Str), DecodeError, ..e])
		text! = |el| text_content_impl!(el.page, Playwright.resolve(el), Bool.True)

		value! : Element([InputValueError(Str), InputValueNotFound, UnexpectedStringResponse(Str), ..e]) => Try(Str, [InputValueError(Str), InputValueNotFound, UnexpectedStringResponse(Str), ..e])
		value! = |el| input_value_impl!(el.page, Playwright.resolve(el), Bool.True)

		attribute! : Element([AttributeNotFound, AttributeError(Str), DecodeError, ..e]), Str => Try(Str, [AttributeNotFound, AttributeError(Str), DecodeError, ..e])
		attribute! = |el, name| get_attribute_impl!(el.page, Playwright.resolve(el), name, Bool.True)

		is_visible! : Element([IsVisibleError(Str), IsVisibleNoResult, UnexpectedBoolResponse(Str), ..e]) => Try(Bool, [IsVisibleError(Str), IsVisibleNoResult, UnexpectedBoolResponse(Str), ..e])
		is_visible! = |el| is_visible_impl!(el.page, Playwright.resolve(el), Bool.True)

		wait_for! : Element([WaitForTimeout(Str), ..e]), WaitForState => Try({}, [WaitForTimeout(Str), ..e])
		wait_for! = |el, state| wait_for_impl!(el.page, Playwright.resolve(el), state, Bool.True)

		bounding_box! : Element([BoundingBoxError(Str), ElementNotFound, ElementNotVisible, WaitForTimeout(Str), ..e]) => Try(BoundingBox, [BoundingBoxError(Str), ElementNotFound, ElementNotVisible, WaitForTimeout(Str), ..e])
		bounding_box! = |el| bounding_box_impl!(el.page, Playwright.resolve(el), Bool.True)

		## The one descendant matching `selector`.
		find : Element(err), Str -> Element(err)
		find = |el, selector| Element.{ page: el.page, selector: "${Playwright.resolve(el)} >> ${selector}", which: Only }

		## Every descendant matching `selector`.
		find_all : Element(err), Str -> Elements(err)
		find_all = |el, selector| Elements.{ page: el.page, selector: "${Playwright.resolve(el)} >> ${selector}" }

		## Claims for [assert!]. Building one is pure and sends nothing to
		## the driver; asserting it goes through the driver's own `expect`
		## call, the same one every official Playwright client's assertions
		## use, which re-checks the page until the claim holds or the timeout
		## expires (the page's [Timeout], unless [assert_with!] overrides
		## it). A claim that never holds fails with
		## [AssertionFailed]; a selector matching more than one element is a
		## strict mode violation and fails immediately with [ExpectError].
		##
		## The `not_` variants re-check until the claim stops holding, so
		## they are how to wait for a value to change away. A missing element
		## fails them rather than passing vacuously: claim absence with
		## [is_hidden] instead.

		## The element's text is exactly `want`. Whitespace is normalized on
		## both sides before comparing, like Playwright's `toHaveText`.
		has_text : Element(AssertError(e)), Str -> Claim(AssertError(e))
		has_text = |el, want| Claim.{
			run!: |t| {
				sel = Playwright.resolve(el)
				expect_text_impl!(el.page, t, sel, "to.have.text", want, Bool.False, Bool.False, |r| match r {
					Received(got) => "${sel}: expected text \"${want}\", got \"${got}\""
					_ => "${sel}: expected text \"${want}\", but no element matched the selector"
				})
			},
		}

		not_has_text : Element(AssertError(e)), Str -> Claim(AssertError(e))
		not_has_text = |el, want| Claim.{
			run!: |t| {
				sel = Playwright.resolve(el)
				expect_text_impl!(el.page, t, sel, "to.have.text", want, Bool.False, Bool.True, |r| match r {
					Received(_) => "${sel}: expected text other than \"${want}\""
					_ => "${sel}: expected text other than \"${want}\", but no element matched the selector"
				})
			},
		}

		## The element's text contains `want` as a substring, after
		## normalizing whitespace, like Playwright's `toContainText`.
		contains_text : Element(AssertError(e)), Str -> Claim(AssertError(e))
		contains_text = |el, want| Claim.{
			run!: |t| {
				sel = Playwright.resolve(el)
				expect_text_impl!(el.page, t, sel, "to.have.text", want, Bool.True, Bool.False, |r| match r {
					Received(got) => "${sel}: expected text containing \"${want}\", got \"${got}\""
					_ => "${sel}: expected text containing \"${want}\", but no element matched the selector"
				})
			},
		}

		not_contains_text : Element(AssertError(e)), Str -> Claim(AssertError(e))
		not_contains_text = |el, want| Claim.{
			run!: |t| {
				sel = Playwright.resolve(el)
				expect_text_impl!(el.page, t, sel, "to.have.text", want, Bool.True, Bool.True, |r| match r {
					Received(got) => "${sel}: expected text not containing \"${want}\", got \"${got}\""
					_ => "${sel}: expected text not containing \"${want}\", but no element matched the selector"
				})
			},
		}

		## The element's text matches the regular expression, which may be
		## found anywhere in the text: anchor with `^` and `$` to claim all
		## of it. For genuinely dynamic content, like counters or generated
		## ids: `matches_text("Synced \\d+ seconds ago")`. Fixed text reads
		## better through [has_text] or [contains_text], which take their
		## argument literally.
		##
		## The text is matched raw, without the whitespace normalization
		## [has_text] applies, like the quantified text claims. An invalid
		## pattern fails immediately with [ExpectError].
		matches_text : Element(AssertError(e)), Str -> Claim(AssertError(e))
		matches_text = |el, regex| Claim.{
			run!: |t| {
				sel = Playwright.resolve(el)
				expect_regex_impl!(el.page, t, sel, "to.have.text", regex, Bool.False, |r| match r {
					Received(got) => "${sel}: expected text matching /${regex}/, got \"${got}\""
					_ => "${sel}: expected text matching /${regex}/, but no element matched the selector"
				})
			},
		}

		not_matches_text : Element(AssertError(e)), Str -> Claim(AssertError(e))
		not_matches_text = |el, regex| Claim.{
			run!: |t| {
				sel = Playwright.resolve(el)
				expect_regex_impl!(el.page, t, sel, "to.have.text", regex, Bool.True, |r| match r {
					Received(got) => "${sel}: expected text not matching /${regex}/, got \"${got}\""
					_ => "${sel}: expected text not matching /${regex}/, but no element matched the selector"
				})
			},
		}

		has_value : Element(AssertError(e)), Str -> Claim(AssertError(e))
		has_value = |el, want| Claim.{
			run!: |t| {
				sel = Playwright.resolve(el)
				expect_value_impl!(el.page, t, sel, want, Bool.False, |r| match r {
					Received(got) => "${sel}: expected value \"${want}\", got \"${got}\""
					_ => "${sel}: expected value \"${want}\", but no element matched the selector"
				})
			},
		}

		not_has_value : Element(AssertError(e)), Str -> Claim(AssertError(e))
		not_has_value = |el, want| Claim.{
			run!: |t| {
				sel = Playwright.resolve(el)
				expect_value_impl!(el.page, t, sel, want, Bool.True, |r| match r {
					Received(_) => "${sel}: expected value other than \"${want}\""
					_ => "${sel}: expected value other than \"${want}\", but no element matched the selector"
				})
			},
		}

		has_attribute : Element(AssertError(e)), Str, Str -> Claim(AssertError(e))
		has_attribute = |el, name, want| Claim.{
			run!: |t| {
				sel = Playwright.resolve(el)
				expect_attribute_impl!(el.page, t, sel, name, want, Bool.False, |r| match r {
					Received(got) => "${sel}: expected ${name}=\"${want}\", got \"${got}\""
					NullReceived => "${sel}: expected ${name}=\"${want}\", but the element has no ${name} attribute"
					NoElement => "${sel}: expected ${name}=\"${want}\", but no element matched the selector"
				})
			},
		}

		not_has_attribute : Element(AssertError(e)), Str, Str -> Claim(AssertError(e))
		not_has_attribute = |el, name, want| Claim.{
			run!: |t| {
				sel = Playwright.resolve(el)
				expect_attribute_impl!(el.page, t, sel, name, want, Bool.True, |r| match r {
					Received(_) => "${sel}: expected ${name} other than \"${want}\""
					NullReceived => "${sel}: expected ${name} other than \"${want}\""
					NoElement => "${sel}: expected ${name} other than \"${want}\", but no element matched the selector"
				})
			},
		}

		## The element's class list contains `want`, as a whole class name
		## rather than a substring, so `has_class("active")` does not match
		## `class="inactive"`. Other classes on the element are fine. `want`
		## may name several classes separated by whitespace, and then all of
		## them must be present, in any order, like Playwright's
		## `toContainClass`.
		has_class : Element(AssertError(e)), Str -> Claim(AssertError(e))
		has_class = |el, want| Claim.{
			run!: |t| {
				sel = Playwright.resolve(el)
				expect_text_impl!(el.page, t, sel, "to.contain.class", want, Bool.False, Bool.False, |r| match r {
					Received(got) => "${sel}: expected class \"${want}\", got class list \"${got}\""
					_ => "${sel}: expected class \"${want}\", but no element matched the selector"
				})
			},
		}

		not_has_class : Element(AssertError(e)), Str -> Claim(AssertError(e))
		not_has_class = |el, want| Claim.{
			run!: |t| {
				sel = Playwright.resolve(el)
				expect_text_impl!(el.page, t, sel, "to.contain.class", want, Bool.False, Bool.True, |r| match r {
					Received(got) => "${sel}: expected class list without \"${want}\", got class list \"${got}\""
					_ => "${sel}: expected class list without \"${want}\", but no element matched the selector"
				})
			},
		}

		is_visible : Element(AssertError(e)) -> Claim(AssertError(e))
		is_visible = |el| Claim.{
			run!: |t| {
				sel = Playwright.resolve(el)
				expect_state_impl!(el.page, t, sel, "to.be.visible", Bool.False, |r| match r {
					Received(got) => "${sel}: expected to be visible, but it is ${got}"
					_ => "${sel}: expected to be visible, but no element matched the selector"
				})
			},
		}

		## Holds when the element is not visible, including when nothing
		## matches the selector at all, like Playwright's `toBeHidden`.
		is_hidden : Element(AssertError(e)) -> Claim(AssertError(e))
		is_hidden = |el| Claim.{
			run!: |t| {
				sel = Playwright.resolve(el)
				expect_state_impl!(el.page, t, sel, "to.be.hidden", Bool.False, |r| match r {
					Received(got) => "${sel}: expected to be hidden, but it is ${got}"
					_ => "${sel}: expected to be hidden"
				})
			},
		}

		## The element exists in the DOM, visible or not, like Playwright's
		## `toBeAttached`. [is_visible] makes the stronger claim.
		exists : Element(AssertError(e)) -> Claim(AssertError(e))
		exists = |el| Claim.{
			run!: |t| {
				sel = Playwright.resolve(el)
				expect_state_impl!(el.page, t, sel, "to.be.attached", Bool.False, |_r|
					"${sel}: expected a matching element, but none exists")
			},
		}

		## No element matches the selector at all. The strictest absence
		## claim: [is_hidden] also passes on an element that is present but
		## invisible, this one does not. Like every single-element claim, a
		## selector matching more than one element is a strict mode violation
		## and fails with [ExpectError] rather than [AssertionFailed].
		not_exists : Element(AssertError(e)) -> Claim(AssertError(e))
		not_exists = |el| Claim.{
			run!: |t| {
				sel = Playwright.resolve(el)
				expect_state_impl!(el.page, t, sel, "to.be.detached", Bool.False, |_r|
					"${sel}: expected no matching element, but one exists")
			},
		}

		## The element has no content: an empty value for an input or
		## textarea, no text (after trimming whitespace) for anything else,
		## like Playwright's `toBeEmpty`.
		is_empty : Element(AssertError(e)) -> Claim(AssertError(e))
		is_empty = |el| Claim.{
			run!: |t| {
				sel = Playwright.resolve(el)
				expect_state_impl!(el.page, t, sel, "to.be.empty", Bool.False, |r| match r {
					Received(_) => "${sel}: expected to be empty, but it has content"
					_ => "${sel}: expected to be empty, but no element matched the selector"
				})
			},
		}

		is_not_empty : Element(AssertError(e)) -> Claim(AssertError(e))
		is_not_empty = |el| Claim.{
			run!: |t| {
				sel = Playwright.resolve(el)
				expect_state_impl!(el.page, t, sel, "to.be.empty", Bool.True, |r| match r {
					Received(_) => "${sel}: expected content, but it is empty"
					_ => "${sel}: expected content, but no element matched the selector"
				})
			},
		}

		## The checkbox or radio button is checked. Fails with [ExpectError]
		## on an element that is neither.
		is_checked : Element(AssertError(e)) -> Claim(AssertError(e))
		is_checked = |el| Claim.{
			run!: |t| {
				sel = Playwright.resolve(el)
				expect_checked_impl!(el.page, t, sel, Bool.True, |r| match r {
					Received(got) => "${sel}: expected to be checked, but it is ${got}"
					_ => "${sel}: expected to be checked, but no element matched the selector"
				})
			},
		}

		is_unchecked : Element(AssertError(e)) -> Claim(AssertError(e))
		is_unchecked = |el| Claim.{
			run!: |t| {
				sel = Playwright.resolve(el)
				expect_checked_impl!(el.page, t, sel, Bool.False, |r| match r {
					Received(got) => "${sel}: expected to be unchecked, but it is ${got}"
					_ => "${sel}: expected to be unchecked, but no element matched the selector"
				})
			},
		}

		is_enabled : Element(AssertError(e)) -> Claim(AssertError(e))
		is_enabled = |el| Claim.{
			run!: |t| {
				sel = Playwright.resolve(el)
				expect_state_impl!(el.page, t, sel, "to.be.enabled", Bool.False, |r| match r {
					Received(got) => "${sel}: expected to be enabled, but it is ${got}"
					_ => "${sel}: expected to be enabled, but no element matched the selector"
				})
			},
		}

		is_disabled : Element(AssertError(e)) -> Claim(AssertError(e))
		is_disabled = |el| Claim.{
			run!: |t| {
				sel = Playwright.resolve(el)
				expect_state_impl!(el.page, t, sel, "to.be.disabled", Bool.False, |r| match r {
					Received(got) => "${sel}: expected to be disabled, but it is ${got}"
					_ => "${sel}: expected to be disabled, but no element matched the selector"
				})
			},
		}
	}

	## Zero or more elements. Deliberately has no actions: there is no sensible
	## meaning for clicking or filling a set. Produced by [Page.find_all].
	Elements(err) := {
		page : Page(err),
		selector : Str,
	}.{
		count! : Elements([QueryCountError(Str), QueryCountNoResult, UnexpectedIntResponse(Str), ..e]) => Try(U64, [QueryCountError(Str), QueryCountNoResult, UnexpectedIntResponse(Str), ..e])
		count! = |els| Playwright.query_count!(els.page, els.selector)

		## The text of every match, in document order. One round trip for the
		## count plus one per element, so prefer [Elements.has_count]
		## when you only care how many there are.
		texts! : Elements([TextContentNotFound, TextContentError(Str), DecodeError, QueryCountError(Str), QueryCountNoResult, UnexpectedIntResponse(Str), ..e]) => Try(List(Str), [TextContentNotFound, TextContentError(Str), DecodeError, QueryCountError(Str), QueryCountNoResult, UnexpectedIntResponse(Str), ..e])
		texts! = |els| {
			n = els.count!()?
			Playwright.collect!(els, 0, n, [], |el| el.text!())
		}

		## The `i`th match, counting from 0. Negative counts from the end.
		nth : Elements(err), I64 -> Element(err)
		nth = |els, i| Element.{ page: els.page, selector: els.selector, which: Nth(i) }

		first : Elements(err) -> Element(err)
		first = |els| els.nth(0)

		last : Elements(err) -> Element(err)
		last = |els| els.nth(-1)

		## Claims about the collection as a whole, for [assert!]. These go
		## through the driver's `expect` call and re-check the page until
		## they hold or the timeout expires (the page's [Timeout], unless
		## [assert_with!] overrides it), like the claims on [Element].

		has_count : Elements(AssertError(e)), U64 -> Claim(AssertError(e))
		has_count = |els, want| Claim.{
			run!: |t| expect_count_impl!(els.page, t, els.selector, want, Bool.False, |r| match r {
				Received(got) => "${els.selector}: expected ${want.to_str()} matches, got ${got}"
				_ => "${els.selector}: expected ${want.to_str()} matches"
			}),
		}

		is_empty : Elements(AssertError(e)) -> Claim(AssertError(e))
		is_empty = |els| els.has_count(0)

		is_not_empty : Elements(AssertError(e)) -> Claim(AssertError(e))
		is_not_empty = |els| Claim.{
			run!: |t| expect_count_impl!(els.page, t, els.selector, 0, Bool.True, |_r|
				"${els.selector}: expected at least one match, got none"),
		}

		## Exactly these texts, in document order, each after normalizing
		## whitespace. The count must match too, so this subsumes [has_count].
		## Playwright's `toHaveText` with an array argument means the same thing.
		has_texts : Elements(AssertError(e)), List(Str) -> Claim(AssertError(e))
		has_texts = |els, want| Claim.{
			run!: |t| {
				want_str = Str.inspect(want)
				expect_texts_impl!(els.page, t, els.selector, want, |r| match r {
					Received(got) => "${els.selector}: expected texts ${want_str}, got ${got}"
					_ => "${els.selector}: expected texts ${want_str}"
				})
			},
		}

		## Quantified claims: the same per-element expectations as on
		## [Element], applied across every match (`all_`), at least one
		## (`any_`), or none of them (`none_`). Playwright has no quantified
		## assertions, so these are this package's own addition.
		##
		## The text and visibility families run as retried count claims on
		## the selector composed with a filter engine, upstream's own idiom
		## for quantifiers, so they re-check the page like every other
		## driver-backed claim. Text is matched raw, without normalizing
		## whitespace, unlike [Element.has_text]. The value and attribute
		## families read live DOM properties no selector engine can see, so
		## they stay one-shot: the claim is judged against the matches as
		## they are at call time, and the page should be settled first, e.g.
		## by asserting [has_count] before one of them.
		##
		## An empty set fails `all_` and `any_` claims rather than passing
		## vacuously: the usual reason a set is empty is a selector typo, and
		## silently passing is the worst thing a test can do. `none_` claims
		## pass on an empty set, because nothing matching is the strongest
		## form of the claimed absence. Pair one with [is_not_empty] when the
		## matches must exist too. The non-vacuity makes `all_` two
		## sequential retried checks, so a claim that never holds can take up
		## to two timeouts to fail.

		all_has_text : Elements(AssertError(e)), Str -> Claim(AssertError(e))
		all_has_text = |els, want| Playwright.filtered_all(els, "internal:has-not-text=/^${regex_escape(want)}$/", "to have text \"${want}\"")

		any_has_text : Elements(AssertError(e)), Str -> Claim(AssertError(e))
		any_has_text = |els, want| Playwright.filtered_any(els, "internal:has-text=/^${regex_escape(want)}$/", "to have text \"${want}\"")

		none_has_text : Elements(AssertError(e)), Str -> Claim(AssertError(e))
		none_has_text = |els, want| Playwright.filtered_none(els, "internal:has-text=/^${regex_escape(want)}$/", "to have text \"${want}\"")

		all_contains_text : Elements(AssertError(e)), Str -> Claim(AssertError(e))
		all_contains_text = |els, want| Playwright.filtered_all(els, "internal:has-not-text=/${regex_escape(want)}/", "to have text containing \"${want}\"")

		any_contains_text : Elements(AssertError(e)), Str -> Claim(AssertError(e))
		any_contains_text = |els, want| Playwright.filtered_any(els, "internal:has-text=/${regex_escape(want)}/", "to have text containing \"${want}\"")

		none_contains_text : Elements(AssertError(e)), Str -> Claim(AssertError(e))
		none_contains_text = |els, want| Playwright.filtered_none(els, "internal:has-text=/${regex_escape(want)}/", "to have text containing \"${want}\"")

		all_has_value : Elements(ValueAssertError(e)), Str -> Claim(ValueAssertError(e))
		all_has_value = |els, want| Playwright.value_claim(els, All, "to have value \"${want}\"", |v| v == want)

		any_has_value : Elements(ValueAssertError(e)), Str -> Claim(ValueAssertError(e))
		any_has_value = |els, want| Playwright.value_claim(els, Any, "to have value \"${want}\"", |v| v == want)

		none_has_value : Elements(ValueAssertError(e)), Str -> Claim(ValueAssertError(e))
		none_has_value = |els, want| Playwright.value_claim(els, None, "to have value \"${want}\"", |v| v == want)

		all_has_attribute : Elements(AttrAssertError(e)), Str, Str -> Claim(AttrAssertError(e))
		all_has_attribute = |els, name, want| Playwright.attr_claim(els, All, name, "to have ${name}=\"${want}\"", |v| v == want)

		any_has_attribute : Elements(AttrAssertError(e)), Str, Str -> Claim(AttrAssertError(e))
		any_has_attribute = |els, name, want| Playwright.attr_claim(els, Any, name, "to have ${name}=\"${want}\"", |v| v == want)

		none_has_attribute : Elements(AttrAssertError(e)), Str, Str -> Claim(AttrAssertError(e))
		none_has_attribute = |els, name, want| Playwright.attr_claim(els, None, name, "to have ${name}=\"${want}\"", |v| v == want)

		all_visible : Elements(AssertError(e)) -> Claim(AssertError(e))
		all_visible = |els| Playwright.filtered_all(els, "visible=false", "to be visible")

		any_visible : Elements(AssertError(e)) -> Claim(AssertError(e))
		any_visible = |els| Playwright.filtered_any(els, "visible=true", "to be visible")

		none_visible : Elements(AssertError(e)) -> Claim(AssertError(e))
		none_visible = |els| Playwright.filtered_none(els, "visible=true", "to be visible")

		all_hidden : Elements(AssertError(e)) -> Claim(AssertError(e))
		all_hidden = |els| Playwright.filtered_all(els, "visible=true", "to be hidden")

		any_hidden : Elements(AssertError(e)) -> Claim(AssertError(e))
		any_hidden = |els| Playwright.filtered_any(els, "visible=false", "to be hidden")

		none_hidden : Elements(AssertError(e)) -> Claim(AssertError(e))
		none_hidden = |els| Playwright.filtered_none(els, "visible=false", "to be hidden")
	}

	## Ways [launch!] and [launch_with!] can fail. `CouldNotStartDriver` means the
	## driver process would not start, and carries why plus what to do about it;
	## it is deliberately not named for one cause, since a missing binary and an
	## unrunnable one both land here. `SpawnFailed` wraps the platform's own
	## spawn error.
	## `BrowserLaunchFailed` carries the driver's error message.
	LaunchError(spawn, e) : [
		CouldNotStartDriver(Str),
		SpawnFailed(spawn),
		BrowserTypeNotFound(Str),
		BrowserLaunchFailed(Str),
		..e,
	]

	## Ways [launch_page!] and [launch_page_with!] can fail: everything in
	## [LaunchError] plus the context and page creation steps.
	LaunchPageError(spawn, e) : [
		CouldNotStartDriver(Str),
		SpawnFailed(spawn),
		BrowserTypeNotFound(Str),
		BrowserLaunchFailed(Str),
		NewContextError(Str),
		NewPageError(Str),
		..e,
	]

	## Options for [launch_with!]. Every field carries a default, so a call
	## spells only what it changes, e.g. `{ headless: Bool.False }`. Like
	## [PlatformHooks]'s `driver`, the defaults fill in a record written
	## inline at the call. A record bound to a name first has to spell every
	## field or carry a `LaunchOptions` annotation.
	LaunchOptions : {
		browser_type : BrowserType ?? Chromium(DefaultChannel),
		headless : Bool ?? Bool.True,
		timeout : Timeout ?? TimeoutMilliseconds(30000),
		args : List(Str) ?? [],
	}

	## Options for [launch_page_with!]: [LaunchOptions] plus the context
	## options from [ContextOptions]. Every field carries a default, applied
	## the way [LaunchOptions] describes.
	LaunchPageOptions : {
		browser_type : BrowserType ?? Chromium(DefaultChannel),
		headless : Bool ?? Bool.True,
		timeout : Timeout ?? TimeoutMilliseconds(30000),
		args : List(Str) ?? [],
		has_touch : Bool ?? Bool.False,
		permissions : List(Str) ?? [],
	}

	## Options for [new_context_with!]. Every field carries a default, applied
	## the way [LaunchOptions] describes.
	ContextOptions : {
		has_touch : Bool ?? Bool.False,
		permissions : List(Str) ?? [],
	}

	## Ways the driver-backed claims ([Element.has_text], [Elements.has_count],
	## [Page.has_title], ...) can fail when asserted. `AssertionFailed` carries
	## the human-readable explanation of an expectation that did not hold.
	## `ExpectError` carries a usage error the driver reported instead of
	## checking, like a strict mode violation or an invalid selector.
	## `UnexpectedExpectResponse` carries a response that did not decode.
	AssertError(e) : [
		AssertionFailed(Str),
		ExpectError(Str),
		UnexpectedExpectResponse(Str),
		..e,
	]

	## Error unions the client-side quantified claims work in. Each is the
	## union of the reads the claim performs (one per match, plus the count
	## read) plus `AssertionFailed`, which carries the human-readable
	## explanation.
	ValueAssertError(e) : [
		InputValueError(Str),
		InputValueNotFound,
		UnexpectedStringResponse(Str),
		QueryCountError(Str),
		QueryCountNoResult,
		UnexpectedIntResponse(Str),
		AssertionFailed(Str),
		..e,
	]

	AttrAssertError(e) : [
		AttributeNotFound,
		AttributeError(Str),
		DecodeError,
		QueryCountError(Str),
		QueryCountNoResult,
		UnexpectedIntResponse(Str),
		AssertionFailed(Str),
		..e,
	]

	## Options for [navigate_with!]. `wait_until` defaults to `Load`, applied
	## the way [LaunchOptions] describes, which makes an inline
	## `{ url }` mean the same as [navigate!].
	NavigateOptions : {
		url : Str,
		wait_until : WaitUntil ?? Load,
	}

	## Start and end point of a touch gesture, in CSS pixels relative to the
	## viewport. Used by [touch_scroll!], [touch_swipe!] and [touch_drag!].
	Gesture : {
		start_x : F64,
		start_y : F64,
		end_x : F64,
		end_y : F64,
	}

	## Which browser engine to use. `Chromium` carries the [Channel] picking
	## which Chromium distribution to launch, e.g. `Chromium(DefaultChannel)`.
	## Firefox and WebKit are always Playwright's bundled builds, so they take
	## no channel.
	BrowserType : [Chromium(Channel), Firefox, WebKit]

	## Which Chromium distribution to launch.
	##
	## `DefaultChannel` is Playwright's default. Since Playwright 1.49 that is a
	## stripped "headless shell" build with no media-capture support when
	## headless.
	##
	## `Full` is the full Playwright-bundled Chromium build (the `"chromium"`
	## channel). Use it when a headless test needs media APIs like `getUserMedia`.
	##
	## `Chrome` and `MsEdge` are the branded stable browsers. They ship the
	## proprietary media codecs (H.264, AAC) that the bundled builds lack. They
	## require Chrome or Edge to be installed on the machine.
	##
	## `Custom` passes any other Playwright channel name, e.g.
	## `Custom("chrome-beta")` or `Custom("msedge-dev")`.
	Channel : [DefaultChannel, Full, Chrome, MsEdge, Custom(Str)]

	## Timeout for action and navigation operations (click, fill, navigate, etc.)
	## and for how long the expect-based assertions keep re-checking before
	## failing. Does not affect browser launch, which always uses a 30s timeout.
	## `NoTimeout` means wait indefinitely.
	Timeout : [TimeoutMilliseconds(U64), NoTimeout]

	## When to consider navigation complete.
	WaitUntil : [Load, DomContentLoaded, NetworkIdle, Commit]

	## State to wait for with [wait_for!].
	WaitForState : [Visible, Hidden, Attached, Detached]

	## Keyboard key for press, up, and down operations.
	Key : [
		# Navigation
		Escape,
		Enter,
		Tab,
		Backspace,
		Delete,
		Insert,
		Space,
		# Arrows
		ArrowUp,
		ArrowDown,
		ArrowLeft,
		ArrowRight,
		# Page navigation
		Home,
		End,
		PageUp,
		PageDown,
		# Function keys
		F1,
		F2,
		F3,
		F4,
		F5,
		F6,
		F7,
		F8,
		F9,
		F10,
		F11,
		F12,
		# Modifiers
		Shift,
		Control,
		Alt,
		Meta,
		ControlOrMeta,
		# Letters
		KeyA,
		KeyB,
		KeyC,
		KeyD,
		KeyE,
		KeyF,
		KeyG,
		KeyH,
		KeyI,
		KeyJ,
		KeyK,
		KeyL,
		KeyM,
		KeyN,
		KeyO,
		KeyP,
		KeyQ,
		KeyR,
		KeyS,
		KeyT,
		KeyU,
		KeyV,
		KeyW,
		KeyX,
		KeyY,
		KeyZ,
		# Digits
		Digit0,
		Digit1,
		Digit2,
		Digit3,
		Digit4,
		Digit5,
		Digit6,
		Digit7,
		Digit8,
		Digit9,
		# Punctuation
		Backquote,
		Minus,
		Equal,
		BracketLeft,
		BracketRight,
		Backslash,
		Semicolon,
		Quote,
		Comma,
		Period,
		Slash,
	]

	## Modifier keys for [key_press!] and [key_press_targetless!] combinations.
	## `ControlOrMeta` resolves to `Meta` on macOS and `Control` on Linux/Windows.
	Modifier : [Control, Shift, Alt, Meta, ControlOrMeta]

	## Bounding box of an element in CSS pixels, relative to the main frame viewport.
	BoundingBox : {
		x : F64,
		y : F64,
		width : F64,
		height : F64,
	}

	## What to set on a file input. Either file paths or in-memory buffers.
	InputFiles : [Paths(List(Str)), Buffers(List(FilePayload))]

	## A file to upload from memory (no disk file needed).
	FilePayload : {
		name : Str,
		mime_type : Str,
		buffer : List(U8),
	}

	## Launch a browser with default settings (headless, 30s timeout).
	##
	## ```
	## browser = Playwright.launch!(hooks, Chromium(DefaultChannel))?
	## ```
	launch! : PlatformHooks(cmd, child, LaunchError(s, e)), BrowserType => Try(Browser(LaunchError(s, e)), LaunchError(s, e)) where [cmd.args_str : cmd, List(Str) -> cmd, child.write_stdin! : child, List(U8) => Try({}, LaunchError(s, e)), child.read_stdout! : child, U64 => Try(List(U8), LaunchError(s, e)), child.kill! : child => Try({}, LaunchError(s, e))]
	launch! = |hooks, browser_type|
		# WORKAROUND: compiler bug. Punning `{ browser_type }` is read as the
		# bare value instead of a one-field record. Revert when fixed.
		Playwright.launch_with!(hooks, { browser_type: browser_type })

	## Launch a browser with custom options.
	##
	## `args` are extra command-line flags passed to the browser binary, e.g.
	## Chromium's `--use-fake-device-for-media-capture`. Pass `[]` for none.
	##
	## The Chromium distribution is picked by the [Channel] inside `browser_type`,
	## e.g. `Chromium(Full)` when a headless test needs media APIs like
	## `getUserMedia`.
	##
	## ```
	## browser = Playwright.launch_with!(hooks, {
	##     browser_type: Chromium(Full),
	##     headless: Bool.True,
	##     timeout: TimeoutMilliseconds(60000),
	##     args: ["--use-fake-device-for-media-capture"],
	## })?
	## ```
	launch_with! : PlatformHooks(cmd, child, LaunchError(s, e)), LaunchOptions => Try(Browser(LaunchError(s, e)), LaunchError(s, e)) where [cmd.args_str : cmd, List(Str) -> cmd, child.write_stdin! : child, List(U8) => Try({}, LaunchError(s, e)), child.read_stdout! : child, U64 => Try(List(U8), LaunchError(s, e)), child.kill! : child => Try({}, LaunchError(s, e))]
	launch_with! = |hooks, { browser_type, headless, timeout, args }| {
		# Bind the hooks to locals for reuse below. (Direct field calls on a
		# plain record parameter resolve as method dispatch, so they would
		# need parens anyway: `(hooks.new)(...)`.)
		cmd_new = hooks.new
		spawn! = hooks.spawn!
		driver = hooks.driver

		spawn_driver! = |name| spawn!(cmd_new(name).args_str(["run-driver"]))

		# npm installs the CLI as `<name>.cmd` on Windows and never as an
		# `.exe`, while a spawn's PATH search there only ever appends `.exe`. So
		# a bare name resolves on Unix and nowhere else. Try the shim second
		# rather than ask the caller which system it is on: on Unix the first
		# spawn succeeds and this costs nothing.
		shim = "${driver}.cmd"
		child = match spawn_driver!(driver) {
			Ok(c) => Ok(c)
			Err(SpawnFailed(why)) =>
				match spawn_driver!(shim) {
					Ok(c) => Ok(c)

					# Report why the FIRST attempt failed, not the shim's. Off
					# Windows the shim was never going to exist, so its
					# NotFound would bury the real cause. And the cause is the
					# whole message: `NotFound` means install it or point
					# `driver` at it, while `PermissionDenied` means it is
					# already there and telling someone to install it sends
					# them after the wrong thing.
					Err(SpawnFailed(_)) =>
						Err(
							CouldNotStartDriver(
								\\Could not spawn '${driver}': ${Str.inspect(why)}
								\\
								\\If it is not installed: `npm install -g playwright`, or add
								\\'pkgs.playwright-test' to your Nix devShell. If it is installed
								\\somewhere a PATH lookup will not find: set `driver` on the hooks
								\\record you pass to launch.
								\\
								\\('${shim}', the name npm installs on Windows, failed too.)
								,
							),
						)

					Err(other) => Err(other)
				}

			Err(other) => Err(other)
		}?

		# Bind the child into per-browser closures once. Everything downstream
		# (initialization and the cleanup on failure) goes through these.
		write_stdin! = |bytes| child.write_stdin!(bytes)
		read_stdout! = |len| child.read_stdout!(len)
		kill! = |{}| child.kill!()

		# Initialization is wrapped to ensure cleanup on failure.
		init_result = initialize_browser!(write_stdin!, read_stdout!, kill!, browser_type, headless, timeout, args)
		match init_result {
			Ok(browser) => Ok(browser)
			Err(err) =>
			# Kill the process before returning the error
				match kill!({}) {
					_ => Err(err)
				}
			}
	}

	## Launch a browser and create a page in one step.
	##
	## ```
	## { browser, page } = Playwright.launch_page!(hooks, Chromium(DefaultChannel))?
	## ```
	launch_page! : PlatformHooks(cmd, child, LaunchPageError(s, e)), BrowserType => Try({ browser : Browser(LaunchPageError(s, e)), page : Page(LaunchPageError(s, e)) }, LaunchPageError(s, e)) where [cmd.args_str : cmd, List(Str) -> cmd, child.write_stdin! : child, List(U8) => Try({}, LaunchPageError(s, e)), child.read_stdout! : child, U64 => Try(List(U8), LaunchPageError(s, e)), child.kill! : child => Try({}, LaunchPageError(s, e))]
	launch_page! = |hooks, browser_type|
		# WORKAROUND: compiler bug. Punning `{ browser_type }` is read as the
		# bare value instead of a one-field record. Revert when fixed.
		Playwright.launch_page_with!(hooks, { browser_type: browser_type })

	## Launch a browser with custom options and create a page.
	##
	## Takes the same options as [launch_with!] plus the context options
	## `has_touch` and `permissions`, which are forwarded to [new_context_with!].
	##
	## ```
	## { browser, page } = Playwright.launch_page_with!(hooks, {
	##     headless: Bool.False,
	##     timeout: TimeoutMilliseconds(5000),
	## })?
	## ```
	##
	## Fields left out take the defaults [LaunchPageOptions] declares.
	launch_page_with! : PlatformHooks(cmd, child, LaunchPageError(s, e)), LaunchPageOptions => Try({ browser : Browser(LaunchPageError(s, e)), page : Page(LaunchPageError(s, e)) }, LaunchPageError(s, e)) where [cmd.args_str : cmd, List(Str) -> cmd, child.write_stdin! : child, List(U8) => Try({}, LaunchPageError(s, e)), child.read_stdout! : child, U64 => Try(List(U8), LaunchPageError(s, e)), child.kill! : child => Try({}, LaunchPageError(s, e))]
	launch_page_with! = |hooks, { browser_type, headless, timeout, args, has_touch, permissions }| {
		browser = Playwright.launch_with!(hooks, { browser_type, headless, timeout, args })?
		context = browser.new_context_with!({ has_touch, permissions })?
		page = context.new_page!()?
		Ok({ browser, page })
	}

	## Create a new browser context with isolated session state.
	##
	## ```
	## context = browser.new_context!()?
	## ```
	new_context! : Browser([NewContextError(Str), ..e]) => Try(Context([NewContextError(Str), ..e]), [NewContextError(Str), ..e])
	new_context! = |browser|
		browser.new_context_with!({ has_touch: Bool.False, permissions: [] })

	## Create a new browser context with options.
	##
	## `permissions` grants browser permissions to the context, e.g.
	## `["microphone"]` lets `getUserMedia` resolve without a prompt.
	##
	## ```
	## context = browser.new_context_with!({ has_touch: Bool.True })?
	## ```
	new_context_with! : Browser([NewContextError(Str), ..e]), ContextOptions => Try(Context([NewContextError(Str), ..e]), [NewContextError(Str), ..e])
	new_context_with! = |browser, { has_touch, permissions }| {
		write_child! = browser.write_stdin!
		read_child! = browser.read_stdout!

		context_msg : NewContextMessage
		context_msg = { id: msg_id, guid: browser.browser_guid, method: "newContext", params: { hasTouch: has_touch, permissions }, metadata: {} }
		send_message!(write_child!, Str.to_utf8(Json.to_str(context_msg)))?

		context_guid = read_until_create_guid!(read_child!, "BrowserContext")?
		response = read_until_response!(read_child!, msg_id)?

		match response.error {
			Ok(err) => Err(NewContextError(err.error.message))
			Err(_) => Ok(Context.{ browser, context_guid, has_touch })
		}
	}

	## Create a new page (tab) in the browser context.
	##
	## ```
	## page = context.new_page!()?
	## ```
	new_page! : Context([NewPageError(Str), ..e]) => Try(Page([NewPageError(Str), ..e]), [NewPageError(Str), ..e])
	new_page! = |context| {
		browser = context.browser
		write_child! = browser.write_stdin!
		read_child! = browser.read_stdout!
		page_msg : SimpleMessage
		page_msg = { id: msg_id, guid: context.context_guid, method: "newPage", params: {}, metadata: {} }
		send_message!(write_child!, Str.to_utf8(Json.to_str(page_msg)))?

		{ page_guid, frame_guid } = read_until_page_and_frame!(read_child!)?
		response = read_until_response!(read_child!, msg_id)?

		match response.error {
			Ok(err) => Err(NewPageError(err.error.message))
			Err(_) => Ok(Page.{ context, page_guid, frame_guid })
		}
	}

	## Navigate to a URL.
	##
	## ```
	## Playwright.navigate!(page, "https://example.com")?
	## ```
	navigate! : Page([NavigateError(Str), ..e]), Str => Try({}, [NavigateError(Str), ..e])
	navigate! = |page, url| {
		goto_msg : GotoMessage
		goto_msg = { id: msg_id, guid: page.frame_guid, method: "goto", params: { url, timeout: timeout_to_ms(page.context.browser.timeout) }, metadata: {} }
		exec_command!(page, Str.to_utf8(Json.to_str(goto_msg)), |m| NavigateError(m))
	}

	## Navigate to a URL with options.
	##
	## ```
	## Playwright.navigate_with!(page, { url: "https://example.com", wait_until: NetworkIdle })?
	## ```
	navigate_with! : Page([NavigateError(Str), ..e]), NavigateOptions => Try({}, [NavigateError(Str), ..e])
	navigate_with! = |page, { url, wait_until }| {
		goto_msg : GotoWithWaitUntilMessage
		goto_msg = { id: msg_id, guid: page.frame_guid, method: "goto", params: { url, timeout: timeout_to_ms(page.context.browser.timeout), waitUntil: wait_until_to_str(wait_until) }, metadata: {} }
		exec_command!(page, Str.to_utf8(Json.to_str(goto_msg)), |m| NavigateError(m))
	}

	## Get the page title.
	##
	## ```
	## title = Playwright.get_title!(page)?
	## ```
	get_title! : Page([TitleError(Str), TitleNotFound, UnexpectedStringResponse(Str), ..e]) => Try(Str, [TitleError(Str), TitleNotFound, UnexpectedStringResponse(Str), ..e])
	get_title! = |page| {
		title_msg : SimpleMessage
		title_msg = { id: msg_id, guid: page.frame_guid, method: "title", params: {}, metadata: {} }
		exec_string_command!(page, Str.to_utf8(Json.to_str(title_msg)), |m| TitleError(m), TitleNotFound)
	}

	## Get the text content of an element.
	##
	## ```
	## text = Playwright.text_content!(page, "h1")?
	## ```
	text_content! : Page([TextContentNotFound, TextContentError(Str), DecodeError, ..e]), Str => Try(Str, [TextContentNotFound, TextContentError(Str), DecodeError, ..e])
	text_content! = |page, selector| text_content_impl!(page, selector, Bool.False)

	## Get the value of an input or textarea.
	##
	## ```
	## value = Playwright.input_value!(page, "#email")?
	## ```
	input_value! : Page([InputValueError(Str), InputValueNotFound, UnexpectedStringResponse(Str), ..e]), Str => Try(Str, [InputValueError(Str), InputValueNotFound, UnexpectedStringResponse(Str), ..e])
	input_value! = |page, selector| input_value_impl!(page, selector, Bool.False)

	## Get an attribute value from an element.
	##
	## ```
	## href = Playwright.get_attribute!(page, "a.nav-link", "href")?
	## ```
	get_attribute! : Page([AttributeNotFound, AttributeError(Str), DecodeError, ..e]), Str, Str => Try(Str, [AttributeNotFound, AttributeError(Str), DecodeError, ..e])
	get_attribute! = |page, selector, attribute_name| get_attribute_impl!(page, selector, attribute_name, Bool.False)

	## Click an element.
	##
	## ```
	## Playwright.click!(page, "button#submit")?
	## ```
	click! : Page([ClickError(Str), ..e]), Str => Try({}, [ClickError(Str), ..e])
	click! = |page, selector| click_impl!(page, selector, Bool.False)

	## Check a checkbox or radio button. If already checked, this is a no-op.
	## Sets the checked state via JS and dispatches `input` + `change` events.
	##
	## Note: Chromium's CDP click does not fire `change` events on custom-styled
	## checkboxes (`appearance: none`), so we set the state and dispatch events
	## directly via JS instead.
	##
	## ```
	## Playwright.check!(page, "input[type='checkbox']")?
	## ```
	check! : Page([CheckError(Str), DecodeError, EvaluateReturnedNull, EvaluateError(Str), ..e]), Str => Try({}, [CheckError(Str), DecodeError, EvaluateReturnedNull, EvaluateError(Str), ..e])
	check! = |page, selector|
		Playwright.set_checked!(page, selector, Bool.True)

	## Uncheck a checkbox. If already unchecked, this is a no-op.
	## Sets the checked state via JS and dispatches `input` + `change` events.
	##
	## ```
	## Playwright.uncheck!(page, "input[type='checkbox']")?
	## ```
	uncheck! : Page([CheckError(Str), DecodeError, EvaluateReturnedNull, EvaluateError(Str), ..e]), Str => Try({}, [CheckError(Str), DecodeError, EvaluateReturnedNull, EvaluateError(Str), ..e])
	uncheck! = |page, selector|
		Playwright.set_checked!(page, selector, Bool.False)

	## Set a checkbox or radio button to `desired`. Backs [check!]/[uncheck!].
	##
	## ```
	## Playwright.set_checked!(page, "#terms", Bool.True)?
	## ```
	set_checked! : Page([CheckError(Str), DecodeError, EvaluateReturnedNull, EvaluateError(Str), ..e]), Str, Bool => Try({}, [CheckError(Str), DecodeError, EvaluateReturnedNull, EvaluateError(Str), ..e])
	set_checked! = |page, selector, desired| set_checked_impl!(page, selector, desired, Bool.False)

	## Set the value of an input or textarea directly, without individual key events.
	## Use [key_type!] if the app relies on keydown/keyup events.
	##
	## Remember that for client-side apps you'll need to [wait_for!] your app to
	## initialize and register event listeners before calling [fill!].
	##
	## ```
	## Playwright.fill!(page, "#email", "user@example.com")?
	## ```
	fill! : Page([FillError(Str), ..e]), Str, Str => Try({}, [FillError(Str), ..e])
	fill! = |page, selector, value| fill_impl!(page, selector, value, Bool.False)

	## Set files for a file input element. Accepts either file paths or in-memory buffers.
	##
	## ```
	## # From file paths
	## Playwright.set_input_files!(page, "#upload", Paths(["/tmp/test.zip"]))?
	##
	## # From in-memory buffers (no disk file needed)
	## Playwright.set_input_files!(page, "#upload", Buffers([{
	##     name: "test.zip",
	##     mime_type: "application/zip",
	##     buffer: List.repeat(0u8, 1024),
	## }]))?
	##
	## # Clear file input
	## Playwright.set_input_files!(page, "#upload", Paths([]))?
	## ```
	set_input_files! : Page([SetInputFilesError(Str), ..e]), Str, InputFiles => Try({}, [SetInputFilesError(Str), ..e])
	set_input_files! = |page, selector, input_files| {
		timeout = timeout_to_ms(page.context.browser.timeout)

		# Empty list for either variant means "clear the file input".
		# Playwright requires {payloads: []} for clearing (not {localPaths: []}).
		message_bytes =
			match input_files {
				Paths(paths) =>
					if paths.is_empty() {
						clear_msg : SetInputFilesPayloadsMessage
						clear_msg = { id: msg_id, guid: page.frame_guid, method: "setInputFiles", params: { selector, payloads: [], timeout }, metadata: {} }
						Str.to_utf8(Json.to_str(clear_msg))
					} else {
						paths_msg : SetInputFilesPathsMessage
						paths_msg = { id: msg_id, guid: page.frame_guid, method: "setInputFiles", params: { selector, localPaths: paths, timeout }, metadata: {} }
						Str.to_utf8(Json.to_str(paths_msg))
					}

				Buffers(payloads) => {
					wire_payloads = payloads.map(
						|p| {
							name: p.name,
							mimeType: p.mime_type,
							buffer: Base64.encode(p.buffer),
						},
					)
					buffers_msg : SetInputFilesPayloadsMessage
					buffers_msg = { id: msg_id, guid: page.frame_guid, method: "setInputFiles", params: { selector, payloads: wire_payloads, timeout }, metadata: {} }
					Str.to_utf8(Json.to_str(buffers_msg))
				}
			}

		exec_command!(page, message_bytes, |m| SetInputFilesError(m))
	}

	## Focus an element and type text character by character (keydown/keyup per char).
	## See [key_type_targetless!] for the page-level variant.
	##
	## ```
	## Playwright.key_type!(page, "#search", "hello")?
	## ```
	key_type! : Page([KeyTypeError(Str), ..e]), Str, Str => Try({}, [KeyTypeError(Str), ..e])
	key_type! = |page, selector, text| {
		msg : PressSequentiallyMessage
		msg = { id: msg_id, guid: page.frame_guid, method: "type", params: { selector, text, timeout: timeout_to_ms(page.context.browser.timeout) }, metadata: {} }
		exec_command!(page, Str.to_utf8(Json.to_str(msg)), |m| KeyTypeError(m))
	}

	## Move the mouse to the center of an element.
	##
	## ```
	## Playwright.hover!(page, ".dropdown-trigger")?
	## ```
	hover! : Page([HoverError(Str), ..e]), Str => Try({}, [HoverError(Str), ..e])
	hover! = |page, selector| hover_impl!(page, selector, Bool.False)

	## Check if an element is visible. Returns immediately without waiting.
	##
	## ```
	## is_shown = Playwright.is_visible!(page, "#modal")?
	## ```
	is_visible! : Page([IsVisibleError(Str), IsVisibleNoResult, UnexpectedBoolResponse(Str), ..e]), Str => Try(Bool, [IsVisibleError(Str), IsVisibleNoResult, UnexpectedBoolResponse(Str), ..e])
	is_visible! = |page, selector| is_visible_impl!(page, selector, Bool.False)

	## Wait for an element to reach a specified state.
	##
	## ```
	## # Wait for element to appear (visible)
	## Playwright.wait_for!(page, "#dynamic-content", Visible)?
	##
	## # Wait for element to disappear (hidden)
	## Playwright.wait_for!(page, "text=Loading...", Hidden)?
	## ```
	wait_for! : Page([WaitForTimeout(Str), ..e]), Str, WaitForState => Try({}, [WaitForTimeout(Str), ..e])
	wait_for! = |page, selector, state| wait_for_impl!(page, selector, state, Bool.False)

	## Count elements matching a selector. Returns `0` if none match.
	##
	## ```
	## count = Playwright.query_count!(page, "ul.results li")?
	## ```
	query_count! : Page([QueryCountError(Str), QueryCountNoResult, UnexpectedIntResponse(Str), ..e]), Str => Try(U64, [QueryCountError(Str), QueryCountNoResult, UnexpectedIntResponse(Str), ..e])
	query_count! = |page, selector| {
		msg : SelectorOnlyMessage
		msg = { id: msg_id, guid: page.frame_guid, method: "queryCount", params: { selector }, metadata: {} }
		read_child! = send_to_page!(page, Str.to_utf8(Json.to_str(msg)))?

		response = read_until_int_response!(read_child!, msg_id)?

		match response.error {
			Ok(err) => Err(QueryCountError(err.error.message))
			Err(_) =>
				match response.result {
					Ok(result) => Ok(result.value)
					Err(_) => Err(QueryCountNoResult)
				}
			}
	}

	## Move the mouse to coordinates.
	##
	## ```
	## Playwright.mouse_move!(page, 100.0, 200.0)?
	## ```
	mouse_move! : Page([MouseMoveError(Str), InvalidCoordinates, ..e]), F64, F64 => Try({}, [MouseMoveError(Str), InvalidCoordinates, ..e])
	mouse_move! = |page, x, y|
		Playwright.mouse_move_with_steps!(page, x, y, 1)

	## Move the mouse to coordinates with interpolated steps.
	##
	## ```
	## Playwright.mouse_move_with_steps!(page, 100.0, 200.0, 10)?
	## ```
	mouse_move_with_steps! : Page([MouseMoveError(Str), InvalidCoordinates, ..e]), F64, F64, U64 => Try({}, [MouseMoveError(Str), InvalidCoordinates, ..e])
	mouse_move_with_steps! = |page, x, y, steps| {
		msg : MouseMoveMessage
		msg = { id: msg_id, guid: page.page_guid, method: "mouseMove", params: { x, y, steps }, metadata: {} }
		exec_command!(page, Str.to_utf8(Json.to_str_try(msg).map_err(|_| InvalidCoordinates)?), |m| MouseMoveError(m))
	}

	## Press the left mouse button at current position.
	##
	## ```
	## Playwright.mouse_down!(page)?
	## ```
	mouse_down! : Page([MouseDownError(Str), ..e]) => Try({}, [MouseDownError(Str), ..e])
	mouse_down! = |page| {
		msg : MouseButtonMessage
		msg = { id: msg_id, guid: page.page_guid, method: "mouseDown", params: { button: "left", clickCount: 1 }, metadata: {} }
		exec_command!(page, Str.to_utf8(Json.to_str(msg)), |m| MouseDownError(m))
	}

	## Release the left mouse button at current position.
	##
	## ```
	## Playwright.mouse_up!(page)?
	## ```
	mouse_up! : Page([MouseUpError(Str), ..e]) => Try({}, [MouseUpError(Str), ..e])
	mouse_up! = |page| {
		msg : MouseButtonMessage
		msg = { id: msg_id, guid: page.page_guid, method: "mouseUp", params: { button: "left", clickCount: 1 }, metadata: {} }
		exec_command!(page, Str.to_utf8(Json.to_str(msg)), |m| MouseUpError(m))
	}

	## Get the bounding box of an element. Waits for the element to be visible.
	##
	## ```
	## box = Playwright.bounding_box!(page, ".swiper")?
	## center_x = box.x + box.width / 2.0
	## center_y = box.y + box.height / 2.0
	## ```
	bounding_box! : Page([BoundingBoxError(Str), ElementNotFound, ElementNotVisible, WaitForTimeout(Str), ..e]), Str => Try(BoundingBox, [BoundingBoxError(Str), ElementNotFound, ElementNotVisible, WaitForTimeout(Str), ..e])
	bounding_box! = |page, selector| bounding_box_impl!(page, selector, Bool.False)

	## Tap an element. Requires `has_touch: Bool.True` context.
	##
	## ```
	## Playwright.tap!(page, "button#submit")?
	## ```
	tap! : Page([TapError(Str), ..e]), Str => Try({}, [TapError(Str), ..e])
	tap! = |page, selector| {
		msg : SelectorMessage
		msg = { id: msg_id, guid: page.frame_guid, method: "tap", params: { selector, timeout: timeout_to_ms(page.context.browser.timeout), strict: Bool.False }, metadata: {} }
		exec_command!(page, Str.to_utf8(Json.to_str(msg)), |m| TapError(m))
	}

	## Tap at coordinates. Requires `has_touch: Bool.True` context.
	##
	## ```
	## Playwright.touchscreen_tap!(page, 100.0, 200.0)?
	## ```
	touchscreen_tap! : Page([TouchscreenTapError(Str), InvalidCoordinates, ..e]), F64, F64 => Try({}, [TouchscreenTapError(Str), InvalidCoordinates, ..e])
	touchscreen_tap! = |page, x, y| {
		msg : TouchTapMessage
		msg = { id: msg_id, guid: page.page_guid, method: "touchscreenTap", params: { x, y }, metadata: {} }
		exec_command!(page, Str.to_utf8(Json.to_str_try(msg).map_err(|_| InvalidCoordinates)?), |m| TouchscreenTapError(m))
	}

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
	evaluate! : Page([EvaluateReturnedNull, EvaluateError(Str), DecodeError, ..e]), Str => Try(Str, [EvaluateReturnedNull, EvaluateError(Str), DecodeError, ..e])
	evaluate! = |page, expression| {
		msg : EvaluateMessage
		msg = {
			id: msg_id,
			guid: page.frame_guid,
			method: "evaluateExpression",
			params: {
				expression,
				isFunction: Bool.False,
				arg: { value: { v: "undefined" }, handles: [] },
			},
			metadata: {},
		}
		match exec_nullable_string_command!(page, Str.to_utf8(Json.to_str(msg)), |m| EvaluateError(m))? {
			Ok(value) => Ok(value)
			Err(ValueIsNull) => Err(EvaluateReturnedNull)
		}
	}

	## Simulate a touch scroll gesture using CDP's `Input.synthesizeScrollGesture`.
	## This goes through Chrome's compositor touch handling pipeline, the same
	## path used by the GPU benchmarking system for real touch gesture simulation.
	## Triggers native scrolling and respects `touch-action` CSS.
	## Requires `has_touch: Bool.True` context.
	##
	## ```
	## Playwright.touch_scroll!(page, { start_x: 100.0, start_y: 400.0, end_x: 100.0, end_y: 200.0 })?
	## ```
	touch_scroll! : Page([InvalidCoordinates, ..e]), Gesture => Try({}, [InvalidCoordinates, ..e])
	touch_scroll! = |page, { start_x, start_y, end_x, end_y }| {
		context = page.context
		browser = context.browser
		write_child! = browser.write_stdin!
		read_child! = browser.read_stdout!

		# Create a CDP session
		cdp_msg : CdpSessionMessage
		cdp_msg = { id: msg_id, guid: context.context_guid, method: "newCDPSession", params: { page: { guid: page.page_guid } }, metadata: {} }
		send_message!(write_child!, Str.to_utf8(Json.to_str(cdp_msg)))?

		cdp_session_guid = read_until_create_guid!(read_child!, "CDPSession")?
		_cdp_response = read_until_response!(read_child!, msg_id)?

		# synthesizeScrollGesture distances: the vector the finger moves
		x_distance = end_x - start_x
		y_distance = end_y - start_y

		scroll_msg : CdpScrollGestureMessage
		scroll_msg = {
			id: msg_id,
			guid: cdp_session_guid,
			method: "send",
			params: {
				method: "Input.synthesizeScrollGesture",
				params: {
					x: start_x,
					y: start_y,
					xDistance: x_distance,
					yDistance: y_distance,
				},
			},
			metadata: {},
		}
		send_message!(write_child!, Str.to_utf8(Json.to_str_try(scroll_msg).map_err(|_| InvalidCoordinates)?))?
		_response = read_until_response!(read_child!, msg_id)?

		# Detach the CDP session
		detach_msg : SimpleMessage
		detach_msg = { id: msg_id, guid: cdp_session_guid, method: "detach", params: {}, metadata: {} }
		send_message!(write_child!, Str.to_utf8(Json.to_str(detach_msg)))?
		_detach_response = read_until_response!(read_child!, msg_id)?

		Ok({})
	}

	## Swipe from one point to another with a real compositor-level touch
	## gesture (CDP `Input.synthesizeScrollGesture` with `gestureSourceType:
	## "touch"`). Unlike [touch_scroll!] (whose "default" source is a mouse
	## wheel on desktop) this produces genuine touch input, so the browser
	## fires the full pointer-event sequence (pointerdown/move/up, or
	## pointercancel when it claims the gesture for scrolling per
	## `touch-action`) exactly as a finger would. Use it to drive JS
	## pointer/touch handlers. Use [touch_scroll!] to test wheel-style native
	## scrolling. Requires `has_touch: Bool.True` context.
	##
	## ```
	## Playwright.touch_swipe!(page, { start_x: 400.0, start_y: 300.0, end_x: 100.0, end_y: 300.0 })?
	## ```
	touch_swipe! : Page([InvalidCoordinates, ..e]), Gesture => Try({}, [InvalidCoordinates, ..e])
	touch_swipe! = |page, { start_x, start_y, end_x, end_y }| {
		context = page.context
		browser = context.browser
		write_child! = browser.write_stdin!
		read_child! = browser.read_stdout!

		# Create a CDP session
		cdp_msg : CdpSessionMessage
		cdp_msg = { id: msg_id, guid: context.context_guid, method: "newCDPSession", params: { page: { guid: page.page_guid } }, metadata: {} }
		send_message!(write_child!, Str.to_utf8(Json.to_str(cdp_msg)))?

		cdp_session_guid = read_until_create_guid!(read_child!, "CDPSession")?
		_cdp_response = read_until_response!(read_child!, msg_id)?

		# synthesizeScrollGesture distances: the vector the finger moves
		x_distance = end_x - start_x
		y_distance = end_y - start_y

		swipe_msg : CdpSwipeGestureMessage
		swipe_msg = {
			id: msg_id,
			guid: cdp_session_guid,
			method: "send",
			params: {
				method: "Input.synthesizeScrollGesture",
				params: {
					x: start_x,
					y: start_y,
					xDistance: x_distance,
					yDistance: y_distance,
					gestureSourceType: "touch",
					# A fling would keep synthesizing inertia events after the
					# finger lifts, making assertions timing-dependent.
					preventFling: Bool.True,
				},
			},
			metadata: {},
		}
		send_message!(write_child!, Str.to_utf8(Json.to_str_try(swipe_msg).map_err(|_| InvalidCoordinates)?))?
		_response = read_until_response!(read_child!, msg_id)?

		# Detach the CDP session
		detach_msg : SimpleMessage
		detach_msg = { id: msg_id, guid: cdp_session_guid, method: "detach", params: {}, metadata: {} }
		send_message!(write_child!, Str.to_utf8(Json.to_str(detach_msg)))?
		_detach_response = read_until_response!(read_child!, msg_id)?

		Ok({})
	}

	## Drag from one point to another using synthetic JavaScript touch events.
	## Fires JS `addEventListener` handlers but does NOT trigger native browser
	## scrolling. Use [touch_scroll!] for testing native scroll behavior.
	## Requires `has_touch: Bool.True` context.
	##
	## ```
	## Playwright.touch_drag!(page, { start_x: 100.0, start_y: 200.0, end_x: 300.0, end_y: 200.0 })?
	## ```
	touch_drag! : Page([TouchDragError(Str), InvalidCoordinates, DecodeError, EvaluateReturnedNull, EvaluateError(Str), ..e]), Gesture => Try({}, [TouchDragError(Str), InvalidCoordinates, DecodeError, EvaluateReturnedNull, EvaluateError(Str), ..e])
	touch_drag! = |page, { start_x, start_y, end_x, end_y }| {
		# A JSON number is always a valid JS literal, and NaN/Infinity fail to
		# serialize, so this both validates and escapes the coordinates before
		# they land in JS source (the CDP gesture messages get the same check
		# from serializing their params).
		start_x_js = Json.to_str_try(start_x).map_err(|_| InvalidCoordinates)?
		start_y_js = Json.to_str_try(start_y).map_err(|_| InvalidCoordinates)?
		end_x_js = Json.to_str_try(end_x).map_err(|_| InvalidCoordinates)?
		end_y_js = Json.to_str_try(end_y).map_err(|_| InvalidCoordinates)?
		js =
			\\(() => {
			\\    const startX = ${start_x_js};
			\\    const startY = ${start_y_js};
			\\    const endX = ${end_x_js};
			\\    const endY = ${end_y_js};
			\\
			\\    const el = document.elementFromPoint(startX, startY);
			\\    if (!el) return 'ElementNotFound';
			\\
			\\    let touchId = 1;
			\\
			\\    function dispatchTouchEvent(type, x, y, hasTouches) {
			\\        const touch = new Touch({
			\\            identifier: touchId,
			\\            target: el,
			\\            clientX: x,
			\\            clientY: y,
			\\            pageX: x,
			\\            pageY: y,
			\\            screenX: x,
			\\            screenY: y,
			\\        });
			\\
			\\        const evt = new TouchEvent(type, {
			\\            bubbles: true,
			\\            cancelable: true,
			\\            view: window,
			\\            touches: hasTouches ? [touch] : [],
			\\            targetTouches: hasTouches ? [touch] : [],
			\\            changedTouches: [touch],
			\\        });
			\\
			\\        el.dispatchEvent(evt);
			\\    }
			\\
			\\    dispatchTouchEvent('touchstart', startX, startY, true);
			\\
			\\    const steps = 5;
			\\    for (let i = 1; i <= steps; i++) {
			\\        const x = startX + (endX - startX) * (i / steps);
			\\        const y = startY + (endY - startY) * (i / steps);
			\\        dispatchTouchEvent('touchmove', x, y, true);
			\\    }
			\\
			\\    dispatchTouchEvent('touchend', endX, endY, false);
			\\
			\\    return 'ok';
			\\})()
		result = Playwright.evaluate!(page, js)?
		if result == "ok" {
			Ok({})
		} else {
			Err(TouchDragError(result))
		}
	}

	## Focus an element and press a key (keydown + keyup).
	## See [key_press_targetless!] for the page-level variant.
	##
	## ```
	## Playwright.key_press!(page, "#my-input", Enter, [])?
	## Playwright.key_press!(page, "#my-input", KeyA, [Control])?
	## ```
	key_press! : Page([KeyPressError(Str), ..e]), Str, Key, List(Modifier) => Try({}, [KeyPressError(Str), ..e])
	key_press! = |page, selector, key, modifiers| {
		msg : KeyPressMessage
		msg = { id: msg_id, guid: page.frame_guid, method: "press", params: { selector, key: key_combo_str(key, modifiers), timeout: timeout_to_ms(page.context.browser.timeout) }, metadata: {} }
		exec_command!(page, Str.to_utf8(Json.to_str(msg)), |m| KeyPressError(m))
	}

	## Press a key at the page level (keydown + keyup, no focus change).
	##
	## ```
	## Playwright.key_press_targetless!(page, Escape, [])?
	## Playwright.key_press_targetless!(page, KeyA, [Control, Shift])?
	## ```
	key_press_targetless! : Page([KeyPressError(Str), ..e]), Key, List(Modifier) => Try({}, [KeyPressError(Str), ..e])
	key_press_targetless! = |page, key, modifiers| {
		msg : KeyboardKeyMessage
		msg = { id: msg_id, guid: page.page_guid, method: "keyboardPress", params: { key: key_combo_str(key, modifiers) }, metadata: {} }
		exec_command!(page, Str.to_utf8(Json.to_str(msg)), |m| KeyPressError(m))
	}

	## Hold down a key at the page level. Use with [key_up_targetless!] to release.
	##
	## Prefer [key_press_targetless!] with modifiers for simple combos.
	## Use [key_down_targetless!] / [key_up_targetless!] when modifier state
	## must span multiple actions (e.g., Shift+click sequences).
	##
	## ```
	## Playwright.key_down_targetless!(page, Shift)?
	## Playwright.click!(page, "#item1")?
	## Playwright.click!(page, "#item3")?
	## Playwright.key_up_targetless!(page, Shift)?
	## ```
	key_down_targetless! : Page([KeyDownError(Str), ..e]), Key => Try({}, [KeyDownError(Str), ..e])
	key_down_targetless! = |page, key| {
		msg : KeyboardKeyMessage
		msg = { id: msg_id, guid: page.page_guid, method: "keyboardDown", params: { key: key_to_str(key) }, metadata: {} }
		exec_command!(page, Str.to_utf8(Json.to_str(msg)), |m| KeyDownError(m))
	}

	## Release a key at the page level. Use after [key_down_targetless!].
	##
	## ```
	## Playwright.key_up_targetless!(page, Control)?
	## ```
	key_up_targetless! : Page([KeyUpError(Str), ..e]), Key => Try({}, [KeyUpError(Str), ..e])
	key_up_targetless! = |page, key| {
		msg : KeyboardKeyMessage
		msg = { id: msg_id, guid: page.page_guid, method: "keyboardUp", params: { key: key_to_str(key) }, metadata: {} }
		exec_command!(page, Str.to_utf8(Json.to_str(msg)), |m| KeyUpError(m))
	}

	## Type text at the page level (keydown/keyup per char, no focus change).
	## See [key_type!] for the targeted variant that focuses an element first.
	##
	## ```
	## Playwright.key_type_targetless!(page, "Hello, World!")?
	## ```
	key_type_targetless! : Page([KeyTypeError(Str), ..e]), Str => Try({}, [KeyTypeError(Str), ..e])
	key_type_targetless! = |page, text| {
		msg : KeyboardTypeMessage
		msg = { id: msg_id, guid: page.page_guid, method: "keyboardType", params: { text }, metadata: {} }
		exec_command!(page, Str.to_utf8(Json.to_str(msg)), |m| KeyTypeError(m))
	}

	## Close the browser and terminate the driver process.
	##
	## ```
	## browser.close!()?
	## ```
	close! : Browser(err) => Try({}, [CloseFailed(Str), ..e])
	close! = |browser| {
		write_child! = browser.write_stdin!
		read_child! = browser.read_stdout!

		# Ask the driver to close the browser, and wait for it to say it did.
		# Killing the driver alone is not enough: it leaves the browser to
		# notice its pipe closing (Chromium's --remote-debugging-pipe,
		# Firefox's juggler pipe, WebKit's inspector pipe), which Chromium's
		# headless shell does and its full build does not. A full Chromium
		# then outlives the program that launched it. Closing through the
		# driver is what makes the browser go away for every build, because
		# the driver terminates the process itself.
		#
		# Failures here are deliberately dropped: if the driver is already
		# gone there is nothing to close, and the kill below is the answer
		# either way.
		close_msg : SimpleMessage
		close_msg = { id: msg_id, guid: browser.browser_guid, method: "close", params: {}, metadata: {} }
		_ = send_message!(write_child!, Str.to_utf8(Json.to_str(close_msg)))
		_ = read_until_response!(read_child!, msg_id)

		# Then take the driver down. A program that never reaches close! is
		# covered by the same driver: `run-driver` exits on stdin EOF and
		# takes its browsers with it, so a plain `Cmd.spawn!` is leash
		# enough. tests/leak/ checks both routes on every OS.
		#
		# The platform error is carried as a Str rather than as the error value
		# itself. Returning CloseFailed(err) makes the app's error union contain
		# itself (platform errors are open unions, so `err` unifies with the
		# union CloseFailed lands in) and the compiler rejects that as an
		# anonymous recursive type.
		kill_child! = browser.kill!
		match kill_child!({}) {
			Ok(_) => Ok({})
			Err(e) => Err(CloseFailed(Str.inspect(e)))
		}
	}

	## A checkable expectation about an [Element], [Elements] or [Page],
	## built by their claim methods ([Element.has_text], [Elements.has_count],
	## [Page.has_title], ...) and run by [assert!] or [assert_with!]. Building
	## a claim is pure and sends nothing to the driver, so claims are plain
	## values: name one, pass it around, assert it as often as needed.
	Claim(err) := {
		run! : AssertTimeout => Try({}, err),
	}

	## Where a claim's re-check deadline comes from: the page's [Timeout]
	## (what [assert!] uses), a per-assert override, or no limit at all.
	## `NoTimeout` re-checks forever, so a claim that never holds hangs the
	## test: reserve it for claims something else is guaranteed to resolve.
	AssertTimeout : [PageTimeout, TimeoutMilliseconds(U64), NoTimeout]

	## Options for [assert_with!]. Every field carries a default, so a call
	## spells only what it changes, the way [LaunchOptions] describes.
	##
	## `label` is prepended to [AssertionFailed]'s message, naming the intent
	## a bare selector cannot: with several asserts on one selector in a test,
	## `label: "listener detached"` says which claim failed and why it
	## matters.
	AssertOptions : {
		timeout : AssertTimeout ?? PageTimeout,
		label : Str ?? "",
	}

	## Check a claim against the live page.
	##
	## ```
	## assert!(page.find("h1").has_text("Welcome"))?
	## assert!(page.find("h1").not_has_text("Error"))?
	## assert!(page.find_all("nav a").has_count(5))?
	## assert!(page.find_all(".item").none_contains_text("Error"))?
	## assert!(page.has_title("Checkout"))?
	## ```
	assert! : Claim([AssertionFailed(Str), ..e]) => Try({}, [AssertionFailed(Str), ..e])
	assert! = |claim| (claim.run!)(PageTimeout)

	## [assert!], with options: a per-assert timeout, a label naming the
	## claim's intent in its failure message, or both.
	##
	## ```
	## assert_with!(page.find("h1").exists(), { timeout: TimeoutMilliseconds(5000) })?
	## assert_with!(page.find("#keys-seen").has_text("Keys seen: 5"), { label: "listener detached" })?
	## ```
	##
	## The timeout bounds the driver-backed claims exactly. The quantified
	## claims ([Elements.all_has_text] and friends) judge a single read, as
	## their docs describe, so for them it bounds each read rather than the
	## claim as a whole.
	assert_with! : Claim([AssertionFailed(Str), ..e]), AssertOptions => Try({}, [AssertionFailed(Str), ..e])
	assert_with! = |claim, { timeout, label }|
		match (claim.run!)(timeout) {
			Ok({}) => Ok({})
			Err(AssertionFailed(msg)) if !label.is_empty() => Err(AssertionFailed("${label}: ${msg}"))
			Err(other) => Err(other)
		}

	## Whether a quantified claim must hold for every match, for at least
	## one, or for none of them.
	Quantifier : [All, Any, None]

	## The driver-backed quantified claims: a quantifier over a property the
	## selector engine can express (text, visibility) is a retried count
	## claim on the selector composed with a filter engine. `filter` picks
	## the matches satisfying the property, `counter_filter` the
	## counterexamples.

	filtered_any : Elements(AssertError(e)), Str, Str -> Claim(AssertError(e))
	filtered_any = |els, filter, want| Claim.{
		run!: |t| expect_count_impl!(els.page, t, "${els.selector} >> ${filter}", 0, Bool.True, |_r|
			"${els.selector}: expected some match ${want}, but none did"),
	}

	filtered_none : Elements(AssertError(e)), Str, Str -> Claim(AssertError(e))
	filtered_none = |els, filter, want| Claim.{
		run!: |t| expect_count_impl!(els.page, t, "${els.selector} >> ${filter}", 0, Bool.False, |r| match r {
			Received(got) => "${els.selector}: expected no match ${want}, but ${got} did"
			_ => "${els.selector}: expected no match ${want}"
		}),
	}

	filtered_all : Elements(AssertError(e)), Str, Str -> Claim(AssertError(e))
	filtered_all = |els, counter_filter, want| Claim.{
		# Non-vacuous, so an empty set fails: two sequential retried checks,
		# like two asserts in a row. First that anything matches at all, then
		# that no counterexample does. Each check waits on its own, so a
		# claim that never holds can take up to two timeouts.
		run!: |t| {
			expect_count_impl!(els.page, t, els.selector, 0, Bool.True, |_r|
				"${els.selector}: expected every match ${want}, but nothing matched the selector")?
			expect_count_impl!(els.page, t, "${els.selector} >> ${counter_filter}", 0, Bool.False, |r| match r {
				Received(got) => "${els.selector}: expected every match ${want}, but ${got} did not"
				_ => "${els.selector}: expected every match ${want}"
			})
		},
	}

	## Build the client-side quantified claims from one value read per match
	## plus a quantifier. One helper per read the claims are judged on.

	value_claim : Elements(ValueAssertError(e)), Quantifier, Str, (Str -> Bool) -> Claim(ValueAssertError(e))
	value_claim = |els, quantifier, want, ok| Claim.{
		run!: |_t| {
			n = els.count!()?
			got = Playwright.collect!(els, 0, n, [], |el| el.value!())?
			Playwright.judge(els.selector, quantifier, got, want, ok)
		},
	}

	attr_claim : Elements(AttrAssertError(e)), Quantifier, Str, Str, (Str -> Bool) -> Claim(AttrAssertError(e))
	attr_claim = |els, quantifier, name, want, ok| Claim.{
		run!: |_t| {
			n = els.count!()?
			got = Playwright.collect!(els, 0, n, [], |el| el.attribute!(name))?
			Playwright.judge(els.selector, quantifier, got, want, ok)
		},
	}

	## Apply a quantifier to the values read from each match.
	##
	## An empty set is handled differently per quantifier, and deliberately
	## so. `All` and `Any` claim something is present and has a property, so
	## an empty set fails: the usual reason a set is empty is a selector
	## typo, and passing vacuously would make the test assert nothing. `None`
	## claims an absence, and an empty set is the strongest form of that
	## absence, so it passes.
	judge : Str, Quantifier, List(Str), Str, (Str -> Bool) -> Try({}, [AssertionFailed(Str), ..e])
	judge = |selector, quantifier, got, want, ok|
		if List.is_empty(got) {
			match quantifier {
				None => Ok({})
				_ => Err(AssertionFailed("${selector}: expected ${want}, but nothing matched the selector"))
			}
		} else {
			match quantifier {
				All =>
					if List.all(got, ok) {
						Ok({})
					} else {
						Err(AssertionFailed("${selector}: expected every match ${want}, got ${Str.inspect(got)}"))
					}
				Any =>
					if List.any(got, ok) {
						Ok({})
					} else {
						Err(AssertionFailed("${selector}: expected some match ${want}, got ${Str.inspect(got)}"))
					}
				None =>
					if List.any(got, ok) {
						Err(AssertionFailed("${selector}: expected no match ${want}, got ${Str.inspect(got)}"))
					} else {
						Ok({})
					}
			}
		}

	## Read one value per match, in document order. Indexes straight into the
	## `>> nth=` selector rather than going through [Elements.nth], which takes
	## an I64 the loop counter would have to be converted to.
	collect! : Elements(err), U64, U64, List(a), (Element(err) => Try(a, err)) => Try(List(a), err)
	collect! = |els, i, n, acc, read!|
		if i >= n {
			Ok(acc)
		} else {
			el = Element.{ page: els.page, selector: "${els.selector} >> nth=${i.to_str()}", which: Only }
			value = read!(el)?
			collect!(els, i + 1, n, List.append(acc, value), read!)
		}

	## The selector an [Element] actually sends to the driver. `Nth` becomes
	## Playwright's own `>> nth=` selector suffix, which counts from the end
	## for negative indices.
	resolve : Element(err) -> Str
	resolve = |el|
		match el.which {
			Only => el.selector
			Nth(i) => "${el.selector} >> nth=${i.to_str()}"
		}
}

# Optional fields are `Try(x, [Missing])`: the builtin JSON parser decodes an
# absent field as `Err(Missing)` and ignores fields not in the target record.
ResponseMessage : {
	id : Try(U64, [Missing]),
	guid : Try(Str, [Missing]),
	method : Try(Str, [Missing]),
	result : Try(ResponseResult, [Missing]),
	error : Try(ResponseError, [Missing]),
}

IdCheckMessage : {
	id : Try(U64, [Missing]),
}

ResponseResult : {
	response : Try(ResponseRef, [Missing]),
	value : Try(SerializedStringValue, [Missing]),
}

SerializedStringValue : {
	s : Str,
}

PlainStringResponseMessage : {
	id : Try(U64, [Missing]),
	result : Try(PlainStringResult, [Missing]),
	error : Try(ResponseError, [Missing]),
}

PlainStringResult : {
	value : Try(Str, [Missing]),
}

BoolResponseMessage : {
	id : Try(U64, [Missing]),
	result : Try(BoolResult, [Missing]),
	error : Try(ResponseError, [Missing]),
}

BoolResult : {
	value : Bool,
}

IntResponseMessage : {
	id : Try(U64, [Missing]),
	result : Try(IntResult, [Missing]),
	error : Try(ResponseError, [Missing]),
}

IntResult : {
	value : U64,
}

# The wire shape of a null/undefined result: {"result": {"value": {"v": "null"}}}.
# Both fields are required so that only this shape decodes - it is the last
# decoder in decode_nullable_string_value's cascade before DecodeError.
NullValueResponseMessage : {
	id : Try(U64, [Missing]),
	result : NullValueResult,
}

NullValueResult : {
	value : SerializedUndefined,
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
	method : Try(Str, [Missing]),
	params : Try(BrowserTypeCreateParams, [Missing]),
}

BrowserTypeCreateParams : {
	type : Try(Str, [Missing]),
	guid : Try(Str, [Missing]),
	initializer : Try(BrowserTypeInitializer, [Missing]),
}

BrowserTypeInitializer : {
	name : Try(Str, [Missing]),
}

BoundingBoxResponseMessage : {
	id : Try(U64, [Missing]),
	result : Try(BoundingBoxResult, [Missing]),
	error : Try(ResponseError, [Missing]),
}

BoundingBoxResult : {
	value : Try(BoundingBoxValue, [Missing]),
}

BoundingBoxValue : {
	x : F64,
	y : F64,
	width : F64,
	height : F64,
}

ElementHandleResponseMessage : {
	id : Try(U64, [Missing]),
	result : Try(ElementHandleResult, [Missing]),
	error : Try(ResponseError, [Missing]),
}

ElementHandleResult : {
	element : Try(ResponseRef, [Missing]),
}

# The wire shape of a failed expect call: an error response with the details
# beside it. A successful expect is a plain empty-result response, so only
# the error side needs fields.
ExpectResponseMessage : {
	id : Try(U64, [Missing]),
	error : Try(ResponseError, [Missing]),
	errorDetails : Try(ExpectErrorDetails, [Missing]),
}

ExpectErrorDetails : {
	timedOut : Try(Bool, [Missing]),
	customErrorMessage : Try(Str, [Missing]),
}

# One shape per serialized form of `errorDetails.received.value`, every field
# required so that exactly the matching form decodes (see expect_received):
# {"s"} strings and state words, {"n"} counts, {"b"} booleans,
# {"v"} null/undefined, {"a"} text lists.
ExpectReceivedStr : { errorDetails : { received : { value : { s : Str } } } }

ExpectReceivedInt : { errorDetails : { received : { value : { n : U64 } } } }

ExpectReceivedBool : { errorDetails : { received : { value : { b : Bool } } } }

ExpectReceivedNull : { errorDetails : { received : { value : { v : Str } } } }

ExpectReceivedTexts : { errorDetails : { received : { value : { a : List({ s : Str }) } } } }

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
	args : List(Str),
}

LaunchChannelMessage : {
	id : U64,
	guid : Str,
	method : Str,
	params : LaunchChannelParams,
	metadata : {},
}

LaunchChannelParams : {
	headless : Bool,
	timeout : U64,
	args : List(Str),
	channel : Str,
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
	strict : Bool,
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
	strict : Bool,
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
	strict : Bool,
}

SetInputFilesPathsMessage : {
	id : U64,
	guid : Str,
	method : Str,
	params : { selector : Str, localPaths : List(Str), timeout : U64 },
	metadata : {},
}

SetInputFilesPayloadsMessage : {
	id : U64,
	guid : Str,
	method : Str,
	params : { selector : Str, payloads : List({ name : Str, mimeType : Str, buffer : Str }), timeout : U64 },
	metadata : {},
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

# For the selector-only protocol methods that accept a strictness flag
# (isVisible, querySelector). queryCount does not, and stays on
# SelectorOnlyMessage.
StrictSelectorMessage : {
	id : U64,
	guid : Str,
	method : Str,
	params : StrictSelectorParams,
	metadata : {},
}

StrictSelectorParams : {
	selector : Str,
	strict : Bool,
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
	strict : Bool,
}

# The expect message comes in a few structurally different shapes because the
# driver's validator rejects null fields: which of expectedText,
# expressionArg, expectedNumber and expectedValue are present depends on the
# expression, so each combination is its own message type.

ExpectedTextParam : {
	string : Str,
	matchSubstring : Bool,
	normalizeWhiteSpace : Bool,
}

ExpectedRegexParam : {
	regexSource : Str,
	regexFlags : Str,
}

ExpectRegexMessage : {
	id : U64,
	guid : Str,
	method : Str,
	params : ExpectRegexParams,
	metadata : {},
}

ExpectRegexParams : {
	selector : Str,
	expression : Str,
	expectedText : List(ExpectedRegexParam),
	isNot : Bool,
	timeout : U64,
}

ExpectPageRegexMessage : {
	id : U64,
	guid : Str,
	method : Str,
	params : ExpectPageRegexParams,
	metadata : {},
}

ExpectPageRegexParams : {
	expression : Str,
	expectedText : List(ExpectedRegexParam),
	isNot : Bool,
	timeout : U64,
}

ExpectTextMessage : {
	id : U64,
	guid : Str,
	method : Str,
	params : ExpectTextParams,
	metadata : {},
}

ExpectTextParams : {
	selector : Str,
	expression : Str,
	expectedText : List(ExpectedTextParam),
	isNot : Bool,
	timeout : U64,
}

ExpectAttributeMessage : {
	id : U64,
	guid : Str,
	method : Str,
	params : ExpectAttributeParams,
	metadata : {},
}

ExpectAttributeParams : {
	selector : Str,
	expression : Str,
	expressionArg : Str,
	expectedText : List(ExpectedTextParam),
	isNot : Bool,
	timeout : U64,
}

ExpectStateMessage : {
	id : U64,
	guid : Str,
	method : Str,
	params : ExpectStateParams,
	metadata : {},
}

ExpectStateParams : {
	selector : Str,
	expression : Str,
	isNot : Bool,
	timeout : U64,
}

ExpectCheckedMessage : {
	id : U64,
	guid : Str,
	method : Str,
	params : ExpectCheckedParams,
	metadata : {},
}

ExpectCheckedParams : {
	selector : Str,
	expression : Str,
	expectedValue : ExpectCheckedValue,
	isNot : Bool,
	timeout : U64,
}

# The wire form of the serialized argument {checked: Bool}.
ExpectCheckedValue : {
	value : { o : List({ k : Str, v : { b : Bool } }) },
	handles : List({}),
}

ExpectCountMessage : {
	id : U64,
	guid : Str,
	method : Str,
	params : ExpectCountParams,
	metadata : {},
}

ExpectCountParams : {
	selector : Str,
	expression : Str,
	expectedNumber : U64,
	isNot : Bool,
	timeout : U64,
}

ExpectPageTextMessage : {
	id : U64,
	guid : Str,
	method : Str,
	params : ExpectPageTextParams,
	metadata : {},
}

ExpectPageTextParams : {
	expression : Str,
	expectedText : List(ExpectedTextParam),
	isNot : Bool,
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
	handles : List({}),
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
	permissions : List(Str),
}

KeyPressMessage : {
	id : U64,
	guid : Str,
	method : Str,
	params : KeyPressParams,
	metadata : {},
}

KeyPressParams : {
	selector : Str,
	key : Str,
	timeout : U64,
}

KeyboardKeyMessage : {
	id : U64,
	guid : Str,
	method : Str,
	params : KeyboardKeyParams,
	metadata : {},
}

KeyboardKeyParams : {
	key : Str,
}

KeyboardTypeMessage : {
	id : U64,
	guid : Str,
	method : Str,
	params : KeyboardTypeParams,
	metadata : {},
}

KeyboardTypeParams : {
	text : Str,
}

ElementSimpleMessage : {
	id : U64,
	guid : Str,
	method : Str,
	params : {},
	metadata : {},
}

CdpSessionMessage : {
	id : U64,
	guid : Str,
	method : Str,
	params : CdpSessionParams,
	metadata : {},
}

CdpSessionParams : {
	page : ResponseRef,
}

CdpScrollGestureMessage : {
	id : U64,
	guid : Str,
	method : Str,
	params : CdpScrollGestureSendParams,
	metadata : {},
}

CdpScrollGestureSendParams : {
	method : Str,
	params : CdpScrollGestureParams,
}

CdpScrollGestureParams : {
	x : F64,
	y : F64,
	yDistance : F64,
	xDistance : F64,
}

CdpSwipeGestureMessage : {
	id : U64,
	guid : Str,
	method : Str,
	params : CdpSwipeGestureSendParams,
	metadata : {},
}

CdpSwipeGestureSendParams : {
	method : Str,
	params : CdpSwipeGestureParams,
}

CdpSwipeGestureParams : {
	x : F64,
	y : F64,
	yDistance : F64,
	xDistance : F64,
	gestureSourceType : Str,
	preventFling : Bool,
}

key_to_str : Playwright.Key -> Str
key_to_str = |key| match key {
	Escape => "Escape"
	Enter => "Enter"
	Tab => "Tab"
	Backspace => "Backspace"
	Delete => "Delete"
	Insert => "Insert"
	Space => "Space"
	ArrowUp => "ArrowUp"
	ArrowDown => "ArrowDown"
	ArrowLeft => "ArrowLeft"
	ArrowRight => "ArrowRight"
	Home => "Home"
	End => "End"
	PageUp => "PageUp"
	PageDown => "PageDown"
	F1 => "F1"
	F2 => "F2"
	F3 => "F3"
	F4 => "F4"
	F5 => "F5"
	F6 => "F6"
	F7 => "F7"
	F8 => "F8"
	F9 => "F9"
	F10 => "F10"
	F11 => "F11"
	F12 => "F12"
	Shift => "Shift"
	Control => "Control"
	Alt => "Alt"
	Meta => "Meta"
	ControlOrMeta => "ControlOrMeta"
	KeyA => "KeyA"
	KeyB => "KeyB"
	KeyC => "KeyC"
	KeyD => "KeyD"
	KeyE => "KeyE"
	KeyF => "KeyF"
	KeyG => "KeyG"
	KeyH => "KeyH"
	KeyI => "KeyI"
	KeyJ => "KeyJ"
	KeyK => "KeyK"
	KeyL => "KeyL"
	KeyM => "KeyM"
	KeyN => "KeyN"
	KeyO => "KeyO"
	KeyP => "KeyP"
	KeyQ => "KeyQ"
	KeyR => "KeyR"
	KeyS => "KeyS"
	KeyT => "KeyT"
	KeyU => "KeyU"
	KeyV => "KeyV"
	KeyW => "KeyW"
	KeyX => "KeyX"
	KeyY => "KeyY"
	KeyZ => "KeyZ"
	Digit0 => "Digit0"
	Digit1 => "Digit1"
	Digit2 => "Digit2"
	Digit3 => "Digit3"
	Digit4 => "Digit4"
	Digit5 => "Digit5"
	Digit6 => "Digit6"
	Digit7 => "Digit7"
	Digit8 => "Digit8"
	Digit9 => "Digit9"
	Backquote => "Backquote"
	Minus => "Minus"
	Equal => "Equal"
	BracketLeft => "BracketLeft"
	BracketRight => "BracketRight"
	Backslash => "Backslash"
	Semicolon => "Semicolon"
	Quote => "Quote"
	Comma => "Comma"
	Period => "Period"
	Slash => "Slash"
}

modifier_to_str : Playwright.Modifier -> Str
modifier_to_str = |modifier| match modifier {
	Control => "Control"
	Shift => "Shift"
	Alt => "Alt"
	Meta => "Meta"
	ControlOrMeta => "ControlOrMeta"
}

## Build a combo string like "Control+Shift+KeyA" from modifiers and a key.
key_combo_str : Playwright.Key, List(Playwright.Modifier) -> Str
key_combo_str = |key, modifiers| {
	key_str = key_to_str(key)
	match modifiers {
		[] => key_str
		_ => Str.join_with(modifiers.map(modifier_to_str).append(key_str), "+")
	}
}

# Escape a literal for use inside a /.../ regex in a selector engine: regex
# metacharacters and the delimiting slash get a backslash, and whitespace
# control characters become their escape sequences so the selector stays one
# line. Byte-level is safe here because every escaped character is ASCII and
# UTF-8 continuation bytes never collide with ASCII.
regex_escape : Str -> Str
regex_escape = |s| {
	bytes = Str.to_utf8(s).fold([], |acc, b|
		match b {
			9 => acc.concat([92, 116])
			10 => acc.concat([92, 110])
			13 => acc.concat([92, 114])
			36 | 40 | 41 | 42 | 43 | 46 | 47 | 63 | 91 | 92 | 93 | 94 | 123 | 124 | 125 => acc.concat([92, b])
			_ => acc.append(b)
		})
	match Str.from_utf8(bytes) {
		Ok(escaped) => escaped
		# Unreachable: the input was a Str and only ASCII was inserted.
		Err(_) => s
	}
}

timeout_to_ms : Playwright.Timeout -> U64
timeout_to_ms = |t| match t {
	TimeoutMilliseconds(ms) => ms
	NoTimeout => 0
}

# The effective deadline for one assert, in the driver's terms: 0 means poll
# forever.
assert_timeout_ms = |page, t| match t {
	PageTimeout => timeout_to_ms(page.context.browser.timeout)
	TimeoutMilliseconds(ms) => ms
	NoTimeout => 0
}

wait_until_to_str : Playwright.WaitUntil -> Str
wait_until_to_str = |wait_until| match wait_until {
	Load => "load"
	DomContentLoaded => "domcontentloaded"
	NetworkIdle => "networkidle"
	Commit => "commit"
}

browser_type_to_name : Playwright.BrowserType -> Str
browser_type_to_name = |browser_type| match browser_type {
	Chromium(_) => "chromium"
	Firefox => "firefox"
	WebKit => "webkit"
}

channel_to_name : Playwright.Channel -> Str
channel_to_name = |channel| match channel {
	DefaultChannel => ""
	Full => "chromium"
	Chrome => "chrome"
	MsEdge => "msedge"
	Custom(name) => name
}

# Shared command plumbing
#
# Almost every command is "serialize a message, send it, wait for the matching
# response, map a driver error into the command's own tag". These helpers below
# hold that shape once, so the per-command functions only build their message
# and name their error tag.

# The strict-aware bodies of the selector commands. The page-level methods
# pass `Bool.False`, keeping Playwright's own page.click-style behavior where
# a multi-match selector acts on the first match. [Element] methods pass
# `Bool.True`, so a selector that matches more than one element is an error
# instead of a silent action on the first.

click_impl! = |page, selector, strict| {
	msg : SelectorMessage
	msg = { id: msg_id, guid: page.frame_guid, method: "click", params: { selector, timeout: timeout_to_ms(page.context.browser.timeout), strict }, metadata: {} }
	exec_command!(page, Str.to_utf8(Json.to_str(msg)), |m| ClickError(m))
}

fill_impl! = |page, selector, value, strict| {
	msg : FillMessage
	msg = { id: msg_id, guid: page.frame_guid, method: "fill", params: { selector, value, timeout: timeout_to_ms(page.context.browser.timeout), strict }, metadata: {} }
	exec_command!(page, Str.to_utf8(Json.to_str(msg)), |m| FillError(m))
}

hover_impl! = |page, selector, strict| {
	msg : SelectorMessage
	msg = { id: msg_id, guid: page.frame_guid, method: "hover", params: { selector, timeout: timeout_to_ms(page.context.browser.timeout), strict }, metadata: {} }
	exec_command!(page, Str.to_utf8(Json.to_str(msg)), |m| HoverError(m))
}

text_content_impl! = |page, selector, strict| {
	msg : SelectorMessage
	msg = { id: msg_id, guid: page.frame_guid, method: "textContent", params: { selector, timeout: timeout_to_ms(page.context.browser.timeout), strict }, metadata: {} }
	match exec_nullable_string_command!(page, Str.to_utf8(Json.to_str(msg)), |m| TextContentError(m))? {
		Ok(value) => Ok(value)
		Err(ValueIsNull) => Err(TextContentNotFound)
	}
}

input_value_impl! = |page, selector, strict| {
	msg : SelectorMessage
	msg = { id: msg_id, guid: page.frame_guid, method: "inputValue", params: { selector, timeout: timeout_to_ms(page.context.browser.timeout), strict }, metadata: {} }
	exec_string_command!(page, Str.to_utf8(Json.to_str(msg)), |m| InputValueError(m), InputValueNotFound)
}

get_attribute_impl! = |page, selector, attribute_name, strict| {
	msg : GetAttributeMessage
	msg = { id: msg_id, guid: page.frame_guid, method: "getAttribute", params: { selector, name: attribute_name, timeout: timeout_to_ms(page.context.browser.timeout), strict }, metadata: {} }
	match exec_nullable_string_command!(page, Str.to_utf8(Json.to_str(msg)), |m| AttributeError(m))? {
		Ok(value) => Ok(value)
		Err(ValueIsNull) => Err(AttributeNotFound)
	}
}

is_visible_impl! = |page, selector, strict| {
	msg : StrictSelectorMessage
	msg = { id: msg_id, guid: page.frame_guid, method: "isVisible", params: { selector, strict }, metadata: {} }
	read_child! = send_to_page!(page, Str.to_utf8(Json.to_str(msg)))?

	response = read_until_bool_response!(read_child!, msg_id)?

	match response.error {
		Ok(err) => Err(IsVisibleError(err.error.message))
		Err(_) =>
			match response.result {
				Ok(result) => Ok(result.value)
				Err(_) => Err(IsVisibleNoResult)
			}
		}
}

wait_for_impl! = |page, selector, state, strict| {
	state_str = match state {
		Visible => "visible"
		Hidden => "hidden"
		Attached => "attached"
		Detached => "detached"
	}

	msg : WaitForSelectorMessage
	msg = { id: msg_id, guid: page.frame_guid, method: "waitForSelector", params: { selector, timeout: timeout_to_ms(page.context.browser.timeout), state: state_str, strict }, metadata: {} }
	exec_command!(page, Str.to_utf8(Json.to_str(msg)), |m| WaitForTimeout(m))
}

set_checked_impl! = |page, selector, desired, strict| {
	desired_str = if desired "true" else "false"
	strict_str = if strict "true" else "false"
	# `Json.to_str` emits a quoted, fully escaped literal, so a selector
	# containing quotes or backslashes (`input[type="checkbox"]`, which is
	# the form most people write) survives the trip into JS source.
	selector_js = Json.to_str(selector)
	js =
		\\(() => {
		\\    const els = document.querySelectorAll(${selector_js});
		\\    if (els.length === 0) return 'ElementNotFound';
		\\    if (${strict_str} && els.length > 1) return 'strict mode violation: ' + els.length + ' elements match ' + ${selector_js};
		\\    const el = els[0];
		\\    if (el.checked === ${desired_str}) return 'ok';
		\\    el.checked = ${desired_str};
		\\    el.dispatchEvent(new Event('input', {bubbles: true}));
		\\    el.dispatchEvent(new Event('change', {bubbles: true}));
		\\    return 'ok';
		\\})()
	result = Playwright.evaluate!(page, js)?
	if result == "ok" {
		Ok({})
	} else {
		Err(CheckError(result))
	}
}

bounding_box_impl! = |page, selector, strict| {
	# Wait for element to be visible first (matches Playwright's auto-wait behavior)
	wait_for_impl!(page, selector, Visible, strict)?

	# Query for the element to get its element handle guid
	query_msg : StrictSelectorMessage
	query_msg = { id: msg_id, guid: page.frame_guid, method: "querySelector", params: { selector, strict }, metadata: {} }
	read_child! = send_to_page!(page, Str.to_utf8(Json.to_str(query_msg)))?

	element_response = read_until_element_handle_response!(read_child!, msg_id)?

	match element_response.error {
		Ok(err) => Err(BoundingBoxError(err.error.message))
		Err(_) =>
			match element_response.result {
				Ok(result) =>
					match result.element {
						Ok(element_ref) => {
							box_msg : ElementSimpleMessage
							box_msg = { id: msg_id, guid: element_ref.guid, method: "boundingBox", params: {}, metadata: {} }
							box_read! = send_to_page!(page, Str.to_utf8(Json.to_str(box_msg)))?

							box_response = read_until_bounding_box_response!(box_read!, msg_id)?

							match box_response.error {
								Ok(box_err) => Err(BoundingBoxError(box_err.error.message))
								Err(_) =>
									match box_response.result {
										Ok(box_result) =>
											match box_result.value {
												Ok(box) => Ok({ x: box.x, y: box.y, width: box.width, height: box.height })
												Err(_) => Err(ElementNotVisible)
											}
										Err(_) => Err(ElementNotVisible)
									}
								}
						}
						Err(_) => Err(ElementNotFound)
					}
				Err(_) => Err(ElementNotFound)
			}
		}
}

# The expect-based assertion bodies. Each is one `expect` call on the frame,
# the same protocol method every official Playwright client's assertions go
# through: the driver re-checks the page until the expectation holds or the
# timeout expires, and enforces strictness for single-element expressions.
#
# The response carries no result beyond success. A failure is an error
# response with the details in `errorDetails` beside it: the last received
# value, whether the timeout expired, and a message of its own for usage
# errors like strict mode violations. exec_expect! turns a timed-out check
# into AssertionFailed with a message the caller builds from the received
# value, and everything else into ExpectError with the driver's message.

expect_text_impl! = |page, t, selector, expression, want, match_substring, is_not, to_msg| {
	timeout_ms = assert_timeout_ms(page, t)
	msg : ExpectTextMessage
	msg = { id: msg_id, guid: page.frame_guid, method: "expect", params: { selector, expression, expectedText: [{ string: want, matchSubstring: match_substring, normalizeWhiteSpace: Bool.True }], isNot: is_not, timeout: timeout_ms }, metadata: {} }
	exec_expect!(page, timeout_ms, Str.to_utf8(Json.to_str(msg)), to_msg)
}

expect_value_impl! = |page, t, selector, want, is_not, to_msg| {
	timeout_ms = assert_timeout_ms(page, t)
	msg : ExpectTextMessage
	msg = { id: msg_id, guid: page.frame_guid, method: "expect", params: { selector, expression: "to.have.value", expectedText: [{ string: want, matchSubstring: Bool.False, normalizeWhiteSpace: Bool.False }], isNot: is_not, timeout: timeout_ms }, metadata: {} }
	exec_expect!(page, timeout_ms, Str.to_utf8(Json.to_str(msg)), to_msg)
}

expect_texts_impl! = |page, t, selector, wants, to_msg| {
	timeout_ms = assert_timeout_ms(page, t)
	expected = List.map(wants, |w| { string: w, matchSubstring: Bool.False, normalizeWhiteSpace: Bool.True })
	msg : ExpectTextMessage
	msg = { id: msg_id, guid: page.frame_guid, method: "expect", params: { selector, expression: "to.have.text.array", expectedText: expected, isNot: Bool.False, timeout: timeout_ms }, metadata: {} }
	exec_expect!(page, timeout_ms, Str.to_utf8(Json.to_str(msg)), to_msg)
}

expect_attribute_impl! = |page, t, selector, attribute_name, want, is_not, to_msg| {
	timeout_ms = assert_timeout_ms(page, t)
	msg : ExpectAttributeMessage
	msg = { id: msg_id, guid: page.frame_guid, method: "expect", params: { selector, expression: "to.have.attribute.value", expressionArg: attribute_name, expectedText: [{ string: want, matchSubstring: Bool.False, normalizeWhiteSpace: Bool.False }], isNot: is_not, timeout: timeout_ms }, metadata: {} }
	exec_expect!(page, timeout_ms, Str.to_utf8(Json.to_str(msg)), to_msg)
}

expect_state_impl! = |page, t, selector, expression, is_not, to_msg| {
	timeout_ms = assert_timeout_ms(page, t)
	msg : ExpectStateMessage
	msg = { id: msg_id, guid: page.frame_guid, method: "expect", params: { selector, expression, isNot: is_not, timeout: timeout_ms }, metadata: {} }
	exec_expect!(page, timeout_ms, Str.to_utf8(Json.to_str(msg)), to_msg)
}

expect_checked_impl! = |page, t, selector, desired, to_msg| {
	timeout_ms = assert_timeout_ms(page, t)
	# to.be.checked reads its target state from expectedValue, which travels
	# as a protocol-serialized {checked: Bool} object.
	msg : ExpectCheckedMessage
	msg = { id: msg_id, guid: page.frame_guid, method: "expect", params: { selector, expression: "to.be.checked", expectedValue: { value: { o: [{ k: "checked", v: { b: desired } }] }, handles: [] }, isNot: Bool.False, timeout: timeout_ms }, metadata: {} }
	exec_expect!(page, timeout_ms, Str.to_utf8(Json.to_str(msg)), to_msg)
}

expect_count_impl! = |page, t, selector, want, is_not, to_msg| {
	timeout_ms = assert_timeout_ms(page, t)
	msg : ExpectCountMessage
	msg = { id: msg_id, guid: page.frame_guid, method: "expect", params: { selector, expression: "to.have.count", expectedNumber: want, isNot: is_not, timeout: timeout_ms }, metadata: {} }
	exec_expect!(page, timeout_ms, Str.to_utf8(Json.to_str(msg)), to_msg)
}

expect_regex_impl! = |page, t, selector, expression, regex_source, is_not, to_msg| {
	timeout_ms = assert_timeout_ms(page, t)
	msg : ExpectRegexMessage
	msg = { id: msg_id, guid: page.frame_guid, method: "expect", params: { selector, expression, expectedText: [{ regexSource: regex_source, regexFlags: "" }], isNot: is_not, timeout: timeout_ms }, metadata: {} }
	exec_expect!(page, timeout_ms, Str.to_utf8(Json.to_str(msg)), to_msg)
}

expect_page_regex_impl! = |page, t, expression, regex_source, is_not, to_msg| {
	timeout_ms = assert_timeout_ms(page, t)
	msg : ExpectPageRegexMessage
	msg = { id: msg_id, guid: page.frame_guid, method: "expect", params: { expression, expectedText: [{ regexSource: regex_source, regexFlags: "" }], isNot: is_not, timeout: timeout_ms }, metadata: {} }
	exec_expect!(page, timeout_ms, Str.to_utf8(Json.to_str(msg)), to_msg)
}

expect_page_text_impl! = |page, t, expression, want, match_substring, normalize, is_not, to_msg| {
	timeout_ms = assert_timeout_ms(page, t)
	# Title and URL are claims about the page, so the message carries no
	# selector: the driver reads document.title / location.href directly.
	msg : ExpectPageTextMessage
	msg = { id: msg_id, guid: page.frame_guid, method: "expect", params: { expression, expectedText: [{ string: want, matchSubstring: match_substring, normalizeWhiteSpace: normalize }], isNot: is_not, timeout: timeout_ms }, metadata: {} }
	exec_expect!(page, timeout_ms, Str.to_utf8(Json.to_str(msg)), to_msg)
}

exec_expect! = |page, timeout_ms, message_bytes, to_msg| {
	browser = page.context.browser
	write_child! = browser.write_stdin!
	read_child! = browser.read_stdout!
	send_message!(write_child!, message_bytes)?
	bytes = read_until_id!(read_child!, msg_id, |b| Ok(b))?

	match decode_expect_response(bytes) {
		Err(_) => Err(UnexpectedExpectResponse(raw_message(bytes)))
		Ok(response) =>
			match response.error {
				Err(_) => Ok({})
				Ok(err) => {
					details =
						match response.errorDetails {
							Ok(d) => d
							Err(_) => { timedOut: Err(Missing), customErrorMessage: Err(Missing) }
						}
					timed_out = details.timedOut.ok_or(Bool.False)
					if timed_out {
						Err(AssertionFailed("${to_msg(expect_received(bytes))} (timed out after ${timeout_ms.to_str()}ms)"))
					} else {
						match details.customErrorMessage {
							Ok(m) => Err(ExpectError(m))
							Err(_) => Err(ExpectError(err.error.message))
						}
					}
				}
			}
	}
}

## The last value the driver saw before giving up, extracted for the failure
## message. Each serialized shape gets its own fully-required decode of the
## raw response, tried in turn like decode_nullable_string_value: one deep
## record full of optional fields sends the JSON decoder's specialization
## into a blowup, and routing by what decodes is the established pattern here
## anyway. `Received` carries strings and state words raw and lists
## pre-rendered, so each assertion picks the quoting that reads best.
## `NullReceived` is a null the driver actually read (a missing attribute),
## `NoElement` is nothing matching the selector.
expect_received = |bytes|
	match decode_expect_received_str(bytes) {
		Ok(m) => Received(m.errorDetails.received.value.s)
		Err(_) =>
			match decode_expect_received_int(bytes) {
				Ok(m) => Received(m.errorDetails.received.value.n.to_str())
				Err(_) =>
					match decode_expect_received_bool(bytes) {
						Ok(m) => Received(if m.errorDetails.received.value.b "true" else "false")
						Err(_) =>
							match decode_expect_received_texts(bytes) {
								Ok(m) => {
									rendered = List.map(m.errorDetails.received.value.a, |item| "\"${item.s}\"")
									Received("[${Str.join_with(rendered, ", ")}]")
								}
								Err(_) =>
									match decode_expect_received_null(bytes) {
										Ok(m) => if m.errorDetails.received.value.v == "null" NullReceived else NoElement
										Err(_) => NoElement
									}
							}
					}
			}
	}

## Send a command message and wait for its response. The shared tail of every
## command that returns nothing: a driver error goes through `to_err`.
exec_command! = |page, message_bytes, to_err| {
	browser = page.context.browser
	write_child! = browser.write_stdin!
	read_child! = browser.read_stdout!
	send_message!(write_child!, message_bytes)?
	response = read_until_response!(read_child!, msg_id)?

	match response.error {
		Ok(err) => Err(to_err(err.error.message))
		Err(_) => Ok({})
	}
}

## Send a command message whose response carries a plain string value.
## A driver error goes through `to_err`, an absent value becomes `missing`.
exec_string_command! = |page, message_bytes, to_err, missing| {
	browser = page.context.browser
	write_child! = browser.write_stdin!
	read_child! = browser.read_stdout!
	send_message!(write_child!, message_bytes)?
	response = read_until_plain_string_response!(read_child!, msg_id)?

	match response.error {
		Ok(err) => Err(to_err(err.error.message))
		Err(_) =>
			match response.result {
				Ok(result) =>
					match result.value {
						Ok(value) => Ok(value)
						Err(_) => Err(missing)
					}
				Err(_) => Err(missing)
			}
		}
}

## Send a command message whose response carries a nullable string value.
## A driver error goes through `to_err`. Returns `Ok(Ok(value))` or
## `Ok(Err(ValueIsNull))` for the caller to map.
exec_nullable_string_command! = |page, message_bytes, to_err| {
	browser = page.context.browser
	write_child! = browser.write_stdin!
	read_child! = browser.read_stdout!
	send_message!(write_child!, message_bytes)?
	read_until_nullable_string_response!(read_child!, msg_id, to_err)
}

## Send a message through the page's browser and hand back the reader, for
## commands that consume the response with their own decoder.
send_to_page! = |page, message_bytes| {
	browser = page.context.browser
	write_child! = browser.write_stdin!
	send_message!(write_child!, message_bytes)?
	Ok(browser.read_stdout!)
}

# Message ID used for all commands.
#
# The Playwright protocol uses message IDs to match responses to requests,
# designed for async/parallel usage where multiple commands are in flight.
#
# We use a constant ID because our usage is fully synchronous:
# - We send one command and wait for its response before sending the next
# - We use `read_until_response!` which blocks until the matching response arrives
# - Message order is guaranteed
# - Event messages (which we skip) don't have matching IDs
#
# This simplifies the API by not requiring callers to thread Browser state.
# If async/parallel commands are needed in the future, this would need to change
# to use unique incrementing IDs per command.
msg_id : U64
msg_id = 1000

encode_u32_le : U32 -> List(U8)
encode_u32_le = |n| [
	n.bitwise_and(0xFF).to_u8_wrap(),
	n.shr_zf_wrap(8).bitwise_and(0xFF).to_u8_wrap(),
	n.shr_zf_wrap(16).bitwise_and(0xFF).to_u8_wrap(),
	n.shr_zf_wrap(24).bitwise_and(0xFF).to_u8_wrap(),
]

decode_u32_le : List(U8) -> U32
decode_u32_le = |bytes| {
	b0 = bytes.get(0).ok_or(0).to_u32()
	b1 = bytes.get(1).ok_or(0).to_u32()
	b2 = bytes.get(2).ok_or(0).to_u32()
	b3 = bytes.get(3).ok_or(0).to_u32()
	b0.bitwise_or(b1.shl_wrap(8)).bitwise_or(b2.shl_wrap(16)).bitwise_or(b3.shl_wrap(24))
}

## Send a length-prefixed message to the driver.
send_message! = |write_child!, message_bytes| {
	# The length prefix is 32 bits, so a message over 4 GiB cannot be framed.
	# Wrapping would corrupt the stream, so crash loudly instead. This is probably
	# only reachable through enormous file-upload payloads?
	if message_bytes.len() > 4294967295 {
		crash "roc-playwright: message exceeds the 4 GiB limit of the wire format"
	} else {
		length_bytes = encode_u32_le(message_bytes.len().to_u32_wrap())
		write_child!(length_bytes)?
		write_child!(message_bytes)
	}
}

## Receive one length-prefixed message from the driver.
##
## Note: crashes if the read does not return the expected number of bytes, since
## the platform contract has then been broken. We rather crash than have undefined
## behaviour in that case.
receive_message_bytes! = |read_child!| {
	# Read 4-byte length prefix. An empty read is EOF: the driver process died
	# or closed its stdout. A partial read means the platform broke the
	# exactly-n-bytes contract.
	length_bytes = read_child!(4)?
	if length_bytes.len() == 0 {
		crash "roc-playwright: the driver closed its stdout, the Playwright process has probably died"
	} else if length_bytes.len() != 4 {
		crash "roc-playwright: read_stdout! returned fewer bytes than requested, message framing is broken"
	} else {
		length = decode_u32_le(length_bytes).to_u64()

		body = read_child!(length)?
		if body.len() != length {
			crash "roc-playwright: read_stdout! returned fewer bytes than requested, message framing is broken"
		} else {
			Ok(body)
		}
	}
}

decode_create_message : List(U8) -> Try(CreateMessage, [DecodeError])
decode_create_message = |bytes| decode_json(bytes)

decode_response_message : List(U8) -> Try(ResponseMessage, [DecodeError])
decode_response_message = |bytes| decode_json(bytes)

decode_bool_response : List(U8) -> Try(BoolResponseMessage, [DecodeError])
decode_bool_response = |bytes| decode_json(bytes)

decode_int_response : List(U8) -> Try(IntResponseMessage, [DecodeError])
decode_int_response = |bytes| decode_json(bytes)

decode_plain_string_response : List(U8) -> Try(PlainStringResponseMessage, [DecodeError])
decode_plain_string_response = |bytes| decode_json(bytes)

decode_null_value_response : List(U8) -> Try(NullValueResponseMessage, [DecodeError])
decode_null_value_response = |bytes| decode_json(bytes)

decode_id_check : List(U8) -> Try(IdCheckMessage, [DecodeError])
decode_id_check = |bytes| decode_json(bytes)

decode_browser_type_create : List(U8) -> Try(BrowserTypeCreateMessage, [DecodeError])
decode_browser_type_create = |bytes| decode_json(bytes)

decode_bounding_box_response : List(U8) -> Try(BoundingBoxResponseMessage, [DecodeError])
decode_bounding_box_response = |bytes| decode_json(bytes)

decode_element_handle_response : List(U8) -> Try(ElementHandleResponseMessage, [DecodeError])
decode_element_handle_response = |bytes| decode_json(bytes)

decode_expect_response : List(U8) -> Try(ExpectResponseMessage, [DecodeError])
decode_expect_response = |bytes| decode_json(bytes)

decode_expect_received_str : List(U8) -> Try(ExpectReceivedStr, [DecodeError])
decode_expect_received_str = |bytes| decode_json(bytes)

decode_expect_received_int : List(U8) -> Try(ExpectReceivedInt, [DecodeError])
decode_expect_received_int = |bytes| decode_json(bytes)

decode_expect_received_bool : List(U8) -> Try(ExpectReceivedBool, [DecodeError])
decode_expect_received_bool = |bytes| decode_json(bytes)

decode_expect_received_null : List(U8) -> Try(ExpectReceivedNull, [DecodeError])
decode_expect_received_null = |bytes| decode_json(bytes)

decode_expect_received_texts : List(U8) -> Try(ExpectReceivedTexts, [DecodeError])
decode_expect_received_texts = |bytes| decode_json(bytes)

decode_json = |bytes|
	match Str.from_utf8(bytes) {
		Ok(s) => Json.parse(s).map_err(|_| DecodeError)
		Err(_) => Err(DecodeError)
	}

initialize_browser! = |write_child!, read_child!, kill!, browser_type, headless, timeout, args| {
	# Send initial message to initialize the connection
	init_msg : InitializeMessage
	init_msg = { id: 1, guid: "", method: "initialize", params: { sdkLanguage: "javascript" }, metadata: {} }
	send_message!(write_child!, Str.to_utf8(Json.to_str(init_msg)))?

	# Read initialization responses until we get the id:1 response
	browser_type_name = browser_type_to_name(browser_type)
	browser_type_guid = read_init_and_find_browser_type!(read_child!, browser_type_name)?

	# Now launch the browser.
	# Always use 30s for browser launch (matching Playwright's default).
	# The user-provided timeout is for action/navigation operations only.
	# The driver's protocol validator rejects `channel: null`, so an unset
	# channel must be a structurally different message, not a null field.
	launch_bytes =
		match browser_type {
			Chromium(DefaultChannel) | Firefox | WebKit => {
				launch_msg : LaunchMessage
				launch_msg = { id: 2, guid: browser_type_guid, method: "launch", params: { headless, timeout: 30000, args }, metadata: {} }
				Str.to_utf8(Json.to_str(launch_msg))
			}

			Chromium(channel) => {
				launch_channel_msg : LaunchChannelMessage
				launch_channel_msg = { id: 2, guid: browser_type_guid, method: "launch", params: { headless, timeout: 30000, args, channel: channel_to_name(channel) }, metadata: {} }
				Str.to_utf8(Json.to_str(launch_channel_msg))
			}
		}
	send_message!(write_child!, launch_bytes)?

	# Read browser creation response
	browser_guid = read_until_browser_guid!(read_child!)?

	# Read the launch response (id:2)
	_launch_response = read_until_response!(read_child!, 2)?

	# The child-bound closures are punned into the Browser record by name.
	Ok(Playwright.Browser.{
		write_stdin!: write_child!,
		read_stdout!: read_child!,
		kill!,
		browser_guid,
		timeout,
	})
}

read_init_and_find_browser_type! = |read_child!, browser_type_name|
	read_init_loop!(read_child!, browser_type_name, "")

read_init_loop! = |read_child!, browser_type_name, found_guid| {
	bytes = receive_message_bytes!(read_child!)?

	# Check if this is the final id:1 response
	match decode_id_check(bytes) {
		Ok(id_msg) =>
			match id_msg.id {
				Ok(1) =>
				# We're done - return the browser type GUID we found
					if Str.is_empty(found_guid) {
						Err(BrowserTypeNotFound(browser_type_name))
					} else {
						Ok(found_guid)
					}

				_ => {
					# Not the id:1 response, check if it's a BrowserType create message
					new_guid = extract_browser_type_guid(bytes, browser_type_name, found_guid)
					read_init_loop!(read_child!, browser_type_name, new_guid)
				}
			}

		Err(_) => {
			# Couldn't decode id, check if it's a BrowserType create message
			new_guid = extract_browser_type_guid(bytes, browser_type_name, found_guid)
			read_init_loop!(read_child!, browser_type_name, new_guid)
		}
	}
}

extract_browser_type_guid : List(U8), Str, Str -> Str
extract_browser_type_guid = |bytes, browser_type_name, default|
	match decode_browser_type_create(bytes) {
		Ok(msg) => {
			is_create = msg.method == Ok("__create__")
			match msg.params {
				Ok(params) => {
					is_browser_type = params.type == Ok("BrowserType")
					name_matches =
						match params.initializer {
							Ok(init) => init.name == Ok(browser_type_name)
							Err(_) => Bool.False
						}

					if is_create and is_browser_type and name_matches {
						match params.guid {
							Ok(guid) => guid
							Err(_) => default
						}
					} else {
						default
					}
				}

				Err(_) => default
			}
		}

		Err(_) => default
	}

read_until_browser_guid! = |read_child!| {
	bytes = receive_message_bytes!(read_child!)?

	# The launch response (id:2) arriving before a Browser __create__ event
	# means the launch failed (e.g. timeout expired). Carry the driver's own
	# error message when it sent one.
	is_launch_response = match decode_id_check(bytes) {
		Ok(id_msg) => id_msg.id == Ok(2)
		Err(_) => Bool.False
	}
	if is_launch_response {
		message = match decode_response_message(bytes) {
			Ok(response) =>
				match response.error {
					Ok(err) => err.error.message
					Err(_) => "the driver reported no error message"
				}
			Err(_) => "the driver reported no error message"
		}
		Err(BrowserLaunchFailed(message))
	} else {
		match decode_create_message(bytes) {
			Ok(msg) =>
				if msg.params.type == "Browser" {
					Ok(msg.params.guid)
				} else {
					read_until_browser_guid!(read_child!)
				}

			Err(_) => read_until_browser_guid!(read_child!)
		}
	}
}

## Skip messages until a `__create__` event for `wanted_type` arrives, then
## return its guid.
read_until_create_guid! = |read_child!, wanted_type| {
	bytes = receive_message_bytes!(read_child!)?

	match decode_create_message(bytes) {
		Ok(msg) =>
			if msg.params.type == wanted_type {
				Ok(msg.params.guid)
			} else {
				read_until_create_guid!(read_child!, wanted_type)
			}

		Err(_) => read_until_create_guid!(read_child!, wanted_type)
	}
}

read_until_page_and_frame! = |read_child!|
	read_page_frame_loop!(read_child!, "", "")

read_page_frame_loop! = |read_child!, found_page, found_frame| {
	# If we have both, we're done
	if Str.is_empty(found_page) or Str.is_empty(found_frame) {
		bytes = receive_message_bytes!(read_child!)?

		match decode_create_message(bytes) {
			Ok(msg) => {
				new_page =
					if msg.params.type == "Page" {
						msg.params.guid
					} else {
						found_page
					}

				new_frame =
					if msg.params.type == "Frame" {
						msg.params.guid
					} else {
						found_frame
					}

				read_page_frame_loop!(read_child!, new_page, new_frame)
			}

			# Not a create message, keep reading
			Err(_) => read_page_frame_loop!(read_child!, found_page, found_frame)
		}
	} else {
		Ok({ page_guid: found_page, frame_guid: found_frame })
	}
}

## Read messages until one carries the expected id, then hand its bytes to
## `handle`. Everything else on the stream (events, responses to other ids,
## anything without an id field) is skipped.
read_until_id! = |read_child!, expected_id, handle| {
	bytes = receive_message_bytes!(read_child!)?
	has_expected_id = match decode_id_check(bytes) {
		Ok(id_msg) => id_msg.id == Ok(expected_id)
		Err(_) => Bool.False
	}
	if has_expected_id {
		handle(bytes)
	} else {
		read_until_id!(read_child!, expected_id, handle)
	}
}

## Stand-in for a matching response whose body did not decode, which happens
## for commands like goto to data: URLs where the result is `{}`.
empty_response : U64 -> ResponseMessage
empty_response = |id| {
	id: Ok(id),
	guid: Err(Missing),
	method: Err(Missing),
	result: Err(Missing),
	error: Err(Missing),
}

## The raw message text, for embedding in decode-failure errors.
raw_message : List(U8) -> Str
raw_message = |bytes| Str.from_utf8(bytes).ok_or("<invalid utf8>")

read_until_response! = |read_child!, expected_id|
	read_until_id!(read_child!, expected_id, |bytes|
		match decode_response_message(bytes) {
			Ok(msg) => Ok(msg)
			Err(_) => Ok(empty_response(expected_id))
		})

## Bool responses always carry a value, so a decode failure is a bug and
## surfaces as UnexpectedBoolResponse with the raw message.
read_until_bool_response! = |read_child!, expected_id|
	read_until_id!(read_child!, expected_id, |bytes|
		decode_bool_response(bytes).map_err(|_| UnexpectedBoolResponse(raw_message(bytes))))

## Int responses always carry a value, so a decode failure is a bug and
## surfaces as UnexpectedIntResponse with the raw message.
read_until_int_response! = |read_child!, expected_id|
	read_until_id!(read_child!, expected_id, |bytes|
		decode_int_response(bytes).map_err(|_| UnexpectedIntResponse(raw_message(bytes))))

read_until_plain_string_response! = |read_child!, expected_id|
	read_until_id!(read_child!, expected_id, |bytes|
		decode_plain_string_response(bytes).map_err(|_| UnexpectedStringResponse(raw_message(bytes))))

read_until_nullable_string_response! = |read_child!, expected_id, to_err|
	read_until_id!(read_child!, expected_id, |bytes| decode_nullable_string_value(bytes, to_err))

## Decode a nullable-string command response by trying each wire shape's
## decoder in turn, most specific first. Routing must go by what actually
## decodes, not by sniffing the raw bytes for substrings like `"s":` - a
## plain-string value whose *content* contains them (JSON in a text node or
## attribute) would be misrouted. The parser fails the whole message on a
## field-shape mismatch, so each shape only decodes under its own decoder.
##
##   {"error": ...}                      driver error   -> Err(to_err(message))
##   {"result": {"value": {"s": ...}}}   serialized     -> Ok(Ok(s))
##   {"result": {"value": "..."}}        plain string   -> Ok(Ok(value))
##   {"result": {"value": {"v": ...}}}   null/undefined -> Ok(Err(ValueIsNull))
##   {"result": {}} or no result         absent value   -> Ok(Err(ValueIsNull))
decode_nullable_string_value = |bytes, to_err|
	match decode_response_message(bytes) {
		Ok(response) =>
			match response.error {
				Ok(err) => Err(to_err(err.error.message))
				Err(_) =>
					match response.result {
						Ok(result) =>
							match result.value {
								Ok(serialized) => Ok(Ok(serialized.s))
								Err(_) => Ok(Err(ValueIsNull))
							}
						Err(_) => Ok(Err(ValueIsNull))
					}
				}

		Err(_) =>
			match decode_plain_string_response(bytes) {
				Ok(response) =>
					match response.error {
						Ok(err) => Err(to_err(err.error.message))
						Err(_) =>
							match response.result {
								Ok(result) =>
									match result.value {
										Ok(value) => Ok(Ok(value))
										Err(_) => Ok(Err(ValueIsNull))
									}
								Err(_) => Ok(Err(ValueIsNull))
							}
						}

				Err(_) =>
					match decode_null_value_response(bytes) {
						Ok(_) => Ok(Err(ValueIsNull))
						Err(_) => Err(DecodeError)
					}
			}
	}

## Wait for the querySelector response. Routing goes by what decodes, never by
## sniffing the raw bytes (see decode_nullable_string_value): every field of
## ElementHandleResponseMessage is optional, so a found element, a no-match
## `{"result": {}}` and a driver error all decode, with the absent parts
## coming back Missing. Only an undecodable response maps to "no element".
read_until_element_handle_response! = |read_child!, expected_id|
	read_until_id!(read_child!, expected_id, |bytes|
		match decode_element_handle_response(bytes) {
			Ok(msg) => Ok(msg)
			Err(_) => Ok(no_element_response(expected_id))
		})

no_element_response : U64 -> ElementHandleResponseMessage
no_element_response = |id| {
	id: Ok(id),
	result: Ok({ element: Err(Missing) }),
	error: Err(Missing),
}

## Wait for the boundingBox response, routed by decoding like
## read_until_element_handle_response!. A response whose value is absent or
## not a box (`{"result": {}}`, or a null value, which fails the decode) maps
## to a Missing value, which the caller reports as ElementNotVisible.
read_until_bounding_box_response! = |read_child!, expected_id|
	read_until_id!(read_child!, expected_id, |bytes|
		match decode_bounding_box_response(bytes) {
			Ok(msg) => Ok(msg)
			Err(_) => Ok(no_bounding_box_response(expected_id))
		})

no_bounding_box_response : U64 -> BoundingBoxResponseMessage
no_bounding_box_response = |id| {
	id: Ok(id),
	result: Ok({ value: Err(Missing) }),
	error: Err(Missing),
}
