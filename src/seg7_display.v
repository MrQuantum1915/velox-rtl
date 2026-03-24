// Stage 4: BCD + 7 segment mux

// =============================================================================
// Module  : seg7_display
// Project : Velox RTL – Multi-Object Speed Measurement (Nexys A7-100T)
// Stage   : 4 – BCD Conversion and 7-Segment Multiplexer
//
// Overview
// --------
// Converts a 16-bit binary speed value (cm/s) to 4 BCD decimal digits using
// the iterative double-dabble (shift-and-add-3) algorithm implemented as a
// purely combinational chain of adder slices – no division needed.
//
// The four BCD digits are then time-multiplexed across the Nexys A7's four
// rightmost 7-segment displays.  A 17-bit refresh counter divides 100 MHz
// down to ≈ 763 Hz scan rate (each digit refreshed at ≈ 190 Hz, well above
// the 60 Hz flicker threshold).
//
// Nexys A7 Segment Encoding (active LOW):
//   seg[6:0] = {CA, CB, CC, CD, CE, CF, CG}  (note: DP driven separately)
//
//    aaa
//   f   b
//   f   b
//    ggg
//   e   c
//   e   c
//    ddd
//
// Ports
//   clk       – 100 MHz
//   rst_n     – active-low synchronous reset
//   speed_cms – 16-bit binary value to display (0..65535)
//   disp_en   – enable display (blanks all segments when 0)
//   seg       – 7-segment cathode drive (active-low, to FPGA pins)
//   an        – anode   enable       (active-low, selects display digit)
// =============================================================================

`timescale 1ns / 1ps

module seg7_display (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [15:0] speed_cms,   // binary speed value
    input  wire        disp_en,     // 0 = blank display
    output reg  [6:0]  seg,         // cathodes {CA..CG} active-low
    output reg  [3:0]  an           // anodes            active-low
);

    // =========================================================================
    // Double-Dabble: binary → 4-digit packed BCD
    // Fully combinational, 16 shift stages.
    // bcd_out[15:12]=thousands, [11:8]=hundreds, [7:4]=tens, [3:0]=units
    // =========================================================================
    function [15:0] bin_to_bcd;
        input [15:0] bin;
        integer      s;
        reg [31:0]   scratch;   // 16 BCD bits + 16 binary bits
        begin
            scratch = {16'b0, bin};
            for (s = 0; s < 16; s = s + 1) begin
                // Add 3 to each BCD nibble that is ≥ 5
                if (scratch[19:16] >= 4'd5) scratch[19:16] = scratch[19:16] + 4'd3;
                if (scratch[23:20] >= 4'd5) scratch[23:20] = scratch[23:20] + 4'd3;
                if (scratch[27:24] >= 4'd5) scratch[27:24] = scratch[27:24] + 4'd3;
                if (scratch[31:28] >= 4'd5) scratch[31:28] = scratch[31:28] + 4'd3;
                scratch = scratch << 1;
            end
            bin_to_bcd = scratch[31:16];
        end
    endfunction

    wire [15:0] bcd_digits;
    assign bcd_digits = bin_to_bcd(speed_cms);

    wire [3:0] dig3 = bcd_digits[15:12]; // thousands
    wire [3:0] dig2 = bcd_digits[11:8];  // hundreds
    wire [3:0] dig1 = bcd_digits[7:4];   // tens
    wire [3:0] dig0 = bcd_digits[3:0];   // units

    // =========================================================================
    // 17-bit refresh counter → top 2 bits select which digit is active
    // 100 MHz / 2^17 ≈ 763 Hz scan, each digit ≈ 190 Hz
    // =========================================================================
    reg [16:0] refresh_cnt;

    always @(posedge clk) begin
        if (!rst_n)
            refresh_cnt <= 17'b0;
        else
            refresh_cnt <= refresh_cnt + 1'b1;
    end

    wire [1:0] digit_sel = refresh_cnt[16:15];

    // =========================================================================
    // 7-Segment decoder  (combinational)
    // Encoding: seg[6:0] = {a, b, c, d, e, f, g}  active-low
    // =========================================================================
    function [6:0] decode_seg;
        input [3:0] bcd;
        begin
            case (bcd)
                4'd0: decode_seg = 7'b000_0001; // 0: a b c d e f on, g off
                4'd1: decode_seg = 7'b100_1111; // 1
                4'd2: decode_seg = 7'b001_0010; // 2
                4'd3: decode_seg = 7'b000_0110; // 3
                4'd4: decode_seg = 7'b100_1100; // 4
                4'd5: decode_seg = 7'b010_0100; // 5
                4'd6: decode_seg = 7'b010_0000; // 6
                4'd7: decode_seg = 7'b000_1111; // 7
                4'd8: decode_seg = 7'b000_0000; // 8
                4'd9: decode_seg = 7'b000_0100; // 9
                default: decode_seg = 7'b111_1111; // blank
            endcase
        end
    endfunction

    // =========================================================================
    // Digit multiplexer – select BCD digit and drive anode + segment
    // =========================================================================
    reg [3:0] active_digit;

    always @(*) begin
        case (digit_sel)
            2'b00: active_digit = dig0;
            2'b01: active_digit = dig1;
            2'b10: active_digit = dig2;
            2'b11: active_digit = dig3;
        endcase
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            seg <= 7'b111_1111;   // all off
            an  <= 4'b1111;       // all disabled
        end else if (!disp_en) begin
            seg <= 7'b111_1111;
            an  <= 4'b1111;
        end else begin
            seg <= decode_seg(active_digit);
            // One-hot anode (active-low: drive selected digit LOW)
            case (digit_sel)
                2'b00: an <= 4'b1110;
                2'b01: an <= 4'b1101;
                2'b10: an <= 4'b1011;
                2'b11: an <= 4'b0111;
            endcase
        end
    end

endmodule