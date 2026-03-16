module fsm (
    parameter num_floors = 16,
    parameter bits= $clog2(num_floors), //log2
    parameter clk_freq= 100_000_000, //100MGHZ
    parameter floor_travel_sec = 2,
    parameter door_open_sec = 3
)(

    input  wire clk,
    input  wire rst_n,
    input  wire emergency,
 
    // scheduler inputs (combinational) (updated every cycle)
    input  wire [bits-1:0] next_floor,
    input  wire next_direction,
    input  wire has_request,
 
    output reg  [bits-1:0] current_floor,
    output reg  [bits-1:0] target_floor,
    output reg  direction, // 1-up 0-down
    output reg  [num_floors-1:0] service_clr, // 1-cycle pulse
    output reg  [2:0] state,
    output reg  door_open,
    output reg  moving
);
    
endmodule

