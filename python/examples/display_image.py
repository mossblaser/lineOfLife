#!/usr/bin/env python

"""
Display a bitmap given on the command line on the display.
"""

import sys
import serial
import random
import Image

from line_of_life.driver import LineOfLife
from line_of_life.bitmap import pil_to_lol

# Connect to the display
ser = serial.Serial(port = "/dev/ttyUSB0", baudrate = 115200, timeout = 3)
lol = LineOfLife(ser)

# Square pixels
lol.pixel_aspect_ratio = 1
lol.pixel_duty = 1.0

# Clear the display
lol.clear_buffer()

# Display the image
im = Image.open(sys.argv[1])
for line in pil_to_lol(im, lol.display_height):
	lol.push_line(line)
