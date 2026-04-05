// =============================================================================
// Module  : fifo_buffer
// Project : Velox RTL – Multi-Object Speed Measurement (Nexys A7-100T)
// Purpose : Generic synchronous FIFO for inter-stage data buffering
//
// Features
// --------
// * Parameterised data width and depth (must be power of 2)
// * Full / empty / count status outputs
// * Simultaneous read+write supported (count updates correctly)
// * Synthesises to block RAM when DATA_W × DEPTH ≥ a few kilobits;
//   otherwise uses distributed LUT RAM
//
// Ports
//   clk        – clock
//   rst_n      – active-low synchronous reset
//   wr_en      – write enable
//   wr_data    – data to push
//   rd_en      – read enable (dequeues head entry)
//   rd_data    – data at head of queue (valid while rd_en is high)
//   full       – FIFO is full  (do not write)
//   empty      – FIFO is empty (do not read)
//   count      – number of valid entries currently stored
// =============================================================================

`timescale 1ns / 1ps

module fifo_buffer #(
    parameter DATA_W = 16,    // payload bit-width
    parameter DEPTH  = 8,     // number of entries  (must be power of 2)
    parameter ADDR_W = 3      // log2(DEPTH)
)(
    input  wire              clk,
    input  wire              rst_n,

    // Write port
    input  wire              wr_en,
    input  wire [DATA_W-1:0] wr_data,

    // Read port
    input  wire              rd_en,
    output reg  [DATA_W-1:0] rd_data,

    // Status
    output wire              full,
    output wire              empty,
    output reg  [ADDR_W:0]   count        // 0 .. DEPTH
);

    // =========================================================================
    // Storage array
    // =========================================================================
    reg [DATA_W-1:0] mem [0:DEPTH-1];

    // =========================================================================
    // Read / write pointers
    // =========================================================================
    reg [ADDR_W-1:0] wr_ptr;
    reg [ADDR_W-1:0] rd_ptr;

    // =========================================================================
    // Status flags
    // =========================================================================
    assign full  = (count == DEPTH[ADDR_W:0]);
    assign empty = (count == {(ADDR_W+1){1'b0}});

    // =========================================================================
    // Write logic
    // =========================================================================
    integer i;
    always @(posedge clk) begin
        if (!rst_n) begin
            wr_ptr <= {ADDR_W{1'b0}};
            for (i = 0; i < DEPTH; i = i + 1)
                mem[i] <= {DATA_W{1'b0}};
        end else if (wr_en && !full) begin
            mem[wr_ptr] <= wr_data;
            wr_ptr      <= wr_ptr + 1'b1;
        end
    end

    // =========================================================================
    // Read logic (registered output for timing)
    // =========================================================================
    always @(posedge clk) begin
        if (!rst_n) begin
            rd_ptr  <= {ADDR_W{1'b0}};
            rd_data <= {DATA_W{1'b0}};
        end else if (rd_en && !empty) begin
            rd_data <= mem[rd_ptr];
            rd_ptr  <= rd_ptr + 1'b1;
        end
    end

    // =========================================================================
    // Count update (handles simultaneous read + write)
    // =========================================================================
    always @(posedge clk) begin
        if (!rst_n) begin
            count <= {(ADDR_W+1){1'b0}};
        end else begin
            case ({wr_en & ~full, rd_en & ~empty})
                2'b10: count <= count + 1'b1;  // push only
                2'b01: count <= count - 1'b1;  // pop  only
                // 2'b11: push + pop → count unchanged
                // 2'b00: no operation
                default: count <= count;
            endcase
        end
    end

endmodule