/**
 * Controller for the Line of Life display.
 */

#include <limits.h>

#include <SPI.h>

#include "TimerOne.h"

#include "controller.h"


////////////////////////////////////////////////////////////////////////////////
// Stepper Motor Driver
////////////////////////////////////////////////////////////////////////////////

// Accumulated number of steps taken.
static volatile unsigned char num_steps;

// Current stepper motor state
static int cur_motor_state = 0;


static void
on_timer_interrupt(void)
{
	// Step the motor
	if (STEPPER_CLOCKWISE) {
		for (int i = 0; i < 4; i++)
			digitalWrite(MOTOR_PINS[4-i-1], (MOTOR_STATES[cur_motor_state] & 1<<i)!=0);
	} else {
		for (int i = 0; i < 4; i++)
			digitalWrite(MOTOR_PINS[i], (MOTOR_STATES[cur_motor_state] & 1<<i)!=0);
	}
	
	num_steps++;
	
	// Advance stepper state
	cur_motor_state ++;
	if (cur_motor_state >= NUM_MOTOR_STATES)
		cur_motor_state = 0;
}


void
motor_setup(void)
{
	// Set up pins
	for (int i = 0; i < 4; i++) {
		pinMode(MOTOR_PINS[i], OUTPUT);
		digitalWrite(MOTOR_PINS[i], LOW);
	}
	
	Timer1.initialize(STEP_MICROSECONDS);
	Timer1.attachInterrupt(on_timer_interrupt);
}

////////////////////////////////////////////////////////////////////////////////
// LED Driving
////////////////////////////////////////////////////////////////////////////////

// Display buffer (head==tail is empty)
unsigned char buf[DISPLAY_BUFFER_LENGTH][NUM_VERTICAL_BYTES];
unsigned int  buf_head=0u;
unsigned int  buf_tail=0u;

// Emergency buffer -- a bitmap to display if no pixels are sent
static unsigned char emg_buf[][NUM_VERTICAL_BYTES] = {
#include "error_bitmap.h"
};
#define EMG_BUF_LENGTH (sizeof(emg_buf) / sizeof(unsigned char[NUM_VERTICAL_BYTES]))
static unsigned int emg_buf_cursor = 0u;


// Current pixel width, in pixel fractions (default to square pixels)
unsigned int cur_pixel_width = PIXEL_FRACTION;

// The amount of the cur_pixel_width (in pixel fractions) the LEDs are on.
unsigned int cur_pixel_duty = cur_pixel_width;


/**
 * Immediately empty the LED line buffer
 */
void
led_buffer_clear()
{
	buf_head = buf_tail = 0;
}


/**
 * Find out if the LED output buffer is empty
 */
bool
is_led_buffer_empty()
{
	return buf_head == buf_tail;
}


/**
 * Insert an item into the buffer. Returns a pointer to the buffer entry which
 * has been allocated or NULL if the buffer is full.
 */
unsigned char *
led_buffer_insert(void)
{
	unsigned int old_tail = buf_tail;
	unsigned int new_tail = (old_tail+1)%DISPLAY_BUFFER_LENGTH;
	if (new_tail == buf_head) {
		// The buffer is full
		return NULL;
	} else {
		buf_tail = new_tail;
		return buf[old_tail];
	}
}


/**
 * Number of free spaces in the buffer.
 */
unsigned int
get_led_buffer_spaces()
{
	return (((int)buf_head - (int)buf_tail) + (int)DISPLAY_BUFFER_LENGTH - 1) % (int)DISPLAY_BUFFER_LENGTH;
}

/**
 * Refresh the LED display if needed
 */
void
led_loop() {
	// Control the duty-cycle of the display
	digitalWrite(nOE_PIN, !(num_steps < STEPS_PER_PIXEL_FRACTION(cur_pixel_duty)));
	
	// Does the display actually need to be refreshed?
	if (num_steps < STEPS_PER_PIXEL_FRACTION(cur_pixel_width))
		return;
	num_steps %= STEPS_PER_PIXEL_FRACTION(cur_pixel_width);
	
	// Work out what to display
	unsigned char *cur_buf;
	if (buf_head == buf_tail) {
		// Empty buffer, show emg message
		cur_pixel_width = PIXEL_FRACTION;
		cur_buf = &(emg_buf[emg_buf_cursor++][0]);
		if (emg_buf_cursor >= EMG_BUF_LENGTH)
			emg_buf_cursor = 0u;
	} else {
		// Consume item from buffer
		cur_buf = &(buf[buf_head++][0]);
		if (buf_head >= DISPLAY_BUFFER_LENGTH)
			buf_head = 0u;
		
		// Also reset the emergency buffer cursor so the emergency buffer starts
		// from scratch when it is next used.
		emg_buf_cursor = 0u;
	}
	
	// Refresh the display
	for (int i = NUM_VERTICAL_BYTES-1; i>=0; i--)
		SPI.transfer(cur_buf[i]);
	digitalWrite(LE_PIN, HIGH);
	digitalWrite(LE_PIN, LOW);
}


////////////////////////////////////////////////////////////////////////////////
// Command Interface
////////////////////////////////////////////////////////////////////////////////


/**
 * Command interface state-machine states.
 */
enum cmd_state {
	// The normal state while not running any particular command.
	CMD_STATE_IDLE,
	
	// Reading in a line of display values from the host
	CMD_STATE_READ_LINE,
	
	// Waiting for the display buffer to become non-full before confirming to the
	// host that this has occurred.
	CMD_STATE_WAIT_UNTIL_BUFFER_NOT_FULL,
	
	// Waiting for the display buffer to become flushed.
	CMD_STATE_FLUSH,
	
	// Waiting for a register's write data to arrive
	CMD_STATE_READ_REG_VALUE,
} cmd_state = CMD_STATE_IDLE;


/**
 * The register which will be written in the CMD_STATE_READ_REG_VALUE state.
 */
reg_t selected_register;


unsigned int
cmd_read_reg(reg_t reg)
{
	switch (reg) {
		case REG_DISPLAY_HEIGHT: return VERTICAL_PIXELS;   break;
		case REG_DISPLAY_WIDTH:  return HORIZONTAL_PIXELS; break;
		case REG_RPM:            return DISPLAY_RPM;       break;
		
		case REG_PIXEL_ASPECT_RATIO:
			// Convert to fixed point 8.8
			return (cur_pixel_width<<8) / PIXEL_FRACTION;
		
		case REG_PIXEL_DUTY_CYCLE:
			// Convert to fixed point 0.16 (lossily by finding the 8.8 and
			// scaling to 0.16, but this is fine for most realistic duty
			// cycles)
			return (cur_pixel_duty<<8 / cur_pixel_width)<<8;
		
		case REG_BUFFER_SIZE:
			return (DISPLAY_BUFFER_LENGTH-1)<<16 | get_led_buffer_spaces();
		
		default:
			// Return 0xDEAD for nonexistant registers
			return 0xDEADu;
	}
}

void
cmd_write_reg(reg_t reg, unsigned int value)
{
	switch (reg) {
		// Read-only registers
		default:
		case REG_DISPLAY_HEIGHT:
		case REG_DISPLAY_WIDTH:
		case REG_RPM:
		case REG_BUFFER_SIZE:
			break;
		
		case REG_PIXEL_ASPECT_RATIO:
			{
				unsigned int old_pixel_width = cur_pixel_width;
				// Convert from fixed point 8.8
				cur_pixel_width == (PIXEL_FRACTION<<8) / value;
				// Clamp value 
				if (cur_pixel_width <= 0)
					cur_pixel_width = 1u;
				
				// Scale the duty to match the new pixel width
				cur_pixel_duty = (cur_pixel_width*cur_pixel_duty) / old_pixel_width;
				// Clamp value
				if (cur_pixel_duty <= 0)
					cur_pixel_duty = 1u;
			}
			break;
		
		case REG_PIXEL_DUTY_CYCLE:
			// Convert from fixed point 0.16, convert to 8.8 and then multiply.
			cur_pixel_duty = ((value>>8) * cur_pixel_width)>>8;
			// Clamp value
			if (cur_pixel_duty <= 0)
				cur_pixel_duty = 1u;
			break;
	}
}


/**
 * Execute one iteration of the command evaluating state machine. This should be
 * interleaved with the LED driving state machine for propper operation.
 */
void
cmd_loop(void)
{
	switch (cmd_state) {
		case CMD_STATE_IDLE:
			// Try and read a command
			if (Serial.available()) {
				unsigned char cmd      = Serial.read();
				opcode_t opcode        = (opcode_t)(cmd & CMD_OPCODE_MASK);
				unsigned int immediate = cmd & CMD_IMMEDIATE_MASK;
				
				switch (opcode) {
					// Unrecognised commands are ignored
					default:
					case OPCODE_NO_OPERATION:
						return;
					
					case OPCODE_PUSH_LINE:
						cmd_state = CMD_STATE_READ_LINE;
						break;
					
					case OPCODE_FLUSH_BUFFER:
						cmd_state = CMD_STATE_FLUSH;
						break;
					
					case OPCODE_CLEAR_BUFFER:
						led_buffer_clear();
						break;
					
					case OPCODE_REG_READ:
						{
							unsigned int reg_value = cmd_read_reg((reg_t)immediate);
							Serial.write((unsigned char)(reg_value>>8u));
							Serial.write((unsigned char)(reg_value&0x0Fu));
						}
						break;
					
					case OPCODE_REG_WRITE:
						cmd_state = CMD_STATE_READ_REG_VALUE;
						selected_register = (reg_t)immediate;
						break;
					
					case OPCODE_PING:
						Serial.write((unsigned char)(PROTOCOL_VERSION<<4u | ((unsigned char)immediate)));
						break;
				}
			}
			break;
		
		case CMD_STATE_READ_LINE:
			// Wait for a full line of input to arrive for the display
			if (Serial.available() >= NUM_VERTICAL_BYTES) {
				// Place the pixels in the buffer
				unsigned char *buffer = led_buffer_insert();
				if (buffer == NULL) {
					// Discard the data, for some reason we tried to over-fill the buffer
					for (int i = 0; i < NUM_VERTICAL_BYTES; i++)
						Serial.read();
				} else {
					for (int i = 0; i < NUM_VERTICAL_BYTES; i++)
						buffer[i] = Serial.read();
				}
				// Potentially block until the buffer has more space
				cmd_state = CMD_STATE_WAIT_UNTIL_BUFFER_NOT_FULL;
			}
			break;
		
		case CMD_STATE_WAIT_UNTIL_BUFFER_NOT_FULL:
			{
				// Allow the host to un-block the system by sending another command
				if (Serial.available()) {
					cmd_state = CMD_STATE_IDLE;
					break;
				}
				
				// Block until there are free spaces in the output buffer
				unsigned int free_spaces = get_led_buffer_spaces();
				if (free_spaces) {
					Serial.write(free_spaces);
					cmd_state = CMD_STATE_IDLE;
				}
			}
			break;
		
		case CMD_STATE_FLUSH:
			// Allow the host to un-block the system by sending another command
			if (Serial.available()) {
				cmd_state = CMD_STATE_IDLE;
				break;
			}
			
			// Block until the number of free spaces is equal to the size of the
			// buffer
			if (is_led_buffer_empty()) {
				Serial.write(0xFF);
				cmd_state = CMD_STATE_IDLE;
			}
			break;
		
		case CMD_STATE_READ_REG_VALUE:
			if (Serial.available() >= 2) {
				// Read the new value
				unsigned int value = Serial.read();
				value = (value<<8u) | Serial.read();
				
				// Write to the register
				cmd_write_reg(selected_register, value);
				cmd_state = CMD_STATE_IDLE;
			}
			break;
		
		default:
			cmd_state = CMD_STATE_IDLE;
	}
}


////////////////////////////////////////////////////////////////////////////////
// Main program
////////////////////////////////////////////////////////////////////////////////


void setup() {
	Serial.begin(BAUD_RATE);
	
	SPI.begin();
	SPI.setBitOrder(MSBFIRST);
	SPI.setClockDivider(SPI_CLOCK_DIV16); // 16MHz/16 = 1MHz
	SPI.setDataMode(SPI_MODE0); // Posedge sensitive, Clock Idle Low
	
	motor_setup();
	
	pinMode(LE_PIN, OUTPUT);
	pinMode(nOE_PIN, OUTPUT);
	
	digitalWrite(LE_PIN, LOW);
	digitalWrite(nOE_PIN, LOW);
}


void loop() {
	cmd_loop();
	led_loop();
}
