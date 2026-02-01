module main

import encoding.binary
import sdl
import sdl.image

const icns_magic_number = [u8(0x69), 0x63, 0x6E, 0x73] // 'icns'
const icns_header_len = 8

// https://en.wikipedia.org/wiki/Apple_Icon_Image_format
fn parse_icns(b []u8) !ICNS {
	if b.len < 8 {
		return error('ICNS data too short')
	}
	magic := b[0..4]
	if magic != icns_magic_number {
		return error('Invalid ICNS magic number')
	}
	len := binary.big_endian_u32_at(b, 4)
	if len > u32(b.len) {
		return error('ICNS length exceeds data size')
	}

	mut icons := []ICNSIcon{}
	mut offset := u32(8)
	for offset < len - icns_header_len {
		os_type := b[offset..offset + 4]
		length := binary.big_endian_u32_at(b, int(offset + 4))
		if offset + length > len {
			return error('Invalid ICNS icon length')
		} else if length == 0 {
			return error('ICNS icon length is zero')
		}
		mut size := 0
		mut bit_depth := 0

		match os_type {
			'icp4'.bytes() {
				size = 16
				bit_depth = 32
			}
			'icp5'.bytes() {
				size = 32
				bit_depth = 32
			}
			'icp6'.bytes() {
				size = 64
				bit_depth = 32
			}
			'ic07'.bytes() {
				size = 128
				bit_depth = 32
			}
			'ic08'.bytes() {
				size = 256
				bit_depth = 32
			}
			'ic09'.bytes() {
				size = 512
				bit_depth = 32
			}
			'ic10'.bytes() {
				size = 1024
				bit_depth = 32
			}
			'ic11'.bytes() {
				size = 16 // retina
				bit_depth = 32
			}
			'ic12'.bytes() {
				size = 32 // retina
				bit_depth = 32
			}
			'ic13'.bytes() {
				size = 64 // retina
				bit_depth = 32
			}
			'ic14'.bytes() {
				size = 256 // retina
				bit_depth = 32
			}
			else {
				println('skipped icns type: ${os_type.bytestr()}')
				offset += length
				continue
			}
		}

		println('Found icon type: ${os_type.bytestr()} Size: ${size} Bit depth: ${bit_depth}')

		data := b[offset + icns_header_len..offset + length]
		icons << ICNSIcon{
			size:      size
			bit_depth: bit_depth
			data:      data
		}
		offset += length
	}

	if icons.len == 0 {
		return error('No valid icons found in ICNS data')
	}

	return ICNS{
		icons: icons
	}
}

struct ICNS {
	icons []ICNSIcon
}

fn (icns ICNS) get_best_icon(desired_size int, desired_bit_depth int) ?ICNSIcon {
	mut best := ?ICNSIcon(none)
	for icon in icns.icons {
		if icon.size < desired_size || icon.bit_depth < desired_bit_depth {
			continue
		}
		if b := best {
			if icon.size > b.size || (icon.size == b.size && icon.bit_depth > b.bit_depth) {
				best = icon
			}
		} else {
			best = icon
		}
	}
	return best
}

struct ICNSIcon {
	size      int
	bit_depth int
	data      []u8
}

// Unpack unpacks the icon data and returns the raw RGBA bytes.
fn (icns ICNSIcon) unpack_sdl(renderer &sdl.Renderer) ?&sdl.Texture {
	buffer := sdl.rw_from_mem(icns.data.data, icns.data.len)
	texture := image.load_texture_rw(renderer, buffer, 0)
	if texture == 0 {
		return none
	}
	return texture
}
