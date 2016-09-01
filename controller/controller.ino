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
// Automata rendering (for when the host is not sending anything...)
////////////////////////////////////////////////////////////////////////////////

#ifdef SHOW_AUTOMATA

// The bitmap of the text to display before showing each rule is displayed
static unsigned char presenting_msg[][NUM_VERTICAL_BYTES] = {
#include "presenting_bitmap.h"
};
#define PRESENTING_MSG_LENGTH (sizeof(presenting_msg) / sizeof(unsigned char[NUM_VERTICAL_BYTES]))

// The bitmaps of the numbers
static unsigned char numbers[10][PRESENTING_MSG_LENGTH] = {
#include "number_bitmaps.h"
};

typedef enum {
	// Pick a rule to demonstrate and output a blank line to seperate off the
	// previous image.
	AUTOMATA_MODE_PICK_RULE,
	
	// Output some text stating which rule is about to be shown
	AUTOMATA_MODE_TEXT,
	
	// Generate and display an initial state for the automaton
	AUTOMATA_MODE_INITIAL_STATE,
	
	// Run the cellular automaton and output the current state (for a while).
	AUTOMATA_MODE_RUN,
} automata_mode_t;

/**
 * Returns a pointer to a line of display graphics to show which (over time)
 * illustrates the operation of a 1D cellular automata. Call once per line.
 */
unsigned char *get_automata_frame() {
	static automata_mode_t mode = AUTOMATA_MODE_PICK_RULE;
	
	// The current rule to use
	static int rule = 0;
	
	// The current frame number for this automaton
	static int frame = AUTOMATA_FRAMES;
	
	// Buffers holding the current state and a second buffer to write the new
	// state into. Flipped after each update. Though in principle only one buffer
	// is needed, having two a: simplifies life a little but mostly b: means we
	// can check if the automata actually does anything!
	static unsigned char buf_a[NUM_VERTICAL_BYTES] = {1};
	static unsigned char buf_b[NUM_VERTICAL_BYTES] = {1};
	static unsigned char *cur_state = buf_a;
	static unsigned char *next_state = buf_b;
	
	switch (mode) {
		
		case AUTOMATA_MODE_PICK_RULE:
			// Pick a new rule. With a 75% chance, pick a known good one
			if (random(4) == 0) {
				rule = random(0x00, 0xFF + 1);
			} else {
				int good_rules[] = AUTOMATA_KNOWN_GOOD_RULES;
				rule = good_rules[random(sizeof(good_rules) / sizeof(good_rules[0]))];
			}
			
			mode = AUTOMATA_MODE_TEXT;
			frame = 0;
			
			// Display a blank line
			for (int byte_num = 0; byte_num < NUM_VERTICAL_BYTES; byte_num++)
				cur_state[byte_num] = 0;
			return cur_state;
		
		case AUTOMATA_MODE_TEXT:
			// The fixed text
			for (int byte_num = 0; byte_num < NUM_VERTICAL_BYTES; byte_num++)
				cur_state[byte_num] = presenting_msg[frame][byte_num];
			
			// Add the rule number to the text
			{
				int offset = NUM_VERTICAL_BYTES - 3;
				int hundreds = rule / 100;
				int tens = (rule - (hundreds * 100)) / 10;
				int units = rule - (hundreds * 100) - (tens * 10);
				if (hundreds)
					cur_state[offset++] = numbers[hundreds][frame];
				if (hundreds || tens)
					cur_state[offset++] = numbers[tens][frame];
				cur_state[offset++] = numbers[units][frame];
			}
			
			frame++;
			if (frame >= PRESENTING_MSG_LENGTH) {
				mode = AUTOMATA_MODE_INITIAL_STATE;
				frame = 0;
			}
			
			return cur_state;
		
		case AUTOMATA_MODE_INITIAL_STATE:
			// Chose a starting state (either random or a single pixel)
			if (random(2) == 0) {
				// Random
				for (int byte_num = 0; byte_num < NUM_VERTICAL_BYTES; byte_num++)
					cur_state[byte_num] = random(0x00, 0xFF + 1);
			} else {
				// Single pixel
				for (int byte_num = 0; byte_num < NUM_VERTICAL_BYTES; byte_num++)
					cur_state[byte_num] = 0;
				cur_state[NUM_VERTICAL_BYTES / 2] = 1<<4;
			}
			
			mode = AUTOMATA_MODE_RUN;
			frame = 0;
			
			return cur_state;
		
		case AUTOMATA_MODE_RUN:
			// Compute next automata state
			for (int bit_num = 0; bit_num < VERTICAL_PIXELS; bit_num++) {
				int cur_byte_num =  bit_num / 8;
				int cur_bit_index = bit_num % 8;
				int prev_byte_num =  (bit_num-1) / 8;
				int prev_bit_index = (bit_num-1) % 8;
				int next_byte_num =  (bit_num+1) / 8;
				int next_bit_index = (bit_num+1) % 8;
				
				unsigned char cur_byte = cur_state[cur_byte_num];
				unsigned char prev_byte = (prev_byte_num >= 0 &&
				                           prev_byte_num < NUM_VERTICAL_BYTES)
				                          ? cur_state[prev_byte_num]
				                          : 0;
				unsigned char next_byte = (next_byte_num >= 0 &&
				                           next_byte_num < NUM_VERTICAL_BYTES)
				                          ? cur_state[next_byte_num]
				                          : 0;
				
				bool cur_bit = (cur_byte >> cur_bit_index) & 1;
				bool prev_bit = (prev_byte >> prev_bit_index) & 1;
				bool next_bit = (next_byte >> next_bit_index) & 1;
				
				next_state[cur_byte_num] = (next_state[cur_byte_num] & ~(1<<cur_bit_index))
				                           | (((rule >> ((prev_bit << 0) +
				                                         (cur_bit  << 1) +
				                                         (next_bit << 2))) & 1) << cur_bit_index);
			}
			
			// Flip the two buffers
			{
				unsigned char *tmp = cur_state;
				cur_state = next_state;
				next_state = tmp;
			}
			
			// If the state hasn't meaningfully changed or we've run for long enough,
			// move on to the next state
			{
				frame++;
				
				bool changed = false;
				for (int byte_num = 0; byte_num < NUM_VERTICAL_BYTES; byte_num++)
					changed |= cur_state[byte_num] != next_state[byte_num];
				
				if ((frame > AUTOMATA_MIN_FRAMES && !changed) ||
				    frame >= AUTOMATA_FRAMES)
					mode = AUTOMATA_MODE_PICK_RULE;
			}
			
			return cur_state;
		
		default:
			mode = AUTOMATA_MODE_PICK_RULE;
			return cur_state;
	}
}

#endif

////////////////////////////////////////////////////////////////////////////////
// LED Driving
////////////////////////////////////////////////////////////////////////////////

// Display buffer (head==tail is empty)
unsigned char buf[DISPLAY_BUFFER_LENGTH][NUM_VERTICAL_BYTES];
unsigned int  buf_head=0u;
unsigned int  buf_tail=0u;

// Emergency buffer -- a bitmap to display if no pixels are sent
#ifndef SHOW_AUTOMATA
static unsigned char emg_buf[][NUM_VERTICAL_BYTES] = {
#include "error_bitmap.h"
};
#define EMG_BUF_LENGTH (sizeof(emg_buf) / sizeof(unsigned char[NUM_VERTICAL_BYTES]))
static unsigned int emg_buf_cursor = 0u;
#endif


// Current pixel width, in pixel fractions (default to square pixels)
unsigned int cur_pixel_width = PIXEL_FRACTION;
unsigned int next_pixel_width = PIXEL_FRACTION;

// The amount of the cur_pixel_width (in pixel fractions) the LEDs are on.
unsigned int cur_pixel_duty = PIXEL_FRACTION;
unsigned int next_pixel_duty = PIXEL_FRACTION;


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
 * Set the width of the next pixel to be displayed.
 */
void
led_set_pixel_width(unsigned int pixel_width)
{
	unsigned int old_pixel_width = next_pixel_width;
	
	next_pixel_width = pixel_width;
	// Clamp value 
	if (next_pixel_width <= 0)
		next_pixel_width = 1u;
	
	// Scale the duty to match the new pixel width
	led_set_pixel_duty((next_pixel_width*led_get_pixel_duty()) / old_pixel_width);
}


/**
 * Get the width of the next pixel to be displayed.
 */
unsigned int
led_get_pixel_width(void)
{
	return next_pixel_width;
}


/**
 * Set the duty of the next pixel to be displayed.
 */
void
led_set_pixel_duty(unsigned int pixel_duty)
{
	next_pixel_duty = pixel_duty;
	// Clamp value
	if (next_pixel_duty <= 0)
		next_pixel_duty = 1u;
	else if (next_pixel_duty > led_get_pixel_width())
		next_pixel_duty = led_get_pixel_width();
}


/**
 * Get the duty of the next pixel to be displayed.
 */
unsigned int
led_get_pixel_duty(void)
{
	return next_pixel_duty;
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
	
	// Only maintain the period if the pixel width hasn't changed
	if (cur_pixel_width != next_pixel_width)
		num_steps = 0;
	else
		num_steps %= STEPS_PER_PIXEL_FRACTION(cur_pixel_width);
	
	// Update the pixel duty and width
	cur_pixel_width = next_pixel_width;
	cur_pixel_duty  = next_pixel_duty;
	
	// Work out what to display
	unsigned char *cur_buf;
	if (buf_head == buf_tail) {
#ifdef SHOW_AUTOMATA
		// Empty buffer, run the automata demo
		cur_buf = get_automata_frame();
#else
		// Empty buffer, show 'emergency' message
		cur_buf = &(emg_buf[emg_buf_cursor++][0]);
		if (emg_buf_cursor >= EMG_BUF_LENGTH)
			emg_buf_cursor = 0u;
#endif
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
		case REG_DISPLAY_HEIGHT: return VERTICAL_PIXELS;           break;
		case REG_DISPLAY_WIDTH:  return HORIZONTAL_PIXELS;         break;
		case REG_RPM:            return (int)(DISPLAY_RPM*(1<<8)); break;
		
		case REG_PIXEL_ASPECT_RATIO:
			// Convert to fixed point 8.8
			return (led_get_pixel_width()<<8) / PIXEL_FRACTION;
		
		case REG_PIXEL_DUTY:
			// Convert to fixed point 8.8
			return (led_get_pixel_duty()<<8) / led_get_pixel_width();
		
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
			// Convert from fixed point 8.8
			led_set_pixel_width((PIXEL_FRACTION * value)>>8);
			break;
		
		case REG_PIXEL_DUTY:
			// Find number of pixel fractions in 8.8 and then convert to integer.
			led_set_pixel_duty((value * led_get_pixel_width())>>8);
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
							Serial.write((unsigned char)(reg_value&0xFFu));
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
			
			// Block until the buffer is empty
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
	randomSeed(analogRead(5));
	
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
	led_loop();
	cmd_loop();
}
