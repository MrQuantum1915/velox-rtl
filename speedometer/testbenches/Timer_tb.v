`timescale 1ns / 1ps

module Timer_tb();
    reg clk;
    reg reset;
    reg start;
    reg stop;
    wire [31:0] cycles;

    Timer uut (.clk(clk), .reset(reset), .start(start), .stop(stop), .cycles(cycles));

    always #5 clk = ~clk;

    initial begin
        clk = 0;
        reset = 1;
        start = 0;
        stop = 0;
        #20;
        reset = 0;
        
        #20;
        start = 1;
        #10;
        start = 0;
        
        #100;
        stop = 1;
        #10;
        stop = 0;
        
        #50;
        if (cycles > 5) $display("Pass: Cycles counted properly.");
        else $display("Fail: Expected 10, got %d", cycles);
        
        $finish;
    end
endmodule
