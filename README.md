Bar-of-Life
===========

A hand-held tool forked from Line-of-Life which allows textual messages to be
printed on UV-sensitive (e.g. glow-in-the-dark) surfaces. Made for the Royal
Institution's Christmas Lectures.

Usage
-----

The display *must* be powered by a 12v source connected to the Arduino's power
jack. It should be connected to a host PC via the Arduino's USB port (see Host
Interface section below).

The device should be placed flat against a glow-in-the-dark surface and moved
smoothly from left-to-right. The microswitch on the bottom of the device
triggers the display of the message.

The speed at which the LEDs are cycled can be adjusted with the blue
potentiometer on the Arduino shield. Anticlockwise = faster, clockwise = slower.

The device also has an optical sensor which is not used. This was intended to be
used to auto-calibrate the speed of the flashing but I didn't manage to get this
working in time.


Host Interface
--------------

The device listens on its serial port (at 115200 baud) for newline ("\n")
terminated messages. Messages should be valid ASCII (i.e. no accents or special
characters) and be relatively short (well under 100 characters).

When a string has been received the device will respond with "OK\r\n" without
the quotes (that is, "OK" followd by a Windows line ending [shudder]).

The device does not respond to any other commands.


Physical Construction
---------------------

The device very crude and consists of a "Line of Life" LED board and a very
rough 3D printed handle. The device is somewhat delicate due to its rather
hurried design and construction (and my lack of experience) so should be treated
with care!
