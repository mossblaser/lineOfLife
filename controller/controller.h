#ifndef CONTROLLER_H
#define CONTROLLER_H


////////////////////////////////////////////////////////////////////////////////
// Controller Parameters
////////////////////////////////////////////////////////////////////////////////

// Baudrate of the serial communications with the host
#define BAUD_RATE 115200

// Resolution of the display (vertical resolution must be multiple of 8)
#define VERTICAL_PIXELS   120ul
#define HORIZONTAL_PIXELS 200ul

// Speed of the display
#define DISPLAY_RPM 1.0f

// Display rotation direction
#define STEPPER_CLOCKWISE false

// Stepper motor pins
static const int MOTOR_PINS[4] = {A0,A1,A2,A3};

// Number of stepper steps to rotate the display completely
#define ROTATION_STEPS 4096ul

// Control pins for LED strip
#define nOE_PIN 9
#define LE_PIN  10
//      MOSI    11
//      MISO    12
//      CLK     13

// The fraction of a pixel of which pixel times are a multiple of
#define PIXEL_FRACTION 8

// Number of display buffer slots
#define DISPLAY_BUFFER_LENGTH 8


////////////////////////////////////////////////////////////////////////////////
// Options for the default cellular automata display
////////////////////////////////////////////////////////////////////////////////

// If defined, show a cellular automata demo when nothing has been received
// over serial. If not defined, a logo/error message is shown on the screen.
#define SHOW_AUTOMATA

// The number of frames to display a particular automataon for if it does not
// get stuck at a fix point
#define AUTOMATA_FRAMES (HORIZONTAL_PIXELS / 4)

// The minimum number of frames to show for a rule, even if it isn't changing
#define AUTOMATA_MIN_FRAMES 8

// A set of known-good rules
#define AUTOMATA_KNOWN_GOOD_RULES {18, 22, 26, 30, 45, 54, 57, 60, 90, 106, 110, 122, 126, 146, 150, 154, 184}

////////////////////////////////////////////////////////////////////////////////
// Utilitiy macros
////////////////////////////////////////////////////////////////////////////////

// Number of bytes to represent one column of vertical pixels
#define NUM_VERTICAL_BYTES (VERTICAL_PIXELS/8)

// Number of microseconds between steps
#define STEP_MICROSECONDS (((unsigned long)(60000000.0f / DISPLAY_RPM)) / ROTATION_STEPS)

// The number of steps per a given number of pixel fractions
#define STEPS_PER_PIXEL_FRACTION(n) (((n)*ROTATION_STEPS) / (HORIZONTAL_PIXELS*PIXEL_FRACTION))


////////////////////////////////////////////////////////////////////////////////
// Communication protocol constants
////////////////////////////////////////////////////////////////////////////////

#define PROTOCOL_VERSION 0x1

#define CMD_OPCODE_MASK    0xF0
#define CMD_IMMEDIATE_MASK 0x0F

/**
 * Defines the commands which can be sent to the controller. The bottom four
 * bits of a command are treated as an immediate argument to the command.
 */
typedef enum opcode {
	// No operation.
	//
	// Immediate value: Ignored
	// Arguments: None
	// Returns: Nothing
	OPCODE_NO_OPERATION = 0x00,
	
	// Add a line of pixels to the display buffer.
	//
	// Immediate value: Ignored
	// Arguments: The pixel values as string of bytes in big endian byte order.
	//            There should be exactly the same number of bytes as specified in
	//            the REG_DISPLAY_HEIGHT register divided by 8.
	// Returns: Returns a byte containing the number of free spaces in the display
	//          buffer. The command will not return until there is at least one
	//          free entry in the buffer as a primitive form of flow control.
	OPCODE_PUSH_LINE = 0x10,
	
	// Block until the display buffer has emptied.
	//
	// Immediate value: Ignored
	// Arguments: None
	// Returns: A byte containing an undefined value.
	OPCODE_FLUSH_BUFFER = 0x20,
	
	// Empty the display buffer immediately.
	//
	// Immediate value: Ignored
	// Arguments: None
	// Returns: Nothing
	OPCODE_CLEAR_BUFFER = 0x30,
	
	// Read the value of a control register.
	//
	// Immediate value: The control register address to access (see reg_t).
	// Arguments: None
	// Returns: The value contained in the register as 2 big-endian bytes (16
	//          bits).
	OPCODE_REG_READ = 0x40,
	
	// Write the value of a control register.
	//
	// Immediate value: The control register address to access (see reg_t).
	// Arguments: The value to write to the register as 2 big-endian bytes (16
	//            bits).
	// Returns: Nothing
	OPCODE_REG_WRITE = 0x50,
	
	// Ping the controller and also report protocol version.
	//
	// Immediate value: A value to be echoed back.
	// Arguments: None
	// Returns: A byte whose high nyble contains the protocol version used and the
	//          low nyble contains the immediate value included in the command.
	OPCODE_PING = 0xF0,
} opcode_t;


/**
 * Control register addresses and their purpose.
 */
typedef enum reg {
	// (Read only) The number of vertical pixels in the display, i.e. the number
	// of LEDs.
	REG_DISPLAY_HEIGHT = 0x0,
	
	// (Read only) The number of horizontal pixels in one complete rotation of the
	// display with an aspect ratio of 1:1.
	REG_DISPLAY_WIDTH = 0x1,
	
	// (Read only) The display's RPM. The value is given as a signed number of
	// 1/256ths of a revolution per minute where +ve values are clockwise.
	REG_RPM = 0x2,
	
	// (Read/Write) The aspect ratio of pixels in the display. The ratio of the
	// width of a pixel to its height.
	//
	// The value of the register is given in 1/256ths, that is as an unsigned 8.8
	// fixed point number. Note that the value written to this register may be
	// clamped to some implementation defined range.
	REG_PIXEL_ASPECT_RATIO = 0x3,
	
	// (Read/Write) The amount of time the LEDs are illuminated during the pixels'
	// time for display. This can be used, for example, to give pixels more
	// defined horizontal boundaries by turning off the LEDs for a short period
	// between each pixel.
	//
	// The value written to this register is given in 1/256ths, has a maximum
	// value of 1.0 and may be clamped to an implementation defined range.
	REG_PIXEL_DUTY = 0x4,
	
	// (Read only) The size/occupancy of the display buffer in lines. The top 8
	// bits gives the size of the buffer and the bottom 8 bits the number of items
	// in the buffer (not including the one currently displayed).
	REG_BUFFER_SIZE = 0x5,
} reg_t;



////////////////////////////////////////////////////////////////////////////////
// Stepper-driving definitions
////////////////////////////////////////////////////////////////////////////////


// Series of states which will induce counter-clockwise motion
#define MOTOR_STATE(p0,p1,p2,p3) ( (p0!=LOW)<<0 \
                                 | (p1!=LOW)<<1 \
                                 | (p2!=LOW)<<2 \
                                 | (p3!=LOW)<<3 \
                                 )
const static unsigned char MOTOR_STATES[] = { MOTOR_STATE(HIGH,  LOW,  LOW,  LOW)
                                            , MOTOR_STATE(HIGH, HIGH,  LOW,  LOW)
                                            , MOTOR_STATE( LOW, HIGH,  LOW,  LOW)
                                            , MOTOR_STATE( LOW, HIGH, HIGH,  LOW)
                                            , MOTOR_STATE( LOW,  LOW, HIGH,  LOW)
                                            , MOTOR_STATE( LOW,  LOW, HIGH, HIGH)
                                            , MOTOR_STATE( LOW,  LOW,  LOW, HIGH)
                                            , MOTOR_STATE(HIGH,  LOW,  LOW, HIGH)
                                            };
#define NUM_MOTOR_STATES (sizeof(MOTOR_STATES) / sizeof(unsigned char))


#endif
