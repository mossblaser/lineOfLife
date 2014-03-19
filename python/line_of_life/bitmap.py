#!/usr/bin/env python

"""
Utilites for displaying bitmaps on the display.
"""

import Image, ImageDraw, ImageFont


def pil_to_lol(im, display_height, center = True):
	"""
	A generator which takes a PIL image and produces lines of pixel values
	suitable for the LineOfLife interface. Truncates images too tall for the
	display. Optionally centers images which are too short to fill on the display
	and fills the empty space with "0" pixels. If not centered, images are
	aligned with the top of the display.
	"""
	
	# Convert the image to black and white
	im = im.convert("L")
	
	width, height = im.size
	
	# Truncate the image
	height = min(height, display_height)
	
	# Work through the image
	for column in range(width):
		pixels = []
		
		# Pad the bottom with zeros if too short (and centered)
		bottom_zeros = 0
		if height < display_height and center:
			bottom_zeros = (display_height-height) / 2
			for _ in range(bottom_zeros):
				pixels.append(0)
		
		# Add the pixel data (convert to black-and-white with simple threshold)
		for row in range(height):
			pixels.append(int(im.getpixel((column, height-row-1)) > 128))
		
		# Pad the top half with zeros if too short
		for _ in range(display_height - height - bottom_zeros):
			pixels.append(0)
		
		yield pixels



def text_to_lol(string, display_height, rotate = False, center = True, text_align="center", font=None, font_size=8):
	"""
	Generator function which uses PIL to render a text string for the display.
	Note that this function does *not* perform line-wrapping for lines which don't
	fit on the display. Long lines will be truncated, possibly mid-character.
	
	rotate rotates the text by 90 degrees
	
	center centers the message vertically (after rotation) on the display
	
	text_align selects the text alignment, can be "center", "left" or "right".
	
	font is the filename of a TrueType (ttf) font file. If not given a default
	font is used (for which the size cannot be selected).
	
	font_size gives the font size in points for the selected font.
	"""
	# Load the font
	if font is None:
		pil_font = ImageFont.load_default()
	else:
		pil_font = ImageFont.truetype(font, font_size)
	
	# Work out how big a string will be
	def get_string_size(string):
		im = Image.new("L", (1,1), 0)
		draw = ImageDraw.Draw(im)
		width, height = draw.textsize(string, font=pil_font)
		del draw
		del im
		return width,height
	
	# Split lines of message to render seperately
	lines = string.split("\n")
	
	# Work out size of each line
	line_sizes = []
	for line in lines:
		line_sizes.append(get_string_size(line))
	
	# Get the total image size
	width  = max(w for (w,h) in line_sizes)
	height = sum(h for (w,h) in line_sizes) + len(lines)
	
	# Generate the image
	im = Image.new("L", (width, height), 0)
	draw = ImageDraw.Draw(im)
	for line_num, (line, (line_width,line_height)) in enumerate(zip(lines, line_sizes)):
		y = sum(h+1 for (w,h) in line_sizes[:line_num])
		if text_align == "left":
			x = 0
		elif text_align == "right":
			x = width - line_width
		elif text_align == "center":
			x = (width - line_width)/2
		else:
			raise Exception("Unknown text alignment '%s'"%text_align)
		draw.text((x,y), line, 256, font=pil_font)
	del draw
	
	# Optionally rotate
	if rotate:
		im = im.transpose(Image.ROTATE_90)
	
	return pil_to_lol(im, display_height, center)
