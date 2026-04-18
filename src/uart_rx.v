// uart_rx.v — 8-N-1 UART Receiver (double-flop CDC safe)
// Author: Dr. Sriram Anbalagan | Guide: Dr. T.N. Prabakar
// SASTRA Deemed University — TTSKY26a / SKY130B
// PVR-004 FIX: port comments added
// REQ-004: double-flop synchroniser on rx_pin
`default_nettype none
module uart_rx #(
    parameter CLK_FREQ  = 50_000_000, // Hz system clock frequency
    parameter BAUD_RATE = 57600        // bps AS-68M UART baud rate
)(
    input  wire       clk,      // System clock (single domain, REQ-003)
    input  wire       rst,      // Active-HIGH async reset
    input  wire       rx_pin,   // Serial input from sensor TD pin 4 (async)
    output reg        rx_valid, // Pulses HIGH 1 clk when byte received
    output reg  [7:0] rx_data   // Received byte value
);
localparam integer CLKS_PER_BIT  = CLK_FREQ / BAUD_RATE;
localparam integer CLKS_HALF_BIT = CLKS_PER_BIT / 2;
reg s1, s2;
always @(posedge clk or posedge rst)
    if (rst) begin s1<=1; s2<=1; end
    else     begin s1<=rx_pin; s2<=s1; end
localparam [1:0] S_IDLE=2'd0, S_START=2'd1, S_DATA=2'd2, S_STOP=2'd3;
reg [1:0]  state;
reg [31:0] cnt;
reg [2:0]  bit_idx;
reg [7:0]  shreg;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        state<=S_IDLE; cnt<=0; bit_idx<=0;
        shreg<=0; rx_valid<=0; rx_data<=0;
    end else begin
        rx_valid<=0;
        case (state)
        S_IDLE:  if (!s2) begin cnt<=0; state<=S_START; end
        S_START: begin
            if (cnt==CLKS_HALF_BIT-1) begin cnt<=0;
                if (!s2) begin bit_idx<=0; state<=S_DATA; end
                else state<=S_IDLE;
            end else cnt<=cnt+1;
        end
        S_DATA: begin
            if (cnt==CLKS_PER_BIT-1) begin cnt<=0; shreg<={s2,shreg[7:1]};
                if (bit_idx==7) state<=S_STOP; else bit_idx<=bit_idx+1;
            end else cnt<=cnt+1;
        end
        S_STOP: begin
            if (cnt==CLKS_PER_BIT-1) begin cnt<=0;
                if (s2) begin rx_data<=shreg; rx_valid<=1; end
                state<=S_IDLE;
            end else cnt<=cnt+1;
        end
        default: state<=S_IDLE;
        endcase
    end
end
endmodule
