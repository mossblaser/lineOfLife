/**
 * Controller for the "Bar of Life" hand-held UV LED array.
 */

#include <limits.h>

#include <avr/pgmspace.h>
#include <SPI.h>

#include "TimerOne.h"

////////////////////////////////////////////////////////////////////////////////
// Font selection
////////////////////////////////////////////////////////////////////////////////

// Uncomment one of these to select the font to use. These files contain an
// ASCII-art preview within the source file.
// 
// Fonts can be generated using:
//
//   python font_gen.py 40 40 "Myriad Pro" FONT_ > file_name.h
//                      |  |   |           |       |
//                      |  |   |           |       '--- Output filename
//                      |  |   |           '-- Prefix used in the code
//                      |  |   |               (must be FONT_)
//                      |  |   '-- Font name
//                      |  '-- Number of LEDs (must be 40)
//                      '-- Height of font (0 - 40)

// Myriad Pro: A Helvetica-like sans-serif font
#include "myriad_pro_large.h"
//#include "myriad_pro_medium.h"
//#include "myriad_pro_small.h"

// Adobe Garamond Pro: A Times New Roman-like serifed font
//#include "adobe_garamond_pro_large.h"
//#include "adobe_garamond_pro_medium.h"
//#include "adobe_garamond_pro_small.h"

// Heathchote: My handwriting as a teenager...
//#include "heathchote_large.h"
//#include "heathchote_medium.h"
//#include "heathchote_small.h"


////////////////////////////////////////////////////////////////////////////////
// Controller Parameters
////////////////////////////////////////////////////////////////////////////////

// Scales the pot value (0-1023) into miliseconds between pixels
#define PIXEL_SPEED_SCALING_FACTOR 0.5

// Baudrate of the serial communications with the host
#define BAUD_RATE 115200

// Resolution of the display
#define PIXELS   40ul


// Polling period of input signals
#define INPUT_POLL_MICROSECONDS 1000

// Number of consecutive polls before the uswitch is considered pressed/released
#define USWITCH_HYST_PRESS 100
#define USWITCH_HYST_RELEASE 1000


////////////////////////////////////////////////////////////////////////////////
// Pin definitions
////////////////////////////////////////////////////////////////////////////////

// Control pins for LED strip
#define nOE_PIN 9
#define LE_PIN  10
//      MOSI    11
//      MISO    12
//      CLK     13

// Surface-contact microswitch
#define USWITCH_PIN 8

// Optical-clock LDR pin
#define OCLK_LDR_PIN 0 // Analog

// Optical-clock LED pin
#define OCLK_LED_PIN A1

// Speed modifier pot pin
#define SPEED_POT_PIN 2 // Analog




////////////////////////////////////////////////////////////////////////////////
// Global flags
////////////////////////////////////////////////////////////////////////////////

// Should output be produced?
bool run = false;

// Number of usec between optical clock cycles. Not valid while run is
// false.
unsigned long oclk_period = 0;


////////////////////////////////////////////////////////////////////////////////
// Microswitch polling
////////////////////////////////////////////////////////////////////////////////

// Control run-state using the uswitch with heavy-handed hysteresis
void poll_uswitch() {
	static bool last_uswitch_state = false;
	static int  uswitch_hyst_count = 0;
	bool uswitch_state = !digitalRead(USWITCH_PIN);
	
	if (last_uswitch_state == uswitch_state) {
		uswitch_hyst_count = 0;
	} else if (last_uswitch_state == false && uswitch_state == true) {
		uswitch_hyst_count++;
		if (uswitch_hyst_count >= USWITCH_HYST_PRESS) {
			run = true;
			last_uswitch_state = uswitch_state;
			uswitch_hyst_count = 0;
		}
	} else if (last_uswitch_state == true && uswitch_state == false) {
		uswitch_hyst_count++;
		if (uswitch_hyst_count >= USWITCH_HYST_RELEASE) {
			run = false;
			last_uswitch_state = uswitch_state;
			uswitch_hyst_count = 0;
		}
	}
}


////////////////////////////////////////////////////////////////////////////////
// LED Driving
////////////////////////////////////////////////////////////////////////////////

// The buffer which holds the (null-terminated) message to display
char str[100] = "Help I'm trapped in an AVR's firmware!  ";
const unsigned int str_max_len = (sizeof(str)/sizeof(char)) - 1;

// The character being displayed
const char *this_char = &(str[0]);

// The pixel column within the current character being displayed
unsigned int this_col = 0;

// The pixel column within the next character being displayed
unsigned int next_col = 0;


void reset_display() {
	this_char = &(str[0]);
	this_col = 0;
	next_col = 0;
}


/**
 * Set the next state for the LEDs.
 */
void display_next() {
	// Get the character index in the font (default to space if character is not
	// available)
	unsigned int this_index = pgm_read_byte_near(FONT_ASCII_TO_INDEX + this_char[0]);
	unsigned int next_index = pgm_read_byte_near(FONT_ASCII_TO_INDEX + this_char[1]);
	if (this_index == 0xFF) this_index = pgm_read_byte_near(FONT_ASCII_TO_INDEX + ' ');
	if (next_index == 0xFF) next_index = pgm_read_byte_near(FONT_ASCII_TO_INDEX + ' ');
	
	// Get the start address of the bitmap for this character
	unsigned int this_bitmap = pgm_read_word_near(FONT_GLYPH_BITMAPS_LOOKUP + this_index);
	unsigned int next_bitmap = pgm_read_word_near(FONT_GLYPH_BITMAPS_LOOKUP + next_index);
	
	unsigned int this_width = pgm_read_byte_near(FONT_GLYPH_WIDTH + this_index);
	unsigned int this_end   = pgm_read_byte_near(FONT_GLYPH_END   + this_index);
	unsigned int next_start = pgm_read_byte_near(FONT_GLYPH_START + next_index);
	
	// Display current the column
	for (int row_byte = 0; row_byte < PIXELS/8; row_byte++) {
		// The current character's line
		unsigned char c = pgm_read_byte_near( FONT_GLYPH_BITMAPS
		                                    + this_bitmap
		                                    + (this_col * (PIXELS/8))
		                                    + row_byte
		                                    );
		
		// Overlaid with the next character's overlapping columns
		if (this_col >= this_end - next_start)
			c |= pgm_read_byte_near( FONT_GLYPH_BITMAPS
			                       + next_bitmap
			                       + (next_col * (PIXELS/8))
			                       + row_byte
			                       );
		SPI.transfer(c);
	}
	
	// Latch the pixels
	digitalWrite(LE_PIN, HIGH);
	digitalWrite(LE_PIN, LOW);
	
	// Advance through the columns
	if (this_col >= this_end - next_start)
		next_col++;
	this_col++;
	
	// Move to the next character as required
	if (this_col >= this_width) {
		this_char++;
		this_col = next_col;
		next_col = 0;
		
		// Wrap-around to the start of the string again
		if (this_char[0] == '\0') {
			this_char = &(str[0]);
			this_col = 0;
		}
	}
}



////////////////////////////////////////////////////////////////////////////////
// Main loop
////////////////////////////////////////////////////////////////////////////////


void setup() {
	Serial.begin(BAUD_RATE);
	
	SPI.begin();
	SPI.setBitOrder(MSBFIRST);
	SPI.setClockDivider(SPI_CLOCK_DIV16); // 16MHz/16 = 1MHz
	SPI.setDataMode(SPI_MODE0); // Posedge sensitive, Clock Idle Low
	
	// Setup LED pins
	pinMode(LE_PIN, OUTPUT);  digitalWrite(LE_PIN, LOW);
	pinMode(nOE_PIN, OUTPUT); digitalWrite(nOE_PIN, LOW);
	
	// Setup contact uSwitch pin with pull-up
	pinMode(USWITCH_PIN, INPUT);
	digitalWrite(USWITCH_PIN, HIGH);
	
	// Setup optical clock LED pin (unused)
	pinMode(OCLK_LED_PIN, OUTPUT); digitalWrite(OCLK_LED_PIN, LOW);
	
	// Poll the uSwitch
	Timer1.initialize(INPUT_POLL_MICROSECONDS);
	Timer1.attachInterrupt(poll_uswitch);
}

void loop() {
	if (Serial.available()) {
		// Get the current string and pad with spaces and a null terminator.
		unsigned int num_chars = Serial.readBytesUntil('\n', str, str_max_len-2);
		str[num_chars+0] = ' ';
		str[num_chars+1] = ' ';
		str[num_chars+2] = '\0';
		
		Serial.println("OK");
	}
	
	int loop_interval = (int)(analogRead(SPEED_POT_PIN) * PIXEL_SPEED_SCALING_FACTOR);
	delay(loop_interval);
	
	if (run) {
		// Display the message
		digitalWrite(nOE_PIN, false);
		display_next();
	} else {
		// Turn off the display & reset the message
		digitalWrite(nOE_PIN, true);
		reset_display();
	}
}
