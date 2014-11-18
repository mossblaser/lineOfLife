#!/usr/bin/env python

"""
Generate an AVR-compatible C file which defines a font for use with "bar of
life".

Usage:

	python font_gen.py 40 40 "Myriad Pro" FONT_
	                   |  |   |           |
	                   |  |   |           '-- Prefix added to all defintions
	                   |  |   '-- Font name
	                   |  '-- Number of LEDs (must be a multiple of 8)
	                   '-- Height of font (0 - number of LEDs)

Users are advised to check the ASCII-art renderings within the generated output
to make sure the generated font is acceptible.

The generated file will contain the following definitions in PROGMEM:

* prefixHEIGHT: The specified font's height.
* prefixNUM_CHARS: The number of characters supported.
* prefixASCII_TO_INDEX: An array with 128 elements (corresponding with
  every ASCII value) which gives an index into other generated tables.
* prefixGLYPH_BITMAPS: An array of character bitmaps given in
  columns-first-order starting at the top-left of the bitmap.
* prefixGLYPH_BITMAPS_LOOKUP: An array giving the starting offset of each
  character in prefixGLYPH_BITMAPS.
* prefixGLYPH_WIDTH: An array giving the width in columns of each character's
  bitmap.
* prefixGLYPH_START: The column within the character bitmap considered the
  "start" of the character by the font designer.
* prefixGLYPH_END: The column within the character bitmap considered the
  "end" of the character by the font designer.

""" 
import string

import cairo
from PIL import Image

"""
An enumeration of all characters to create.
"""
CHARS = "".join(sorted(set(string.printable) - set(string.whitespace))) + " "


def generate_glyph(glyph, file_name, font = "Myriad Pro", text_height = 40, height = None, width = None):
	"""
	Produce a black (bg)  and white (fg) PNG in file_name containing the given
	glyph at the specified width/height in pixels. The glyph will be left-aligned.
	
	Returns a tuple (start, end) where start is the x-coordinate of the
	character's true starting pixel and end that of the true ending pixel.
	"""
	if height is None:
		height = text_height
	if width is None:
		width = height * 2
	surface = cairo.ImageSurface(cairo.FORMAT_RGB24, width, height)
	ctx = cairo.Context(surface)
	
	ctx.set_source_rgb(0.0, 0.0, 0.0)
	ctx.rectangle(0, 0, width, height)
	ctx.fill()
	
	ctx.select_font_face(font)
	ctx.set_font_size(text_height)
	ctx.set_source_rgb(1.0, 1.0, 1.0)
	( ascent
	, descent
	, font_height
	, max_x_advance
	, max_y_advance
	) = ctx.font_extents()
	( x_bearing
	, y_bearing
	, bounding_box_text_width
	, bounding_box_text_height
	, x_advance
	, y_advance
	) = ctx.text_extents(glyph[0])
	ctx.move_to(max(0,-x_bearing), (-(height - text_height)/2) + height - descent)
	ctx.show_text(glyph[0])
	ctx.fill()
	
	surface.write_to_png(file_name)
	
	return (int(round(max(0,-x_bearing))), int(round(max(0,-x_bearing) + x_advance)))


def glyph_to_bits(file_name, min_width = 0):
	"""
	Given an RGB PNG of a single glyph (whose height is a multiple of 8), produces
	a sequence of bits (encoded as a sequence of bytes) corresponding to the pixel
	values. Also crops the right-hand-side of the image.
	
	The first byte's MSB is at (0,0) (upper left) and the less significant bits
	correspond to (0,1) - (0,7). The next byte's MSB is (0,8) and so on. Once all
	the bits in a column have been converted, the next column is encoded in the
	same manner.
	
	Returns a tuple (data, width, height). Width and height are in pixels.
	"""
	
	glyph = Image.open(file_name).convert("1")
	
	assert glyph.size[1]%8 == 0, "Image heights must be a multiple of 8"
	
	pixels = glyph.load()
	
	data = []
	
	# Convert pixels to bytes
	last_x_with_pixels = 0
	for x in range(glyph.size[0]):
		for y_byte in range(glyph.size[1]//8):
			data.append( sum( int(bool(pixels[x, y_byte*8 + y])) << (7-y)
			                  for y in range(8)
			                )
			           )
			if data[-1]:
				last_x_with_pixels = x
	
	# Crop the right-hand side of the glyph image
	crop_x = max(last_x_with_pixels, min_width)
	data = data[:(glyph.size[1]//8) * crop_x]
	
	return (data, crop_x, glyph.size[1])


def bytes_to_array_body(data, height = 8):
	"""
	Given an array of bytes (e.g. from glyph_to_bits) produce a valid C string
	defining an array body for a character array.
	"""
	data = data[:]
	
	out = "\t" + "/"*(5*(height//8) + 4 + height*2) + "\n"
	
	while data:
		this_column = 0
		out += "\t"
		for y in range(height//8):
			byte = data.pop(0)
			
			out += "0x%02X,"%byte
			
			this_column <<= 8
			this_column |= byte
		
		out += " // "
		for bit in range(height):
			out += "**" if this_column & (1<<bit) else "  "
		out = out.rstrip()
		out += "\n"
	
	return out


if __name__ == "__main__":
	import sys
	import tempfile
	
	text_height = int(sys.argv[1])
	height      = int(sys.argv[2])
	font        = sys.argv[3]
	prefix      = sys.argv[4]
	
	out  = "/**\n"
	out += " * Automatically-generated font definition file.\n"
	out += " *   %s\n"%(" ".join(sys.argv))
	out += " */\n"
	
	# A tempoary file to generate glyphs in
	temp = tempfile.mktemp(suffix=".png", prefix="font_gen_")
	
	# The characters as bitmaps {char: bytes} 
	glyph_data = {}
	
	# The (width,start,end) of every character
	glyph_dimensions = {}
	
	# Generate the character bitmaps
	for char in CHARS:
		glyph_start, glyph_end = generate_glyph(char, temp, font, text_height, height)
		glyph_data[char], glyph_width, glyph_height = glyph_to_bits(temp, glyph_end)
		glyph_dimensions[char] = (glyph_width, glyph_start, glyph_end)
	
	
	# Bitmap height
	out += "uint16_t %sHEIGHT = %d;\n"%(prefix, height)
	
	# The number of characters included in the set
	out += "uint16_t %sNUM_CHARS = %d;\n"%(prefix, len(CHARS))
	
	# Generate lookup table from ASCII to char number
	out += "PROGMEM prog_uchar %sASCII_TO_INDEX[] = {\n"%(prefix, )
	for i in range(128):
		out += "\t0x%02X, // '%s'\n"%(
			CHARS.find(chr(i)) & 0xFF,
			chr(i) if chr(i) in CHARS else "[Not included]"
		)
	out = out.rstrip() + "\n};\n"
	
	# Generate character bitmap array
	out += "PROGMEM prog_uchar %sGLYPH_BITMAPS[] = {\n"%(prefix, )
	for c in CHARS:
		out += bytes_to_array_body(glyph_data[c], height)
	out = out.rstrip() + "\n};\n"
	
	# Generate character bitmap array lookup table
	out += "PROGMEM prog_uint16_t %sGLYPH_BITMAPS_LOOKUP[] = {\n"%(prefix, )
	cur_offset = 0
	for c in CHARS:
		out += "\t%d, // '%s'\n"%(cur_offset, c)
		cur_offset += len(glyph_data[c])
	out = out.rstrip() + "\n};\n"
	
	# Generate character width/start/end lookup tables
	out += "PROGMEM prog_uchar %sGLYPH_WIDTH[] = {\n"%(prefix, )
	for c in CHARS:
		out += "\t%2d, // '%s'\n"%(glyph_dimensions[c][0], c)
	out = out.rstrip() + "\n};\n"
	out += "PROGMEM prog_uchar %sGLYPH_START[] = {\n"%(prefix, )
	for c in CHARS:
		out += "\t%2d, // '%s'\n"%(glyph_dimensions[c][1], c)
	out = out.rstrip() + "\n};\n"
	out += "PROGMEM prog_uchar %sGLYPH_END[] = {\n"%(prefix, )
	for c in CHARS:
		out += "\t%2d, // '%s'\n"%(glyph_dimensions[c][2], c)
	out = out.rstrip() + "\n};\n"
	
	print(out)
