// uart_tx.v — 8-N-1 UART Transmitter
// Author: Dr. Sriram Anbalagan | Guide: Dr. T.N. Prabakar
// SASTRA Deemed University — TTSKY26a / SKY130B
// PVR-004 FIX: port comments added
// CS-003 FIX: CLKS_PER_BIT as localparam
// NXS-001 NOTE: state initialised in async reset
`default_nettype none
module uart_tx #(
    parameter CLK_FREQ  = 50_000_000, // Hz system clock frequency
    parameter BAUD_RATE = 57600        // bps AS-68M UART baud rate
)(
    input  wire       clk,      // System clock (single domain, REQ-003)
    input  wire       rst,      // Active-HIGH async reset
    input  wire       tx_start, // Pulse HIGH 1 clk to start transmission
    input  wire [7:0] tx_data,  // Byte to transmit (sampled on tx_start)
    output reg        tx_busy,  // HIGH during entire UART frame
    output reg        tx_pin    // Serial output to sensor RD pin 5
);
localparam integer CLKS_PER_BIT = CLK_FREQ / BAUD_RATE;
localparam [1:0] S_IDLE=2'd0, S_START=2'd1, S_DATA=2'd2, S_STOP=2'd3;
reg [1:0]  state;
reg [31:0] cnt;
reg [2:0]  bit_idx;
reg [7:0]  shreg;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        state<=S_IDLE; cnt<=0; bit_idx<=0;
        shreg<=0; tx_busy<=0; tx_pin<=1;
    end else case (state)
        S_IDLE: begin
            tx_pin<=1; tx_busy<=0;
            if (tx_start) begin shreg<=tx_data; cnt<=0; tx_busy<=1; state<=S_START; end
        end
        S_START: begin
            tx_pin<=0;
            if (cnt==CLKS_PER_BIT-1) begin cnt<=0; bit_idx<=0; state<=S_DATA; end
            else cnt<=cnt+1;
        end
        S_DATA: begin
            tx_pin<=shreg[0];
            if (cnt==CLKS_PER_BIT-1) begin
                cnt<=0; shreg<={1'b0,shreg[7:1]};
                if (bit_idx==7) state<=S_STOP; else bit_idx<=bit_idx+1;
            end else cnt<=cnt+1;
        end
        S_STOP: begin
            tx_pin<=1;
            if (cnt==CLKS_PER_BIT-1) begin cnt<=0; tx_busy<=0; state<=S_IDLE; end
            else cnt<=cnt+1;
        end
        default: state<=S_IDLE;
    endcase
end
endmodule
