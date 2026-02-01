module main

struct Input {
mut:
	value          string
	cursor_pos     int
	selected_start ?int
	selected_end   ?int
}

fn (inp Input) has_selection() bool {
	return inp.selected_start != none && inp.selected_end != none
}

fn (mut inp Input) clear_selection() {
	inp.selected_start = none
	inp.selected_end = none
}

fn (mut inp Input) reset() {
	inp.value = ''
	inp.cursor_pos = 0
	inp.clear_selection()
}

fn (mut inp Input) delete_selection() {
	if !inp.has_selection() {
		return
	}
	start := inp.selected_start or { 0 }
	end := inp.selected_end or { 0 }
	inp.value = inp.value[..start] + inp.value[end..]
	inp.cursor_pos = start
	inp.clear_selection()
}

fn (mut inp Input) get_selected_text() string {
	if !inp.has_selection() {
		return ''
	}
	start := inp.selected_start or { 0 }
	end := inp.selected_end or { 0 }
	return inp.value[start..end]
}

fn (mut inp Input) select_all() {
	inp.selected_start = 0
	inp.selected_end = inp.value.len
	inp.cursor_pos = inp.value.len
}

fn (mut inp Input) insert_text(text string) {
	inp.delete_selection()
	inp.value = inp.value[..inp.cursor_pos] + text + inp.value[inp.cursor_pos..]
	inp.cursor_pos += text.len
}

fn (mut inp Input) backspace(mod MoveModifier) {
	if inp.has_selection() {
		if mod.has(.cmd) { // do nothing at all if cmd is pressed
			return
		}
		inp.delete_selection()
	} else if inp.cursor_pos > 0 {
		mut new_pos := inp.cursor_pos - 1
		if mod.has(.cmd) {
			new_pos = inp.move_absolute(.left)
		} else if mod.has(.opt) {
			new_pos = inp.move_word(.left)
		}

		inp.value = inp.value[..new_pos] + inp.value[inp.cursor_pos..]
		inp.cursor_pos = new_pos
	}
}

fn (inp Input) move_single(dir MoveDirection) int {
	pos := inp.cursor_pos + dir.velocity()
	if pos < 0 || pos > inp.value.len {
		return inp.cursor_pos
	}
	return pos
}

fn (inp Input) move_word(dir MoveDirection) int {
	mut pos := inp.cursor_pos
	velocity := dir.velocity()
	if dir == .left {
		pos--
	}

	// Skip spaces first
	for pos >= 0 && pos < inp.value.len && inp.value[pos].is_space() {
		pos += velocity
	}

	// Then move through word characters
	for pos >= 0 && pos < inp.value.len && !inp.value[pos].is_space() {
		pos += velocity
	}
	if dir == .left {
		pos++
	}

	if pos < 0 {
		return 0
	}
	if pos > inp.value.len {
		return inp.value.len
	}

	return pos
}

fn (inp Input) move_absolute(dir MoveDirection) int {
	return match dir {
		.left { 0 }
		.right { inp.value.len }
	}
}

fn (mut inp Input) map_input(dir MoveDirection, modifiers MoveModifier) {
	mut new_pos := 0
	if modifiers.has(.cmd) {
		new_pos = inp.move_absolute(dir)
	} else if modifiers.has(.opt) {
		new_pos = inp.move_word(dir)
	} else {
		new_pos = inp.move_single(dir)
	}

	if modifiers.has(.shift) {
		if !inp.has_selection() {
			inp.selected_start = inp.cursor_pos
			inp.selected_end = new_pos
		} else {
			if inp.selected_start or { 0 } == inp.cursor_pos {
				inp.selected_start = new_pos
			} else {
				inp.selected_end = new_pos
			}
		}
		if inp.selected_start or { 0 } >= inp.selected_end or { 0 } {
			tmp := inp.selected_start
			inp.selected_start = inp.selected_end
			inp.selected_end = tmp
		}
	} else {
		inp.clear_selection()
	}
	inp.cursor_pos = new_pos
}

@[flag]
enum MoveModifier {
	shift
	ctrl
	opt
	cmd
}

enum MoveDirection {
	left
	right
}

fn (m MoveDirection) velocity() int {
	return match m {
		.left { -1 }
		.right { 1 }
	}
}
