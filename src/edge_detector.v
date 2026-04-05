// =============================================================================
// Module  : edge_detector
// Project : Velox RTL – Multi-Object Speed Measurement (Nexys A7-100T)
// Purpose : Standalone, reusable single-cycle edge-strobe generator
//
// Usage
// -----
// Instantiate after a synchroniser when you need explicit edge strobes from
// a signal that is already in the clock domain.  input_capture.v includes
// equivalent logic internally; this module exists as a standalone primitive
// that can be reused anywhere in the design.
//
//   ┌──────────────┐     ┌─────────────────┐
//   │ input_capture│────►│  edge_detector  │
//   │  (2-FF sync) │     │  (this module)  │
//   └──────────────┘     └─────────────────┘
//
// Operation
// ---------
//   sig_in ──► [D Q]──► current ──► rising  = current &  ~prev
//               clk       │          falling = ~current &  prev
//                          └─► prev
//
// Ports
//   clk      – system clock
//   rst_n    – active-low synchronous reset
//   sig_in   – synchronised (already in clock domain) input signal
//   rising   – 1-cycle strobe on 0→1 transition
//   falling  – 1-cycle strobe on 1→0 transition
//   sig_q    – registered output of sig_in (1-cycle delay)
// =============================================================================

`timescale 1ns / 1ps

module edge_detector (
    input  wire clk,
    input  wire rst_n,
    input  wire sig_in,    // must already be synchronised to clk domain
    output wire rising,    // single-cycle strobe: 0→1
    output wire falling,   // single-cycle strobe: 1→0
    output reg  sig_q      // registered level
);

    reg sig_prev;

    always @(posedge clk) begin
        if (!rst_n) begin
            sig_prev <= 1'b0;
            sig_q    <= 1'b0;
        end else begin
            sig_prev <= sig_in;
            sig_q    <= sig_in;
        end
    end

    // Rising edge:  previous LOW,  current HIGH
    assign rising  =  sig_in & ~sig_prev;

    // Falling edge: previous HIGH, current LOW
    assign falling = ~sig_in &  sig_prev;

endmodule