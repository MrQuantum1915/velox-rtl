// Stage 3: speed computation
// =============================================================================
// Module  : speed_compute
// Project : Velox RTL – Multi-Object Speed Measurement (Nexys A7-100T)
// Stage   : 3 – Speed Computation
//
// speed [cm/s] = DIST_CM * 100000000 / delta_t
// =============================================================================

`timescale 1ns / 1ps

module speed_compute #(
    parameter DIST_CM = 10
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire [31:0] delta_t,
    input  wire        data_valid,
    output reg  [15:0] speed_cms,
    output reg         speed_valid,
    output reg         too_fast
);

    localparam [63:0] NUMERATOR = DIST_CM * 64'd100000000;

    reg [31:0] dt_r;
    reg        valid_r;
    wire [63:0] quotient;

    assign quotient = (dt_r == 0) ? 64'd0 : (NUMERATOR / dt_r);

    always @(posedge clk) begin
        if (!rst_n) begin
            dt_r       <= 32'd0;
            valid_r    <= 1'b0;
            speed_cms  <= 16'd0;
            speed_valid <= 1'b0;
            too_fast   <= 1'b0;
        end else begin
            dt_r    <= delta_t;
            valid_r <= data_valid;

            speed_valid <= valid_r;

            if (valid_r) begin
                if (dt_r == 0) begin
                    speed_cms <= 16'hFFFF;
                    too_fast  <= 1'b1;
                end else if (quotient > 64'd65535) begin
                    speed_cms <= 16'hFFFF;
                    too_fast  <= 1'b1;
                end else begin
                    speed_cms <= quotient[15:0];
                    too_fast  <= 1'b0;
                end
            end else begin
                too_fast <= 1'b0;
            end
        end
    end

endmodule