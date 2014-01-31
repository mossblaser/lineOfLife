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
DOWEL_PRINTED_SOCKET_RADIUS= DOWEL_RADIUS + 0.3;
DOWEL_CUT_HOLE_RADIUS= DOWEL_RADIUS * 3;

// Thickness of a block into which a dowel rod inserted should be
DOWEL_PRINTED_SOCKET_BLOCK = DOWEL_PRINTED_SOCKET_RADIUS * 3;
// Depth of a socket to accept the dowel rod
DOWEL_PRINTED_SOCKET_DEPTH = DOWEL_PRINTED_SOCKET_RADIUS * 2.5;

// As above but for load-bearing joints
DOWEL_PRINTED_SOCKET_BLOCK_LOADED = DOWEL_PRINTED_SOCKET_RADIUS * 4;
DOWEL_PRINTED_SOCKET_DEPTH_LOADED = DOWEL_PRINTED_SOCKET_RADIUS * 4;

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
BEARING_INNER_RADIUS = 18/2; // Inner radius
BEARING_OUTER_RADIUS = 34/2; // Outer radius
BEARING_THICKNESS    = 10;   // Ring thickness
BEARING_INNER_LIP    = 2;    // Size of the edge of the inner ring
BEARING_OUTER_LIP    = 5;    // Size of the fixed outer ring
BEARING_PRINT_SLACK  = 0.5;  // Amount of slack to add to the radius for 3D printed fittings

// Motor shaft dimensions
MOTOR_SHAFT_RADIUS        = (5+0.5)/2;
MOTOR_SHAFT_KEY_WIDTH     = 3+0.5;
MOTOR_SHAFT_LENGTH        = 6+1;
MOTOR_SHAFT_CENTER_OFFSET = 8;

// Motor Body Dimensions
MOTOR_RADIUS = 28/2 + 0.3;
MOTOR_BLOCK_RADIUS = 17.5 + 0.3;
MOTOR_BLOCK_WIDTH = 14.5 + 0.3;
MOTOR_DEPTH = 19 + 0.3;
MOTOR_TAB_RADIUS = 7/2 + 0.3;
MOTOR_TAB_SPACING = 35 + 0.3;
MOTOR_TAB_THICKNESS = 1;
MOTOR_WIRE_WIDTH = 12;
MOTOR_WIRE_HEIGHT = 15;

// Motor holder wall thicknesses
MOTOR_WALL_THICKNESS = 2.5;
// The thickness of the motor bearing cup's base
MOTOR_SHELF_THICKNESS = 3;
// The thickness of the outer ring around the base bearing
MOTOR_SHELF_RING_THICKNESS = 4;
// Slack added to the shelf's dimensions itself 
MOTOR_SHELF_SLACK = 0.5;

// Number of spokes/grips used to support the display
DISPLAY_BASE_SPOKES = 6;
// Number of spokes at the top of the display
DISPLAY_TOP_SPOKES = 3;

// Seperation between the two rods which run down the side of the system
// attached to the electronics.
DOUBLE_SHAFT_SEP = 33; // Approximately the width of circuit board (1.4")


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
module display_grip( angle
                   , DOWEL_PRINTED_SOCKET_BLOCK = DOWEL_PRINTED_SOCKET_BLOCK
                   , DOWEL_PRINTED_SOCKET_DEPTH = DOWEL_PRINTED_SOCKET_DEPTH
                   ) {
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
module axel( num_spokes
           , keyed = false
           , DOWEL_PRINTED_SOCKET_BLOCK = DOWEL_PRINTED_SOCKET_BLOCK
           , DOWEL_PRINTED_SOCKET_DEPTH = DOWEL_PRINTED_SOCKET_DEPTH) {
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
	axel( DISPLAY_BASE_SPOKES
	    , keyed = true
	    , DOWEL_PRINTED_SOCKET_BLOCK = DOWEL_PRINTED_SOCKET_BLOCK_LOADED
	    , DOWEL_PRINTED_SOCKET_DEPTH = DOWEL_PRINTED_SOCKET_DEPTH_LOADED
	    );
	
	translate([0,0,BEARING_THICKNESS + DISPLAY_GRIP_THICKNESS]) { 
		// Cylinder Itself
		translate([0,0,DISPLAY_GRIP_THICKNESS])
			%display();
		
		// Base Support
		for (i = [0:DISPLAY_BASE_SPOKES-1])
			display_grip( i*(360/DISPLAY_BASE_SPOKES)
			            , DOWEL_PRINTED_SOCKET_BLOCK = DOWEL_PRINTED_SOCKET_BLOCK_LOADED
			            , DOWEL_PRINTED_SOCKET_DEPTH = DOWEL_PRINTED_SOCKET_DEPTH_LOADED
			            );
		
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



// An axel-like item which supports the outside of the top bearing and connects
// to the outer frame.
module top_bearing_grip(num_spokes = 3) {
	// Work out the minimum radius of the inside of the axel which will fit the
	// specified number of spokes. (Cosine rule rearranged)
	min_inner_radius = sqrt(pow(DOWEL_PRINTED_SOCKET_BLOCK,2) / (2*(1 - cos(360/num_spokes))));
	
	inner_radius = max(min_inner_radius, BEARING_OUTER_RADIUS + DISPLAY_GRIP_THICKNESS + BEARING_PRINT_SLACK);
	
	// Position of the end of rods within the axel
	rod_inner_radius = inner_radius * cos((360/num_spokes)/2);
	
	color(COLOUR_3D_PRINTED) {
		// The axel
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
		}
		
		// The grip for the bearing
		difference() {
			// Outer cylinder
			cylinder( r = inner_radius
			        , h = BEARING_THICKNESS + DISPLAY_GRIP_THICKNESS
			        );
			
			// Drill out the bearing grip
			translate([0,0,-1])
			cylinder( r = BEARING_OUTER_RADIUS + BEARING_PRINT_SLACK
			        , h = BEARING_THICKNESS+1
			        );
			
			// Drill out the lip
			translate([0,0,-1])
			cylinder( r = BEARING_OUTER_RADIUS - BEARING_OUTER_LIP + BEARING_PRINT_SLACK
			        , h = BEARING_THICKNESS+DISPLAY_GRIP_THICKNESS+1
			        );
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


// A 3-spoked bracket which also terminates a long double vertial shaft
module double_terminal_bracket() {
	color(COLOUR_3D_PRINTED)
	difference() {
		union() {
			bracket();
			
			// Extension wings
			hull() {
				for (offset = [-DOUBLE_SHAFT_SEP/2,DOUBLE_SHAFT_SEP/2]) {
					translate([0,offset,0])
					cylinder( r = DOWEL_PRINTED_SOCKET_BLOCK/2
					        , h = DOWEL_PRINTED_SOCKET_BLOCK
					        );
				}
			}
		}
		
		// Drill out Shafts
		for (offset = [-DOUBLE_SHAFT_SEP/2,DOUBLE_SHAFT_SEP/2]) {
			translate([0,offset,DOWEL_PRINTED_SOCKET_BLOCK-DOWEL_PRINTED_SOCKET_DEPTH])
			cylinder( r = DOWEL_PRINTED_SOCKET_RADIUS
			        , h = DOWEL_PRINTED_SOCKET_DEPTH+1
			        );
		}
	}
}


// The module in which the motor sits at the bottom of the system. Features 3
// spokes.
module motor_base(num_spokes = 3) {
	color(COLOUR_3D_PRINTED) {
		difference() {
			// The basic block of material out of which the unit will be cut
			union() {
				// Size of the material from which a shelf will be cut for the bearing
				cylinder( r = BEARING_OUTER_RADIUS + MOTOR_SHELF_RING_THICKNESS + MOTOR_WALL_THICKNESS
				        , h = MOTOR_DEPTH + MOTOR_WALL_THICKNESS + MOTOR_SHELF_THICKNESS + BEARING_THICKNESS+ DOWEL_PRINTED_SOCKET_BLOCK
				        );
				
				translate([-MOTOR_SHAFT_CENTER_OFFSET,0,0]) {
					// Size of the material from which space will be cut for the motor
					// Motor body
					cylinder( r = MOTOR_RADIUS + MOTOR_WALL_THICKNESS
					        , h = MOTOR_DEPTH + MOTOR_WALL_THICKNESS + MOTOR_SHELF_THICKNESS + BEARING_THICKNESS + DOWEL_PRINTED_SOCKET_BLOCK
					        );
					
					// ...and the motor block
					translate([ -(MOTOR_BLOCK_RADIUS + MOTOR_WALL_THICKNESS)
					          , -(MOTOR_BLOCK_WIDTH + 2*(MOTOR_WALL_THICKNESS))/2
					          , 0])
					cube([ MOTOR_BLOCK_RADIUS + MOTOR_WALL_THICKNESS
					     , MOTOR_BLOCK_WIDTH + 2*(MOTOR_WALL_THICKNESS)
					     , MOTOR_DEPTH + MOTOR_WALL_THICKNESS + MOTOR_SHELF_THICKNESS + BEARING_THICKNESS + DOWEL_PRINTED_SOCKET_BLOCK
					     ]);
				}
			}
			
			// Carve out the shelf
			translate([0,0,MOTOR_WALL_THICKNESS + MOTOR_DEPTH + DOWEL_PRINTED_SOCKET_BLOCK])
			cylinder( r = BEARING_OUTER_RADIUS + MOTOR_SHELF_RING_THICKNESS
			        , h = MOTOR_DEPTH + MOTOR_WALL_THICKNESS + MOTOR_SHELF_THICKNESS + BEARING_THICKNESS
			        );
			
			// Carve out the motor
			translate([-MOTOR_SHAFT_CENTER_OFFSET,0,MOTOR_WALL_THICKNESS + DOWEL_PRINTED_SOCKET_BLOCK]) {
				// Carve out the motor body
				cylinder( r = MOTOR_RADIUS
				        , h = MOTOR_DEPTH + MOTOR_SHELF_THICKNESS + BEARING_THICKNESS + 1
				        );
				
				// ...and the motor block
				translate([ -MOTOR_BLOCK_RADIUS
				          , -MOTOR_BLOCK_WIDTH/2
				          , 0])
				cube([ MOTOR_BLOCK_RADIUS
				     , MOTOR_BLOCK_WIDTH
				     , MOTOR_DEPTH + MOTOR_SHELF_THICKNESS + BEARING_THICKNESS + 1
				     ]);
				
				// ...and the tabs
				translate([0, 0, MOTOR_DEPTH - MOTOR_TAB_THICKNESS]) {
					hull() {
						for (offset = [-MOTOR_TAB_SPACING/2, MOTOR_TAB_SPACING/2]) {
							translate([0, offset, 0])
							cylinder( r = MOTOR_TAB_RADIUS
							        , h = MOTOR_TAB_THICKNESS + BEARING_THICKNESS + MOTOR_SHELF_THICKNESS + 1
							        );
						}
					}
				}
				
				// ...and the wiring channel
				translate([0,0, MOTOR_WIRE_HEIGHT])
				rotate([0,-90,0])
				cylinder( r = MOTOR_WIRE_WIDTH/2
				        , h = MOTOR_BLOCK_RADIUS+MOTOR_WALL_THICKNESS+1
				        );
			}
			
			// Drill out the spokes
			for (i = [0:num_spokes-1]) {
				rotate([0,0,i*(360/num_spokes)])
				translate([ BEARING_OUTER_RADIUS + MOTOR_SHELF_RING_THICKNESS + MOTOR_WALL_THICKNESS
				            - DOWEL_PRINTED_SOCKET_DEPTH
				          , 0
				          , DOWEL_PRINTED_SOCKET_BLOCK/2
				          ])
				rotate([0,90,0])
				cylinder( r = DOWEL_PRINTED_SOCKET_RADIUS
				        , h = MOTOR_BLOCK_RADIUS+MOTOR_SHAFT_CENTER_OFFSET // Long enough...
				        );
			}
		}
	}
}


// The cup which sits between the motor base and the bearing
module motor_base_bearing_fitting() {
	color(COLOUR_3D_PRINTED) {
		difference() {
			// The cup itself
			cylinder( r = BEARING_OUTER_RADIUS + MOTOR_SHELF_RING_THICKNESS - MOTOR_SHELF_SLACK
			        , h = BEARING_THICKNESS + MOTOR_SHELF_THICKNESS
			        );
			
			// Carve out space for the bearing
			translate([0,0,MOTOR_SHELF_THICKNESS])
			cylinder( r = BEARING_OUTER_RADIUS + BEARING_PRINT_SLACK
			        , h = BEARING_THICKNESS + 1
			        );
			
			// Punch out everything except the lip
			translate([0,0,-0.5])
			cylinder( r = BEARING_OUTER_RADIUS - BEARING_OUTER_LIP
			        , h = MOTOR_SHELF_THICKNESS + 1
			        );
		}
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
	translate([0,0,(BEARING_THICKNESS + DISPLAY_GRIP_THICKNESS + DOWEL_PRINTED_SOCKET_BLOCK_LOADED)])
	rotate([180,0,0])
	axel( DISPLAY_BASE_SPOKES
	    , keyed = true
	    , DOWEL_PRINTED_SOCKET_BLOCK = DOWEL_PRINTED_SOCKET_BLOCK_LOADED
	    , DOWEL_PRINTED_SOCKET_DEPTH = DOWEL_PRINTED_SOCKET_DEPTH_LOADED
	    );
}

// Tripple bracket
module print_bracket() {
	terminal_bracket();
}

// Tripple bracket with two vertical attachments
module print_double_bracket() {
	double_terminal_bracket();
}

// Motor base
module print_motor_base() {
	motor_base();
}

// Motor base bearing fitting
module print_motor_base_bearing_fitting() {
	motor_base_bearing_fitting();
}

// A grip for the top of the display
module print_top_display_grip() {
	rotate([0,0,45])
	translate([-DISPLAY_RADIUS + DOWEL_PRINTED_SOCKET_BLOCK/2,0,0])
	display_grip(0);
}

// A grip for the bottom of the display
module print_base_display_grip() {
	rotate([0,0,45])
	translate([-DISPLAY_RADIUS + DOWEL_PRINTED_SOCKET_BLOCK_LOADED/2,0,0])
	display_grip( 0 
	            , DOWEL_PRINTED_SOCKET_BLOCK = DOWEL_PRINTED_SOCKET_BLOCK_LOADED
	            , DOWEL_PRINTED_SOCKET_DEPTH = DOWEL_PRINTED_SOCKET_DEPTH_LOADED
	            );
}

// A axel which holds the outside of the top bearing and connects to the frame
module print_top_bearing_grip() {
	translate([ 0,0
	          , DOWEL_PRINTED_SOCKET_BLOCK + BEARING_THICKNESS + DISPLAY_GRIP_THICKNESS
	          ])
	rotate([180,0,0])
	top_bearing_grip();
}


////////////////////////////////////////////////////////////////////////////////
// What's displayed
////////////////////////////////////////////////////////////////////////////////

//display_assembly();

//translate([0,0,-(BEARING_THICKNESS + DISPLAY_GRIP_THICKNESS)])
//rotate([0,0,60])
//top_bearing_grip(3);
//for (a = [0:2]) {
//	rotate([0,0,a*(360/3)])
//		translate([-100,0,0])
//			if (a == 0)
//				double_terminal_bracket();
//			else
//				terminal_bracket();
//}

print_motor_base();
