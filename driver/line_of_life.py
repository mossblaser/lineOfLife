#!/usr/bin/env python

"""
An implementation of and library for the host interface to the Line of Life
controller.
"""

import random


class ProtocolError(Exception):
	"""
	Errors thrown by violations of the LineOfLife protocol.
	"""
	pass


class LineOfLife(object):
	"""
	A (blocking) interface to the Line of LIfe display hardware.
	"""
	
	
	def __init__(self, pipe):
		"""
		Connect to a line of life display at the end of the given pipe, for example
		a Serial connection.
		"""
		
		self.pipe = pipe
		
		# Cached display constants
		self._display_height = None
		self._display_width = None
		
		# Re-sync on first connection
		self.resync()
	
	
	def resync(self):
		"""
		Resynchronise with the controller putting it into the idle state.
		"""
		# Since all blocking commands are terminated by sending a command and no
		# command accepts an infinite number of arguments sending a long stream of
		# NOPs will guarantee the device will end up in the command-accepting state.
		
		for _ in range(100):
			self._cmd_no_operation()
		
		# Ignore any incoming unconsumed bytes
		if hasattr(self.pipe, "flushInput"):
			self.pipe.flushInput()
		
		self._cmd_ping()
	
	
	def push_line(self, line):
		"""
		Push a line of pixels to the display. The pixel values should be given as a
		list of pixel values of length self.display_height. This method blocks when
		the device's on-board buffer is full.
		"""
		assert len(line) == self.display_height \
		     , "Display line must match display height."
		
		line_str = ""
		for byte_offset in range(0, self.display_height, 8):
			byte = 0
			for bit_num in range(7,-1,-1):
				byte <<= 1
				byte |= int(bool(line[byte_offset + bit_num]))
			line_str += chr(byte)
		
		self._cmd_push_line(line_str)
	
	def flush_buffer(self):
		"""
		Block until the device's buffer is empty. Returns as soon as the last item
		from the buffer is sent to the display.
		
		This should be used before changing device settings such as the pixel aspect
		ratio and duty to ensure only subsequent added lines are effected.
		"""
		# Simply a thin wrapper around the native command
		self._cmd_flush_buffer()
	
	
	def clear_buffer(self):
		"""
		Forcibly empty the device's display buffer. The pixel currently displayed
		will not be interrupted.
		"""
		# Simply a thin wrapper around the native command
		self._cmd_clear_buffer()
	
	
	################################################################################
	# Device settings/information
	################################################################################
	
	@property
	def display_height(self):
		"""
		Read only. Get the display height in pixels (also the number of LEDs).
		
		Internally caches this value the first time it is read.
		"""
		if self._display_height is None:
			self._display_height = self._cmd_reg_read(self.REG_DISPLAY_HEIGHT)
		
		return self._display_height
	
	
	@property
	def display_width(self):
		"""
		Read only. Get the display width in pixels (the number of pixels in one
		complete rotation with a pixel aspect ratio of 1:1.
		
		Internally caches this value the first time it is read.
		"""
		if self._display_width is None:
			self._display_width = self._cmd_reg_read(self.REG_DISPLAY_WIDTH)
		
		return self._display_width
	
	
	@property
	def rpm(self):
		"""
		Read only. The display rotation speed in RPM.
		"""
		raw_rpm = self._cmd_reg_read(self.REG_RPM)
		
		# Sign extend
		raw_rpm |= -1<<16 if raw_rpm&0x8000 else 0
		
		# Convert from fixed point to floating point
		return float(raw_rpm) / float(1<<8)
	
	
	@property
	def pixel_aspect_ratio(self):
		"""
		The size of the pixel width as a proportion of a pixel's height.
		"""
		raw_aspect_ratio = self._cmd_reg_read(self.REG_PIXEL_ASPECT_RATIO)
		
		# Convert to a floating point number
		return float(raw_aspect_ratio) / float(1<<8)
	
	
	@pixel_aspect_ratio.setter
	def pixel_aspect_ratio(self, aspect_ratio):
		"""
		The size of the pixel width as a proportion of a pixel's height.
		"""
		assert aspect_ratio > 0.0 \
		     , "Cannot have negative or zero aspect ratio."
		
		# Convert to fixed point
		raw_aspect_ratio = int(aspect_ratio*(1<<8))
		
		# Truncate (as required) and write back
		self._cmd_reg_write(self.REG_PIXEL_ASPECT_RATIO, raw_aspect_ratio & 0xFFFF)
	
	
	@property
	def pixel_duty(self):
		"""
		The proportion of the time pixels are lit during their time for display. Can
		be used to add clean divisions between pixels.
		"""
		raw_duty = self._cmd_reg_read(self.REG_PIXEL_DUTY)
		
		# Convert to a floating point number
		return float(raw_duty) / float(1<<8)
	
	
	@pixel_duty.setter
	def pixel_duty(self, duty):
		"""
		The proportion of the time pixels are lit during their time for display. Can
		be used to add clean divisions between pixels.
		"""
		assert 0.0 < duty <= 1.0 \
		     , "Duty must be between 0 and 1."
		
		# Convert to fixed point
		raw_duty = int(duty*(1<<8))
		
		# Truncate (as required) and write back
		self._cmd_reg_write(self.REG_PIXEL_DUTY, raw_duty & 0xFFFF)
	
	
	@property
	def buffer_size(self):
		"""
		Read only. Returns a tuple (size, free_spaces) representing the current size
		and state of the display buffer.
		"""
		response = self._cmd_reg_read(self.REG_BUFFER_SIZE)
		return (response>>8, response&0xFF)
	
	
	PROTOCOL_VERSION = 0x1
	
	################################################################################
	# Command Opcodes
	################################################################################
	
	# Defines the commands which can be sent to the controller. The bottom four
	# bits of a command are treated as an immediate argument to the command.
	# No operation.
	#
	# Immediate value: Ignored
	# Arguments: None
	# Returns: Nothing
	OPCODE_NO_OPERATION = 0x00
	
	# Add a line of pixels to the display buffer.
	#
	# Immediate value: Ignored
	# Arguments: The pixel values as string of bytes in big endian byte order.
	#            There should be exactly the same number of bytes as specified in
	#            the REG_DISPLAY_HEIGHT register divided by 8.
	# Returns: Returns a byte containing the number of free spaces in the display
	#          buffer. The command will not return until there is at least one
	#          free entry in the buffer as a primitive form of flow control.
	OPCODE_PUSH_LINE = 0x10
	
	# Block until the display buffer has emptied.
	#
	# Immediate value: Ignored
	# Arguments: None
	# Returns: A byte containing an undefined value.
	OPCODE_FLUSH_BUFFER = 0x20
	
	# Empty the display buffer immediately.
	#
	# Immediate value: Ignored
	# Arguments: None
	# Returns: Nothing
	OPCODE_CLEAR_BUFFER = 0x30
	
	# Read the value of a control register.
	#
	# Immediate value: The control register address to access (see reg_t).
	# Arguments: None
	# Returns: The value contained in the register as 2 big-endian bytes (16
	#          bits).
	OPCODE_REG_READ = 0x40
	
	# Write the value of a control register.
	#
	# Immediate value: The control register address to access (see reg_t).
	# Arguments: The value to write to the register as 2 big-endian bytes (16
	#            bits).
	# Returns: Nothing
	OPCODE_REG_WRITE = 0x50
	
	# Ping the controller and also report protocol version.
	#
	# Immediate value: A value to be echoed back.
	# Arguments: None
	# Returns: A byte whose high nyble contains the protocol version used and the
	#          low nyble contains the immediate value included in the command.
	OPCODE_PING = 0xF0
	
	
	################################################################################
	# Register Identifiers
	################################################################################
	
	# Control register addresses and their purpose.
	# (Read only) The number of vertical pixels in the display, i.e. the number
	# of LEDs.
	REG_DISPLAY_HEIGHT = 0x0
	
	# (Read only) The number of horizontal pixels in one complete rotation of the
	# display with an aspect ratio of 1:1.
	REG_DISPLAY_WIDTH = 0x1
	
	# (Read only) The display's RPM. The value is given as a signed number of
	# 1/256ths of a revolution per minute where +ve values are clockwise.
	REG_RPM = 0x2
	
	# (Read/Write) The aspect ratio of pixels in the display. The ratio of the
	# width of a pixel to its height.
	#
	# The value of the register is given in 1/256ths, that is as an unsigned 8.8
	# fixed point number. Note that the value written to this register may be
	# clamped to some implementation defined range.
	REG_PIXEL_ASPECT_RATIO = 0x3
	
	# (Read/Write) The amount of time the LEDs are illuminated during the pixels'
	# time for display. This can be used, for example, to give pixels more
	# defined horizontal boundaries by turning off the LEDs for a short period
	# between each pixel.
	#
	# The value written to this register is given in 1/256ths, has a maximum
	# value of 1.0 and may be clamped to an implementation defined range.
	REG_PIXEL_DUTY = 0x4
	
	# (Read only) The size/occupancy of the display buffer in lines. The top 8
	# bits gives the size of the buffer and the bottom 8 bits the number of items
	# (not including the one currently displayed)
	REG_BUFFER_SIZE = 0x5
	
	
	################################################################################
	# Low-level display driver commands.
	################################################################################
	
	def _cmd_no_operation(self):
		"""
		Send a no-operation command to the display.
		"""
		self.pipe.write(chr(self.OPCODE_NO_OPERATION))
	
	
	def _cmd_push_line(self, line):
		"""
		Send a line of pixel data to this display. The data should be given as a
		string of the correct length for the display. This command blocks until the
		device has at least one free space in its display buffer, i.e.  this command
		is self rate-limiting.
		
		Returns the number of remaining display buffer entries.
		
		Warning: The length of the data supplied is not checked and providing the
		wrong length for the display is a protocol violation.
		"""
		self.pipe.write(chr(self.OPCODE_PUSH_LINE))
		self.pipe.write(line)
		
		return ord(self.pipe.read(1))
	
	
	def _cmd_flush_buffer(self):
		"""
		Block until the display buffer has emptied.
		"""
		self.pipe.write(chr(self.OPCODE_FLUSH_BUFFER))
		self.pipe.read(1)
	
	
	def _cmd_clear_buffer(self):
		"""
		Forcibly, and immediately, empty the buffer of the display.
		"""
		self.pipe.write(chr(self.OPCODE_CLEAR_BUFFER))
	
	
	def _cmd_reg_read(self, register):
		"""
		Read the requested register from the controller. Returns an unsigned 16-bit
		integer.
		"""
		if register&0xF != register:
			raise ProtocolError("Register number 0x%X does not exist."%register)
		
		self.pipe.write(chr(self.OPCODE_REG_READ | register))
		
		hbyte = self.pipe.read()
		lbyte = self.pipe.read()
		return (ord(hbyte)<<8) | ord(lbyte)
	
	
	def _cmd_reg_write(self, register, value):
		"""
		Write the specified value to the controller. The value must be an unsigned
		16-bit integer.
		"""
		if register&0xF != register:
			raise ProtocolError("Register number 0x%X does not exist."%register)
		
		if value&0xFFFF != value:
			raise ProtocolError("Value '%s' not 16-bit unsigned integer."%repr(value))
		
		self.pipe.write(chr(self.OPCODE_REG_WRITE | register))
		self.pipe.write(chr(value>>8))
		self.pipe.write(chr(value&0xFF))
	
	
	def _cmd_ping(self, nonce = None):
		"""
		Send a ping to the controller, optionally specifying the nonce to attach. If
		non supplied, a random value will be used.
		"""
		if nonce is None:
			nonce = int(random.random()*(1<<4))
		nonce &= 0xF
		
		self.pipe.write(chr(self.OPCODE_PING | nonce))
		
		pong = ord(self.pipe.read(1))
		version    = pong>>4
		pong_nonce = pong & 0xF
		
		if version != self.PROTOCOL_VERSION:
			raise ProtocolError("Unsupported protocol version 0x%X (expected 0x%X)."%(version, self.PROTOCOL_VERSION))
		
		if pong_nonce != nonce:
			raise ProtocolError("Ping returned wrong nonce 0x%X (expected 0x%X)."%(pong_nonce, nonce))



################################################################################
# Example usage: A very quick'n'dirty 1D cellular automata demo
################################################################################

if __name__=="__main__":
	import serial
	import time
	import math
	
	ser = serial.Serial(port = "/dev/ttyUSB0", baudrate = 115200, timeout = 3)
	lol = LineOfLife(ser)
	
	lol.pixel_aspect_ratio = 1
	lol.pixel_duty = 1.0
	
	# A quick-and-dirty 1D cellular automata
	mask  = (1l<<lol.display_height)-1
	
	while True:
		# Random rule
		rule = random.choice([30, 90, 110, 184])
		rule = random.choice([110])
		rule = int(random.random()*0xFF)
		
		print "Presenting Rule %d"%rule
		
		# Random initial state
		state = sum(1l<<n for n in range(lol.display_height) if random.random()<0.5)
		
		for _ in range(lol.display_width/4):
			# Calculate the new state
			new_state = 0l
			state <<= 1
			for bit_num in range(1, lol.display_height+1):
				new_state |= ((rule>>((state>>(bit_num-1))&0b111))&1)<<(bit_num-1)
			
			# Skip if the automata just shows a constant pattern
			if (state>>1) == new_state&mask:
				break;
			else:
				state = new_state&mask
			
			# Push the line to the display
			lol.push_line([state&(1<<y) for y in range(lol.display_height)])
		
		# Put a blank space between different automata
		lol.push_line([0] * lol.display_height)
		lol.push_line([0] * lol.display_height)
		lol.push_line([0] * lol.display_height)
		lol.push_line([0] * lol.display_height)
		lol.flush_buffer()
	
	lol.pixel_aspect_ratio = 1
	lol.pixel_duty = 1

