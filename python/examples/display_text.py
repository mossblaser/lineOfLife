#!/usr/bin/env python

"""
Display a message given on the command line on the display.
"""

import sys
import serial
import random

from line_of_life.driver import LineOfLife
from line_of_life.bitmap import text_to_lol

# Connect to the display
ser = serial.Serial(port = "/dev/ttyUSB0", baudrate = 115200, timeout = 3)
lol = LineOfLife(ser)

# Square pixels
lol.pixel_aspect_ratio = 1
lol.pixel_duty = 1.0

# Display the message (interpreting newlines)
for line in text_to_lol( sys.argv[1].replace("\\n","\n")
                       , lol.display_height
                       , rotate = True
                       ):
	lol.push_line(line)
