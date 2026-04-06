`timescale 1ns / 1ps

module Seven_Segment_Driver (
    input clk,
    input reset,
    input [19:0] bcd,
    input is_error, // If true, display 'E r r'
    output reg [7:0] an, // Anodes (active low)
    output reg [6:0] seg // Cathodes (active low, 0=on)
);
    // Refresh counter ~1kHz
    reg [16:0] refresh_counter;
    always @(posedge clk) begin
        if (reset) refresh_counter <= 0;
        else refresh_counter <= refresh_counter + 1;
    end
    
    wire [2:0] digit_sel = refresh_counter[16:14];

    reg [3:0] current_digit;

    always @(*) begin
        if (is_error) begin 
            // Display 'Err' on lower digits
            case(digit_sel)
                3'd0: an = 8'b11111110;
                3'd1: an = 8'b11111101;
                3'd2: an = 8'b11111011;
                default: an = 8'b11111111;
            endcase
            
            case(digit_sel)
                3'd0: seg = 7'b0101111; // 'r'
                3'd1: seg = 7'b0101111; // 'r'
                3'd2: seg = 7'b0000110; // 'E'
                default: seg = 7'b1111111;
            endcase
        end else begin
            // Normal display
            case (digit_sel)
                3'd0: begin an = 8'b11111110; current_digit = bcd[3:0]; end
                3'd1: begin an = 8'b11111101; current_digit = bcd[7:4]; end
                3'd2: begin an = 8'b11111011; current_digit = bcd[11:8]; end
                3'd3: begin an = 8'b11110111; current_digit = bcd[15:12]; end
                3'd4: begin an = 8'b11101111; current_digit = bcd[19:16]; end
                default: begin an = 8'b11111111; current_digit = 0; end
            endcase
            
            // Default digit decoder
            case (current_digit)
                4'h0: seg = 7'b1000000;
                4'h1: seg = 7'b1111001;
                4'h2: seg = 7'b0100100;
                4'h3: seg = 7'b0110000;
                4'h4: seg = 7'b0011001;
                4'h5: seg = 7'b0010010;
                4'h6: seg = 7'b0000010;
                4'h7: seg = 7'b1111000;
                4'h8: seg = 7'b0000000;
                4'h9: seg = 7'b0010000;
                default: seg = 7'b1111111;
            endcase
            
            // Leading zero blanking
            if (digit_sel == 4 && bcd[19:16] == 0) seg = 7'b1111111;
            if (digit_sel == 3 && bcd[19:12] == 0) seg = 7'b1111111;
            if (digit_sel == 2 && bcd[19:8] == 0)  seg = 7'b1111111;
            if (digit_sel == 1 && bcd[19:4] == 0)  seg = 7'b1111111;
        end
    end
endmodule
