module main

import os
import sdl

const application_icon_size = application_extra_height - 8 * padding

fn (mut a App) render_application_results() {
	a.set_draw_color(background_200_color)
	sdl.render_fill_rect(a.renderer, &sdl.Rect{0, height, width, application_extra_height})

	application := a.cached_application or { return }

	if icon := a.get_application_icon() {
		dstrect := sdl.Rect{8 * padding, height + 4 * padding, application_icon_size, application_icon_size}
		sdl.render_copy(a.renderer, icon, sdl.null, &dstrect)
	}

	a.draw_centered_text(8 * padding + application_icon_size, height + application_extra_height / 2,
		application.name, text_color, background_200_color)

	text_width, _ := a.size_text(application.name)
	h_offset := 8 * padding + application_icon_size + text_width
	a.draw_centered_text(h_offset + padding, height + application_extra_height / 2, ' Return to launch',
		muted_text_color, background_200_color)
}

fn (mut a App) launch_application() {
	application := a.cached_application or { return }
	println('Launching application: ${application.name} at path: ${application.executable}')
	// we can't call the application executable directly for TextEdit.app and some others
	// otherwise TextEdit crashes due to Code Signature validation failure
	// mut p := os.new_process(application.executable)
	mut p := os.new_process('/usr/bin/open')
	p.set_args([application.path])
	p.set_environment(os.environ())
	p.set_work_folder(os.home_dir())
	p.run()
	spawn p.wait()
}

fn (mut a App) get_application_icon() ?&sdl.Texture {
	application := a.cached_application or { return none }
	icon_path := application.icon_path or { return none }

	if cached := a.cached_application_icon {
		if cached.id == application.id {
			return cached.texture
		}
	}

	println('Loading icon for application: ${application.name} from path: ${icon_path}')

	content := os.read_file(icon_path) or {
		eprintln('Failed to read icon file at path: ${icon_path}')
		return none
	}

	a.clear_application_icon_cache()

	texture := a.try_load_icns(content.bytes())

	a.cached_application_icon = CachedApplicationIcon{
		id:      application.id
		texture: texture
	}

	return texture
}

fn (mut a App) clear_application_icon_cache() {
	if cached := a.cached_application_icon {
		if texture := cached.texture {
			sdl.destroy_texture(texture)
		}
	}
	a.cached_application_icon = none
}

fn (a &App) try_load_icns(content []u8) ?&sdl.Texture {
	icns := parse_icns(content) or {
		eprintln('Failed to parse ICNS file: ${err}')
		return none
	}

	icon := icns.get_best_icon(application_icon_size, 1) or {
		eprintln('No suitable icon found in ICNS')
		return none
	}

	println('Loading icon of size: ${icon.size} and bit depth: ${icon.bit_depth}')

	texture := icon.unpack_sdl(a.renderer) or {
		eprintln('Failed to unpack icon from ICNS: ${err}')
		return none
	}

	return texture
}

struct CachedApplicationIcon {
	id      int
	texture ?&sdl.Texture
}

fn (mut a App) find_relevant_applications() (?IndexedApplication, int) {
	query := a.search_input.value.to_lower()

	mut all_apps := sql a.db {
		select from IndexedApplication
	} or {
		eprintln('Failed to query database: ${err}')
		return none, -1
	}

	result := fuzzy_find(query.to_lower(), all_apps.map(it.name.to_lower())) or { return none, -1 }
	return all_apps[result.index], result.score
}

fn (mut a App) index_applications() {
	mut search_paths := get_application_searchpaths()
	mut depth := 0

	for search_paths.len > 0 && depth < 100 {
		path := search_paths.pop()
		entries := os.ls(path) or {
			eprintln('Failed to list directory: ${path}')
			continue
		}

		for entry in entries {
			full_path := os.join_path(path, entry)
			if os.is_dir(full_path) {
				if entry.ends_with('.app') {
					a.index_application(full_path)
				} else {
					search_paths << full_path
					depth++
				}
			}
		}
	}

	if search_paths.len > 0 {
		eprintln('Max search depth reached, some applications may not be indexed.')
		eprintln('Make sure you do not have recursive symbolic links in your Applications folders.')
	}
}

fn (mut a App) index_application(app_path string) {
	app_name := os.file_name(app_path).replace('.app', '')
	plist := os.join_path(app_path, 'Contents', 'Info.plist')
	plist_content := os.read_file(plist) or {
		eprintln('Failed to read Info.plist for application: ${app_name}')
		return
	}

	mut executable_name := ''
	mut icon_filenames := []string{}
	if plist_content.starts_with('<?xml') {
		executable_name = plist_content.all_after('<key>CFBundleExecutable</key>')
			.all_after('<string>').all_before('</string>').trim_space()

		icon_name := plist_content.all_after('<key>CFBundleIconFile</key>')
			.all_after('<string>').all_before('</string>').trim_space()

		icon_filenames << icon_name + '.icns'
		icon_filenames << icon_name
	} else {
		executable_name = app_name
	}

	icon_filenames << app_name + '.icns'
	if executable_name != app_name {
		icon_filenames << executable_name + '.icns'
	}
	icon_filenames << 'AppIcon.icns' // Apple loves this name and binary plist's which we don't parse

	if executable_name == '' {
		eprintln('Failed to find executable name in Info.plist for application: ${app_name}')
		return
	}

	executable_path := os.join_path(app_path, 'Contents', 'MacOS', executable_name)

	if !os.exists(executable_path) {
		eprintln('Executable not found for application: ${app_name} at ${executable_path}')
		return
	}

	mut final_icon_path := ?string(none)
	for icon_filename in icon_filenames {
		icon_path := os.join_path(app_path, 'Contents', 'Resources', icon_filename)
		if os.exists(icon_path) {
			final_icon_path = icon_path
			break
		}
	}

	new_entry := IndexedApplication{
		name:       app_name
		path:       app_path
		executable: executable_path
		icon_path:  final_icon_path
	}

	sql a.db {
		insert new_entry into IndexedApplication
	} or {
		if !is_conflict(err) {
			eprintln('Failed to index application ${app_name}: ${err}')
			return
		}

		sql a.db {
			update IndexedApplication set path = new_entry.path, executable = new_entry.executable,
			icon_path = new_entry.icon_path where name == new_entry.name
		} or { eprintln('Failed to update application ${app_name}: ${err}') }

		return
	}

	println('Indexed application: ${app_name}')
}

fn get_application_searchpaths() []string {
	mut paths := []string{}
	paths << '/Applications'
	paths << '/System/Applications'
	paths << os.home_dir() + '/Applications'
	return paths
}
