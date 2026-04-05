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
//   seg[6:0] = {CA, CB, CC, CD, CE, CF, CG}
//
// Ports
//   clk       – 100 MHz
//   rst_n     – active-low synchronous reset
//   speed_cms – 16-bit binary value to display (0..65535)
//   disp_en   – enable display (blanks all segments when 0)
//   seg       – 7-segment cathode drive (active-low)
//   an        – anode enable (active-low)
// =============================================================================

`timescale 1ns / 1ps

module seg7_display (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [15:0] speed_cms,
    input  wire        disp_en,
    output reg  [6:0]  seg,
    output reg  [3:0]  an
);

    // =========================================================================
    // Binary → BCD (Double Dabble)
    // =========================================================================
    function [15:0] bin_to_bcd;
        input [15:0] bin;
        integer s;
        reg [31:0] scratch;
        begin
            scratch = {16'b0, bin};
            for (s = 0; s < 16; s = s + 1) begin
                if (scratch[19:16] >= 5) scratch[19:16] = scratch[19:16] + 3;
                if (scratch[23:20] >= 5) scratch[23:20] = scratch[23:20] + 3;
                if (scratch[27:24] >= 5) scratch[27:24] = scratch[27:24] + 3;
                if (scratch[31:28] >= 5) scratch[31:28] = scratch[31:28] + 3;
                scratch = scratch << 1;
            end
            bin_to_bcd = scratch[31:16];
        end
    endfunction

    wire [15:0] bcd = bin_to_bcd(speed_cms);

    wire [3:0] dig3 = bcd[15:12];
    wire [3:0] dig2 = bcd[11:8];
    wire [3:0] dig1 = bcd[7:4];
    wire [3:0] dig0 = bcd[3:0];

    // =========================================================================
    // Refresh counter
    // =========================================================================
    reg [16:0] refresh_cnt;

    always @(posedge clk) begin
        if (!rst_n)
            refresh_cnt <= 0;
        else
            refresh_cnt <= refresh_cnt + 1;
    end

    wire [1:0] sel = refresh_cnt[16:15];

    // =========================================================================
    // 7-segment decoder
    // =========================================================================
    function [6:0] decode;
        input [3:0] d;
        begin
            case (d)
                4'd0: decode = 7'b0000001;
                4'd1: decode = 7'b1001111;
                4'd2: decode = 7'b0010010;
                4'd3: decode = 7'b0000110;
                4'd4: decode = 7'b1001100;
                4'd5: decode = 7'b0100100;
                4'd6: decode = 7'b0100000;
                4'd7: decode = 7'b0001111;
                4'd8: decode = 7'b0000000;
                4'd9: decode = 7'b0000100;
                default: decode = 7'b1111111;
            endcase
        end
    endfunction

    reg [3:0] active;

    always @(*) begin
        case (sel)
            2'b00: active = dig0;
            2'b01: active = dig1;
            2'b10: active = dig2;
            2'b11: active = dig3;
        endcase
    end

    // =========================================================================
    // Output logic
    // =========================================================================
    always @(posedge clk) begin
        if (!rst_n || !disp_en) begin
            seg <= 7'b1111111;
            an  <= 4'b1111;
        end else begin
            seg <= decode(active);

            case (sel)
                2'b00: an <= 4'b1110;
                2'b01: an <= 4'b1101;
                2'b10: an <= 4'b1011;
                2'b11: an <= 4'b0111;
            endcase
        end
    end

endmodule