module input_capture (
    input  wire clk,
    input  wire rst_n,
    input  wire sensor_raw,    // async signal direct from IR sensor pin
    output wire sensor_pulse,  // single-cycle HIGH pulse, metastability-safe
    output wire s1_valid       // same as sensor_pulse - valid bit for pipeline
);
endmodule
