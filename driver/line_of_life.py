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
	# display with the current pixel aspect ratio. Changing the value of
	# REG_PIXEL_ASPECT_RATIO will change this value.
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
	# The value written to this register is given in 1/(2^16)ths and may be
	# clamped to an implementation defined range.
	REG_PIXEL_DUTY_CYCLE = 0x4
	
	# (Read only) The size/occupancy of the display buffer in lines. The top 8
	# bits gives the size of the buffer and the bottom 8 bits the number of items
	# in the buffer (including the one currently displayed).
	REG_BUFFER_SIZE = 0x5
	
	
	def __init__(self, pipe):
		"""
		Connect to a line of life display at the end of the given pipe, for example
		a Serial connection.
		"""
		
		self.pipe = pipe
		
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
		
		self._cmd_ping()
	
	
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
		
		return ord(self.pipe.read())<<8 | ord(self.pipe.read())
	
	
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
# Example usage
################################################################################

if __name__=="__main__":
	import serial
	import time
	ser = serial.Serial(port = "/dev/ttyUSB0", baudrate = 115200, timeout = 1)
	
	lol = LineOfLife(ser)
	for _ in range(5):
		lol._cmd_push_line("\xFF"*(120/8))
		lol._cmd_push_line("\x55"*(120/8))
		lol._cmd_push_line("\xAA"*(120/8))
		lol._cmd_push_line("\x55"*(120/8))
		lol._cmd_push_line("\xFF"*(120/8))
		lol._cmd_push_line("\x00"*(120/8))
		lol._cmd_push_line("\x00"*(120/8))
	
