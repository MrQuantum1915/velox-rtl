`timescale 1ns / 1ps

module FSM_tb();
    reg clk;
    reg reset;
    reg sensor1_edge;
    reg sensor2_edge;
    reg calc_done;
    
    wire timer_start;
    wire timer_stop;
    wire calc_start;

    FSM_Control uut (
        .clk(clk), .reset(reset),
        .sensor1_edge(sensor1_edge), .sensor2_edge(sensor2_edge), .calc_done(calc_done),
        .timer_start(timer_start), .timer_stop(timer_stop), .calc_start(calc_start)
    );

    always #5 clk = ~clk;

    initial begin
        clk = 0; reset = 1;
        sensor1_edge = 0; sensor2_edge = 0; calc_done = 0;
        #20 reset = 0;
        
        #15 sensor1_edge = 1; #10 sensor1_edge = 0;
        #50 sensor2_edge = 1; #10 sensor2_edge = 0;
        #30 calc_done = 1; #10 calc_done = 0;
        
        #50 $finish;
    end
endmodule
