`timescale 1ns / 1ps

module Top_tb();
    reg clk;
    reg reset_n;
    reg sensor1;
    reg sensor2;
    wire [7:0] an;
    wire [6:0] seg;

    Top_Speedometer #(
        .DISTANCE_CM(50), 
        .CLOCK_FREQ(100000000)
    ) UUT (
        .clk(clk),
        .reset_n(reset_n),
        .sensor1(sensor1),
        .sensor2(sensor2),
        .an(an),
        .seg(seg)
    );

    // 100 MHz clock -> 10ns period
    always #5 clk = ~clk;

    initial begin
        clk = 0;
        reset_n = 0;
        sensor1 = 0;
        sensor2 = 0;
        
        #100;
        reset_n = 1;
        #100;
        
        $display("Time: %0t - Starting test", $time);
        
        // Fire sensor 1
        sensor1 = 1;
        // Hold for 1.1ms to account for debouncer (100,000 cycles = 1ms)
        #1100000; 
        sensor1 = 0;
        $display("Time: %0t - Sensor 1 fired and debounced", $time);
        
        // Wait another 1ms
        #1000000; 
        
        // Fire sensor 2
        sensor2 = 1;
        #1100000;
        sensor2 = 0;
        $display("Time: %0t - Sensor 2 fired and debounced", $time);

        // Wait for calculation to finish (33 clock cycles)
        #5000;

        $display("Time: %0t - End of test, checking display", $time);
        
        $finish;
    end
endmodule
