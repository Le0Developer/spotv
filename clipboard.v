module main

import sdl

fn copy_to_clipboard(text string) bool {
	return sdl.set_clipboard_text(text.str) == 0
}

fn get_text_from_clipboard() ?string {
	clipboard_text := sdl.get_clipboard_text()
	if clipboard_text == 0 {
		return none
	}
	return unsafe { clipboard_text.vstring() }
}
