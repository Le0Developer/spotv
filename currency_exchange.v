module main

import strconv
import time
import net.http
import x.json2
import sdl

const exchange_url = 'https://api.frankfurter.dev/v1/latest'
const currencies = ['EUR', 'AUD', 'BRL', 'CAD', 'CHF', 'CNY', 'CZK', 'DKK', 'GBP', 'HKD', 'HUF',
	'IDR', 'ILS', 'INR', 'ISK', 'JPY', 'KRW', 'MXN', 'MYR', 'NOK', 'NZD', 'PHP', 'PLN', 'RON',
	'SEK', 'SGD', 'THB', 'TRY', 'USD', 'ZAR']

fn (mut a App) render_currency_exchange_results() {
	a.set_draw_color(background_200_color)
	sdl.render_fill_rect(a.renderer, &sdl.Rect{0, height, width, currency_exchange_extra_height})

	query := a.cached_exchange_rate_query or { return }

	text := '${query.quantity:.4f} ${query.from_currency} = ${query.result:.4f} ${query.to_currency}'
	a.draw_centered_text(8 * padding, height + currency_exchange_extra_height / 2, text,
		text_color, background_200_color)
}

fn (mut a App) find_currency_exchange() ?CurrencyExchangeRateQuery {
	mut words := a.search_input.value.fields().filter(it !in ['is', 'to', '=', '?', '=='])
	if words.len == 0 {
		return none
	}

	mut count := 1.0

	// allow "1 USD EUR"
	if c := strconv.atof64(words[0]) {
		words.pop_left()
		count = c
	}

	if words.len == 0 || words.len > 2 || !words.all(it.len == 3 && it.to_upper() in currencies) {
		return none
	}

	from_currency := words[0].to_upper()
	mut to_currency := 'EUR'
	if words.len == 2 {
		to_currency = words[1].to_upper()
	} else if from_currency == 'EUR' {
		to_currency = 'USD'
	}

	rate := sql a.db {
		select from CurrencyExchangeRate where from_currency == from_currency
		&& to_currency == to_currency
	} or {
		eprintln('Failed to query currency exchange rate: ${err}')
		return none
	}

	if rate.len == 0 {
		return none
	}

	return CurrencyExchangeRateQuery{
		from_currency: from_currency
		to_currency:   to_currency
		rate:          rate[0].rate
		quantity:      count
		result:        rate[0].rate * count
	}
}

fn (mut a App) copy_exchange_rate_to_clipboard() {
	query := a.find_currency_exchange() or { return }

	copy_to_clipboard(query.result.str())
}

struct CurrencyExchangeRateQuery {
	from_currency string
	to_currency   string
	rate          f64
	quantity      f64
	result        f64
}

fn (mut a App) index_currency_exchange_rates() {
	// Check if rates are outdated (older than 1 day)
	outdated := sql a.db {
		select count from CurrencyExchangeRate where last_updated < time.now().add_days(-1)
	} or { 1 }

	if outdated == 0 {
		return
	}

	res := http.get(exchange_url) or {
		eprintln('Failed to fetch currency exchange rates: ${err}')
		return
	}

	println('Currency exchange rate status: ${res.status_code}')

	payload := json2.decode[CurrencyExchangeRateResponse](res.body) or {
		eprintln('Failed to decode currency exchange rates response: ${err}')
		return
	}

	println('Base currency: ${payload.base} Date: ${payload.date} Rates: ${payload.rates}')

	for from in currencies {
		for to in currencies {
			if from == to {
				continue
			}
			mut rate := 0.0
			if from == payload.base {
				rate = payload.rates[to] or { 0.0 }
			} else if to == payload.base {
				from_rate := payload.rates[from] or { 0.0 }
				if from_rate != 0.0 {
					rate = 1.0 / from_rate
				}
			} else {
				from_rate := payload.rates[from] or { 0.0 }
				to_rate := payload.rates[to] or { 0.0 }
				if from_rate != 0.0 {
					rate = to_rate / from_rate
				}
			}

			if rate == 0.0 {
				continue
			}

			// println('1 ${from} -> ${rate} ${to}')
			rate_struct := CurrencyExchangeRate{
				from_currency: from
				to_currency:   to
				rate:          rate
				last_updated:  time.now()
			}

			sql a.db {
				insert rate_struct into CurrencyExchangeRate
			} or {
				if !is_conflict(err) {
					// For other errors, print them
					eprintln('Failed to insert currency exchange rate: ${err}')
					continue
				}

				sql a.db {
					update CurrencyExchangeRate set rate = rate_struct.rate, last_updated = rate_struct.last_updated
					where from_currency == rate_struct.from_currency
					&& to_currency == rate_struct.to_currency
				} or { eprintln('Failed to update currency exchange rate: ${err}') }
			}
		}
	}
}

struct CurrencyExchangeRateResponse {
	amount f64
	base   string // "EUR"
	date   string // "2026-01-30"
	rates  map[string]f64
}
