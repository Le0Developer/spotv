module main

import time

const history_limit = 7 * 24 * time.hour

fn (a &App) history_cleanup() {
	cutoff := time.now().add(-history_limit)
	sql a.db {
		delete from HistoryEntry where timestamp < cutoff
	} or { eprintln('Failed to clean up old history entries: ${err}') }
}

fn (mut a App) save_history_entry(query string) {
	entry := HistoryEntry{
		query:     query
		timestamp: time.now()
	}
	sql a.db {
		insert entry into HistoryEntry
	} or {
		if is_conflict(err) {
			sql a.db {
				update HistoryEntry set timestamp = entry.timestamp where query == entry.query
			} or { eprintln('Failed to update history entry timestamp: ${err}') }
			return
		}
		eprintln('Failed to save history entry: ${err}')
	}
}

fn (mut a App) history_load_older() {
	mut entries := []HistoryEntry{}

	if a.history_timestamp == none {
		entries = sql a.db {
			select from HistoryEntry order by timestamp desc limit 1
		} or {
			eprintln('Failed to load older history entry: ${err}')
			return
		}
	} else {
		ts := a.history_timestamp
		entries = sql a.db {
			select from HistoryEntry where timestamp < ts order by timestamp desc limit 1
		} or {
			eprintln('Failed to load older history entry: ${err}')
			return
		}
	}

	if entries.len > 0 {
		if a.history_timestamp == none {
			// First time loading history, save current input temporarily
			a.history_temp_save = a.search_input.value
		}

		entry := entries[0]
		a.search_input.reset()
		a.search_input.value = entry.query
		a.search_input.cursor_pos = entry.query.len
		a.history_timestamp = entry.timestamp
		a.evaluate()
	}
}

fn (mut a App) history_load_newer() {
	if a.history_timestamp == none {
		return
	}

	ts := a.history_timestamp or { return }
	entries := sql a.db {
		select from HistoryEntry where timestamp > ts order by timestamp limit 1
	} or {
		eprintln('Failed to load newer history entry: ${err}')
		return
	}

	if entries.len > 0 {
		entry := entries[0]
		a.search_input.set_value(entry.query)
		a.history_timestamp = entry.timestamp
		a.evaluate()
	} else {
		if saved := a.history_temp_save {
			a.search_input.set_value(saved)
		} else {
			a.search_input.reset()
		}

		a.history_timestamp = none
		a.evaluate()
	}
}
