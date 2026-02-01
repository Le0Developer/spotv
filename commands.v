module main

fn (mut a App) launch_command() {
	cmd := a.cached_command or { return }
	match cmd {
		.index {
			a.index()
		}
		.quit {
			a.should_quit = true
		}
	}
}

fn (mut a App) find_command() ?Command {
	return match a.search_input.value {
		'/index' {
			.index
		}
		'/quit' {
			.quit
		}
		else {
			none
		}
	}
}

enum Command {
	index
	quit
}
