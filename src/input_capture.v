// Stage 1: synchronizer + edge detector

// =============================================================================
// Module  : input_capture
// Project : Velox RTL – Multi-Object Speed Measurement (Nexys A7-100T)
// Stage   : 1 – Sensor Synchronisation & Edge Detection
//
// Each IR sensor produces an asynchronous active-low pulse when an object
// breaks the beam.  This module:
//   1. Passes the raw signal through a 2-FF synchroniser to eliminate
//      metastability (standard practice for CDC).
//   2. Detects the falling edge (object arriving) and rising edge
//      (object leaving) and outputs single-cycle strobes.
//
// Inputs
//   clk        – 100 MHz system clock
//   rst_n      – Active-low synchronous reset
//   sensor_in  – Raw asynchronous sensor signal (active-low: 0 = object present)
//
// Outputs
//   sync_out   – Synchronised, registered sensor level (active-low retained)
//   fall_edge  – 1-cycle strobe: object just broke the beam  (0→1 of ~signal)
//   rise_edge  – 1-cycle strobe: object just cleared the beam(1→0 of ~signal)
// =============================================================================

`timescale 1ns / 1ps

module input_capture (
    input  wire clk,
    input  wire rst_n,
    input  wire sensor_in,   // asynchronous, active-low
    output reg  sync_out,    // synchronised level (active-low)
    output wire fall_edge,   // object enters  (negedge of sensor_in)
    output wire rise_edge    // object exits   (posedge of sensor_in)
);

    // -------------------------------------------------------------------------
    // Stage 1: Two-flop synchroniser
    // -------------------------------------------------------------------------
    reg meta_ff;   // first  capture FF – may be metastable, never used combinatorially
    reg sync_ff;   // second capture FF – stable, used downstream

    always @(posedge clk) begin
        if (!rst_n) begin
            meta_ff  <= 1'b1;   // sensor idle = high
            sync_ff  <= 1'b1;
        end else begin
            meta_ff  <= sensor_in;
            sync_ff  <= meta_ff;
        end
    end

    // -------------------------------------------------------------------------
    // Stage 2: One extra register for edge detection
    // -------------------------------------------------------------------------
    reg sync_prev;

    always @(posedge clk) begin
        if (!rst_n) begin
            sync_prev <= 1'b1;
            sync_out  <= 1'b1;
        end else begin
            sync_prev <= sync_ff;
            sync_out  <= sync_ff;
        end
    end

    // -------------------------------------------------------------------------
    // Edge strobes (single cycle)
    //   sensor is active-LOW, so:
    //     falling edge  = prev HIGH, now LOW  → object entered beam
    //     rising  edge  = prev LOW,  now HIGH → object left   beam
    // -------------------------------------------------------------------------
    assign fall_edge = sync_prev & ~sync_ff;   // 1→0 on sensor (object enters)
    assign rise_edge = ~sync_prev & sync_ff;   // 0→1 on sensor (object leaves)

endmodule