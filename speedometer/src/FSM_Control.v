`timescale 1ns / 1ps

module FSM_Control (
    input clk,
    input reset,
    input sensor1_edge,
    input sensor2_edge,
    input calc_done,
    output reg timer_start,
    output reg timer_stop,
    output reg calc_start
);

    localparam IDLE = 2'b00;
    localparam TIMING = 2'b01;
    localparam CALC = 2'b10;
    localparam DONE = 2'b11;

    reg [1:0] state, next_state;

    always @(posedge clk) begin
        if (reset) state <= IDLE;
        else state <= next_state;
    end

    always @(*) begin
        next_state = state;
        timer_start = 0;
        timer_stop = 0;
        calc_start = 0;

        case (state)
            IDLE: begin
                if (sensor1_edge) begin
                    timer_start = 1;
                    next_state = TIMING;
                end
            end

            TIMING: begin
                if (sensor2_edge) begin
                    timer_stop = 1;
                    calc_start = 1;
                    next_state = CALC;
                end
            end

            CALC: begin
                if (calc_done) begin
                    next_state = DONE;
                end
            end

            DONE: begin
                // Stay in done until reset or new sensor1 edge
                if (sensor1_edge) begin
                    timer_start = 1;
                    next_state = TIMING;
                end
            end
            
            default: next_state = IDLE;
        endcase
    end
endmodule
