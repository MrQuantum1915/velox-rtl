// =============================================================================
// Module  : top
// Project : Velox RTL – Multi-Object Speed Measurement (Nexys A7-100T)
//
// Board pin-out (Nexys A7-100T)
// ──────────────────────────────
//  CLK100MHZ   → E3        (100 MHz oscillator)
//  CPU_RESETN  → C12       (active-low pushbutton reset)
//  SENSOR_A    → JA[0]     (IR sensor A, active-low)
//  SENSOR_B    → JA[1]     (IR sensor B, active-low)
//  SEG         → {CA..CG}  (7-segment cathodes, active-low)
//  AN[3:0]     → AN[3:0]   (7-segment anodes, active-low)
//  LED[0]      → T8        (overflow indicator)
//  LED[1]      → V9        (too-fast indicator)
//  LED[2]      → R8        (timeout error indicator)
//
// Pipeline Overview
// ─────────────────
//   Sensor A ──► input_capture_a ──► measurement ──► datapath ──► seg7_display
//   Sensor B ──► input_capture_b ──┘                     ▲
//                                                   fsm_control
//
// Design notes
// ─────────────
//  * All flip-flops run on the single 100 MHz clock (clk).
//  * Sensor inputs are asynchronous; input_capture handles CDC.
//  * The measurement module maintains a 4-entry circular buffer for
//    in-flight objects, enabling true pipelined multi-object measurement.
//  * Speed is displayed in cm/s on the 4-digit 7-segment display.
// =============================================================================

`timescale 1ns / 1ps

module top (
    // Board clock & reset
    input  wire       CLK100MHZ,   // 100 MHz XTAL
    input  wire       CPU_RESETN,  // active-low reset button

    // IR sensor inputs (active-low: 0 = beam broken = object present)
    input  wire       SENSOR_A,
    input  wire       SENSOR_B,

    // 7-segment display
    output wire [6:0] SEG,         // cathodes {CA..CG}
    output wire [3:0] AN,          // anodes (active-low)

    // Status LEDs
    output wire       LED_OVERFLOW,   // FIFO overflow (too many objects)
    output wire       LED_TOO_FAST,   // object faster than LUT range
    output wire       LED_TIMEOUT     // object never reached sensor B
);

    // =========================================================================
    // Internal wires
    // =========================================================================

    // -- Synchronised sensor signals --
    wire sync_a, sync_b;
    wire fall_a, rise_a;   // sensor A edge strobes
    wire fall_b, rise_b;   // sensor B edge strobes

    // -- Measurement stage outputs --
    wire [31:0] delta_t;
    wire        meas_valid;
    wire        meas_overflow;

    // -- Datapath (speed compute) outputs --
    wire [15:0] speed_cms;
    wire        speed_valid;
    wire        too_fast;
    wire        fifo_full;
    wire        fifo_empty;

    // -- FSM outputs --
    wire        compute_en;
    wire        display_en;
    wire        timeout_err;

    // =========================================================================
    // Stage 1-A: Synchronise Sensor A
    // =========================================================================
    input_capture u_cap_a (
        .clk       (CLK100MHZ),
        .rst_n     (CPU_RESETN),
        .sensor_in (SENSOR_A),
        .sync_out  (sync_a),
        .fall_edge (fall_a),
        .rise_edge (rise_a)
    );

    // =========================================================================
    // Stage 1-B: Synchronise Sensor B
    // =========================================================================
    input_capture u_cap_b (
        .clk       (CLK100MHZ),
        .rst_n     (CPU_RESETN),
        .sensor_in (SENSOR_B),
        .sync_out  (sync_b),
        .fall_edge (fall_b),
        .rise_edge (rise_b)
    );

    // =========================================================================
    // Stage 2: Time Measurement
    // =========================================================================
    measurement #(
        .CNT_WIDTH (32),
        .FIFO_DEPTH (4),
        .ADDR_W    (2)
    ) u_meas (
        .clk        (CLK100MHZ),
        .rst_n      (CPU_RESETN),
        .fall_edge_a(fall_a),
        .fall_edge_b(fall_b),
        .delta_t    (delta_t),
        .meas_valid (meas_valid),
        .overflow   (meas_overflow)
    );

    // =========================================================================
    // Stages 3+: Datapath (FIFO → speed_compute)
    // =========================================================================
    datapath #(
        .DIST_CM (10)    // 10 cm sensor separation – change as needed
    ) u_data (
        .clk        (CLK100MHZ),
        .rst_n      (CPU_RESETN),
        .delta_t    (delta_t),
        .meas_valid (meas_valid),
        .speed_cms  (speed_cms),
        .speed_valid(speed_valid),
        .too_fast   (too_fast),
        .fifo_full  (fifo_full),
        .fifo_empty (fifo_empty)
    );

    // =========================================================================
    // FSM: pipeline flow control
    // =========================================================================
    fsm_control #(
        .HOLD_CYCLES    (32'd1000),   // 1 s display hold
        .TIMEOUT_CYCLES (32'd500_000)    // 2 s object timeout
    ) u_fsm (
        .clk        (CLK100MHZ),
        .rst_n      (CPU_RESETN),
        .fall_edge_a(fall_a),
        .fall_edge_b(fall_b),
        .meas_valid (meas_valid),
        .speed_valid(speed_valid),
        .compute_en (compute_en),
        .display_en (display_en),
        .timeout_err(timeout_err)
    );

    // =========================================================================
    // Stage 4: 7-Segment Display
    // Hold the last valid speed until a new measurement arrives
    // =========================================================================
    reg [15:0] speed_latch;

    always @(posedge CLK100MHZ) begin
        if (!CPU_RESETN)
            speed_latch <= 16'b0;
        else if (speed_valid)
            speed_latch <= speed_cms;
    end

    seg7_display u_seg (
        .clk      (CLK100MHZ),
        .rst_n    (CPU_RESETN),
        .speed_cms(speed_latch),
        .disp_en  (display_en),
        .seg      (SEG),
        .an       (AN)
    );

    // =========================================================================
    // LED status indicators
    // =========================================================================
    // Latch sticky flags so they remain visible after the event
    reg led_ovf_r, led_fast_r, led_tmo_r;

    always @(posedge CLK100MHZ) begin
        if (!CPU_RESETN) begin
            led_ovf_r  <= 1'b0;
            led_fast_r <= 1'b0;
            led_tmo_r  <= 1'b0;
        end else begin
            if (meas_overflow | fifo_full) led_ovf_r  <= 1'b1;
            if (too_fast)                  led_fast_r <= 1'b1;
            if (timeout_err)               led_tmo_r  <= 1'b1;
        end
    end

    assign LED_OVERFLOW = led_ovf_r;
    assign LED_TOO_FAST = led_fast_r;
    assign LED_TIMEOUT  = led_tmo_r;

    // Prevent unused-signal warnings for rise edges (kept for future use)
    // synthesis translate_off
    wire _unused = rise_a | rise_b | compute_en | fifo_empty;
    // synthesis translate_on

endmodule