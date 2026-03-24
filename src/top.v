module top #(
    parameter CLK_FREQ    = 100_000_000,
    parameter DISTANCE_MM = 100
)(
    input  wire       clk,
    input  wire       btnc,        // active-high reset → invert to rst_n
    input  wire       sw0,         // unit select: 0 = m/s, 1 = km/h
    input  wire       ir_sensor0,  // raw IR pin — PMOD JA[0]
    input  wire       ir_sensor1,  // raw IR pin — PMOD JA[1]
 
    output wire [7:0] seg_an,
    output wire [6:0] seg_cat,
    output wire [7:0] led
);
 
// LED assignments (for reference when wiring)
// led[0]   = sensor0 pulse
// led[1]   = sensor1 pulse
// led[3:2] = fsm state
// led[4]   = unit_sel
// led[5]   = stall (divider busy)
// led[6]   = div_done (new result ready)

endmodule