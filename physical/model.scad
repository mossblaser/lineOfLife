include <wedge.scad>;

// Minimum angle for fragmenting curves
$fa = 1;

PI = 3.1415927;

////////////////////////////////////////////////////////////////////////////////
// Size Definitions
////////////////////////////////////////////////////////////////////////////////

// Size of the dowel rods used in construction
DOWEL_DIAMETER = 9;
DOWEL_RADIUS   = DOWEL_DIAMETER/2;

// Sizes of holes for dowel rods in various situations
DOWEL_PRINTED_SOCKET_RADIUS= DOWEL_RADIUS + 0.5;
DOWEL_CUT_HOLE_RADIUS= DOWEL_RADIUS * 2;

// Thickness of a block into which a dowel rod inserted should be
DOWEL_PRINTED_SOCKET_BLOCK = DOWEL_PRINTED_SOCKET_RADIUS * 3;
// Depth of a socket to accept the dowel rod
DOWEL_PRINTED_SOCKET_DEPTH = DOWEL_PRINTED_SOCKET_RADIUS * 2.5;

// Maximum 3D printable size
MAX_3D_PRINT_DIMENSION = 90;

// Size of the glow-in-the-dark cylinder
DISPLAY_HEIGHT       = 609.6; // 24in
DISPLAY_CIRCUMFRENCE = 1000;  // 1m
DISPLAY_RADIUS       = (DISPLAY_CIRCUMFRENCE / PI) / 2;
DISPLAY_THICKNESS    = 1;

// The cardboard rings which live inside the display to hold its shape
DISPLAY_SHAPE_RING_THICKNESS = 3;  // Cardboard Thickness
DISPLAY_SHAPE_RINGS_START    = 50; // The offset from the bottom of the cylinder of the first ring.
DISPLAY_SHAPE_RINGS_END      = 50; // The offset from the top of the cylinder of the last ring.
DISPLAY_SHAPE_RINGS_NUM      = 4;  // Number of shaping rings

// Size of the ledge on each of the spokes which the display will rest.
DISPLAY_GRIP_LEDGE = 5;
// Thickness of the ledge on which the display sits
DISPLAY_GRIP_THICKNESS = 5;

// Bearing dimensions
BEARING_INNER_RADIUS = 17/2; // Inner radius
BEARING_OUTER_RADIUS = 35/2; // Outer radius
BEARING_THICKNESS    = 10;   // Ring thickness
BEARING_INNER_LIP    = 2;    // Size of the edge of the inner ring
BEARING_OUTER_LIP    = 5;    // Size of the fixed outer ring
BEARING_PRINT_SLACK  = 0.5;  // Amount of slack to add to the radius for 3D printed fittings

// Motor shaft dimensions
MOTOR_SHAFT_RADIUS    = (5+0.5)/2;
MOTOR_SHAFT_KEY_WIDTH = 3+0.5;
MOTOR_SHAFT_LENGTH    = 6+1;

// Number of spokes/grips used to support the display
DISPLAY_BASE_SPOKES = 6;
// Number of spokes at the top of the display
DISPLAY_TOP_SPOKES = 3;




////////////////////////////////////////////////////////////////////////////////
// Colour Palette
////////////////////////////////////////////////////////////////////////////////

COLOUR_CARDBOARD    = [184/255,165/255,103/255];
COLOUR_GLOW_IN_DARK = [198/255,245/255,188/255];
COLOUR_3D_PRINTED   = [0.2,0.2,0.2];


////////////////////////////////////////////////////////////////////////////////
// Components
////////////////////////////////////////////////////////////////////////////////

// The display cylinder and axel
module display() {
	// The display surface itself
	color(COLOUR_GLOW_IN_DARK)
		difference() {
			cylinder(h = DISPLAY_HEIGHT, r=DISPLAY_RADIUS);
			translate([0,0,-0.5])
			cylinder(h = DISPLAY_HEIGHT+1, r=DISPLAY_RADIUS - DISPLAY_THICKNESS);
		}
	
	// The cardboard support rings 
	color(COLOUR_CARDBOARD)
		for (i = [0 : DISPLAY_SHAPE_RINGS_NUM-1]) {
			translate([0,0,DISPLAY_SHAPE_RINGS_START
			                 + i * (( DISPLAY_HEIGHT
			                          - DISPLAY_SHAPE_RINGS_START
			                          - DISPLAY_SHAPE_RINGS_END
			                        ) / (DISPLAY_SHAPE_RINGS_NUM-1))
			          ])
				difference() {
					// The ring
					cylinder( h = DISPLAY_SHAPE_RING_THICKNESS
					        , r = DISPLAY_RADIUS - DISPLAY_THICKNESS
					        );
					// Space for the axel
					translate([0,0,-0.5])
					cylinder( h = DISPLAY_SHAPE_RING_THICKNESS+1
					        , r = DOWEL_CUT_HOLE_RADIUS
					        );
				}
		}
}


// A part which sits on the end of a spoke and grips the display
module display_grip(angle) {
	// A wedge the width of the ledge which should be as big as can be 3D
	// printed (cosine rule)
	wedge_angle = acos( (2*pow(DISPLAY_RADIUS+DISPLAY_GRIP_LEDGE,2) - pow(MAX_3D_PRINT_DIMENSION,2))
	                    / (2*pow(DISPLAY_RADIUS+DISPLAY_GRIP_LEDGE,2))
	                  );
	
	color(COLOUR_3D_PRINTED)
	rotate([0,0, angle]) {
		difference() {
			// The wedge with a lip
			intersection() {
				// The profile of the ledge
				union() {
					// The spoke accepting part
					cylinder( h = DOWEL_PRINTED_SOCKET_BLOCK
					        , r = DISPLAY_RADIUS - DISPLAY_THICKNESS
					        );
					// The ledge
					cylinder( h = DISPLAY_GRIP_THICKNESS
					        , r = DISPLAY_RADIUS + DISPLAY_GRIP_LEDGE
					        );
				}
				rotate([0,0, -wedge_angle/2])
					wedge( h = DOWEL_PRINTED_SOCKET_BLOCK
					     , r = DISPLAY_RADIUS + DISPLAY_GRIP_LEDGE
					     , d = wedge_angle
					     );
			}
			
			// The excess wedge excluding space for the axel
			difference() {
				translate([0,0,-0.5])
				cylinder( h = DOWEL_PRINTED_SOCKET_BLOCK + 1
				        , r = DISPLAY_RADIUS - DISPLAY_THICKNESS - DISPLAY_GRIP_THICKNESS
				        );
				translate([0, -DOWEL_PRINTED_SOCKET_BLOCK/2, 0])
					cube([ DISPLAY_RADIUS - DISPLAY_THICKNESS
					     , DOWEL_PRINTED_SOCKET_BLOCK
					     , DOWEL_PRINTED_SOCKET_BLOCK
					     ]);
			}
			
			// The excess axel socket 
			translate([0,0,-0.5])
			cylinder( h = DOWEL_PRINTED_SOCKET_BLOCK + 1
			        , r = DISPLAY_RADIUS
			              - DISPLAY_THICKNESS
			              - DISPLAY_GRIP_THICKNESS
			              - DOWEL_PRINTED_SOCKET_DEPTH
			        );
			
			// Drill out the hole for the dowel
			translate([0, 0, DOWEL_PRINTED_SOCKET_BLOCK/2])
				rotate([0, 90, 0])
					cylinder( h = DISPLAY_RADIUS - DISPLAY_THICKNESS - DISPLAY_GRIP_THICKNESS
					        , r = DOWEL_PRINTED_SOCKET_RADIUS
					        );
		}
	}
}




// An axel with an arbitary number of spokes, a shaft and an inner-bearing
// fitting with motor key.
//
// The center of the spoke holes are at BEARING_THICKNESS +
// DISPLAY_GRIP_THICKNESS +
// DOWEL_PRINTED_SOCKET_BLOCK/2.
module axel(num_spokes, keyed = false) {
	// Work out the minimum radius of the inside of the axel which will fit the
	// specified number of spokes. (Cosine rule rearranged)
	min_inner_radius = sqrt(pow(DOWEL_PRINTED_SOCKET_BLOCK,2) / (2*(1 - cos(360/num_spokes))));
	
	inner_radius = max(min_inner_radius, BEARING_INNER_RADIUS + DISPLAY_GRIP_THICKNESS - BEARING_PRINT_SLACK);
	
	// Position of the end of rods within the axel
	rod_inner_radius = inner_radius * cos((360/num_spokes)/2);
	
	color(COLOUR_3D_PRINTED) {
		// Bearing lip contact
		translate([0,0,BEARING_THICKNESS])
			cylinder( r = BEARING_INNER_RADIUS + BEARING_INNER_LIP - BEARING_PRINT_SLACK
			        , h = DISPLAY_GRIP_THICKNESS
			        );
		
		// Bearing fitting with motor keying
		difference() {
			// Bearing fitting
			cylinder( r = BEARING_INNER_RADIUS - BEARING_PRINT_SLACK
			        , h = BEARING_THICKNESS
			        );
			
			// Keying
			if (keyed) {
				translate([0,0,-1])
				intersection() {
					cylinder( r = MOTOR_SHAFT_RADIUS
					        , h = MOTOR_SHAFT_LENGTH+1
					        );
					cube( [ MOTOR_SHAFT_RADIUS*2
					      , MOTOR_SHAFT_KEY_WIDTH
					      , 2*(MOTOR_SHAFT_LENGTH+2)
					      ]
					    , center=true
					    );
				}
			}
		}
		
		// Axel body
		translate([0,0,BEARING_THICKNESS + DISPLAY_GRIP_THICKNESS])
		difference() {
			union() {
				// Central cylinder
				cylinder( r = inner_radius
				        , h = DOWEL_PRINTED_SOCKET_BLOCK
				        );
				// Blocks for the spokes
				for (i = [0:num_spokes-1]) {
					rotate([0,0,i*(360/num_spokes)])
						translate([rod_inner_radius,-DOWEL_PRINTED_SOCKET_BLOCK/2,0])
							cube([ DOWEL_PRINTED_SOCKET_DEPTH
							     , DOWEL_PRINTED_SOCKET_BLOCK
							     , DOWEL_PRINTED_SOCKET_BLOCK
							     ]);
				}
			}
			
			// Drill out the holes for the spokes
			for (i = [0:num_spokes-1]) {
				rotate([0, 0, i*(360/num_spokes)])
					translate([rod_inner_radius, 0, DOWEL_PRINTED_SOCKET_BLOCK/2])
						rotate([0, 90, 0])
							cylinder( h = DOWEL_PRINTED_SOCKET_DEPTH+1
							        , r = DOWEL_PRINTED_SOCKET_RADIUS
							        );
			}
			
			// Drill out the hole for the shaft
			translate([0,0,DOWEL_PRINTED_SOCKET_BLOCK-DOWEL_PRINTED_SOCKET_DEPTH])
			cylinder( h = DOWEL_PRINTED_SOCKET_DEPTH+1
			        , r = DOWEL_PRINTED_SOCKET_RADIUS
			        );
		}
	}
}


// Display with grips and axels.
module display_assembly() {
	// Bottom Axel with shaft
	axel(DISPLAY_BASE_SPOKES, keyed = true);
	
	translate([0,0,BEARING_THICKNESS + DISPLAY_GRIP_THICKNESS]) { 
		// Cylinder Itself
		translate([0,0,DISPLAY_GRIP_THICKNESS])
			%display();
		
		// Base Support
		for (i = [0:DISPLAY_BASE_SPOKES-1])
			display_grip(i*(360/DISPLAY_BASE_SPOKES));
		
		// Top Support
		translate([0,0, DISPLAY_HEIGHT + 2*DISPLAY_GRIP_THICKNESS]) {
			// Supports
			for (i = [0:DISPLAY_TOP_SPOKES])
				rotate([180,0,0])
					display_grip(i*(360/DISPLAY_TOP_SPOKES));
			// Axel at the top
			translate([0,0,BEARING_THICKNESS + DISPLAY_GRIP_THICKNESS])
				rotate([180,0,0])
					axel(DISPLAY_TOP_SPOKES);
		}
	}
}


// An N-dowel bracket
module bracket(angles = [-180/6, 0, 180/6]) {
	// XXX: Because I can't compute this in OSCAD...
	min_angle = angles[1] - angles[0];
	
	// Work out the minimum radius of the inside of the bracket from which the
	// rods should radiate.
	min_inner_radius = sqrt(pow(2.5*DOWEL_PRINTED_SOCKET_RADIUS,2) / (2*(1 - cos(min_angle))));
	
	color(COLOUR_3D_PRINTED) {
		// The joint between the two angles
		cylinder(r = DOWEL_PRINTED_SOCKET_BLOCK/2, h = DOWEL_PRINTED_SOCKET_BLOCK);
		
		difference() {
			// Blocks
			for (a = angles) {
				rotate([0,0,a]) {
					translate([0, -DOWEL_PRINTED_SOCKET_BLOCK/2, 0])
						cube([ min_inner_radius + DOWEL_PRINTED_SOCKET_DEPTH
						     , DOWEL_PRINTED_SOCKET_BLOCK
						     , DOWEL_PRINTED_SOCKET_BLOCK
						     ]);
				}
			}
			
			// Holes
			for (a = angles) {
				rotate([0,0,a]) {
					translate([min_inner_radius, 0, DOWEL_PRINTED_SOCKET_BLOCK/2])
						rotate([0,90,0])
							cylinder(r = DOWEL_PRINTED_SOCKET_RADIUS, h = DOWEL_PRINTED_SOCKET_DEPTH+1);
				}
			}
		}
	}
}


// A 3-spoked bracket which also terminates a long vertial shaft
module terminal_bracket() {
	color(COLOUR_3D_PRINTED)
	difference() {
		bracket();
		
		translate([0,0,DOWEL_PRINTED_SOCKET_BLOCK-DOWEL_PRINTED_SOCKET_DEPTH])
		cylinder( r = DOWEL_PRINTED_SOCKET_RADIUS
		        , h = DOWEL_PRINTED_SOCKET_DEPTH+1
		        );
	}
}



////////////////////////////////////////////////////////////////////////////////
// Printable Parts (for STL Export)
////////////////////////////////////////////////////////////////////////////////

// Top Axel
module print_top_axel() {
	translate([0,0,(BEARING_THICKNESS + DISPLAY_GRIP_THICKNESS + DOWEL_PRINTED_SOCKET_BLOCK)])
	rotate([180,0,0])
	axel(DISPLAY_TOP_SPOKES, keyed = false);
}

// Bottom Axel
module print_base_axel() {
	translate([0,0,(BEARING_THICKNESS + DISPLAY_GRIP_THICKNESS + DOWEL_PRINTED_SOCKET_BLOCK)])
	rotate([180,0,0])
	axel(DISPLAY_BASE_SPOKES, keyed = true);
}


////////////////////////////////////////////////////////////////////////////////
// What's displayed
////////////////////////////////////////////////////////////////////////////////

//display_assembly();

//// Top Axel
//translate([0,0,-(BEARING_THICKNESS + DISPLAY_GRIP_THICKNESS)])
//rotate([0,0,60])
//axel(6);
//for (a = [0:2]) {
//	rotate([0,0,a*(360/3)])
//		translate([-100,0,0])
//			terminal_bracket();
//}


print_base_axel();
