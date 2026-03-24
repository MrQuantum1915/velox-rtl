// =============================================================================
// Module  : fsm_control
// Project : Velox RTL – Multi-Object Speed Measurement (Nexys A7-100T)
// Purpose : Top-level Moore FSM controlling the measurement pipeline
//
// State Machine
// -------------
//
//   ┌─────────────────────────────────────────────────────────────┐
//   │                                                             │
//   ▼                                                             │
//  IDLE ──(fall_edge_a)──► WAIT_B ──(fall_edge_b)──► COMPUTE     │
//   ▲                        │                          │         │
//   │                        │(timeout)                 ▼         │
//   │                        └──────────────────────► DISPLAY ────┘
//   │                                                   │(hold_done)
//   └───────────────────────────────────────────────────┘
//
//  IDLE    : Waiting for first sensor to trigger.
//  WAIT_B  : Object is between the sensors; counting cycles.
//  COMPUTE : Assert compute_en for one cycle; speed stage processes.
//  DISPLAY : Hold speed on display for HOLD_CYCLES, then return to IDLE.
//
// For pipelined multi-object support, the FSM immediately returns to IDLE/
// WAIT_B after asserting compute_en.  The downstream stages handle queuing.
//
// Ports
//   fall_edge_a   – strobe: object crossed sensor A
//   fall_edge_b   – strobe: object crossed sensor B
//   meas_valid    – strobe: measurement stage has a valid delta_t
//   speed_valid   – strobe: speed_compute has a valid result
//   compute_en    – 1-cycle pulse: tell measurement to latch its output
//   display_en    – keep high while holding speed on display
//   timeout_err   – set if object never reaches sensor B within TIMEOUT cycles
// =============================================================================

`timescale 1ns / 1ps

module fsm_control #(
    parameter HOLD_CYCLES   = 32'd100_000_000,   // 1 second display hold
    parameter TIMEOUT_CYCLES = 32'd200_000_000   // 2 second max travel time
)(
    input  wire clk,
    input  wire rst_n,

    // Sensor events
    input  wire fall_edge_a,
    input  wire fall_edge_b,

    // Pipeline status
    input  wire meas_valid,
    input  wire speed_valid,

    // Control outputs
    output reg  compute_en,    // not used externally – informational
    output reg  display_en,    // enable 7-segment display
    output reg  timeout_err    // LED indicator: object lost / timed out
);

    // =========================================================================
    // State encoding
    // =========================================================================
    localparam [2:0]
        S_IDLE    = 3'b000,
        S_WAIT_B  = 3'b001,
        S_COMPUTE = 3'b010,
        S_DISPLAY = 3'b011,
        S_TIMEOUT = 3'b100;

    reg [2:0] state, next_state;

    // =========================================================================
    // Timers
    // =========================================================================
    reg [31:0] hold_cnt;
    reg [31:0] timeout_cnt;

    wire hold_done    = (hold_cnt    == HOLD_CYCLES   - 1);
    wire timed_out    = (timeout_cnt == TIMEOUT_CYCLES - 1);

    // =========================================================================
    // State register
    // =========================================================================
    always @(posedge clk) begin
        if (!rst_n)
            state <= S_IDLE;
        else
            state <= next_state;
    end

    // =========================================================================
    // Next-state logic (combinational)
    // =========================================================================
    always @(*) begin
        next_state = state;   // default: stay
        case (state)
            S_IDLE: begin
                if (fall_edge_a)
                    next_state = S_WAIT_B;
            end

            S_WAIT_B: begin
                if (fall_edge_b)
                    next_state = S_COMPUTE;
                else if (timed_out)
                    next_state = S_TIMEOUT;
            end

            S_COMPUTE: begin
                // Single-cycle compute pulse, then wait for speed_valid
                next_state = S_DISPLAY;
            end

            S_DISPLAY: begin
                if (hold_done)
                    next_state = S_IDLE;
                // Allow new object to start immediately (pipeline continues
                // in measurement module independently)
            end

            S_TIMEOUT: begin
                // Brief display of error, then reset
                if (hold_done)
                    next_state = S_IDLE;
            end

            default: next_state = S_IDLE;
        endcase
    end

    // =========================================================================
    // Output logic (Moore: depends only on state)
    // =========================================================================
    always @(posedge clk) begin
        if (!rst_n) begin
            compute_en  <= 1'b0;
            display_en  <= 1'b0;
            timeout_err <= 1'b0;
            hold_cnt    <= 32'b0;
            timeout_cnt <= 32'b0;
        end else begin
            // Defaults
            compute_en  <= 1'b0;
            timeout_err <= 1'b0;

            case (state)
                S_IDLE: begin
                    display_en  <= 1'b0;
                    hold_cnt    <= 32'b0;
                    timeout_cnt <= 32'b0;
                end

                S_WAIT_B: begin
                    timeout_cnt <= timed_out ? timeout_cnt : timeout_cnt + 1'b1;
                    display_en  <= 1'b0;
                end

                S_COMPUTE: begin
                    compute_en  <= 1'b1;   // 1-cycle pulse
                    display_en  <= 1'b0;
                    timeout_cnt <= 32'b0;
                end

                S_DISPLAY: begin
                    display_en <= 1'b1;
                    hold_cnt   <= hold_done ? hold_cnt : hold_cnt + 1'b1;
                end

                S_TIMEOUT: begin
                    timeout_err <= 1'b1;
                    display_en  <= 1'b0;
                    hold_cnt    <= hold_done ? hold_cnt : hold_cnt + 1'b1;
                end

                default: begin
                    display_en <= 1'b0;
                end
            endcase
        end
    end

endmodule