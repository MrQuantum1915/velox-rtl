// ============================================================
// TESTBENCH: FPGA Speedometer (Nexys A7)
// Updated for 100 MHz clock
// ============================================================

`timescale 1ns / 1ps

module test_speedometer_tb;

    // ============ TESTBENCH SIGNALS ============
    reg clk;                          // 100 MHz clock
    reg reset_btn;                    // Reset button (active HIGH)
    reg ir1;                          // IR Sensor 1
    reg ir2;                          // IR Sensor 2

    wire [6:0] seg;                   // 7-segment cathode pins
    wire [7:0] an;                    // 7-segment anode selectors
    wire red_led;                     // Red LED output

    // Internal signals for monitoring
    wire timer_done;
    wire timer_reset;
    wire [8:0] pulse_count;
    wire [7:0] speed_kmh;
    integer i;


    // ============ DEVICE UNDER TEST ============
    speedometer_top uut (
        .clk(clk),
        .reset_btn(reset_btn),
        .ir1(ir1),
        .ir2(ir2),
        .seg(seg),
        .an(an),
        .red_led(red_led)
    );


    // ============ CLOCK GENERATION (100 MHz) ============
    initial begin
        clk = 0;
        forever #5 clk = ~clk;  // 10 ns period = 100 MHz
    end


    // ============ HELPER TASK: GENERATE QUADRATURE PULSE ============
    // Simulates one complete wheel rotation step (4-state transition)
    // 00 → 01 → 11 → 10 → 00 (forward direction)
    // Input: delay_time in nanoseconds
    task generate_quadrature_step;
        input integer delay_ns;
        begin
            ir1 = 0; ir2 = 0; #delay_ns;  // State 00
            ir1 = 0; ir2 = 1; #delay_ns;  // State 01
            ir1 = 1; ir2 = 1; #delay_ns;  // State 11
            ir1 = 1; ir2 = 0; #delay_ns;  // State 10
        end
    endtask


    // ============ HELPER TASK: GENERATE NOISY PULSE ============
    // Simulates IR sensor noise/bouncing
    task generate_noisy_step;
        input integer delay_ns;
        begin
            // 00 → 01 with bouncing
            ir1 = 0; ir2 = 0; #delay_ns;
            ir1 = 0; ir2 = 1; #(delay_ns/2);
            ir1 = 0; ir2 = 0; #(delay_ns/4);  // Bounce back
            ir1 = 0; ir2 = 1; #(delay_ns/4);  // Back to normal
            ir1 = 1; ir2 = 1; #delay_ns;
            ir1 = 1; ir2 = 0; #delay_ns;
        end
    endtask


    // ============ MAIN TEST SEQUENCE ============
    initial begin

        // ===== INITIALIZATION =====
        $display("\n");
        $display("========================================");
        $display("  SPEEDOMETER SIMULATION - Nexys A7");
        $display("  Clock: 100 MHz");
        $display("  Measurement Window: 0.5 seconds");
        $display("========================================");
        $display("\n");

        reset_btn = 0;  // Button released (reset inactive)
        ir1 = 0;
        ir2 = 0;

        #100;

        // ===== APPLY RESET =====
        $display("[TIME: %t] Applying reset...", $time);
        reset_btn = 1;  // Assert reset (active HIGH)
        #100;
        reset_btn = 0;  // Release reset
        #100;

        $display("[TIME: %t] Reset complete. Starting tests...\n", $time);

        // ==================================================
        // TEST 1: LOW SPEED (~50 km/h)
        // ==================================================
        $display("\n========================================");
        $display("TEST 1: LOW SPEED (~50 km/h)");
        $display("========================================");
        $display("Generating 100 pulses over 0.5 seconds...");

        for (i = 0; i < 100; i = i + 1) begin
            generate_quadrature_step(2500000);  // Slower pulses
        end

        // Wait for FULL measurement window (500ms + buffer)
        #520000000;

        $display("[TIME: %t] Measurement window closed", $time);
        $display("[RESULT] Speed: %d km/h", uut.speed_kmh);
        $display("[RESULT] Pulse Count: %d", uut.pulse_count);
        $display("[RESULT] Red LED: %b (should be 0 for speed < 110 km/h)", red_led);
        $display("[RESULT] Display Segments: %7b", seg);
        $display("[RESULT] Display Anodes: %8b\n", an);

        // ==================================================
        // RESET BETWEEN TESTS
        // ==================================================
        #500000;
        reset_btn = 1;  // Assert reset
        #100;
        reset_btn = 0;  // Release reset
        #1000000;

        // ==================================================
        // TEST 2: MEDIUM SPEED (~75 km/h)
        // ==================================================
        $display("\n========================================");
        $display("TEST 2: MEDIUM SPEED (~75 km/h)");
        $display("========================================");
        $display("Generating 150 pulses over 0.5 seconds...");

        for (i = 0; i < 150; i = i + 1) begin
            generate_quadrature_step(1666667);  // Medium pulses
        end

        // Wait for FULL measurement window (500ms + buffer)
        #520000000;

        $display("[TIME: %t] Measurement window closed", $time);
        $display("[RESULT] Speed: %d km/h", uut.speed_kmh);
        $display("[RESULT] Pulse Count: %d", uut.pulse_count);
        $display("[RESULT] Red LED: %b (should be 0)", red_led);
        $display("[RESULT] Display Segments: %7b", seg);
        $display("[RESULT] Display Anodes: %8b\n", an);

        // ==================================================
        // RESET BETWEEN TESTS
        // ==================================================
        #500000;
        reset_btn = 1;  // Assert reset
        #100;
        reset_btn = 0;  // Release reset
        #1000000;

        // ==================================================
        // TEST 3: HIGH SPEED (~120 km/h) - Should trigger LED
        // ==================================================
        $display("\n========================================");
        $display("TEST 3: HIGH SPEED (~120 km/h)");
        $display("========================================");
        $display("Generating 200 pulses over 0.5 seconds...");

        for (i = 0; i < 200; i = i + 1) begin
            generate_quadrature_step(1250000);  // Faster pulses
        end

        // Wait for FULL measurement window (500ms + buffer)
        #520000000;

        $display("[TIME: %t] Measurement window closed", $time);
        $display("[RESULT] Speed: %d km/h", uut.speed_kmh);
        $display("[RESULT] Pulse Count: %d", uut.pulse_count);
        $display("[RESULT] Red LED: %b (should be 1 for speed > 110 km/h)", red_led);
        $display("[RESULT] Display Segments: %7b", seg);
        $display("[RESULT] Display Anodes: %8b\n", an);

        // ==================================================
        // RESET BETWEEN TESTS
        // ==================================================
        #500000;
        reset_btn = 1;  // Assert reset
        #100;
        reset_btn = 0;  // Release reset
        #1000000;

        // ==================================================
        // TEST 4: VERY HIGH SPEED (~180 km/h)
        // ==================================================
        $display("\n========================================");
        $display("TEST 4: VERY HIGH SPEED (~180 km/h)");
        $display("========================================");
        $display("Generating 250 pulses over 0.5 seconds...");

        for (i = 0; i < 250; i = i + 1) begin
            generate_quadrature_step(1000000);  // Very fast pulses
        end

        // Wait for FULL measurement window (500ms + buffer)
        #520000000;

        $display("[TIME: %t] Measurement window closed", $time);
        $display("[RESULT] Speed: %d km/h", uut.speed_kmh);
        $display("[RESULT] Pulse Count: %d", uut.pulse_count);
        $display("[RESULT] Red LED: %b (should be 1)", red_led);
        $display("[RESULT] Display Segments: %7b", seg);
        $display("[RESULT] Display Anodes: %8b\n", an);

        // ==================================================
        // TEST 5: ZERO SPEED (No pulses)
        // ==================================================
        #500000;
        reset_btn = 1;  // Assert reset
        #100;
        reset_btn = 0;  // Release reset
        #1000000;

        $display("\n========================================");
        $display("TEST 5: ZERO SPEED (No pulses)");
        $display("========================================");
        $display("No pulses generated (stationary)...");

        // Wait for FULL measurement window (500ms + buffer)
        #520000000;

        $display("[TIME: %t] Measurement window closed", $time);
        $display("[RESULT] Speed: %d km/h", uut.speed_kmh);
        $display("[RESULT] Pulse Count: %d", uut.pulse_count);
        $display("[RESULT] Red LED: %b (should be 0)", red_led);
        $display("[RESULT] Display Segments: %7b", seg);
        $display("[RESULT] Display Anodes: %8b\n", an);

        // ==================================================
        // TEST COMPLETE
        // ==================================================
        #1000000;
        $display("\n========================================");
        $display("  ALL TESTS COMPLETE");
        $display("========================================\n");

        $finish;
    end


    // ============ WAVEFORM DUMP FOR VIEWING ============
    initial begin
        $dumpfile("speedometer_nexys_a7.vcd");
        $dumpvars(0, test_speedometer_tb);
        // Dump only selected signals for readability
        $dumpvars(1, uut.speed_kmh, uut.pulse_count, uut.timer_done);
    end


    // ============ MONITORING BLOCK ============
    always @(posedge uut.timer_done) begin
        $display("[TIMER] Measurement window closed at time %t", $time);
        $display("        Pulses counted: %d", uut.pulse_count);
        $display("        Calculated speed: %d km/h", uut.speed_kmh);
    end

    always @(posedge red_led) begin
        $display("[ALERT] Overspeed! Speed exceeded 110 km/h at time %t", $time);
    end

endmodule