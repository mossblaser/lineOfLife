$fn = 50;

// The dimensions of the metal extruded bar.
BAR_WIDTH = 31;
BAR_THICKNESS = 16;
BAR_MATERIAL_THICKNESS = 1;

// Dimensions of the line-of-life board
LOL_WIDTH = 40;
LOL_LENGTH = 204/3;
LOL_BOARD_THICKNESS = 2;
// Size of the pins sticking out of the back
LOL_PIN_THICKNESS = 4;
// Gap between the pins and left/right edges of the board
LOL_LIP = 3.7;
// Size of the components sticking out of the front of the board
LOL_COMPONENT_THICKNESS = 10;
// Size of area where components exist flush with the edge of the board opposite
// the LEDs (i.e. the header pins and smoothing capacitor)
LOL_LEFT_GAP = 5; // On the left edge of the board (LEDs on top)
LOL_RIGHT_GAP = 36; // On the right edge of the board (LEDs on top)
// The width of the above gaps
LOL_GAP_WIDTH = 20;

// Thickness of the board backing plate
BCK_THICKNESS = 1;
// Radius of the cylindrical clips in the board backing plate
BCK_CLIP_RADIUS = LOL_LIP * 0.75;


// M4 bot/nut sizes
M4_BOLT_HEAD_RADIUS = 6/2;
M4_BOLT_HEAD_HEIGHT = 2.5;
M4_BOLT_RADIUS = 3.5/2;
M4_NUT_RADIUS = 3.5;
M4_NUT_HEIGHT = 2.5;


// Amount of aditional boarder around the mounting plates
MNT_BORDER = 5;
// Size of the ends of the mounting plates
MNT_END_LENGTH = 20;
// Thickness of the mount plate
MNT_THICKNESS = 3.5;
// Size of the protrusions from the base of the bottom mounting plate
MNT_BASE_THICKNESS = (LOL_COMPONENT_THICKNESS + MNT_BORDER - MNT_THICKNESS) * 1.05;
// Rounding of the mount base
MNT_BASE_ROUNDING = MNT_BASE_THICKNESS*0.35;
// Thickness of the top mounting plate
MNT_TOP_THICKNESS = 2.5;
// Rounding of the mount top
MNT_TOP_ROUNDING = MNT_TOP_THICKNESS*0.35;

// Dimensions of the micro-switch
MNT_SWITCH_WIDTH = 21.5;
MNT_SWITCH_THICKNESS = 7.35;
MNT_SWITCH_DEPTH = 11.7;

// Dimensions of the LDR & LED
MNT_LDR_RADIUS = 6.1/2;
MNT_LED_RADIUS = 4.2/2;

// Depth of the component area of the mount
MNT_COMPONENT_DEPTH = 7;

// Size of the cable exiting the mounting
MNT_CABLE_WIDTH = 20;
MNT_CABLE_THICKNESS = 2.5;

// Thickness of the material gripping components in the base of the mount
MNT_COMPONENT_GRIP_THICKNESS = 5;

// 3D printed mount handle dimensions
MNT_HANDLE_LENGTH = LOL_LENGTH * 0.6666;
MNT_HANDLE_RADIUS = 13;
MNT_HANDLE_OFFSET = MNT_HANDLE_RADIUS*2;

// Size of material surrounding the bar in the extruded mount handle
MNT_BAR_GRIP_THICKNESS = 3;


// Offset for the center of the right-hand nut/bolt
MNT_BOLT_RIGHT_X = ( MNT_BASE_ROUNDING + 2*MNT_LDR_RADIUS + 2*MNT_LED_RADIUS
                   + LOL_WIDTH + 2*MNT_BORDER - MNT_SWITCH_WIDTH - MNT_BASE_ROUNDING
                   ) / 2;
MNT_BOLT_RIGHT_Y = -MNT_END_LENGTH/2;

// Offset for the center of the left-hand nut/bolt
MNT_BOLT_LEFT_X = ( LOL_WIDTH + 2*MNT_BORDER
                  ) - MNT_BOLT_RIGHT_X;
MNT_BOLT_LEFT_Y = LOL_LENGTH + MNT_END_LENGTH/2;


////////////////////////////////////////////////////////////////////////////////
// Aluminium extrusion
////////////////////////////////////////////////////////////////////////////////

module extrusion(length = LOL_LENGTH, hollow = true) {
	color([0.9,0.9,0.9])
	difference () {
		hull() {
			translate([BAR_THICKNESS/2, BAR_THICKNESS/2, 0])
				cylinder(length, r = BAR_THICKNESS/2);
			
			translate([BAR_THICKNESS/2 + BAR_WIDTH - BAR_THICKNESS/2, BAR_THICKNESS/2, 0])
				cylinder(length, r = BAR_THICKNESS/2);
		}
		
		if (hollow)
			translate([0,0,-0.5])
				hull() {
					translate([BAR_THICKNESS/2, BAR_THICKNESS/2, 0])
						cylinder(length+1, r = BAR_THICKNESS/2 - BAR_MATERIAL_THICKNESS);
					
					translate([BAR_THICKNESS/2 + BAR_WIDTH - BAR_THICKNESS/2, BAR_THICKNESS/2, 0])
						cylinder(length+1, r = BAR_THICKNESS/2 - BAR_MATERIAL_THICKNESS);
				}
	}
}


////////////////////////////////////////////////////////////////////////////////
// Circuit Board
////////////////////////////////////////////////////////////////////////////////

module lol_board() {
	// The board
	color([222/255, 205/255, 164/255])
	cube([LOL_WIDTH, LOL_BOARD_THICKNESS, LOL_LENGTH]);
	// The pins out of the back
	color([0.8, 0.8, 0.8])
	translate([LOL_LIP,LOL_BOARD_THICKNESS,0])
	cube([LOL_WIDTH - 2*LOL_LIP, LOL_PIN_THICKNESS, LOL_LENGTH]);
	
	// Shifters for reference
	color([0.6, 0.6, 0.6])
	for (i = [0:4]) {
		echo(i);
		translate([ LOL_LIP + LOL_LENGTH/40
		          , -LOL_COMPONENT_THICKNESS*0.7
		          , ((0.5 + i) * (LOL_LENGTH / 5)) - 5
		          ])
		cube([LOL_WIDTH/2, LOL_COMPONENT_THICKNESS*0.7, 10]);
	}
	
	// LEDs for reference
	color([0.6, 0.6, 1.0])
	for (i = [0:39]) {
		echo(i);
		translate([ LOL_LIP + LOL_LENGTH/40/2
		          , -LOL_COMPONENT_THICKNESS
		          , (0.5 + i) * (LOL_LENGTH / 40)
		          ])
		rotate([-90, 0, 0])
		cylinder(LOL_COMPONENT_THICKNESS, r = LOL_LENGTH/40/2);
	}
	
	// Areas where sockets/caps live
	color([0.2,0.2,0.2])
	translate([LOL_WIDTH-LOL_GAP_WIDTH, -LOL_COMPONENT_THICKNESS*0.5, 0])
	cube([LOL_GAP_WIDTH, LOL_COMPONENT_THICKNESS*0.5, LOL_LEFT_GAP]);
	
	color([0.2,0.2,0.2])
	translate([ LOL_WIDTH-LOL_GAP_WIDTH
	          , -LOL_COMPONENT_THICKNESS*0.5
	          , LOL_LENGTH - LOL_RIGHT_GAP
	          ])
	cube([LOL_GAP_WIDTH, LOL_COMPONENT_THICKNESS*0.5, LOL_RIGHT_GAP]);
	
	// Pins
	for (i = [0:6]) {
		color([0.8,0.8,0.8])
		translate([ LOL_WIDTH - LOL_GAP_WIDTH * ((0.5 + i) / 7)
		          , -LOL_COMPONENT_THICKNESS*0.25 - 0.5
		          , -7
		          ])
		cylinder(7, r=1);
	}
}


////////////////////////////////////////////////////////////////////////////////
// Board Backing/mounting
////////////////////////////////////////////////////////////////////////////////

module board_backing_clip() {
	difference () {
		union () {
			translate([0, BCK_THICKNESS, 0])
			rotate([90, 0, 0])
			cylinder(LOL_BOARD_THICKNESS + LOL_PIN_THICKNESS, r=BCK_CLIP_RADIUS);
			
			translate([0, BCK_THICKNESS - LOL_BOARD_THICKNESS - LOL_PIN_THICKNESS, 0])
			sphere(r = BCK_CLIP_RADIUS);
		}
		
		translate([0, -LOL_BOARD_THICKNESS - LOL_PIN_THICKNESS, -BCK_CLIP_RADIUS])
		cube([ BCK_CLIP_RADIUS+1
		     , LOL_BOARD_THICKNESS + LOL_PIN_THICKNESS
		     , BCK_CLIP_RADIUS*3
		     ]);
	}
}

module board_backing(num_hex_x = 9, hex_width = 0.85, rim_width = 0.2, num_clips = 5) {
	color([0,0,1]) {
		// Borders
		difference() {
			// Outer
			cube([LOL_WIDTH, BCK_THICKNESS, LOL_LENGTH]);
			
			// Inner rim boundry
			translate([rim_width*LOL_WIDTH*0.5,-0.5,rim_width*LOL_WIDTH*0.5])
			cube([ LOL_WIDTH * (1-rim_width)
			     , BCK_THICKNESS+1
			     , LOL_LENGTH - (LOL_WIDTH * rim_width)
			     ]);
		}
		
		// Hexagonal Mesh
		intersection() {
			// Board-sized area
			translate([0,-0.5,0])
			cube([LOL_WIDTH, BCK_THICKNESS+1, LOL_LENGTH]);
			
			// Raw mesh
			scale([LOL_WIDTH/num_hex_x, 1, LOL_WIDTH/num_hex_x])
			for (y = [0 : ceil(LOL_LENGTH / (LOL_WIDTH/(num_hex_x/1.5))) - 1]) {
				for (x = [0 : num_hex_x - 1]) {
					translate([x*1.5, 0, y*sqrt(3) + (x%2) * (sqrt(3)/2)])
					rotate([-90, 0, 0])
					difference() {
						cylinder(BCK_THICKNESS, r = 1, $fn=6);
						translate([0,0,-0.5])
						cylinder(BCK_THICKNESS+1, r = hex_width, $fn=6);
					}
				}
			}
		}
		
		// Clips
		for (x = [0, LOL_WIDTH]) {
			for (y = [0:num_clips-1]) {
				translate([ x
				          , 0
				          , (y+0.5) * (LOL_LENGTH/num_clips)
				          ])
				rotate([0, x ? 180 : 0, 0])
				board_backing_clip();
			}
		}
	}
}


////////////////////////////////////////////////////////////////////////////////
// Plan B: A three-part mount which can be bolted together.
////////////////////////////////////////////////////////////////////////////////


module mount_bottom_end() {
	hull () {
		translate([0, -MNT_END_LENGTH + MNT_BASE_ROUNDING, 0])
		cube([ LOL_WIDTH + 2*MNT_BORDER
		     , MNT_END_LENGTH - MNT_BASE_ROUNDING + 0.01
		     , MNT_THICKNESS
		     ]);
		
		for (x = [ MNT_BASE_ROUNDING
		         , LOL_WIDTH + 2*MNT_BORDER - MNT_BASE_ROUNDING
		         ]) {
			translate([ x
			          , -MNT_END_LENGTH + MNT_BASE_ROUNDING
			          , 0])
			cylinder(MNT_THICKNESS, r = MNT_BASE_ROUNDING);
		}
		
		for (y = [ -MNT_BASE_ROUNDING
		         , -MNT_END_LENGTH + MNT_BASE_ROUNDING
		         ]) {
			for (x = [ MNT_BASE_ROUNDING
			         , LOL_WIDTH + 2*MNT_BORDER - MNT_BASE_ROUNDING
			         ]) {
				translate([ x
				          , y
				          , MNT_BASE_THICKNESS - MNT_BASE_ROUNDING
				          ])
				sphere(MNT_BASE_ROUNDING);
			}
		}
	}
}

module mount_end(thickness) {
	hull () {
		translate([0, -MNT_END_LENGTH + MNT_BASE_ROUNDING, 0])
		cube([ LOL_WIDTH + 2*MNT_BORDER
		     , MNT_END_LENGTH - MNT_BASE_ROUNDING + 0.01
		     , thickness
		     ]);
		
		for (x = [ MNT_BASE_ROUNDING
		         , LOL_WIDTH + 2*MNT_BORDER - MNT_BASE_ROUNDING
		         ]) {
			translate([ x
			          , -MNT_END_LENGTH + MNT_BASE_ROUNDING
			          , 0])
			cylinder(thickness, r = MNT_BASE_ROUNDING);
		}
		
	}
}


module mount_bottom() {
	
	difference() {
		union () {
			// The support plate around the board
			cube([ LOL_WIDTH + 2*MNT_BORDER
			     , LOL_LENGTH
			     , MNT_THICKNESS
			     ]);
			
			// The ends
			mount_bottom_end();
			translate([LOL_WIDTH + 2*MNT_BORDER,LOL_LENGTH,0])
			rotate([0,0,180])
			mount_bottom_end();
		}
		
		// Hollow out space for board minus the lips
		translate([MNT_BORDER + LOL_LIP, 0, -0.5])
		cube([ LOL_WIDTH - 2*LOL_LIP
		     , LOL_LENGTH
		     , MNT_THICKNESS + 1
		     ]);
		
		// Hollow out space for connectors (at the component end)
		translate([MNT_BORDER, -MNT_END_LENGTH/2, -0.5])
		cube([ LOL_GAP_WIDTH
		     , LOL_RIGHT_GAP + MNT_END_LENGTH/2
		     , MNT_THICKNESS + 1
		     ]);
		
		// Hollow out space for connectors (at the empty end)
		translate([MNT_BORDER, LOL_LENGTH-LOL_LEFT_GAP, -0.5])
		cube([ LOL_GAP_WIDTH
		     , LOL_LEFT_GAP + MNT_END_LENGTH/2
		     , MNT_THICKNESS + 1
		     ]);
		
		// Hollow out a space for the uSwitch
		translate([ LOL_WIDTH + 2*MNT_BORDER - MNT_SWITCH_WIDTH - MNT_BASE_ROUNDING
		          , -((MNT_END_LENGTH/2) + (MNT_SWITCH_THICKNESS/2))
		          , -0.5
		          ])
		cube([MNT_SWITCH_WIDTH, MNT_SWITCH_THICKNESS, MNT_BASE_THICKNESS + 1 ]);
		
		// Hollow out a chamber for the LED/LDR to live in
		hull () {
			// LDR
			translate([ MNT_BASE_ROUNDING + MNT_LDR_RADIUS
			          , -MNT_END_LENGTH/2
			          , ])
			cylinder(MNT_BASE_THICKNESS + 1, r = MNT_LDR_RADIUS);
			
			// LED
			translate([ MNT_BASE_ROUNDING + 2*MNT_LDR_RADIUS + MNT_LED_RADIUS
			          , -MNT_END_LENGTH/2
			          , ])
			cylinder(MNT_BASE_THICKNESS + 1, r = MNT_LED_RADIUS);
		}
		
		// Hollow out a space for the components
		hull () {
			// Hole in top
			translate([ MNT_BORDER
			          , -((MNT_END_LENGTH/2) + (MNT_SWITCH_THICKNESS/2))
			          , MNT_BASE_THICKNESS - MNT_COMPONENT_GRIP_THICKNESS - 1
			          ])
			cube([LOL_WIDTH, MNT_SWITCH_THICKNESS, 1 ]);
			
			// Cavern at bottom
			translate([ MNT_BORDER,
			          , -MNT_END_LENGTH + MNT_BASE_ROUNDING/2
			          , -1
			          ])
			cube([LOL_WIDTH, MNT_END_LENGTH - MNT_BASE_ROUNDING, 1 ]);
		}
		
		// Cut out the space for the right-hand bolt
		translate([MNT_BOLT_RIGHT_X, MNT_BOLT_RIGHT_Y, -0.5])
		cylinder(MNT_BASE_THICKNESS + 1, r = M4_BOLT_RADIUS);
		
		translate([MNT_BOLT_RIGHT_X, MNT_BOLT_RIGHT_Y,
		MNT_BASE_THICKNESS-M4_BOLT_HEAD_HEIGHT])
		cylinder(M4_BOLT_HEAD_HEIGHT + 1, r = M4_BOLT_HEAD_RADIUS);
		
		
		// Cut out the space for the left-hand bolt
		translate([MNT_BOLT_LEFT_X, MNT_BOLT_LEFT_Y, -0.5])
		cylinder(MNT_BASE_THICKNESS + 1, r = M4_BOLT_RADIUS);
		
		translate([MNT_BOLT_LEFT_X, MNT_BOLT_LEFT_Y,
		MNT_BASE_THICKNESS-M4_BOLT_HEAD_HEIGHT])
		cylinder(M4_BOLT_HEAD_HEIGHT + 1, r = M4_BOLT_HEAD_RADIUS);
	}
}

module mount_middle() {
	difference() {
		union () {
			// The support plate around the board
			cube([ LOL_WIDTH + 2*MNT_BORDER
			     , LOL_LENGTH
			     , LOL_BOARD_THICKNESS + LOL_PIN_THICKNESS
			     ]);
			
			// The ends
			mount_end(LOL_BOARD_THICKNESS + LOL_PIN_THICKNESS);
			translate([LOL_WIDTH + 2*MNT_BORDER,LOL_LENGTH,0])
			rotate([0,0,180])
			mount_end(LOL_BOARD_THICKNESS + LOL_PIN_THICKNESS);
		}
		
		// Hollow out space for pins
		translate([MNT_BORDER + LOL_LIP, 0, -0.5])
		cube([ LOL_WIDTH - 2*LOL_LIP
		     , LOL_LENGTH
		     , LOL_BOARD_THICKNESS + LOL_PIN_THICKNESS + 1
		     ]);
		
		// Hollow out space for board
		translate([ MNT_BORDER
		          , 0
		          , LOL_PIN_THICKNESS
		          ])
		cube([ LOL_WIDTH
		     , LOL_LENGTH
		     , LOL_BOARD_THICKNESS + 1
		     ]);
		
		
		// Hollow out a chamber for components to live in
		translate([ MNT_BORDER
		          , -MNT_END_LENGTH + MNT_BASE_ROUNDING*0.5
		          , 1
		          ])
		cube([ LOL_WIDTH
		      , MNT_END_LENGTH - MNT_BASE_ROUNDING
		      , LOL_BOARD_THICKNESS + LOL_PIN_THICKNESS + 1
		      ]);
		
		
		// Hollow out a slit for cables to exit
		translate([ (LOL_WIDTH + 2*MNT_BORDER - MNT_CABLE_WIDTH) / 2
		          , -MNT_END_LENGTH - 1
		          , LOL_BOARD_THICKNESS + LOL_PIN_THICKNESS - MNT_CABLE_THICKNESS
		          ])
		cube([ MNT_CABLE_WIDTH
		      , MNT_END_LENGTH/2 + 1
		      , MNT_CABLE_THICKNESS + 1
		      ]);
		
		// Cut out the space for the right-hand bolt
		translate([MNT_BOLT_RIGHT_X, MNT_BOLT_RIGHT_Y, -0.5])
		cylinder(LOL_BOARD_THICKNESS + LOL_PIN_THICKNESS + 1, r = M4_BOLT_RADIUS);
		
		// Cut out the space for the left-hand bolt
		translate([MNT_BOLT_LEFT_X, MNT_BOLT_LEFT_Y, -0.5])
		cylinder(LOL_BOARD_THICKNESS + LOL_PIN_THICKNESS + 1, r = M4_BOLT_RADIUS);
	}
}

// Printed handle
module mount_top() {
	union () {
		// The support plate around the board
		cube([ LOL_WIDTH + 2*MNT_BORDER
		     , LOL_LENGTH
		     , MNT_TOP_THICKNESS
		     ]);
		
		// The ends
		mount_end(MNT_TOP_THICKNESS);
		translate([LOL_WIDTH + 2*MNT_BORDER,LOL_LENGTH,0])
		rotate([0,0,180])
		mount_end(MNT_TOP_THICKNESS);
	}
	
	// Handle
	translate([ (LOL_WIDTH + 2*MNT_BORDER) / 2
	          , (LOL_LENGTH - MNT_HANDLE_LENGTH)/2
	          , -MNT_HANDLE_OFFSET
	          ])
	rotate([-90, 0, 0])
	cylinder(MNT_HANDLE_LENGTH, r = MNT_HANDLE_RADIUS);
	
	// Handle caps
	translate([ (LOL_WIDTH + 2*MNT_BORDER) / 2
	          , (LOL_LENGTH - MNT_HANDLE_LENGTH)/2
	          , -MNT_HANDLE_OFFSET
	          ])
	sphere(MNT_HANDLE_RADIUS);
	translate([ (LOL_WIDTH + 2*MNT_BORDER) / 2
	          , (LOL_LENGTH - MNT_HANDLE_LENGTH)/2 + MNT_HANDLE_LENGTH
	          , -MNT_HANDLE_OFFSET
	          ])
	sphere(MNT_HANDLE_RADIUS);
	
	// Handle support
	hull () {
		// Within the handle
		translate([ (LOL_WIDTH + 2*MNT_BORDER) / 2
		          , (LOL_LENGTH - MNT_HANDLE_LENGTH)/2
		          , -MNT_HANDLE_OFFSET
		          ])
		sphere(MNT_HANDLE_RADIUS / 2);
		translate([ (LOL_WIDTH + 2*MNT_BORDER) / 2
		          , (LOL_LENGTH - MNT_HANDLE_LENGTH)/2 + MNT_HANDLE_LENGTH
		          , -MNT_HANDLE_OFFSET
		          ])
		sphere(MNT_HANDLE_RADIUS / 2);
		
		translate([ (LOL_WIDTH + 2*MNT_BORDER) / 2 - MNT_HANDLE_RADIUS
		          , (LOL_LENGTH - MNT_HANDLE_LENGTH - 2*MNT_HANDLE_RADIUS)/2
		          , 0
		          ])
		cube([MNT_HANDLE_RADIUS*2, MNT_HANDLE_LENGTH + 2*MNT_HANDLE_RADIUS, 1]);
	}
}

// Extrusion-based handle
module mount_top_extrusion_() {
	grip_radius = BAR_THICKNESS/2 + MNT_BAR_GRIP_THICKNESS;
	
	difference() {
		hull() {
			translate([0,0, -MNT_TOP_THICKNESS])
			mount_end(MNT_TOP_THICKNESS);
			
			translate([ (LOL_WIDTH+2*MNT_BORDER) - grip_radius
			          , 0
			          , -MNT_HANDLE_OFFSET
			          ])
			sphere(grip_radius);
			
			translate([ grip_radius
			          , 0
			          , -MNT_HANDLE_OFFSET
			          ])
			sphere(grip_radius);
		}
		
		hull() {
			translate([ (LOL_WIDTH+2*MNT_BORDER - BAR_WIDTH)/2 + BAR_THICKNESS/2
			          , 0
			          , -MNT_HANDLE_OFFSET - MNT_BAR_GRIP_THICKNESS/2
			          ])
			rotate([-90,0,0])
			cylinder(grip_radius, r = BAR_THICKNESS/2);
			
			translate([ (LOL_WIDTH+2*MNT_BORDER + BAR_WIDTH)/2 - BAR_THICKNESS/2
			          , 0
			          , -MNT_HANDLE_OFFSET - MNT_BAR_GRIP_THICKNESS/2
			          ])
			rotate([-90,0,0])
			cylinder(grip_radius, r = BAR_THICKNESS/2);
		}
	}
}

module mount_top_extrusion() {
	difference() {
		union() {
			mount_top_extrusion_();
			translate([0, LOL_LENGTH, 0])
			scale([1, -1, 1])
			mount_top_extrusion_();
		}
		
		// Cut out the space for the right-hand bolt
		translate([MNT_BOLT_RIGHT_X, MNT_BOLT_RIGHT_Y, -(MNT_HANDLE_OFFSET + BAR_THICKNESS/2 + MNT_BAR_GRIP_THICKNESS + 0.5)])
		cylinder((MNT_HANDLE_OFFSET + BAR_THICKNESS/2 + MNT_BAR_GRIP_THICKNESS + 1), r = M4_BOLT_RADIUS);
		
		translate([MNT_BOLT_RIGHT_X, MNT_BOLT_RIGHT_Y, -M4_NUT_HEIGHT-(MNT_HANDLE_OFFSET + BAR_THICKNESS/2 + MNT_BAR_GRIP_THICKNESS + 0.5)])
		cylinder((MNT_HANDLE_OFFSET + BAR_THICKNESS/2 + MNT_BAR_GRIP_THICKNESS +
		1), r = M4_NUT_RADIUS, $fn=6);
		
		// Cut out the space for the right-hand bolt
		translate([MNT_BOLT_LEFT_X, MNT_BOLT_LEFT_Y, -(MNT_HANDLE_OFFSET + BAR_THICKNESS/2 + MNT_BAR_GRIP_THICKNESS + 0.5)])
		cylinder((MNT_HANDLE_OFFSET + BAR_THICKNESS/2 + MNT_BAR_GRIP_THICKNESS + 1), r = M4_BOLT_RADIUS);
		
		translate([MNT_BOLT_LEFT_X, MNT_BOLT_LEFT_Y, -M4_NUT_HEIGHT-(MNT_HANDLE_OFFSET + BAR_THICKNESS/2 + MNT_BAR_GRIP_THICKNESS + 0.5)])
		cylinder((MNT_HANDLE_OFFSET + BAR_THICKNESS/2 + MNT_BAR_GRIP_THICKNESS +
		1), r = M4_NUT_RADIUS, $fn=6);
	}
}


////////////////////////////////////////////////////////////////////////////////
// Main assembly
////////////////////////////////////////////////////////////////////////////////


//// Initial design
//lol_board();
//
//translate([0, LOL_BOARD_THICKNESS + LOL_PIN_THICKNESS, 0])
//board_backing();
//
//translate([0, 20, 0])
//extrusion();


//// All 3D printed
//translate([0,0,  0]) color([1,0,0]) mount_bottom();
//translate([0,0,-20])
//translate([LOL_WIDTH + MNT_BORDER, LOL_LENGTH, 0])
//rotate([-90,0,180])
//lol_board();
//translate([0,0,-40]) color([0,1,0]) mount_middle();
//translate([0,0,-60]) color([0,0,1]) mount_top();

////////////////////////////////////////////////////////////////////////////////

// Extruded Handle
rotate([0,180,0])
difference() {
	union() {
		//translate([0,0,  0]) color([1,0,0]) mount_bottom();
		//translate([0,0,-20])
		//translate([LOL_WIDTH + MNT_BORDER, LOL_LENGTH, 0])
		//	rotate([-90,0,180])
		//	lol_board();
		//translate([0,0,-LOL_BOARD_THICKNESS - LOL_PIN_THICKNESS]) color([0,1,0]) mount_middle();
		//
		translate([0,0,-60]) color([0,0,1]) mount_top_extrusion();
		//
		//translate([0,0,-100])
		//	translate([LOL_WIDTH + MNT_BORDER, LOL_LENGTH, 0])
		//	rotate([-90,0,180])
		//	extrusion();
	}
	
	//translate([-0.5, -500 + LOL_LENGTH*0.8, -500])
	//cube([LOL_WIDTH + 2*MNT_BORDER + 1, 500, 1000]);
	
	translate([-0.5, 30, -500])
	cube([LOL_WIDTH + 2*MNT_BORDER + 1, 500, 1000]);
}
