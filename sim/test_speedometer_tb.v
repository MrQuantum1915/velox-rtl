// ============================================================
// TESTBENCH: FPGA Speedometer (Nexys A7)
// Aligned to implemented RTL behavior documented in IEEE report:
// - Speed unit is cm/s
// - Measurement window is 0.5 s in hardware
// - Speed calculation is pulse_count * 16
// - Overspeed threshold is 200 cm/s
//
// For practical Vivado simulation, this testbench fast-forwards the
// internal timer near the end of the 0.5 s window. This changes only
// simulation runtime, not the synthesizable RTL.
// ============================================================

`timescale 1ns / 1ps

module test_speedometer_tb;

    reg clk;
    reg reset_btn;
    reg ir1;
    reg ir2;

    wire [6:0] seg;
    wire [7:0] an;
    wire red_led;

    reg  [8:0]  captured_pulse_count;
    reg  [12:0] captured_speed_cm_s;
    reg         led_seen;
    integer     pass_count;
    integer     fail_count;

    speedometer_top uut (
        .clk(clk),
        .reset_btn(reset_btn),
        .ir1(ir1),
        .ir2(ir2),
        .seg(seg),
        .an(an),
        .red_led(red_led)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;  // 100 MHz
    end

    task apply_reset;
        begin
            reset_btn = 1'b1;
            ir1       = 1'b0;
            ir2       = 1'b0;
            repeat (5) @(posedge clk);
            reset_btn = 1'b0;
            repeat (5) @(posedge clk);
        end
    endtask

    task start_test;
        begin
            captured_pulse_count = 9'd0;
            captured_speed_cm_s  = 13'd0;
            led_seen             = 1'b0;
            ir1                  = 1'b0;
            ir2                  = 1'b0;
            repeat (2) @(posedge clk);
        end
    endtask

    // One complete forward quadrature cycle:
    // 00 -> 01 -> 11 -> 10 -> 00
    // This produces 4 valid counted transitions.
    task generate_quadrature_cycle;
        input integer delay_ns;
        begin
            ir1 = 1'b0; ir2 = 1'b0; #delay_ns;
            ir1 = 1'b0; ir2 = 1'b1; #delay_ns;
            ir1 = 1'b1; ir2 = 1'b1; #delay_ns;
            ir1 = 1'b1; ir2 = 1'b0; #delay_ns;
            ir1 = 1'b0; ir2 = 1'b0; #delay_ns;
        end
    endtask

    // Invalid state jumps should not increment the pulse counter.
    task generate_invalid_jump;
        input integer delay_ns;
        begin
            ir1 = 1'b0; ir2 = 1'b0; #delay_ns;
            ir1 = 1'b1; ir2 = 1'b1; #delay_ns;  // 00 -> 11
            ir1 = 1'b0; ir2 = 1'b0; #delay_ns;  // 11 -> 00
        end
    endtask

    // Short glitches stay below the 3-sample filter length and should
    // not appear at the cleaned sensor outputs.
    task generate_short_glitch_noise;
        begin
            ir1 = 1'b0; ir2 = 1'b0; #7;
            ir2 = 1'b1; #8;
            ir2 = 1'b0; #9;
            ir1 = 1'b1; #6;
            ir1 = 1'b0; #10;
            ir2 = 1'b1; #5;
            ir2 = 1'b0; #11;
            ir1 = 1'b0; ir2 = 1'b0; #20;
        end
    endtask

    // Move the hardware timer close to its 0.5 s terminal count so the
    // simulation closes the measurement window in a few clock cycles.
    task fast_forward_to_window_close;
        begin
            @(negedge clk);
            uut.clk_div_inst.count = 26'd49_999_998;
            @(posedge uut.timer_done);
            @(posedge clk);
        end
    endtask

    task check_measurement;
        input integer test_id;
        input integer expected_pulses;
        input integer expected_speed_cm_s;
        input integer expected_led_seen;
        begin
            if ((captured_pulse_count == expected_pulses) &&
                (captured_speed_cm_s  == expected_speed_cm_s) &&
                (led_seen             == expected_led_seen)) begin
                pass_count = pass_count + 1;
                $display("[PASS] TEST %0d -> pulses=%0d, speed=%0d cm/s, led_seen=%0d",
                         test_id, captured_pulse_count, captured_speed_cm_s, led_seen);
            end else begin
                fail_count = fail_count + 1;
                $display("[FAIL] TEST %0d", test_id);
                $display("       expected: pulses=%0d, speed=%0d cm/s, led_seen=%0d",
                         expected_pulses, expected_speed_cm_s, expected_led_seen);
                $display("       observed: pulses=%0d, speed=%0d cm/s, led_seen=%0d",
                         captured_pulse_count, captured_speed_cm_s, led_seen);
            end
        end
    endtask

    task check_display_hold;
        input integer test_id;
        input integer expected_measured_speed;
        input integer expected_displayed_speed;
        begin
            if ((captured_speed_cm_s   == expected_measured_speed) &&
                (uut.displayed_speed   == expected_displayed_speed) &&
                (red_led               == 1'b0)) begin
                pass_count = pass_count + 1;
                $display("[PASS] TEST %0d -> measured_speed=%0d cm/s, displayed_speed=%0d cm/s, red_led=%0d",
                         test_id, captured_speed_cm_s, uut.displayed_speed, red_led);
            end else begin
                fail_count = fail_count + 1;
                $display("[FAIL] TEST %0d", test_id);
                $display("       expected: measured_speed=%0d cm/s, displayed_speed=%0d cm/s, red_led=0",
                         expected_measured_speed, expected_displayed_speed);
                $display("       observed: measured_speed=%0d cm/s, displayed_speed=%0d cm/s, red_led=%0d",
                         captured_speed_cm_s, uut.displayed_speed, red_led);
            end
        end
    endtask

    initial begin
        pass_count = 0;
        fail_count = 0;
        reset_btn  = 1'b0;
        ir1        = 1'b0;
        ir2        = 1'b0;
        led_seen   = 1'b0;
        captured_pulse_count = 9'd0;
        captured_speed_cm_s  = 13'd0;

        $display("\n========================================");
        $display(" SPEEDOMETER SIMULATION - Nexys A7");
        $display(" Unit: cm/s");
        $display(" Implemented formula: speed = pulse_count * 16");
        $display(" Overspeed threshold: 200 cm/s");
        $display("========================================\n");

        apply_reset;

        $display("TEST 1: LOW SPEED -> 8 valid transitions, 128 cm/s, LED must stay low");
        start_test;
        repeat (2) generate_quadrature_cycle(50);
        fast_forward_to_window_close;
        check_measurement(1, 8, 128, 0);

        apply_reset;

        $display("TEST 2: THRESHOLD-EDGE BELOW LIMIT -> 12 valid transitions, 192 cm/s");
        start_test;
        repeat (3) generate_quadrature_cycle(50);
        fast_forward_to_window_close;
        check_measurement(2, 12, 192, 0);

        apply_reset;

        $display("TEST 3: OVERSPEED -> 16 valid transitions, 256 cm/s, LED must assert");
        start_test;
        repeat (4) generate_quadrature_cycle(50);
        fast_forward_to_window_close;
        check_measurement(3, 16, 256, 1);

        apply_reset;

        $display("TEST 4: INVALID QUADRATURE JUMPS -> counter must remain zero");
        start_test;
        repeat (6) generate_invalid_jump(50);
        fast_forward_to_window_close;
        check_measurement(4, 0, 0, 0);

        apply_reset;

        $display("TEST 5: SHORT GLITCH NOISE -> filter must reject glitches");
        start_test;
        repeat (10) generate_short_glitch_noise;
        fast_forward_to_window_close;
        check_measurement(5, 0, 0, 0);

        apply_reset;

        $display("TEST 6: ZERO SPEED -> no motion, zero output");
        start_test;
        fast_forward_to_window_close;
        check_measurement(6, 0, 0, 0);

        apply_reset;

        $display("TEST 7A: DISPLAY HOLD SETUP -> create non-zero reading");
        start_test;
        repeat (4) generate_quadrature_cycle(50);
        fast_forward_to_window_close;
        check_measurement(7, 16, 256, 1);

        $display("TEST 7B: DISPLAY HOLD -> next zero window keeps last displayed value");
        start_test;
        fast_forward_to_window_close;
        check_display_hold(8, 0, 256);

        $display("\n========================================");
        $display(" TEST SUMMARY");
        $display(" Passed: %0d", pass_count);
        $display(" Failed: %0d", fail_count);
        $display("========================================\n");

        if (fail_count == 0)
            $display("[RESULT] All simulation tests passed.");
        else
            $display("[RESULT] One or more simulation tests failed.");

        #100;
        $finish;
    end

    initial begin
        $dumpfile("speedometer_nexys_a7.vcd");
        $dumpvars(0, test_speedometer_tb);
    end

    always @(posedge uut.timer_done) begin
        captured_pulse_count = uut.pulse_count;
        captured_speed_cm_s  = uut.speed_cm_s;
        $display("[TIMER] Window closed at %0t ns -> pulses=%0d, speed=%0d cm/s, displayed=%0d cm/s",
                 $time, uut.pulse_count, uut.speed_cm_s, uut.displayed_speed);
    end

    always @(posedge red_led) begin
        led_seen = 1'b1;
        $display("[ALERT] Overspeed indication observed at %0t ns", $time);
    end

endmodule
