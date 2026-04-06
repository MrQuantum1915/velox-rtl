`timescale 1ns / 1ps

module Bin2BCD (
    input [15:0] bin,
    output reg [19:0] bcd // 5 digits
);
    integer i;
    reg [35:0] shift; // 20 BCD bits + 16 binary bits = 36 bits

    always @(*) begin
        shift = {20'd0, bin};

        for (i = 0; i < 16; i = i + 1) begin
            // Check each BCD digit and add 3 if >= 5
            if (shift[19:16] >= 5) shift[19:16] = shift[19:16] + 3;
            if (shift[23:20] >= 5) shift[23:20] = shift[23:20] + 3;
            if (shift[27:24] >= 5) shift[27:24] = shift[27:24] + 3;
            if (shift[31:28] >= 5) shift[31:28] = shift[31:28] + 3;
            if (shift[35:32] >= 5) shift[35:32] = shift[35:32] + 3;
            
            shift = shift << 1;
        end
        bcd = shift[35:16];
    end
endmodule
