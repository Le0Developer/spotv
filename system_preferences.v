module main

import os
import sdl

fn (mut a App) render_system_preference_results() {
	a.set_draw_color(background_200_color)
	sdl.render_fill_rect(a.renderer, &sdl.Rect{0, height, width, system_preference_extra_height})

	preference := a.cached_system_preference or { return }

	a.draw_centered_text(8 * padding, height + system_preference_extra_height / 2, preference.name,
		text_color, background_200_color)

	text_width, _ := a.size_text(preference.name)
	h_offset := 8 * padding + text_width
	a.draw_centered_text(h_offset + padding, height + system_preference_extra_height / 2,
		' Return to open', muted_text_color, background_200_color)
}

fn (mut a App) launch_system_preference() {
	preference := a.cached_system_preference or { return }
	println('Opening system preference: ${preference.name} at path: ${preference.path}')
	mut p := os.new_process('/usr/bin/open')
	p.set_args([preference.path])
	p.set_environment(os.environ())
	p.set_work_folder(os.home_dir())
	p.run()
	spawn p.wait()
}

fn (mut a App) find_relevant_system_preferences() (?SystemPreference, int) {
	preferences := sql a.db {
		select from SystemPreference
	} or {
		eprintln('Failed to query system preferences: ${err}')
		return none, -1
	}

	result := fuzzy_find(a.search_input.value.to_lower(), preferences.map(it.name.to_lower())) or {
		return none, -1
	}

	return preferences[result.index], result.score
}

fn (mut a App) index_system_preferences() {
	dir := '/System/Library/PreferencePanes'
	entries := os.ls(dir) or {
		eprintln('Failed to list system preferences directory: ${err}')
		return
	}
	for entry in entries {
		if entry.ends_with('.prefPane') {
			path := os.join_path(dir, entry)
			a.index_system_preferences_entry(path)
		}
	}
}

fn (mut a App) index_system_preferences_entry(path string) {
	mut name := os.file_name(path).replace('.prefPane', '')

	plist := os.join_path(path, 'Contents', 'Info.plist')
	plist_content := os.read_file(plist) or { '' }

	if plist_content.starts_with('<?xml') {
		if plist_content.contains('CFBundleGetInfoString') {
			name = plist_content.all_after('<key>CFBundleGetInfoString</key>').all_after('<string>').all_before('</string>').replace(' Preference Pane',
				'').replace('&amp;', '&')
		}
	}

	new_entry := SystemPreference{
		name: name
		path: path
	}

	sql a.db {
		insert new_entry into SystemPreference
	} or {
		if !is_conflict(err) {
			eprintln('Failed to insert system preference: ${err}')
			return
		}

		sql a.db {
			update SystemPreference set name = new_entry.name where path == new_entry.path
		} or { eprintln('Failed to update system preference: ${err}') }
	}
}
