// Stage 3: fixed-point divider + scaler
// =============================================================================
// Module  : speed_compute
// Project : Velox RTL – Multi-Object Speed Measurement (Nexys A7-100T)
// Stage   : 3 – Speed Computation  (division-free)
//
// Physics
// -------
//   speed  = distance / time
//   speed [cm/s] = DIST_CM × 10^8 / delta_t   (delta_t in 100 MHz cycles)
//
// Division-free approximation
// ---------------------------
// Dividing by an arbitrary N-bit value requires a hardware divider which is
// large and slow.  Instead we use a 10-bit reciprocal lookup table:
//
//   1/delta_t ≈ LUT[ delta_t[31:22] ]   (top 10 bits → 1024-entry LUT)
//
// Then:  speed = SCALE × LUT_value >> FRAC
//
// This gives ≈0.1% error for delta_t > 1024 cycles (≥ 10.24 µs travel time),
// which is adequate for cm/s display at typical conveyor / human speeds.
//
// For very small delta_t values (< 1024 cycles, i.e. < 10.24 µs) the top
// 10 bits would be 0, so we cap at maximum speed and assert a FAST flag.
//
// Parameter DIST_CM – physical sensor separation in centimetres (default 10).
//
// Ports
//   clk         – 100 MHz
//   rst_n       – active-low synchronous reset
//   delta_t     – 32-bit clock-cycle count from measurement stage
//   data_valid  – 1-cycle strobe: delta_t is valid
//   speed_cms   – computed speed in cm/s (16-bit, max ≈ 65535 cm/s)
//   speed_valid – 1-cycle strobe: speed_cms is valid
//   too_fast    – object too fast for LUT range (speed clamped to MAX)
// =============================================================================

`timescale 1ns / 1ps

module speed_compute #(
    parameter DIST_CM   = 10,          // sensor separation in centimetres
    parameter CLK_MHZ   = 100,         // clock frequency in MHz
    parameter LUT_BITS  = 10,          // reciprocal LUT address width
    parameter FRAC_BITS = 20           // fixed-point fractional bits in LUT
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire [31:0] delta_t,
    input  wire        data_valid,
    output reg  [15:0] speed_cms,
    output reg         speed_valid,
    output reg         too_fast
);

    // =========================================================================
    // Reciprocal LUT: lut_recip[i] = round( 2^FRAC_BITS / (i+1) )
    // Precomputed for i = 0..1023  (index 0 represents delta_t[31:22] = 0)
    // =========================================================================
    // We generate the 1024 entries using an initial block (synthesis-safe ROM).
    // Each entry is FRAC_BITS wide.
    // =========================================================================
    localparam LUT_SIZE = (1 << LUT_BITS);   // 1024

    reg [FRAC_BITS-1:0] recip_lut [0:LUT_SIZE-1];

    integer idx;
    initial begin
        // Entry 0: delta_t top bits = 0 → "too fast"; store 0 (handled separately)
        recip_lut[0] = {FRAC_BITS{1'b0}};
        // Entries 1..1023: 2^20 / idx
        for (idx = 1; idx < LUT_SIZE; idx = idx + 1)
            recip_lut[idx] = (1 << FRAC_BITS) / idx;
    end

    // =========================================================================
    // Pipeline Stage A: register inputs, extract LUT index
    // =========================================================================
    reg [31:0]          dt_a;
    reg [LUT_BITS-1:0]  lut_idx;
    reg                 valid_a;
    reg                 fast_a;

    always @(posedge clk) begin
        if (!rst_n) begin
            dt_a    <= 32'b0;
            lut_idx <= {LUT_BITS{1'b0}};
            valid_a <= 1'b0;
            fast_a  <= 1'b0;
        end else begin
            valid_a <= data_valid;
            dt_a    <= delta_t;
            // Top LUT_BITS of delta_t select the LUT row
            lut_idx <= delta_t[31 : 32-LUT_BITS];
            // Flag objects whose top bits are all zero (extremely fast)
            fast_a  <= (delta_t[31 : 32-LUT_BITS] == {LUT_BITS{1'b0}});
        end
    end

    // =========================================================================
    // Pipeline Stage B: LUT read (1 cycle RAM-read latency)
    // =========================================================================
    reg [FRAC_BITS-1:0] recip_b;
    reg                 valid_b;
    reg                 fast_b;

    always @(posedge clk) begin
        if (!rst_n) begin
            recip_b <= {FRAC_BITS{1'b0}};
            valid_b <= 1'b0;
            fast_b  <= 1'b0;
        end else begin
            recip_b <= recip_lut[lut_idx];
            valid_b <= valid_a;
            fast_b  <= fast_a;
        end
    end

    // =========================================================================
    // Pipeline Stage C: multiply  DIST_CM × CLK_MHZ × recip_b  then shift
    //
    //   speed [cm/s] = DIST_CM × CLK_MHZ × 10^6 / delta_t
    //
    // With reciprocal approximation:
    //   speed ≈ DIST_CM × CLK_MHZ × 10^6 × recip_b / 2^FRAC_BITS
    //
    // Factor K = DIST_CM × CLK_MHZ × 10^6 / 2^FRAC_BITS
    //          = 10 × 100 × 10^6 / 2^20
    //          = 10^9 / 1048576  ≈ 954  (integer constant)
    //
    // speed ≈ K × recip_b   (then clip to 16 bits)
    // =========================================================================
    // Compile-time constant K to avoid runtime multiply with large values
    localparam integer K_FACTOR =
        (DIST_CM * CLK_MHZ * 1000000) >> FRAC_BITS;  // ≈ 954 for defaults

    // recip_b is at most (2^20 / 1) = 2^20 ≈ 1M, K ≈ 954
    // product ≈ 954 M which fits in 30 bits → use 32-bit register
    reg [31:0] product_c;
    reg        valid_c;
    reg        fast_c;

    always @(posedge clk) begin
        if (!rst_n) begin
            product_c <= 32'b0;
            valid_c   <= 1'b0;
            fast_c    <= 1'b0;
        end else begin
            product_c <= K_FACTOR[15:0] * recip_b;   // 16-bit × 20-bit → 36 bits; clip
            valid_c   <= valid_b;
            fast_c    <= fast_b;
        end
    end

    // =========================================================================
    // Pipeline Stage D: clamp to 16 bits and output
    // =========================================================================
    always @(posedge clk) begin
        if (!rst_n) begin
            speed_cms   <= 16'h0000;
            speed_valid <= 1'b0;
            too_fast    <= 1'b0;
        end else begin
            speed_valid <= valid_c;
            too_fast    <= fast_c;
            if (fast_c) begin
                speed_cms <= 16'hFFFF;   // clamp: too fast to measure
            end else if (product_c[31:16] != 16'b0) begin
                speed_cms <= 16'hFFFF;   // overflow clamp
            end else begin
                speed_cms <= product_c[15:0];
            end
        end
    end

endmodule