module seg7_display #(
    parameter CLK_FREQ = 100_000_000
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        s3_valid,      // latch new value when HIGH
    input  wire        unit_sel,      // for digit[7] glyph: S = m/s, C = km/h
    input  wire [23:0] speed_fixed,   // Q16.8 from speed_compute.v
 
    output reg  [7:0]  seg_an,        // anodes  — active LOW
    output reg  [6:0]  seg_cat        // cathodes — active LOW {g,f,e,d,c,b,a}
);
endmodule