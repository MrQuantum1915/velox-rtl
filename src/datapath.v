// =============================================================================
// Module  : datapath
// Project : Velox RTL – Multi-Object Speed Measurement (Nexys A7-100T)
// Purpose : Connects measurement → FIFO → speed_compute pipeline stages
//
// Data flow
// ---------
//  measurement → [meas_valid + delta_t] → fifo_buffer (16-entry)
//                                               │
//                                          [rd_en on speed_valid_ack]
//                                               │
//                                         speed_compute → speed_cms
//
// The FIFO decouples measurement from speed computation so that burst arrivals
// do not stall the pipeline.  The FIFO consumer (speed_compute) pops one entry
// per measurement computation cycle.
// =============================================================================

`timescale 1ns / 1ps

module datapath #(
    parameter DIST_CM = 10   // sensor separation (cm), passed to speed_compute
)(
    input  wire        clk,
    input  wire        rst_n,

    // From measurement stage
    input  wire [31:0] delta_t,
    input  wire        meas_valid,

    // Final outputs
    output wire [15:0] speed_cms,
    output wire        speed_valid,
    output wire        too_fast,
    output wire        fifo_full,
    output wire        fifo_empty
);

    // =========================================================================
    // FIFO between measurement and speed_compute
    // =========================================================================
    localparam FIFO_D = 16;   // 16 entries deep
    localparam FIFO_A = 4;    // log2(16)

    wire        fifo_rd_en;
    wire [31:0] fifo_rd_data;
    wire [4:0]  fifo_count;   // FIFO_A+1

    fifo_buffer #(
        .DATA_W (32),
        .DEPTH  (FIFO_D),
        .ADDR_W (FIFO_A)
    ) u_delta_fifo (
        .clk     (clk),
        .rst_n   (rst_n),
        .wr_en   (meas_valid),
        .wr_data (delta_t),
        .rd_en   (fifo_rd_en),
        .rd_data (fifo_rd_data),
        .full    (fifo_full),
        .empty   (fifo_empty),
        .count   (fifo_count)
    );

    // =========================================================================
    // Speed compute stage
    // =========================================================================
    // Pop from FIFO whenever it is non-empty and speed_compute is ready.
    // speed_compute accepts a new value every cycle (4-stage pipeline, no
    // back-pressure).  We use a simple register to track whether we have
    // issued a read that hasn't been consumed yet.
    // =========================================================================
    reg pop_pending;   // 1 = data was popped but not yet presented to compute

    assign fifo_rd_en = !fifo_empty && !pop_pending;

    // One-cycle delay: data appears on fifo_rd_data the cycle after rd_en
    reg        compute_valid;
    reg [31:0] compute_dt;

    always @(posedge clk) begin
        if (!rst_n) begin
            pop_pending   <= 1'b0;
            compute_valid <= 1'b0;
            compute_dt    <= 32'b0;
        end else begin
            if (fifo_rd_en) begin
                pop_pending   <= 1'b1;
            end else begin
                pop_pending   <= 1'b0;
            end
            compute_valid <= pop_pending;
            compute_dt    <= pop_pending ? fifo_rd_data : compute_dt;
        end
    end

    speed_compute #(
        .DIST_CM   (DIST_CM),
        .CLK_MHZ   (100),
        .LUT_BITS  (10),
        .FRAC_BITS (20)
    ) u_speed (
        .clk        (clk),
        .rst_n      (rst_n),
        .delta_t    (compute_dt),
        .data_valid (compute_valid),
        .speed_cms  (speed_cms),
        .speed_valid(speed_valid),
        .too_fast   (too_fast)
    );

endmodule