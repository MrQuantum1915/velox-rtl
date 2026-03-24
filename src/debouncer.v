// =============================================================================
// Module  : debouncer
// Project : Velox RTL – Multi-Object Speed Measurement (Nexys A7-100T)
// Purpose : Glitch-filter / debouncer for mechanical switches or noisy sensors
//
// Algorithm – Shift-register majority vote
// ─────────────────────────────────────────
// The raw input is sampled at a configurable sub-rate (SAMPLE_DIV cycles).
// DEPTH consecutive samples are kept in a shift register.  The output is
// asserted only when ALL DEPTH samples are identical, eliminating any glitches
// shorter than (DEPTH × SAMPLE_DIV) clock cycles.
//
// Typical use:  SAMPLE_DIV=1_000, DEPTH=16  ⟹  16 ms debounce at 1 MHz
//               (or at 100 MHz: SAMPLE_DIV=100_000 ⟹ 1 ms sample rate,
//                16 ms debounce window)
//
// Note: IR sensor inputs in this design are fast optical sensors and usually
// do NOT need debouncing.  This module is provided for completeness and for
// use with mechanical pushbuttons (e.g., a manual trigger button).
//
// Ports
//   clk         – 100 MHz system clock
//   rst_n       – active-low synchronous reset
//   raw_in      – noisy asynchronous input (will be sampled; no CDC here –
//                 pair with input_capture for CDC if truly async)
//   debounced   – clean stable output
// =============================================================================

`timescale 1ns / 1ps

module debouncer #(
    parameter SAMPLE_DIV = 32'd100_000,  // sample every 1 ms at 100 MHz
    parameter DEPTH      = 16            // consecutive equal samples required
)(
    input  wire clk,
    input  wire rst_n,
    input  wire raw_in,
    output reg  debounced
);

    // =========================================================================
    // Sample-rate divider
    // =========================================================================
    reg [31:0]  sample_cnt;
    reg         sample_en;     // single-cycle enable at sample rate

    always @(posedge clk) begin
        if (!rst_n) begin
            sample_cnt <= 32'b0;
            sample_en  <= 1'b0;
        end else if (sample_cnt == SAMPLE_DIV - 1) begin
            sample_cnt <= 32'b0;
            sample_en  <= 1'b1;
        end else begin
            sample_cnt <= sample_cnt + 1'b1;
            sample_en  <= 1'b0;
        end
    end

    // =========================================================================
    // Shift register: one bit per sample
    // =========================================================================
    reg [DEPTH-1:0] sr;

    always @(posedge clk) begin
        if (!rst_n) begin
            sr <= {DEPTH{1'b0}};
        end else if (sample_en) begin
            sr <= {sr[DEPTH-2:0], raw_in};
        end
    end

    // =========================================================================
    // Output: assert when all samples agree
    // =========================================================================
    wire all_ones  = &sr;               // AND-reduction
    wire all_zeros = ~(|sr);            // NOR-reduction

    always @(posedge clk) begin
        if (!rst_n)
            debounced <= 1'b0;
        else if (all_ones)
            debounced <= 1'b1;
        else if (all_zeros)
            debounced <= 1'b0;
        // else: hold last stable value during transition
    end

endmodule