module fsm_control (
    input  wire clk,
    input  wire rst_n,
    input  wire s2_valid,      // measurement done
    input  wire div_done,      // speed_compute done
 
    output reg  start_div,     // single-cycle pulse: tell S3 to start
    output reg  stall,         // hold S2 while S3 is busy
    output reg  latch_display, // single-cycle pulse: tell S4 to show result
    output reg  [2:0] state    // current FSM state → LED[3:2] debug
);
 
// State encoding (for LED debug map)
localparam IDLE       = 3'd0;
localparam ARMED      = 3'd1;
localparam MEASURING  = 3'd2;
localparam COMPUTING  = 3'd3;
localparam DISPLAYING = 3'd4;
endmodule