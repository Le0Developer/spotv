module main

import time
import math
import strconv
import sdl

const calculator_functions = ['sin', 'cos', 'tan', 'asin', 'acos', 'atan', 'sqrt', 'log', 'log2',
	'log10', 'ln', 'exp', 'abs', 'floor', 'ceil']
const operator_precedence = {
	CalcExprOperation.add:          1
	CalcExprOperation.subtract:     1
	CalcExprOperation.multiply:     2
	CalcExprOperation.divide:       2
	CalcExprOperation.power:        3
	CalcExprOperation.modulo:       2
	CalcExprOperation.bxor:         0
	CalcExprOperation.bor:          0
	CalcExprOperation.band:         0
	CalcExprOperation.bshift_left:  0
	CalcExprOperation.bshift_right: 0
}

const discord_epoch = u64(1420070400000) // January 1, 2015

fn (mut a App) render_calculator_results() {
	a.set_draw_color(background_200_color)
	sdl.render_fill_rect(a.renderer, &sdl.Rect{0, height, width, calculator_extra_height})

	result := a.cached_calculator_result or { return }

	text := result
	a.draw_centered_text(8 * padding, height + calculator_extra_height / 2, text, text_color,
		background_200_color)
}

fn (mut a App) copy_calculator_result_to_clipboard() {
	result := a.cached_calculator_result or { return }
	text := result
	copy_to_clipboard(text)
}

fn (mut a App) find_calculator_expression() ?string {
	mut parser := Parser{
		text: a.search_input.value
		end:  a.search_input.value.len
	}
	// don't let the parser go into the suffix
	if end := parser.text.last_index(':') {
		parser.end = end
	}

	ast := parser.parse_expr() or {
		eprintln('Failed to parse calculator expression: ${err}')
		return none
	}

	if parser.pos < parser.end {
		eprintln('Unexpected characters at end of expression')
		return none
	}

	parser.end = a.search_input.value.len
	// parse suffix
	mut suffix_data_type := CalcSufDataType.none
	mut suffix_custom_unit := ''
	mut suffix_si_prefix := false

	if !parser.eof() {
		parser.advance() // skip ':'
		suffix_start := parser.pos
		for !parser.eof() && parser.current_char() or { 0 }.is_letter() {
			parser.advance()
		}
		suffix := parser.text[suffix_start..parser.pos]
		match suffix {
			'msec' {
				suffix_data_type = .milliseconds
			}
			'sec' {
				suffix_data_type = .seconds
			}
			'min' {
				suffix_data_type = .minutes
			}
			'hour' {
				suffix_data_type = .hours
			}
			'day' {
				suffix_data_type = .days
			}
			'week' {
				suffix_data_type = .weeks
			}
			'month' {
				suffix_data_type = .months
			}
			'year' {
				suffix_data_type = .years
			}
			'unix' {
				suffix_data_type = .unix
			}
			'munix' {
				suffix_data_type = .unix_ms
			}
			'snowflake' {
				suffix_data_type = .snowflake
			}
			'x' {
				suffix_data_type = .hex
			}
			'b' {
				suffix_data_type = .binary
			}
			'o' {
				suffix_data_type = .octal
			}
			else {}
		}

		if parser.current_char() or { 0 } == `*` {
			suffix_si_prefix = true
			parser.advance()
		}

		if suffix_data_type == .none && parser.current_char() or { 0 } == `+` {
			parser.advance() // skip '+'
			suffix_custom_unit = parser.text[parser.pos..parser.end]
			suffix_data_type = .custom
			parser.pos = parser.end
		}

		if parser.pos < parser.end {
			eprintln('Unexpected characters at end of suffix')
			return none
		}
	}

	result := ast.evaluate() or {
		eprintln('Failed to evaluate calculator expression: ${err}')
		return 'Error: ${err}'
	}

	return calc_stringify_result(result, suffix_data_type, suffix_custom_unit, suffix_si_prefix)
}

struct Parser {
	text string
mut:
	pos int
	end int
}

fn (p &Parser) eof() bool {
	return p.pos >= p.end
}

fn (mut p Parser) read() ?u8 {
	if p.eof() {
		return none
	}
	ch := p.text[p.pos]
	p.pos++
	return ch
}

fn (mut p Parser) expect(expected u8) ! {
	ch := p.current_char() or {
		return error('Unexpected end of input, expected: ${expected.ascii_str()}')
	}
	if ch != expected {
		return error('Expected character: ${expected.ascii_str()}, got: ${ch.ascii_str()}')
	}
	p.advance()
}

fn (p &Parser) current_char() ?u8 {
	if p.eof() {
		return none
	}
	return p.text[p.pos]
}

fn (p &Parser) peek_char(ahead int) ?u8 {
	new_pos := p.pos + ahead
	if new_pos >= p.end {
		return none
	}
	return p.text[new_pos]
}

fn (mut p Parser) advance() {
	p.pos++
}

fn (mut p Parser) skip_whitespace() {
	for !p.eof() && p.text[p.pos].is_space() {
		p.advance()
	}
}

fn (mut p Parser) parse_expr() !CalcExpr {
	mut expr := p.parse_single()!
	p.skip_whitespace()
	mut exprs := [expr]
	mut operators := []CalcExprOperation{}
	for !p.eof() {
		mut ch := p.current_char() or { break }.ascii_str()
		match ch {
			'+', '-', '*', '/', '^', '%', '&', '|', '<', '>' {
				p.advance()
				if ch == '*' && p.current_char() or { 0 } == `*` {
					p.advance() // skip second '*'
					ch = '**'
				} else if ch == '<' && p.current_char() or { 0 } == `<` {
					p.advance() // skip second '<'
					ch = '<<'
				} else if ch == '>' && p.current_char() or { 0 } == `>` {
					p.advance() // skip second '>'
					ch = '>>'
				}
				p.skip_whitespace()
				right := p.parse_single()!
				operator := match ch {
					'+' { CalcExprOperation.add }
					'-' { CalcExprOperation.subtract }
					'*' { CalcExprOperation.multiply }
					'**' { CalcExprOperation.power }
					'/' { CalcExprOperation.divide }
					'%' { CalcExprOperation.modulo }
					'^' { CalcExprOperation.bxor }
					'&' { CalcExprOperation.band }
					'|' { CalcExprOperation.bor }
					'<<' { CalcExprOperation.bshift_left }
					'>>' { CalcExprOperation.bshift_right }
					else { panic('Unreachable') }
				}
				exprs << right
				operators << operator
				p.skip_whitespace()
			}
			else {
				break
			}
		}
	}

	// Now build the expression tree based on operator precedence
	for precedence in [3, 2, 1, 0] {
		mut i := 0
		for i < operators.len {
			op := operators[i]
			op_prec := operator_precedence[op] or { -1 }
			if op_prec == precedence {
				left := exprs[i]
				right := exprs[i + 1]
				new_expr := CalcExpr{
					typ:      .binary_operator
					left:     &left
					right:    &right
					operator: op
				}
				exprs[i] = new_expr
				exprs.delete(i + 1)
				operators.delete(i)
			} else {
				i++
			}
		}
	}

	return exprs[0]
}

fn (mut p Parser) parse_single() !CalcExpr {
	p.skip_whitespace()
	ch := p.current_char() or { return error('Unexpected end of input') }

	match ch {
		`+`, `-`, `~` {
			p.advance()
			p.skip_whitespace()
			operand := p.parse_single()!
			operator := match ch {
				`+` { CalcExprOperation.unary_plus }
				`-` { CalcExprOperation.unary_minus }
				`~` { CalcExprOperation.unary_bnot }
				else { panic('Unreachable') }
			}
			return CalcExpr{
				typ:      .unary_operator
				left:     &operand
				operator: operator
			}
		}
		`0`...`9` {
			if ch == `0` {
				next := p.peek_char(1) or { 0 }
				match next {
					`x`, `X` {
						return p.parse_number_hex()
					}
					`b`, `B` {
						return p.parse_number_binary()
					}
					`o`, `O` {
						return p.parse_number_octal()
					}
					else {
						return p.parse_number_decimal()
					}
				}
			} else {
				return p.parse_number_decimal()
			}
		}
		`a`...`z` {
			return p.parse_function_call()
		}
		`(` {
			p.advance() // skip '('
			expr := p.parse_expr()!
			p.skip_whitespace()
			p.expect(`)`)!
			return expr
		}
		else {
			return error('Unexpected character: ${ch.ascii_str()}')
		}
	}
}

fn (mut p Parser) parse_number_decimal() !CalcExpr {
	mut accu := []u8{}
	mut last_e := false
	for !p.eof() {
		ch := p.current_char() or { break }
		if ch.is_digit() || ch == `.` || ch == `e` || ch == `E`
			|| (last_e && (ch == `+` || ch == `-`)) {
			p.advance()
			accu << ch
			last_e = ch == `e` || ch == `E`
		} else if ch == `_` {
			p.advance()
		} else {
			break
		}
	}
	mut number := strconv.atof64(accu.bytestr()) or {
		return error('Invalid decimal number: ${accu.bytestr()}')
	}

	accu.clear()
	for !p.eof() {
		ch := p.current_char() or { break }
		if ch.is_letter() {
			accu << ch
			p.advance()
		} else {
			break
		}
	}

	if accu.len > 0 {
		match accu.bytestr() {
			'p' {
				number *= 1e-12
			}
			'n' {
				number *= 1e-9
			}
			'µ', 'u' {
				number *= 1e-6
			}
			'm' {
				number *= 1e-3
			}
			'c' {
				number *= 1e-2
			}
			'd' {
				number *= 1e-1
			}
			'da' {
				number *= 1e1
			}
			'h' {
				number *= 1e2
			}
			'k', 'K' {
				number *= 1e3
			}
			'ki', 'Ki' {
				number *= 1024.0
			}
			'M' {
				number *= 1e6
			}
			'mi', 'Mi' {
				number *= 1024.0 * 1024.0
			}
			'G' {
				number *= 1e9
			}
			'gi', 'Gi' {
				number *= 1024.0 * 1024.0 * 1024.0
			}
			'T' {
				number *= 1e12
			}
			'ti', 'Ti' {
				number *= 1024.0 * 1024.0 * 1024.0 * 1024.0
			}
			'P' {
				number *= 1e15
			}
			'pi', 'Pi' {
				number *= 1024.0 * 1024.0 * 1024.0 * 1024.0 * 1024.0
			}
			'E' {
				number *= 1e18
			}
			'ei', 'Ei' {
				number *= 1024.0 * 1024.0 * 1024.0 * 1024.0 * 1024.0 * 1024.0
			}
			else {
				return error('Unknown SI prefix: ${accu.bytestr()}')
			}
		}
	}

	return CalcExpr{
		typ:   .literal
		value: number
	}
}

fn (mut p Parser) parse_number_hex() !CalcExpr {
	mut accu := []u8{}
	p.advance() // skip '0'
	p.advance() // skip 'x' or 'X'
	for !p.eof() {
		ch := p.current_char() or { break }
		if ch.is_hex_digit() {
			p.advance()
			accu << ch
		} else if ch == `_` {
			p.advance()
		} else {
			break
		}
	}
	number := strconv.parse_uint(accu.bytestr(), 16, 64) or {
		return error('Invalid hexadecimal number: ${accu.bytestr()}')
	}
	return CalcExpr{
		typ:   .literal
		value: number
	}
}

fn (mut p Parser) parse_number_binary() !CalcExpr {
	mut accu := []u8{}
	p.advance() // skip '0'
	p.advance() // skip 'b' or 'B'
	for !p.eof() {
		ch := p.current_char() or { break }
		if ch == `0` || ch == `1` {
			p.advance()
			accu << ch
		} else if ch == `_` {
			p.advance()
		} else {
			break
		}
	}
	number := strconv.parse_uint(accu.bytestr(), 2, 64) or {
		return error('Invalid binary number: ${accu.bytestr()}')
	}
	return CalcExpr{
		typ:   .literal
		value: number
	}
}

fn (mut p Parser) parse_number_octal() !CalcExpr {
	mut accu := []u8{}
	p.advance() // skip '0'
	p.advance() // skip 'o' or 'O'
	for !p.eof() {
		ch := p.current_char() or { break }
		if ch >= `0` && ch <= `7` {
			p.advance()
			accu << ch
		} else if ch == `_` {
			p.advance()
		} else {
			break
		}
	}
	number := strconv.parse_uint(accu.bytestr(), 8, 64) or {
		return error('Invalid octal number: ${accu.bytestr()}')
	}
	return CalcExpr{
		typ:   .literal
		value: number
	}
}

fn (mut p Parser) parse_function_call() !CalcExpr {
	start_pos := p.pos
	for !p.eof() && (p.text[p.pos].is_letter() || p.text[p.pos].is_digit() || p.text[p.pos] == `_`) {
		p.advance()
	}

	end_pos := p.pos

	p.skip_whitespace()

	p.expect(`(`)!
	mut args := []CalcExpr{}
	for {
		p.skip_whitespace()
		if p.current_char() == none {
			return error('Unexpected end of input while parsing function arguments')
		}
		if p.current_char() or { 0 } == `)` {
			break
		}
		arg := p.parse_expr()!
		args << arg
		p.skip_whitespace()
		if p.current_char() or { 0 } == `,` {
			p.advance() // skip ','
		} else {
			break
		}
	}
	p.expect(`)`)!
	return CalcExpr{
		typ:       .func
		func_name: p.text[start_pos..end_pos]
		func_args: args
	}
}

fn calc_stringify_result(result f64, suffix_data_type CalcSufDataType, suffix_custom_unit string, suffix_si_prefix bool) string {
	mut v := result
	mut s := ''

	match suffix_data_type {
		.none {}
		.milliseconds, .seconds, .minutes, .hours, .days, .weeks, .months, .years {
			mut multiplier := 1.0
			match suffix_data_type {
				.milliseconds {
					multiplier = 1.0
				}
				.seconds {
					multiplier = 1000.0
				}
				.minutes {
					multiplier = 1000.0 * 60.0
				}
				.hours {
					multiplier = 1000.0 * 60.0 * 60.0
				}
				.days {
					multiplier = 1000.0 * 60.0 * 60.0 * 24.0
				}
				.weeks {
					multiplier = 1000.0 * 60.0 * 60.0 * 24.0 * 7.0
				}
				.months {
					multiplier = 1000.0 * 60.0 * 60.0 * 24.0 * 30.0
				}
				.years {
					multiplier = 1000.0 * 60.0 * 60.0 * 24.0 * 365.0
				}
				else {}
			}
			milli := v * multiplier
			duration := time.nanosecond * i64(milli * 1e6)
			s = '(${duration.str()})'
		}
		.unix {
			t := time.unix(i64(v))
			s = '(${t.format_ss()})'
		}
		.unix_ms {
			t := time.unix_milli(i64(v))
			s = '(${t.format_ss()})'
		}
		.snowflake {
			t := time.unix_milli(u64(v) >> 22 + discord_epoch)
			s = '(${t.format_ss()})'
		}
		.binary {
			return '= 0b${strconv.format_uint(u64(v), 2)}'
		}
		.octal {
			return '= 0o${strconv.format_uint(u64(v), 8)}'
		}
		.hex {
			return '= 0x${strconv.format_uint(u64(v), 16)}'
		}
		.custom {
			s = '${suffix_custom_unit}'
		}
	}

	if suffix_si_prefix {
		mut si_prefix := ''
		mut abs_v := v
		if abs_v < 0 {
			abs_v = -abs_v
		}
		if abs_v != 0 {
			if abs_v >= 1e18 {
				si_prefix = 'E'
				v /= 1e18
			} else if abs_v >= 1e15 {
				si_prefix = 'P'
				v /= 1e15
			} else if abs_v >= 1e12 {
				si_prefix = 'T'
				v /= 1e12
			} else if abs_v >= 1e9 {
				si_prefix = 'G'
				v /= 1e9
			} else if abs_v >= 1e6 {
				si_prefix = 'M'
				v /= 1e6
			} else if abs_v >= 1e3 {
				si_prefix = 'k'
				v /= 1e3
			} else if abs_v >= 1.0 {
				si_prefix = ''
			} else if abs_v >= 1e-3 {
				si_prefix = 'm'
				v *= 1e3
			} else if abs_v >= 1e-6 {
				si_prefix = 'µ'
				v *= 1e6
			} else if abs_v >= 1e-9 {
				si_prefix = 'n'
				v *= 1e9
			} else {
				si_prefix = 'p'
				v *= 1e12
			}
		}
		s = '${si_prefix}${s}'
	}

	if s != '' {
		s = ' ${s}'
	}

	return '= ${v}${s}'
}

struct CalcExpr {
	typ   CalcExprType
	left  ?&CalcExpr
	right ?&CalcExpr

	value     ?f64
	func_name ?string
	func_args ?[]CalcExpr
	operator  ?CalcExprOperation
}

fn (c CalcExpr) evaluate() !f64 {
	match c.typ {
		.func {
			name := c.func_name or { '' }
			args := c.func_args or { [] }
			return calc_func(name, args.map(it.evaluate()!))
		}
		.literal {
			return c.value or { 0.0 }
		}
		.binary_operator {
			left_val := c.left or { panic('Left expression is missing') }.evaluate()!
			right_val := c.right or { panic('Right expression is missing') }.evaluate()!
			return calc_binary_operator(c.operator or { panic('Operator is missing') },
				left_val, right_val)!
		}
		.unary_operator {
			left_val := c.left or { panic('Left expression is missing') }.evaluate()!
			return calc_unary_operator(c.operator or { panic('Operator is missing') },
				left_val)!
		}
	}
}

fn calc_func(name string, args []f64) !f64 {
	match name {
		// all functions with one argument
		'sin', 'cos', 'tan', 'asin', 'acos', 'atan', 'sqrt', 'log2', 'log10', 'ln', 'exp', 'abs',
		'floor', 'ceil' {
			if args.len != 1 {
				return error('Function ${name} expects 1 argument, got ${args.len}')
			}
			arg := args[0]
			return match name {
				'sin' { math.sin(arg) }
				'cos' { math.cos(arg) }
				'tan' { math.tan(arg) }
				'asin' { math.asin(arg) }
				'acos' { math.acos(arg) }
				'atan' { math.atan(arg) }
				'sqrt' { math.sqrt(arg) }
				'log' { math.log(arg) }
				'log2' { math.log2(arg) }
				'log10' { math.log10(arg) }
				'ln' { math.log(arg) }
				'exp' { math.exp(arg) }
				'abs' { math.abs(arg) }
				'floor' { math.floor(arg) }
				'ceil' { math.ceil(arg) }
				else { 0.0 } // unreachable
			}
		}
		'log' {
			if args.len !in [1, 2] {
				return error('Function log expects 1 or 2 arguments, got ${args.len}')
			}
			if args.len == 1 {
				return math.log(args[0])
			} else {
				base := args[1]
				if base <= 0.0 || base == 1.0 {
					return error('Logarithm base must be positive and not equal to 1')
				}
				return math.log_n(args[0], base)
			}
		}
		else {
			return error('Unknown function: ${name}')
		}
	}
}

fn calc_binary_operator(op CalcExprOperation, left f64, right f64) !f64 {
	match op {
		.add {
			return left + right
		}
		.subtract {
			return left - right
		}
		.multiply {
			return left * right
		}
		.divide {
			if right == 0.0 {
				return error('Division by zero')
			}
			return left / right
		}
		.power {
			return math.pow(left, right)
		}
		.modulo {
			return math.mod(left, right)
		}
		.bxor {
			return f64(u64(left) ^ u64(right))
		}
		.bor {
			return f64(u64(left) | u64(right))
		}
		.band {
			return f64(u64(left) & u64(right))
		}
		.bshift_left {
			return f64(u64(left) << u64(right))
		}
		.bshift_right {
			return f64(u64(left) >> u64(right))
		}
		else {
			return error('Invalid binary operator')
		}
	}
}

fn calc_unary_operator(op CalcExprOperation, value f64) !f64 {
	match op {
		.unary_plus {
			return value
		}
		.unary_minus {
			return -value
		}
		.unary_bnot {
			return f64(~u64(value))
		}
		else {
			return error('Invalid unary operator')
		}
	}
}

enum CalcExprOperation {
	add
	subtract
	multiply
	divide
	power
	modulo

	bxor
	bor
	band
	bshift_left
	bshift_right

	unary_plus
	unary_minus
	unary_bnot
}

enum CalcExprType {
	func
	literal
	binary_operator
	unary_operator
}

enum CalcSufDataType {
	none

	milliseconds
	seconds
	minutes
	hours
	days
	weeks
	months
	years

	unix
	unix_ms
	snowflake

	binary
	octal
	hex

	custom
}
