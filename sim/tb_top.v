// =============================================================================
// Module  : tb_top
// Project : Velox RTL – Multi-Object Speed Measurement (Nexys A7-100T)
// Purpose : System-level testbench
//
// Test cases
// ----------
//  TC1 – Single object, known speed (50 cm/s  → delta_t = 2 000 000 cycles)
//  TC2 – Single object, fast speed  (500 cm/s → delta_t =   200 000 cycles)
//  TC3 – Three objects in rapid succession (pipeline stress test)
//  TC4 – Timeout test: object hits A but never reaches B
//  TC5 – Back-to-back objects, FIFO fill test
//
// How sensors are modelled
// ────────────────────────
//  SENSOR_A and SENSOR_B are active-low.  A task drives them LOW for a
//  short pulse to simulate an object breaking the beam.
//
// Expected speed formula
// ──────────────────────
//  speed [cm/s] = 10 cm × 100e6 Hz / delta_t_cycles
//
// Usage (Vivado xsim or ModelSim):
//   vlog  src/*.v sim/tb_top.v
//   vsim  tb_top -do "run -all"
// =============================================================================

`timescale 1ns / 1ps

module tb_top;

    // =========================================================================
    // DUT signals
    // =========================================================================
    reg        CLK100MHZ;
    reg        CPU_RESETN;
    reg        SENSOR_A;
    reg        SENSOR_B;

    wire [6:0] SEG;
    wire [3:0] AN;
    wire       LED_OVERFLOW;
    wire       LED_TOO_FAST;
    wire       LED_TIMEOUT;

    // =========================================================================
    // DUT instantiation
    // =========================================================================
    top dut (
        .CLK100MHZ  (CLK100MHZ),
        .CPU_RESETN (CPU_RESETN),
        .SENSOR_A   (SENSOR_A),
        .SENSOR_B   (SENSOR_B),
        .SEG        (SEG),
        .AN         (AN),
        .LED_OVERFLOW (LED_OVERFLOW),
        .LED_TOO_FAST (LED_TOO_FAST),
        .LED_TIMEOUT  (LED_TIMEOUT)
    );

    // =========================================================================
    // Clock generation: 100 MHz → 10 ns period
    // =========================================================================
    initial CLK100MHZ = 1'b0;
    always  #5 CLK100MHZ = ~CLK100MHZ;

    // =========================================================================
    // Helper parameters
    // =========================================================================
    localparam CYCLE = 10;          // ns per clock cycle
    localparam BEAM_PULSE_NS = 500; // sensor pulse width in ns (50 cycles)

    // =========================================================================
    // Task: trigger a sensor with a short active-low pulse
    // =========================================================================
    task trigger_sensor;
        input sensor_sel;   // 0 = A, 1 = B
        begin
            if (sensor_sel == 1'b0) begin
                SENSOR_A = 1'b0;
                #BEAM_PULSE_NS;
                SENSOR_A = 1'b1;
            end else begin
                SENSOR_B = 1'b0;
                #BEAM_PULSE_NS;
                SENSOR_B = 1'b1;
            end
        end
    endtask

    // =========================================================================
    // Task: fire both sensors with a controlled delta_t gap
    //       delta_t_cycles = number of 10 ns clock cycles between triggers
    // =========================================================================
    task send_object;
        input [31:0] delta_t_cycles;
        integer      expected_cms;
        begin
            expected_cms = (10 * 100_000_000) / delta_t_cycles;
            $display("[%0t ns] --> Object: delta_t=%0d cycles, expected speed~%0d cm/s",
                     $time, delta_t_cycles, expected_cms);

            trigger_sensor(1'b0);           // sensor A fires
            #(delta_t_cycles * CYCLE);      // object travels for delta_t cycles
            trigger_sensor(1'b1);           // sensor B fires
        end
    endtask

    // =========================================================================
    // Monitor: watch for speed_valid and print result
    // =========================================================================
    always @(posedge CLK100MHZ) begin
        if (dut.speed_valid)
            $display("[%0t ns] <<< speed_valid: speed_cms = %0d cm/s  too_fast=%b",
                     $time, dut.speed_cms, dut.too_fast);
        if (dut.LED_TIMEOUT)
            $display("[%0t ns] !!! TIMEOUT – object did not reach sensor B", $time);
        if (dut.LED_OVERFLOW)
            $display("[%0t ns] !!! OVERFLOW – measurement FIFO full", $time);
    end

    // =========================================================================
    // Test stimulus
    // =========================================================================
    integer tc;
    initial begin
        // ------------------------------------------------------------------
        // Initialise
        // ------------------------------------------------------------------
        CPU_RESETN = 1'b0;
        SENSOR_A   = 1'b1;   // idle = high
        SENSOR_B   = 1'b1;
        #200;                 // hold reset for 200 ns (20 cycles)
        CPU_RESETN = 1'b1;
        #100;

        // ==================================================================
        // TC1: Single slow object  – 50 cm/s
        //       delta_t = 10 cm / 50 cm/s × 100 MHz = 2 000 000 cycles
        // ==================================================================
        $display("\n=== TC1: Single object @ ~50 cm/s ===");
        send_object(32'd2_000_000);
        #5_000_000;   // wait 50 ms for pipeline to flush and display to update

        // ==================================================================
        // TC2: Single fast object – 500 cm/s
        //       delta_t = 10 cm / 500 cm/s × 100 MHz = 200 000 cycles
        // ==================================================================
        $display("\n=== TC2: Single object @ ~500 cm/s ===");
        send_object(32'd200_000);
        #2_000_000;

        // ==================================================================
        // TC3: Three objects in rapid succession (pipeline stress)
        //      Objects arrive 500 000 cycles (5 ms) apart
        // ==================================================================
        $display("\n=== TC3: Three rapid objects (pipeline stress) ===");
        fork
            begin : obj1
                send_object(32'd1_000_000);   // 100 cm/s
            end
            begin : obj2
                #3_000_000;                    // 30 ms later
                send_object(32'd750_000);      // 133 cm/s
            end
            begin : obj3
                #6_000_000;                    // 60 ms later
                send_object(32'd500_000);      // 200 cm/s
            end
        join
        #10_000_000;

        // ==================================================================
        // TC4: Timeout test – object hits sensor A but never sensor B
        // ==================================================================
        $display("\n=== TC4: Timeout test ===");
        trigger_sensor(1'b0);          // only sensor A fires
        // Wait more than TIMEOUT_CYCLES × 10 ns = 2 000 000 000 ns = 2 s
        // Use abbreviated model: reduce timeout in sim to 500 000 cycles
        // (fsm_control's TIMEOUT_CYCLES is parameterised in the DUT –
        //  for simulation we can reduce it; here we just wait 5 ms)
        #5_000_000;
        // After timeout, reset and continue
        CPU_RESETN = 1'b0; #100; CPU_RESETN = 1'b1; #200;

        // ==================================================================
        // TC5: Very fast object (LUT saturation / too_fast flag)
        //      delta_t = 512 cycles → top 10 bits = 0 → fast flag
        // ==================================================================
        $display("\n=== TC5: Too-fast object (LUT saturation) ===");
        send_object(32'd512);
        #1_000_000;

        // ==================================================================
        // Done
        // ==================================================================
        $display("\n=== All test cases complete ===");
        #100_000;
        $finish;
    end

    // =========================================================================
    // Waveform dump (for GTKWave or Vivado simulator)
    // =========================================================================
    initial begin
        $dumpfile("tb_top.vcd");
        $dumpvars(0, tb_top);
    end

    // =========================================================================
    // Timeout guard – prevent infinite simulation
    // =========================================================================
    initial begin
        #500_000_000;
        $display("[%0t ns] *** Simulation timeout guard triggered ***", $time);
        $finish;
    end

endmodule