/**
 * Controller for the Line of Life display.
 */

#include <SPI.h>

#include "TimerOne.h"


////////////////////////////////////////////////////////////////////////////////
// Controller Parameters
////////////////////////////////////////////////////////////////////////////////


// Resolution of the display (vertical resolution must be multiple of 8)
#define VERTICAL_PIXELS   120ul
#define HORIZONTAL_PIXELS 200ul

// Speed of the display
#define DISPLAY_RPM 1.0f

// Display rotation direction
#define STEPPER_CLOCKWISE false

// Stepper motor pins
static const int MOTOR_PINS[4] = {2,3,4,5};

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
// Utilitiy macros
////////////////////////////////////////////////////////////////////////////////

// Number of bytes to represent one column of vertical pixels
#define NUM_VERTICAL_BYTES (VERTICAL_PIXELS/8)

// Number of microseconds between steps
#define STEP_MICROSECONDS (((unsigned long)(60000000.0f / DISPLAY_RPM)) / ROTATION_STEPS)

// The number of steps per a given number of pixel fractions
#define STEPS_PER_PIXEL_FRACTION(n) (((n)*ROTATION_STEPS) / (HORIZONTAL_PIXELS*PIXEL_FRACTION))


////////////////////////////////////////////////////////////////////////////////
// Stepper Motor Driver
////////////////////////////////////////////////////////////////////////////////

// Accumulated number of steps taken.
static volatile unsigned char num_steps;

// Current stepper motor state
static int cur_motor_state = 0;

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


// Current pixel width (default to square pixels)
unsigned int cur_pixel_width = PIXEL_FRACTION;

/**
 * Refresh the LED display if needed
 */
void led_refresh() {
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
	}
	
	// Refresh the display
	for (int i = NUM_VERTICAL_BYTES-1; i>=0; i--)
		SPI.transfer(cur_buf[i]);
	digitalWrite(LE_PIN, HIGH);
	digitalWrite(LE_PIN, LOW);
}

////////////////////////////////////////////////////////////////////////////////
// Main program
////////////////////////////////////////////////////////////////////////////////


void setup() {
	Serial.begin(115200);
	
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


void loop(){
	led_refresh();
}
