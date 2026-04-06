// =============================================================================
// Module  : speed_compute
// Project : Velox RTL – Multi-Object Speed Measurement (Nexys A7-100T)
// Stage   : 3 – Speed Computation (Sequential Restoring Divider)
//
// speed [cm/s] = DIST_CM * 100000000 / delta_t
//
// Updates: Replaced combinational division with a 64-cycle sequential
// state machine to ensure clean synthesis and timing closure.
// =============================================================================

`timescale 1ns / 1ps

module speed_compute #(
    parameter DIST_CM = 10
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire [31:0] delta_t,
    input  wire        data_valid,
    output reg         ready,         // NEW: Tells datapath we can accept data
    output reg  [15:0] speed_cms,
    output reg         speed_valid,
    output reg         too_fast
);

    localparam [63:0] NUMERATOR = DIST_CM * 64'd100_000_000;

    // FSM States
    localparam S_IDLE   = 2'b00;
    localparam S_DIVIDE = 2'b01;
    localparam S_DONE   = 2'b10;

    reg [1:0]  state;
    reg [6:0]  count;

    reg [63:0] dividend_q;
    reg [31:0] remainder_a;
    reg [31:0] divisor_m;

    wire [32:0] shift_val = {remainder_a, dividend_q[63]};

    always @(posedge clk) begin
        if (!rst_n) begin
            state       <= S_IDLE;
            ready       <= 1'b1;
            count       <= 7'd0;
            dividend_q  <= 64'd0;
            remainder_a <= 32'd0;
            divisor_m   <= 32'd0;
            speed_cms   <= 16'd0;
            speed_valid <= 1'b0;
            too_fast    <= 1'b0;
        end else begin
            // Default: clear single-cycle valid pulse
            speed_valid <= 1'b0;

            case (state)
                S_IDLE: begin
                    ready <= 1'b1;
                    if (data_valid) begin
                        ready <= 1'b0; // Lock out new data while calculating
                        if (delta_t == 0) begin
                            speed_cms   <= 16'hFFFF;
                            too_fast    <= 1'b1;
                            speed_valid <= 1'b1;
                            ready       <= 1'b1;
                        end else begin
                            dividend_q  <= NUMERATOR;
                            remainder_a <= 32'd0;
                            divisor_m   <= delta_t;
                            count       <= 7'd63; // 64 shifts for 64-bit dividend
                            state       <= S_DIVIDE;
                        end
                    end
                end

                S_DIVIDE: begin
                    // Shift and subtract mechanism
                    if (shift_val >= divisor_m) begin
                        remainder_a <= shift_val[31:0] - divisor_m;
                        dividend_q  <= {dividend_q[62:0], 1'b1};
                    end else begin
                        remainder_a <= shift_val[31:0];
                        dividend_q  <= {dividend_q[62:0], 1'b0};
                    end

                    if (count == 0) begin
                        state <= S_DONE;
                    end else begin
                        count <= count - 1;
                    end
                end

                S_DONE: begin
                    // Check bounds on quotient
                    if (dividend_q > 64'd65535) begin
                        speed_cms <= 16'hFFFF;
                        too_fast  <= 1'b1;
                    end else begin
                        speed_cms <= dividend_q[15:0];
                        too_fast  <= 1'b0;
                    end
                    speed_valid <= 1'b1;
                    state       <= S_IDLE;
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule
