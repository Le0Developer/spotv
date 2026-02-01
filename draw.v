module main

import sdl
import sdl.ttf

fn (a &App) draw_text(x int, y int, text string, tcol sdl.Color, bcol sdl.Color) {
	a.draw_text_with_font(x, y, text, a.font, tcol, bcol)
}

fn (a &App) draw_text_with_font(x int, y int, text string, font &ttf.Font, tcol sdl.Color, bcol sdl.Color) {
	mut tsurf := &sdl.Surface(unsafe { nil })
	if bcol.a > 0 {
		tsurf = ttf.render_text_shaded(font, text.str, tcol, bcol)
	} else {
		tsurf = ttf.render_text_solid(font, text.str, tcol)
	}
	ttext := sdl.create_texture_from_surface(a.renderer, tsurf)
	texw := 0
	texh := 0
	sdl.query_texture(ttext, sdl.null, sdl.null, &texw, &texh)
	dstrect := sdl.Rect{x, y, texw, texh}
	sdl.render_copy(a.renderer, ttext, sdl.null, &dstrect)
	sdl.destroy_texture(ttext)
	sdl.free_surface(tsurf)
}

fn (a &App) draw_centered_text(x int, y int, text string, tcol sdl.Color, bcol sdl.Color) {
	a.draw_centered_text_with_font(x, y, text, a.font, tcol, bcol)
}

fn (a &App) draw_centered_text_with_font(x int, y int, text string, font &ttf.Font, tcol sdl.Color, bcol sdl.Color) {
	mut tsurf := &sdl.Surface(unsafe { nil })
	if bcol.a > 0 {
		tsurf = ttf.render_text_shaded(font, text.str, tcol, bcol)
	} else {
		tsurf = ttf.render_text_solid(font, text.str, tcol)
	}
	ttext := sdl.create_texture_from_surface(a.renderer, tsurf)
	texw := 0
	texh := 0
	sdl.query_texture(ttext, sdl.null, sdl.null, &texw, &texh)
	dstrect := sdl.Rect{x, y - texh / 2, texw, texh}
	sdl.render_copy(a.renderer, ttext, sdl.null, &dstrect)
	sdl.destroy_texture(ttext)
	sdl.free_surface(tsurf)
}

fn (a &App) size_text(text string) (int, int) {
	x := 0
	y := 0
	ttf.size_text(a.font, text.str, &x, &y)
	return x, y
}

fn (a &App) set_draw_color(color sdl.Color) {
	sdl.set_render_draw_color(a.renderer, color.r, color.g, color.b, color.a)
}
