module speed_compute #(
    parameter CLK_FREQ    = 100_000_000,
    parameter DISTANCE_MM = 100        // physical gap between sensors in mm
                                       // set this to your actual hardware value
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,          // single-cycle pulse from fsm_control
    input  wire        unit_sel,       // 0 = m/s,  1 = km/h
    input  wire [31:0] elapsed_cycles, // from measurement.v
 
    output reg  [23:0] speed_fixed,    // Q16.8 result (16-bit int, 8-bit frac)
    output reg         div_done,       // single-cycle pulse when result ready
    output reg         s3_valid        // valid bit for S4
);
endmodule