// Stage 2: timer / pulse counter

// =============================================================================
// Module  : measurement
// Project : Velox RTL – Multi-Object Speed Measurement (Nexys A7-100T)
// Stage   : 2 – Time Measurement
//
// Overview
// --------
// A 32-bit free-running counter driven at 100 MHz gives 42.9-second wrap and
// 10 ns resolution.  When sensor A detects an object (fall_edge_a), the
// current counter value is captured as t1.  When sensor B detects the same
// object (fall_edge_b), t2 is captured.  The elapsed time delta_t = t2 – t1
// is passed downstream together with a valid strobe.
//
// Multi-object pipelining
// -----------------------
// A new object may enter sensor A before the previous object has left sensor B.
// A small 4-entry circular buffer stores t1 captures so that each object's t1
// is paired with the correct t2.
//
// Ports
//   clk          – 100 MHz
//   rst_n        – active-low synchronous reset
//   fall_edge_a  – 1-cycle strobe from input_capture (sensor A)
//   fall_edge_b  – 1-cycle strobe from input_capture (sensor B)
//   delta_t      – elapsed clock cycles between sensor A and B
//   meas_valid   – 1-cycle strobe: delta_t is valid
//   overflow     – set when buffer fills
// =============================================================================

`timescale 1ns / 1ps

module measurement #(
    parameter CNT_WIDTH  = 32,
    parameter FIFO_DEPTH = 4,
    parameter ADDR_W     = 2
)(
    input  wire                  clk,
    input  wire                  rst_n,
    input  wire                  fall_edge_a,
    input  wire                  fall_edge_b,
    output reg  [CNT_WIDTH-1:0]  delta_t,
    output reg                   meas_valid,
    output reg                   overflow
);

    // =========================================================================
    // Free-running counter
    // =========================================================================
    reg [CNT_WIDTH-1:0] counter;

    always @(posedge clk) begin
        if (!rst_n)
            counter <= 0;
        else
            counter <= counter + 1;
    end

    // =========================================================================
    // FIFO for timestamps
    // =========================================================================
    reg [CNT_WIDTH-1:0] t1_buf [0:FIFO_DEPTH-1];
    reg [ADDR_W-1:0] wr_ptr, rd_ptr;
    reg [ADDR_W:0]   count;

    wire fifo_full  = (count == FIFO_DEPTH);
    wire fifo_empty = (count == 0);

    integer i;

    always @(posedge clk) begin
        if (!rst_n) begin
            wr_ptr   <= 0;
            rd_ptr   <= 0;
            count    <= 0;
            overflow <= 0;
            meas_valid <= 0;

            for (i = 0; i < FIFO_DEPTH; i = i + 1)
                t1_buf[i] <= 0;

        end else begin
            overflow   <= 0;
            meas_valid <= 0;

            // ---- Push (sensor A) ----
            if (fall_edge_a) begin
                if (fifo_full) begin
                    overflow <= 1;
                end else begin
                    t1_buf[wr_ptr] <= counter;
                    wr_ptr <= wr_ptr + 1;
                    count  <= count + 1;
                end
            end

            // ---- Pop + compute (sensor B) ----
            if (fall_edge_b && !fifo_empty) begin
                delta_t    <= counter - t1_buf[rd_ptr];
                meas_valid <= 1;
                rd_ptr     <= rd_ptr + 1;

                if (!(fall_edge_a && !fifo_full))
                    count <= count - 1;
            end
        end
    end

endmodule