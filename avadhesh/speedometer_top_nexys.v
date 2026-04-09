// ============================================================
// FPGA Digital Speedometer for Nexys A7
// 2 IR Sensors - Quadrature Based
// Modified for 100 MHz clock and multiplexed 7-segment display
// ============================================================

module speedometer_top (
    input wire clk,              // 100 MHz clock (Nexys A7)
    input wire reset_btn,        // Reset button (active high)

    input wire ir1,              // IR Sensor 1 (PMOD JA)
    input wire ir2,              // IR Sensor 2 (PMOD JA)

    output wire [6:0] seg,       // 7-segment cathode pins (a-g)
    output wire [7:0] an,        // 7-segment anode selectors
    output wire red_led          // Red LED output
);

    // Internal signals
    wire timer_done;
    wire timer_reset;
    wire [8:0] pulse_count;
    wire [7:0] speed_kmh;

    wire [3:0] hundreds_digit;
    wire [3:0] tens_digit;
    wire [3:0] ones_digit;

    wire ir1_clean, ir2_clean;
    wire reset_n;

    // Invert active-high button to active-low reset
    assign reset_n = ~reset_btn;

    // ============ IR FILTERS (Debouncing) ============
    ir_filter f1 (.clk(clk), .signal_in(ir1), .signal_out(ir1_clean));
    ir_filter f2 (.clk(clk), .signal_in(ir2), .signal_out(ir2_clean));

    // ============ CLOCK DIVIDER (0.5 sec window) ============
    // Updated for 100 MHz clock
    clock_divider #(
        .MAX_COUNT (50_000_000 - 1)  // 100 MHz / 2 = 50 MHz, 0.5 sec window
    ) clk_div_inst (
        .clk(clk),
        .reset_n(reset_n),
        .timer_done(timer_done),
        .timer_reset(timer_reset)
    );

    // ============ PULSE COUNTER ============
    pulse_counter pulse_cnt_inst (
        .clk(clk),
        .reset_n(reset_n),
        .ir1(ir1_clean),
        .ir2(ir2_clean),
        .timer_done(timer_done),
        .timer_reset(timer_reset),
        .pulse_count_out(pulse_count)
    );

    // ============ SPEED CALCULATION ============
    speed_calculator speed_calc_inst (
        .pulse_count_in(pulse_count),
        .speed_kmh_out(speed_kmh)
    );

    // ============ BCD CONVERSION ============
    bcd_to_digits bcd_conv_inst (
        .speed_in(speed_kmh),
        .hundreds_out(hundreds_digit),
        .tens_out(tens_digit),
        .ones_out(ones_digit)
    );

    // ============ MULTIPLEXED 7-SEGMENT DISPLAY ============
    seven_segment_mux display_mux (
        .clk(clk),
        .reset_n(reset_n),
        .hundreds(hundreds_digit),
        .tens(tens_digit),
        .ones(ones_digit),
        .seg(seg),
        .an(an)
    );

    // ============ LED CONTROLLER ============
    red_led_controller led_ctrl_inst (
        .speed_in(speed_kmh),
        .red_led_out(red_led)
    );

endmodule


// ============================================================
// IR FILTER (Debouncing)
// ============================================================
module ir_filter (
    input clk,
    input signal_in,
    output reg signal_out
);

    reg [2:0] shift;

    always @(posedge clk) begin
        shift <= {shift[1:0], signal_in};

        if (shift == 3'b111)
            signal_out <= 1;
        else if (shift == 3'b000)
            signal_out <= 0;
    end

endmodule


// ============================================================
// CLOCK DIVIDER (0.5 sec window)
// Updated for 100 MHz clock
// ============================================================
module clock_divider #(
    parameter MAX_COUNT = 50_000_000 - 1  // 100 MHz clock
)(
    input wire clk,
    input wire reset_n,
    output reg timer_done,
    output reg timer_reset
);

    reg [26:0] count;

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            count <= 0;
            timer_done <= 0;
            timer_reset <= 0;
        end else begin
            if (count == MAX_COUNT) begin
                count <= 0;
                timer_done <= 1;
                timer_reset <= 1;
            end else begin
                count <= count + 1;
                timer_done <= 0;
                if (timer_done)
                    timer_reset <= 0;
            end
        end
    end

endmodule


// ============================================================
// QUADRATURE PULSE COUNTER (2 IR Sensors)
// ============================================================
module pulse_counter (
    input wire clk,
    input wire reset_n,

    input wire ir1,
    input wire ir2,

    input wire timer_done,
    input wire timer_reset,

    output reg [8:0] pulse_count_out
);

    reg [1:0] prev_state;
    reg [1:0] curr_state;

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            pulse_count_out <= 0;
            prev_state <= 0;
        end else begin

            curr_state <= {ir1, ir2};

            if (timer_reset) begin
                pulse_count_out <= 0;
            end
            else if (!timer_done) begin
                case ({prev_state, curr_state})

                    // Valid forward transitions
                    4'b0001,
                    4'b0111,
                    4'b1110,
                    4'b1000:
                        pulse_count_out <= pulse_count_out + 1;

                    default: ;
                endcase
            end

            prev_state <= curr_state;
        end
    end

endmodule


// ============================================================
// SPEED CALCULATOR
// Formula: speed = (pulse_count * 23) / 40
// ============================================================
module speed_calculator (
    input wire [8:0] pulse_count_in,
    output reg [7:0] speed_kmh_out
);

    always @(*) begin
        speed_kmh_out = (pulse_count_in * 23) / 40;
    end

endmodule


// ============================================================
// BCD CONVERTER (Binary to Decimal Digits)
// ============================================================
module bcd_to_digits (
    input wire [7:0] speed_in,
    output reg [3:0] hundreds_out,
    output reg [3:0] tens_out,
    output reg [3:0] ones_out
);

    always @(*) begin
        hundreds_out = speed_in / 100;
        tens_out = (speed_in % 100) / 10;
        ones_out = speed_in % 10;
    end

endmodule


// ============================================================
// 7-SEGMENT DISPLAY MULTIPLEXER
// Handles display refresh and digit selection
// ============================================================
module seven_segment_mux (
    input wire clk,
    input wire reset_n,
    input wire [3:0] hundreds,
    input wire [3:0] tens,
    input wire [3:0] ones,
    output reg [6:0] seg,
    output reg [7:0] an
);

    reg [3:0] clk_divider;
    reg [1:0] digit_select;
    wire [3:0] digit_to_display;

    // Clock divider for display refresh (~1 kHz from 100 MHz)
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n)
            clk_divider <= 0;
        else
            clk_divider <= clk_divider + 1;
    end

    // Select digit every refresh cycle
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n)
            digit_select <= 0;
        else if (clk_divider == 4'b1111)  // Every 16 clocks
            digit_select <= digit_select + 1;
    end

    // Multiplex digit selection
    assign digit_to_display = (digit_select == 2'd0) ? ones :
                              (digit_select == 2'd1) ? tens :
                              (digit_select == 2'd2) ? hundreds : 4'b0000;

    // Anode selection (common-cathode display)
    // Only 3 displays used (ones, tens, hundreds)
    always @(*) begin
        case (digit_select)
            2'd0: an = 8'b11111110;  // Display 0 (ones) - AN[0] active
            2'd1: an = 8'b11111101;  // Display 1 (tens) - AN[1] active
            2'd2: an = 8'b11111011;  // Display 2 (hundreds) - AN[2] active
            default: an = 8'b11111111;  // All off
        endcase
    end

    // 7-segment decoder (common-cathode, segments active HIGH)
    always @(*) begin
        case (digit_to_display)
            4'd0: seg = 7'b1000000;  // 0
            4'd1: seg = 7'b1111001;  // 1
            4'd2: seg = 7'b0100100;  // 2
            4'd3: seg = 7'b0110000;  // 3
            4'd4: seg = 7'b0011001;  // 4
            4'd5: seg = 7'b0010010;  // 5
            4'd6: seg = 7'b0000010;  // 6
            4'd7: seg = 7'b1111000;  // 7
            4'd8: seg = 7'b0000000;  // 8
            4'd9: seg = 7'b0010000;  // 9
            default: seg = 7'b1111111;  // All off
        endcase
    end

endmodule


// ============================================================
// LED CONTROLLER
// Lights red LED when speed exceeds threshold
// ============================================================
module red_led_controller (
    input wire [7:0] speed_in,
    output reg red_led_out
);

    parameter SPEED_LIMIT = 110;  // km/h

    always @(*) begin
        if (speed_in > SPEED_LIMIT)
            red_led_out = 1;
        else
            red_led_out = 0;
    end

endmodule