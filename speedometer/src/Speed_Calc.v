`timescale 1ns / 1ps

module Speed_Calc #(
    parameter DISTANCE_CM = 50,      // Distance between sensors in cm
    parameter CLOCK_FREQ = 100000000 // 100 MHz clock
)(
    input clk,
    input reset,
    input start,
    input [31:0] cycles,
    output reg [15:0] speed_cm_s,
    output reg done
);

    // Speed in cm/s = DISTANCE_CM / (cycles / CLOCK_FREQ)
    // Speed in cm/s = (DISTANCE_CM * CLOCK_FREQ) / cycles
    // The numerator is large, requiring 64 bits.
    // E.g., for 50 cm at 100 MHz: 50 * 100,000,000 = 5,000,000,000
    localparam [63:0] NUMERATOR = DISTANCE_CM * CLOCK_FREQ;

    reg [1:0] state;
    localparam IDLE = 2'd0, DIVIDE = 2'd1, FINISHED = 2'd2;

    reg [63:0] dividend;
    reg [63:0] divisor;
    reg [63:0] quotient;
    reg [6:0] count;

    always @(posedge clk) begin
        if (reset) begin
            state <= IDLE;
            done <= 0;
            speed_cm_s <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        if (cycles == 0) begin
                            speed_cm_s <= 16'hFFFF; // Error or max
                            done <= 1;
                        end else begin
                            dividend <= NUMERATOR;
                            // Pre-shift the divisor up by the max number of iterations.
                            // Since cycles is 32 bits, the max count we might need is 64 but divisor 
                            // is only up to 32 bits, so shift up by 32 so it aligns with upper half of dividend
                            divisor <= {32'd0, cycles} << 32; 
                            quotient <= 0;
                            count <= 33;
                            state <= DIVIDE;
                        end
                    end
                end

                DIVIDE: begin
                    if (count == 0) begin
                        // Check for overflow of 16-bit
                        if (quotient > 65535) 
                            speed_cm_s <= 16'hFFFF;
                        else
                            speed_cm_s <= quotient[15:0];
                        
                        done <= 1;
                        state <= FINISHED;
                    end else begin
                        if (dividend >= divisor) begin
                            dividend <= dividend - divisor;
                            quotient <= (quotient << 1) | 1;
                        end else begin
                            quotient <= quotient << 1;
                        end
                        divisor <= divisor >> 1;
                        count <= count - 1;
                    end
                end

                FINISHED: begin
                    done <= 0;
                    state <= IDLE; // Auto return to idle
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule
