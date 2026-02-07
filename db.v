module main

import time
import db.sqlite

@[table: 'indexed_applications']
struct IndexedApplication {
	id         int @[autoincrement; primary; sql: serial]
	name       string
	path       string @[unique]
	executable string
	icon_path  ?string
}

@[table: 'system_preferences']
struct SystemPreference {
	id   int @[autoincrement; primary; sql: serial]
	name string
	path string @[unique]
}

@[table: 'currency_exchange_rates']
struct CurrencyExchangeRate {
	from_currency string
	to_currency   string
	rate          f64
	last_updated  time.Time
}

@[table: 'history_entries']
struct HistoryEntry {
	id        int @[autoincrement; primary; sql: serial]
	query     string
	timestamp time.Time
}

fn create_database(path string) !sqlite.DB {
	db := sqlite.connect(path)!

	sql db {
		create table IndexedApplication
		create table SystemPreference
		create table CurrencyExchangeRate
		create table HistoryEntry
	}!

	return db
}

fn is_conflict(err IError) bool {
	return err.msg().contains('UNIQUE constraint failed')
}
