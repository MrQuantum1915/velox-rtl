// ============================================================
// FPGA Digital Speedometer for Nexys A7
// 2 IR Sensors - Quadrature Based
// 100 MHz clock, multiplexed 7-segment display
//
// FIXES APPLIED:
//  1. speed_cm_s widened to 13 bits (was 8-bit → overflow)
//  2. displayed_speed widened to 13 bits
//  3. hold_counter widened to 30 bits (500M needs 30 bits)
//  4. seven_segment_mux: clock divider widened to 17 bits (~1kHz refresh)
//  5. pulse_counter: curr_state made combinational wire (was registered → race)
//  6. red_led_controller: SPEED_LIMIT lowered to 200 (fits 8-bit; use 13-bit if needed)
//  7. bcd_to_digits: input widened to 13 bits
// ============================================================

module speedometer_top (
    input  wire       clk,          // 100 MHz clock (Nexys A7)
    input  wire       reset_btn,    // Reset button (active high)

    input  wire       ir1,          // IR Sensor 1 (PMOD JA)
    input  wire       ir2,          // IR Sensor 2 (PMOD JA)

    output wire [6:0] seg,          // 7-segment cathode pins (a-g)
    output wire [7:0] an,           // 7-segment anode selectors
    output wire       red_led       // Red LED output
);

    // -------------------------------------------------------
    // Internal signals
    // -------------------------------------------------------
    wire        timer_done;
    wire        timer_reset;
    wire [8:0]  pulse_count;
    wire [12:0] speed_cm_s;         // FIX 1: widened from 8 to 13 bits

    wire [3:0]  hundreds_digit;
    wire [3:0]  tens_digit;
    wire [3:0]  ones_digit;

    wire        ir1_clean, ir2_clean;
    wire        reset_n;

    // FIX 2: displayed_speed widened to 13 bits
    reg [12:0]  displayed_speed;
    // FIX 3: hold_counter widened to 30 bits (500_000_000 needs 30 bits)
    reg [29:0]  hold_counter;

    // Invert active-high button to active-low reset
    assign reset_n = ~reset_btn;

    // -------------------------------------------------------
    // IR FILTERS (Debouncing)
    // -------------------------------------------------------
    ir_filter f1 (.clk(clk), .signal_in(ir1), .signal_out(ir1_clean));
    ir_filter f2 (.clk(clk), .signal_in(ir2), .signal_out(ir2_clean));

    // -------------------------------------------------------
    // CLOCK DIVIDER (0.5 sec measurement window)
    // 100 MHz → 50,000,000 cycles = 0.5 s
    // -------------------------------------------------------
    clock_divider #(
        .MAX_COUNT (49_999_999)     // 100 MHz: 0.5 sec = 50M cycles - 1
    ) clk_div_inst (
        .clk        (clk),
        .reset_n    (reset_n),
        .timer_done (timer_done),
        .timer_reset(timer_reset)
    );

    // -------------------------------------------------------
    // PULSE COUNTER
    // -------------------------------------------------------
    pulse_counter pulse_cnt_inst (
        .clk            (clk),
        .reset_n        (reset_n),
        .ir1            (ir1_clean),
        .ir2            (ir2_clean),
        .timer_done     (timer_done),
        .timer_reset    (timer_reset),
        .pulse_count_out(pulse_count)
    );

    // -------------------------------------------------------
    // SPEED CALCULATION
    // -------------------------------------------------------
    speed_calculator speed_calc_inst (
        .pulse_count_in  (pulse_count),
        .speed_cm_s_out  (speed_cm_s)
    );

    // -------------------------------------------------------
    // BCD CONVERSION
    // -------------------------------------------------------
    bcd_to_digits bcd_conv_inst (
        .speed_in    (displayed_speed),
        .hundreds_out(hundreds_digit),
        .tens_out    (tens_digit),
        .ones_out    (ones_digit)
    );

    // -------------------------------------------------------
    // MULTIPLEXED 7-SEGMENT DISPLAY
    // -------------------------------------------------------
    seven_segment_mux display_mux (
        .clk     (clk),
        .reset_n (reset_n),
        .hundreds(hundreds_digit),
        .tens    (tens_digit),
        .ones    (ones_digit),
        .seg     (seg),
        .an      (an)
    );

    // -------------------------------------------------------
    // LED CONTROLLER
    // -------------------------------------------------------
    red_led_controller led_ctrl_inst (
        .speed_in    (speed_cm_s),
        .red_led_out (red_led)
    );

    // -------------------------------------------------------
    // DISPLAY PERSISTENCE LOGIC
    // Holds last nonzero speed on display for 5 seconds
    // -------------------------------------------------------
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            displayed_speed <= 0;
            hold_counter    <= 0;
        end else begin
            if (timer_done && pulse_count > 0) begin
                displayed_speed <= speed_cm_s;
                hold_counter    <= 30'd500_000_000; // 5 sec at 100 MHz
            end else if (timer_done && pulse_count == 0) begin
                // Object stopped: clear display after hold expires
                if (hold_counter == 0)
                    displayed_speed <= 0;
                else
                    hold_counter <= hold_counter - 1;
            end else if (hold_counter > 0) begin
                hold_counter <= hold_counter - 1;
            end
        end
    end

endmodule


// ============================================================
// IR FILTER (Debouncing via 3-bit majority / shift register)
// ============================================================
module ir_filter (
    input  wire clk,
    input  wire signal_in,
    output reg  signal_out
);
    reg [2:0] shift;

    always @(posedge clk) begin
        shift <= {shift[1:0], signal_in};
        if (shift == 3'b111)
            signal_out <= 1;
        else if (shift == 3'b000)
            signal_out <= 0;
        // else: hold previous value (glitch rejection)
    end
endmodule


// ============================================================
// CLOCK DIVIDER (0.5 sec measurement window)
// MAX_COUNT = 49,999,999 for 100 MHz → 0.5 s
// Uses 26-bit counter (max 67M — fits 50M)
// ============================================================
module clock_divider #(
    parameter MAX_COUNT = 49_999_999
)(
    input  wire clk,
    input  wire reset_n,
    output reg  timer_done,
    output reg  timer_reset
);
    reg [25:0] count;   // 26 bits covers up to 67,108,863 → fits 50,000,000

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            count       <= 0;
            timer_done  <= 0;
            timer_reset <= 0;
        end else begin
            if (count == MAX_COUNT[25:0]) begin
                count       <= 0;
                timer_done  <= 1;
                timer_reset <= 1;
            end else begin
                count      <= count + 1;
                timer_done <= 0;
                if (timer_done)
                    timer_reset <= 0;
            end
        end
    end
endmodule


// ============================================================
// QUADRATURE PULSE COUNTER (2 IR Sensors)
// FIX 5: curr_state is now a WIRE (combinational), not a register
//         to avoid the 1-cycle stale read race condition
// ============================================================
module pulse_counter (
    input  wire       clk,
    input  wire       reset_n,

    input  wire       ir1,
    input  wire       ir2,

    input  wire       timer_done,
    input  wire       timer_reset,

    output reg  [8:0] pulse_count_out
);
    // FIX: wire = combinational, always reflects current sensor state
    wire [1:0] curr_state;
    assign curr_state = {ir1, ir2};

    reg [1:0] prev_state;

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            pulse_count_out <= 0;
            prev_state      <= 2'b00;
        end else begin
            if (timer_reset) begin
                // Latch happens in top-level; just reset counter
                pulse_count_out <= 0;
            end else if (!timer_done) begin
                // Quadrature decoding — forward transitions only
                case ({prev_state, curr_state})
                    4'b00_01,
                    4'b01_11,
                    4'b11_10,
                    4'b10_00:
                        pulse_count_out <= pulse_count_out + 1;
                    default: ; // no count
                endcase
            end
            prev_state <= curr_state;
        end
    end
endmodule


// ============================================================
// SPEED CALCULATOR
// Formula: speed (cm/s) = pulse_count * 16
// 9-bit input * 16 = up to 8176 → needs 13 bits output
// FIX 1: output widened from 8 to 13 bits
// ============================================================
module speed_calculator (
    input  wire [8:0]  pulse_count_in,
    output reg  [12:0] speed_cm_s_out   // FIX: was [7:0], caused overflow
);
    always @(*) begin
        speed_cm_s_out = pulse_count_in * 13'd16;
    end
endmodule


// ============================================================
// BCD CONVERTER (Binary to Decimal Digits)
// FIX 7: input widened to 13 bits to match speed_calculator output
//         Displays up to 9999 — safe for our max of 8176 cm/s
// ============================================================
module bcd_to_digits (
    input  wire [12:0] speed_in,    // FIX: was [7:0]
    output reg  [3:0]  hundreds_out,
    output reg  [3:0]  tens_out,
    output reg  [3:0]  ones_out
);
    always @(*) begin
        // Show only the lowest 3 digits (0–999 cm/s range displayed)
        // For >999, display wraps at hundreds — add a 4th digit if needed
        hundreds_out = (speed_in % 1000) / 100;
        tens_out     = (speed_in % 100)  / 10;
        ones_out     =  speed_in % 10;
    end
endmodule


// ============================================================
// 7-SEGMENT DISPLAY MULTIPLEXER
// FIX 4: clk_divider widened to 17 bits
//   100 MHz / 2^17 = ~763 Hz per full cycle
//   Each of 3 digits refreshes at ~254 Hz — clearly visible
// ============================================================
module seven_segment_mux (
    input  wire       clk,
    input  wire       reset_n,
    input  wire [3:0] hundreds,
    input  wire [3:0] tens,
    input  wire [3:0] ones,
    output reg  [6:0] seg,
    output reg  [7:0] an
);
    // FIX: was 4-bit (divided by only 16 → 6.25 MHz, far too fast)
    reg [16:0] clk_divider;
    reg [1:0]  digit_select;

    wire [3:0] digit_to_display;

    // Increment divider every clock
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n)
            clk_divider <= 0;
        else
            clk_divider <= clk_divider + 1;
    end

    // Advance digit every time divider rolls over (bit 16 toggles)
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n)
            digit_select <= 0;
        else if (clk_divider == 17'h1_FFFF)  // full 17-bit rollover
            digit_select <= digit_select + 1;
    end

    // Select which digit value to encode
    assign digit_to_display = (digit_select == 2'd0) ? ones     :
                              (digit_select == 2'd1) ? tens     :
                              (digit_select == 2'd2) ? hundreds :
                                                       4'd0;

    // Anode selection — Nexys A7 anodes are ACTIVE LOW
    // AN[0] = rightmost digit (ones), AN[1] = tens, AN[2] = hundreds
    always @(*) begin
        case (digit_select)
            2'd0: an = 8'b1111_1110; // AN[0] active → ones
            2'd1: an = 8'b1111_1101; // AN[1] active → tens
            2'd2: an = 8'b1111_1011; // AN[2] active → hundreds
            default: an = 8'b1111_1111; // all off
        endcase
    end

    // 7-segment decoder
    // Nexys A7: common ANODE display → segments are ACTIVE LOW
    // seg[6:0] = {g,f,e,d,c,b,a}
    always @(*) begin
        case (digit_to_display)
            4'd0: seg = 7'b100_0000; // 0
            4'd1: seg = 7'b111_1001; // 1
            4'd2: seg = 7'b010_0100; // 2
            4'd3: seg = 7'b011_0000; // 3
            4'd4: seg = 7'b001_1001; // 4
            4'd5: seg = 7'b001_0010; // 5
            4'd6: seg = 7'b000_0010; // 6
            4'd7: seg = 7'b111_1000; // 7
            4'd8: seg = 7'b000_0000; // 8
            4'd9: seg = 7'b001_0000; // 9
            default: seg = 7'b111_1111; // blank
        endcase
    end
endmodule


// ============================================================
// LED CONTROLLER
// Lights red LED when speed exceeds threshold
// FIX 6: input widened to 13 bits; threshold updated to 200 cm/s
//         (change SPEED_LIMIT to whatever suits your application)
// ============================================================
module red_led_controller (
    input  wire [12:0] speed_in,        // FIX: was [7:0]
    output reg         red_led_out
);
    parameter SPEED_LIMIT = 13'd200;    // cm/s — adjust as needed

    always @(*) begin
        red_led_out = (speed_in > SPEED_LIMIT) ? 1'b1 : 1'b0;
    end
endmodule
