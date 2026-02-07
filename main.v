module main

import time
import os
import sdl
import sdl.ttf
import db.sqlite

const width = 800
const height = 60
const application_extra_height = 80
const currency_exchange_extra_height = 80
const calculator_extra_height = 80
const padding = 4
const font_size = 20

const font_bytes = $embed_file('assets/NotoSans.ttf')

fn main() {
	if sdl.init(sdl.init_video) != 0 {
		panic('Failed to initialize SDL: ${sdl.get_error()}')
	}
	if ttf.init() != 0 {
		panic('Failed to initialize TTF')
	}

	config := $if prod { os.join_path(os.config_dir()!, 'spotv') } $else { '.' }
	os.mkdir_all(config) or {
		panic('Failed to create config directory at path: ${config}, error: ${err}')
	}

	db := create_database(os.join_path(config, 'spotv.sqlite')) or {
		panic('Failed to create or open database: ${err}')
	}

	window := sdl.create_window(c'spot.v', int(sdl.windowpos_centered_display(300)), int(sdl.windowpos_centered_display(300)),
		width, height, u32(sdl.WindowFlags.borderless))
	if window == 0 {
		panic('Failed to create SDL window: ${unsafe { cstring_to_vstring(sdl.get_error()) }}')
	}
	renderer := sdl.create_renderer(window, -1, u32(sdl.RendererFlags.accelerated) | u32(sdl.RendererFlags.presentvsync))
	if renderer == 0 {
		panic('Failed to create SDL renderer: ${unsafe { cstring_to_vstring(sdl.get_error()) }}')
	}

	font_buf := font_bytes.to_bytes()
	font_sdl_buf := sdl.rw_from_const_mem(font_buf.data, font_buf.len)

	font := ttf.open_font_rw(font_sdl_buf, 0, font_size)
	if font == 0 {
		panic('Failed to load font: ${unsafe { cstring_to_vstring(sdl.get_error()) }}')
	}

	sdl.set_window_size(window, 1, 1)

	mut app := &App{
		window:       window
		renderer:     renderer
		font:         font
		db:           db
		search_input: &Input{}

		is_initial_render: true
	}

	println('starting')
	event_tap := register_callback(app) or {
		eprintln('Failed to register event callback')
		eprintln('Failed to create event tap. Make sure the app has Accessibility permissions.')
		eprintln('Go to System Preferences -> Security & Privacy -> Privacy -> Accessibility and add this app.')
		exit(1)
	}

	C.setupWindow()
	C.loseFocus()

	spawn run_event_loop(event_tap)

	app.index()
	app.run()
	app.cleanup()
}

struct App {
	window   &sdl.Window
	renderer &sdl.Renderer
	font     &ttf.Font
	db       sqlite.DB
mut:
	was_hotkey_pressed bool
	should_hide        bool
	should_quit        bool
	is_hiding          bool
	is_initial_render  bool
	frames             int

	search_input &Input

	mod                        SearchModule
	cached_application         ?IndexedApplication
	cached_application_icon    ?CachedApplicationIcon
	cached_exchange_rate_query ?CurrencyExchangeRateQuery
	cached_command             ?Command
	cached_calculator_result   ?string

	history_timestamp ?time.Time
	history_temp_save ?string
}

fn (mut a App) run() {
	target_fps_while_inactive := u32(5)
	target_ms_per_frame_inactive := u32(1000) / target_fps_while_inactive
	mut last_time := sdl.get_ticks64()

	for {
		evt := sdl.Event{}
		for 0 < sdl.poll_event(&evt) {
			match evt.@type {
				.keydown {
					key_event := evt.key
					println('Key down: ${key_event.keysym.sym}')
					keycode := unsafe { sdl.KeyCode(key_event.keysym.sym) }
					keymod := key_event.keysym.mod
					is_shift := (keymod & int(sdl.Keymod.shift)) != 0
					is_ctrl := (keymod & int(sdl.Keymod.ctrl)) != 0
					is_opt := (keymod & int(sdl.Keymod.alt)) != 0
					is_cmd := (keymod & int(sdl.Keymod.gui)) != 0
					mut mod := MoveModifier.zero()
					if is_shift {
						mod.set(.shift)
					}
					if is_ctrl {
						mod.set(.ctrl)
					}
					if is_opt {
						mod.set(.opt)
					}
					if is_cmd {
						mod.set(.cmd)
					}

					match keycode {
						.escape {
							a.should_hide = true
							a.reset()
						}
						.up {
							a.history_load_older()
						}
						.down {
							a.history_load_newer()
						}
						.left, .right {
							dir := if keycode == .left {
								MoveDirection.left
							} else {
								MoveDirection.right
							}

							a.search_input.map_input(dir, mod)
						}
						.backspace {
							a.search_input.backspace(mod)
							a.history_timestamp = none
							a.evaluate()
						}
						.a {
							if is_cmd {
								a.search_input.select_all()
							}
						}
						.x {
							if is_cmd && a.search_input.has_selection() {
								selected := a.search_input.get_selected_text()
								copy_to_clipboard(selected)
								a.search_input.delete_selection()
								a.history_timestamp = none
								a.evaluate()
							}
						}
						.c {
							if is_cmd && a.search_input.has_selection() {
								selected := a.search_input.get_selected_text()
								copy_to_clipboard(selected)
							}
						}
						.v {
							if is_cmd {
								if clipboard_text := get_text_from_clipboard() {
									a.search_input.insert_text(clipboard_text)
									a.history_timestamp = none
									a.evaluate()
								}
							}
						}
						.@return {
							match a.mod {
								.none {
									continue
								}
								.application {
									a.launch_application()
									a.should_hide = true
								}
								.currency_exchange {
									a.copy_exchange_rate_to_clipboard()
									a.should_hide = true
								}
								.command {
									a.launch_command()
									a.reset()
								}
								.calculator {
									a.copy_calculator_result_to_clipboard()
									a.should_hide = true
								}
							}
							if a.mod != .none {
								a.save_history_entry(a.search_input.value)
								a.reset()
							}
						}
						else {}
					}
				}
				.windowevent {
					println('Window event: ${evt.window.event}')
					match unsafe { sdl.WindowEventID(evt.window.event) } {
						.focus_lost, .close {
							a.should_hide = true
						}
						else {}
					}
				}
				.textinput {
					text_event := evt.text
					a.search_input.insert_text(unsafe { cstring_to_vstring(&text_event.text[0]) })
					a.history_timestamp = none
					a.evaluate()
				}
				.quit {
					a.should_quit = true
				}
				.mousemotion, .mousewheel, .mousebuttondown, .mousebuttonup {}
				else {
					println('Other event: ${evt.@type}')
				}
			}
		}

		if a.should_quit {
			break
		}

		now := sdl.get_ticks64()

		if a.should_hide {
			a.hide()
		} else if a.was_hotkey_pressed {
			a.was_hotkey_pressed = false
			if a.is_hiding {
				a.show()
			} else {
				a.hide()
			}
		}

		if !a.is_hiding && !a.is_initial_render {
			mut real_height := height
			match a.mod {
				.none {}
				.application {
					real_height += application_extra_height
				}
				.currency_exchange {
					real_height += currency_exchange_extra_height
				}
				.command {}
				.calculator {
					real_height += calculator_extra_height
				}
			}

			sdl.set_window_size(a.window, width, real_height)
			a.set_draw_color(background_100_color)
			sdl.render_clear(a.renderer)

			h_offset := height / 2
			a.draw_centered_text(3 * padding, h_offset, '>', neutral_content_color, background_100_color)
			if a.search_input.value.len == 0 {
				a.draw_centered_text(8 * padding, h_offset, 'Search for apps, currency exchange and to use a calculator',
					muted_text_color, background_100_color)
			} else {
				a.draw_centered_text(8 * padding, h_offset, a.search_input.value, text_color,
					background_100_color)

				if a.search_input.has_selection() {
					// draw selection background
					start := a.search_input.selected_start or { 0 }
					end := a.search_input.selected_end or { 0 }
					w1, _ := a.size_text(a.search_input.value[..start])
					selection_x := 8 * padding + w1

					a.draw_centered_text(selection_x, h_offset, a.search_input.value[start..end],
						accent_content_color, accent_color)
				}
			}

			if now % 1000 < 500 {
				// draw cursor
				w, _ := a.size_text(a.search_input.value[..a.search_input.cursor_pos])
				cursor_x := 8 * padding + w
				a.draw_centered_text(cursor_x, h_offset, '_', text_color, sdl.Color{255, 255, 255, 0})
			}

			match a.mod {
				.none {}
				.application {
					a.render_application_results()
				}
				.currency_exchange {
					a.render_currency_exchange_results()
				}
				.command {}
				.calculator {
					a.render_calculator_results()
				}
			}

			sdl.render_present(a.renderer)
		}

		now2 := sdl.get_ticks64()
		delta_time := now2 - last_time
		// println('frame! ${f32(1000) / f32(delta_time)} fps (${delta_time} ms) took: ${now2 - now} ms')
		last_time = now2
		if a.is_hiding && delta_time < target_ms_per_frame_inactive {
			sdl.delay(target_ms_per_frame_inactive - u32(delta_time))
		}

		a.frames++
	}
}

fn (mut a App) show() {
	if !a.is_hiding {
		return
	}

	println('Showing window')
	sdl.show_window(a.window)
	C.focusWindow()
	a.is_hiding = false
	a.search_input.select_all()

	a.evaluate()
}

fn (mut a App) hide() {
	a.should_hide = false
	if a.is_hiding {
		return
	}

	println('Hiding window')
	C.loseFocus()
	sdl.hide_window(a.window)
	a.is_hiding = true

	if a.is_initial_render {
		C.setupWindow2()
		a.is_initial_render = false
	}

	// we don't need to keep the cache when closed
	a.clear_application_icon_cache()
}

fn (mut a App) evaluate() {
	a.mod = .none
	if a.search_input.value.len == 0 {
		return
	}

	if cmd := a.find_command() {
		a.mod = .command
		a.cached_command = cmd
	} else if rate := a.find_currency_exchange() {
		a.mod = .currency_exchange
		a.cached_exchange_rate_query = rate
	} else if result := a.find_calculator_expression() {
		a.mod = .calculator
		a.cached_calculator_result = result
	} else if app := a.find_relevant_applications() {
		a.mod = .application
		a.cached_application = app
	}
}

fn (mut a App) reset() {
	a.search_input.reset()

	a.mod = .none
	a.cached_application = none
	a.clear_application_icon_cache()
	a.cached_exchange_rate_query = none
}

fn (mut a App) index() {
	spawn a.index_applications()
	spawn a.index_currency_exchange_rates()
	spawn a.history_cleanup()
}

enum SearchModule {
	none
	application
	currency_exchange
	command
	calculator
}

fn (mut a App) cleanup() {
	sdl.destroy_renderer(a.renderer)
	sdl.destroy_window(a.window)
	sdl.quit()
}
