`timescale 1ns / 1ps

module Timer (
    input clk,
    input reset,
    input start,
    input stop,
    output reg [31:0] cycles
);
    reg running;

    always @(posedge clk) begin
        if (reset) begin
            running <= 0;
            cycles <= 0;
        end else begin
            if (start && !running) begin
                running <= 1;
                cycles <= 0;
            end else if (stop && running) begin
                running <= 0;
            end
            
            if (running) begin
                cycles <= cycles + 1;
            end
        end
    end
endmodule
