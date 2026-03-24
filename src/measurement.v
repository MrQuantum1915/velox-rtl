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
// A small 4-entry circular buffer (4 entries is enough for very close objects
// at any practical belt speed) stores t1 captures so that each object's t1 is
// paired with the correct t2.
//
// Ports
//   clk          – 100 MHz
//   rst_n        – active-low synchronous reset
//   fall_edge_a  – 1-cycle strobe from input_capture (sensor A)
//   fall_edge_b  – 1-cycle strobe from input_capture (sensor B)
//   delta_t      – elapsed clock cycles between sensor A and B
//   meas_valid   – 1-cycle strobe: delta_t is valid and ready for speed_compute
//   overflow     – set when buffer fills (more than 4 objects in flight)
// =============================================================================

`timescale 1ns / 1ps

module measurement #(
    parameter CNT_WIDTH = 32,     // timer counter width
    parameter FIFO_DEPTH = 4,     // number of in-flight objects supported
    parameter ADDR_W     = 2      // log2(FIFO_DEPTH)
)(
    input  wire                  clk,
    input  wire                  rst_n,
    input  wire                  fall_edge_a,   // object crosses sensor A
    input  wire                  fall_edge_b,   // object crosses sensor B
    output reg  [CNT_WIDTH-1:0]  delta_t,       // cycle count between sensors
    output reg                   meas_valid,    // delta_t is valid this cycle
    output reg                   overflow       // buffer full error
);

    // =========================================================================
    // Free-running 100 MHz counter
    // =========================================================================
    reg [CNT_WIDTH-1:0] counter;

    always @(posedge clk) begin
        if (!rst_n)
            counter <= {CNT_WIDTH{1'b0}};
        else
            counter <= counter + 1'b1;
    end

    // =========================================================================
    // Circular FIFO to store t1 timestamps for multiple in-flight objects
    // =========================================================================
    reg [CNT_WIDTH-1:0] t1_buf [0:FIFO_DEPTH-1];  // timestamp buffer
    reg [ADDR_W-1:0]    wr_ptr;                    // write pointer
    reg [ADDR_W-1:0]    rd_ptr;                    // read pointer
    reg [ADDR_W:0]      count;                     // number of stored entries

    wire fifo_full  = (count == FIFO_DEPTH[ADDR_W:0]);
    wire fifo_empty = (count == {(ADDR_W+1){1'b0}});

    // =========================================================================
    // Write: capture t1 when sensor A fires
    // =========================================================================
    integer i;
    always @(posedge clk) begin
        if (!rst_n) begin
            wr_ptr   <= {ADDR_W{1'b0}};
            rd_ptr   <= {ADDR_W{1'b0}};
            count    <= {(ADDR_W+1){1'b0}};
            overflow <= 1'b0;
            for (i = 0; i < FIFO_DEPTH; i = i + 1)
                t1_buf[i] <= {CNT_WIDTH{1'b0}};
        end else begin
            overflow <= 1'b0;   // default: clear each cycle

            // ---- Push t1 on sensor-A edge ----
            if (fall_edge_a) begin
                if (fifo_full) begin
                    overflow <= 1'b1;   // lost object – assert flag
                end else begin
                    t1_buf[wr_ptr] <= counter;
                    wr_ptr         <= wr_ptr + 1'b1;
                    count          <= count + 1'b1;
                end
            end

            // ---- Pop t1 and compute delta on sensor-B edge ----
            // (simultaneous push handled; count updated correctly below)
            if (fall_edge_b && !fifo_empty) begin
                delta_t    <= counter - t1_buf[rd_ptr];
                meas_valid <= 1'b1;
                rd_ptr     <= rd_ptr + 1'b1;
                // Adjust count: if we also pushed this cycle, net = 0
                count      <= (fall_edge_a && !fifo_full) ? count : count - 1'b1;
            end else begin
                meas_valid <= 1'b0;
                // Push-only adjustment when no pop
                if (fall_edge_a && !fifo_full && !fall_edge_b)
                    count <= count + 1'b1;
            end
        end
    end

endmodule