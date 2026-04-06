`timescale 1ns / 1ps

module Top_Speedometer #(
    parameter DISTANCE_CM = 50,      // Distance between sensors in cm
    parameter CLOCK_FREQ = 100000000 // 100 MHz clock
)(
    input clk,
    input reset_n, // Active low reset from Nexys A7 CPU_RESET button
    input sensor1, // PMOD header
    input sensor2, // PMOD header
    output [7:0] an,
    output [6:0] seg
);

    wire reset = ~reset_n; // Convert to active high internal

    wire s1_edge, s2_edge;
    
    Edge_Detector #(.DEBOUNCE_MAX(100000)) ED1 (
        .clk(clk), .reset(reset), .signal_in(sensor1), .edge_out(s1_edge)
    );
    
    Edge_Detector #(.DEBOUNCE_MAX(100000)) ED2 (
        .clk(clk), .reset(reset), .signal_in(sensor2), .edge_out(s2_edge)
    );

    wire timer_start, timer_stop, calc_start, calc_done;
    wire [31:0] timer_cycles;
    
    Timer TIM (
        .clk(clk), .reset(reset), .start(timer_start), .stop(timer_stop), .cycles(timer_cycles)
    );

    FSM_Control FSM (
        .clk(clk), .reset(reset), 
        .sensor1_edge(s1_edge), .sensor2_edge(s2_edge), .calc_done(calc_done),
        .timer_start(timer_start), .timer_stop(timer_stop), .calc_start(calc_start)
    );

    wire [15:0] speed_cm_s;
    
    Speed_Calc #(.DISTANCE_CM(DISTANCE_CM), .CLOCK_FREQ(CLOCK_FREQ)) CALC (
        .clk(clk), .reset(reset), .start(calc_start), .cycles(timer_cycles),
        .speed_cm_s(speed_cm_s), .done(calc_done)
    );
    
    wire [19:0] bcd;
    
    Bin2BCD B2D (
        .bin(speed_cm_s), .bcd(bcd)
    );
    
    wire is_err = (speed_cm_s == 16'hFFFF);
    
    Seven_Segment_Driver DISP (
        .clk(clk), .reset(reset), .bcd(bcd), .is_error(is_err),
        .an(an), .seg(seg)
    );

endmodule
