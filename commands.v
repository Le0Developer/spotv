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
		.clear_history {
			sql a.db {
				delete from HistoryEntry where true
			} or { eprintln('Failed to clear history: ${err}') }
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
		'/clear_history' {
			.clear_history
		}
		else {
			none
		}
	}
}

enum Command {
	index
	quit
	clear_history
}
