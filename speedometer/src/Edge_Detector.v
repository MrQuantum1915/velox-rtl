`timescale 1ns / 1ps

module Edge_Detector #(
    // Smaller debounce for sim, 100k for synth (1ms at 100MHz)
    parameter DEBOUNCE_MAX = 100000 
)(
    input clk,
    input reset,
    input signal_in,
    output edge_out
);
    // Synchronizer for metastability
    reg sync_0, sync_1;
    always @(posedge clk) begin
        if (reset) begin
            sync_0 <= 0;
            sync_1 <= 0;
        end else begin
            sync_0 <= signal_in;
            sync_1 <= sync_0;
        end
    end

    // Debouncer
    reg [16:0] count;
    reg debounced_state;
    
    always @(posedge clk) begin
        if (reset) begin
            count <= 0;
            debounced_state <= 0;
        end else begin
            if (sync_1 != debounced_state) begin
                count <= count + 1;
                if (count == DEBOUNCE_MAX) begin
                    debounced_state <= sync_1;
                    count <= 0;
                end
            end else begin
                count <= 0;
            end
        end
    end

    // Edge Detection (Rising Edge)
    reg delay_state;
    always @(posedge clk) begin
        if (reset) delay_state <= 0;
        else delay_state <= debounced_state;
    end

    assign edge_out = debounced_state & ~delay_state;

endmodule
