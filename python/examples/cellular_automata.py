#!/usr/bin/env python

"""
A quick-and-dirty 1D cellular automata demo. Displays randomly initialised
automata with random rules.

See http://en.wikipedia.org/wiki/Elementary_cellular_automaton for more details
of this class of automata.
"""

import serial
import random

from line_of_life import LineOfLife

# Connect to the display
ser = serial.Serial(port = "/dev/ttyUSB0", baudrate = 115200, timeout = 3)
lol = LineOfLife(ser)

# Clear the display's current buffer to start displaying the new automata
# immediately.
lol.clear_buffer()

lol.pixel_aspect_ratio = 1
lol.pixel_duty = 1.0

# A mask for the bits representing the cells of the automata
mask = (1l<<lol.display_height)-1

while True:
	# Pick a random rule to show
	rule = int(random.random()*0xFF)
	
	
	# Flush the buffer, that way the print statement will not happen until the
	# next automata is actually due to appear on the display
	lol.flush_buffer()
	print "Presenting Rule %d"%rule
	
	# Random initial state
	state = sum(1l<<n for n in range(lol.display_height) if random.random()<0.5)
LineOfLife interface.
	# Run this automata for one quarter of a rotation
	for _ in range(lol.display_width/4):
		# Calculate the new automata state
		new_state = 0l
		state <<= 1
		for bit_num in range(1, lol.display_height+1):
			new_state |= ((rule>>((state>>(bit_num-1))&0b111))&1)<<(bit_num-1)
		
		# Move on to another automata immediately if this one doesn't change
		if (state>>1) == new_state&mask:
			break
		
		state = new_state&mask
		
		# Push the line to the display
		lol.push_line([state&(1<<y) for y in range(lol.display_height)])
	
	# Put a blank space between different automata
	for _ in range(5):
		lol.push_line([0] * lol.display_height)
