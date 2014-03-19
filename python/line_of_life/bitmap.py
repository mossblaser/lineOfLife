#!/usr/bin/env python

"""
Utilites for displaying bitmaps on the display.
"""

import Image


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
			pixels.append(int(im.getpixel((column, height-row-1)) > 0.5))
		
		# Pad the top half with zeros if too short
		for _ in range(display_height - height - bottom_zeros):
			pixels.append(0)
		
		yield pixels

