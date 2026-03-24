module measurement #(
    parameter COUNTER_MAX = 32
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        sensor0_pulse,  // from input_capture
    input  wire        sensor1_pulse,  // from input_capture (linear only)

    output reg  [31:0] elapsed_cycles, // linear:   delta(t) in clock cycles
    output reg         measurement_done // 1-cycle pulse when result is ready
);
endmodule