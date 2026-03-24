// =============================================================================
// Module  : clock_divider
// Project : Velox RTL – Multi-Object Speed Measurement (Nexys A7-100T)
// Purpose : Generates enable pulses at lower rates from 100 MHz master clock
//
// All flip-flops in the design use the 100 MHz master clock.  This module
// produces a single-cycle enable strobe at the requested divided rate.
// Using an enable (rather than a gated clock) is the recommended practice
// for synthesis: it avoids clock-skew issues and is safe for static timing.
//
// Parameters
//   DIV_COUNT – number of 100 MHz cycles per enable pulse (default = 100 000
//               which gives a 1 kHz enable, useful for slow debug displays)
// =============================================================================

`timescale 1ns / 1ps

module clock_divider #(
    parameter DIV_COUNT = 32'd100_000   // default: 1 kHz enable from 100 MHz
)(
    input  wire clk,
    input  wire rst_n,
    output reg  clk_en    // single-cycle enable strobe at divided rate
);

    reg [31:0] cnt;

    always @(posedge clk) begin
        if (!rst_n) begin
            cnt    <= 32'b0;
            clk_en <= 1'b0;
        end else if (cnt == DIV_COUNT - 1) begin
            cnt    <= 32'b0;
            clk_en <= 1'b1;
        end else begin
            cnt    <= cnt + 1'b1;
            clk_en <= 1'b0;
        end
    end

endmodule