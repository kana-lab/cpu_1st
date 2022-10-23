`timescale 1ps/1ps

// `include "D:/cpu_ex/cpu_1st/src/UartTx.sv"
// `include "D:/cpu_ex/cpu_1st/src/UartRx.sv"

// 3Mbaudまでテスト済み (CLK_PER_HALF_BIT = 15)
module LoopBack #(parameter CLK_PER_HALF_BIT = 5208) (
    input wire clock,
    input wire resetn,
    input wire rxd,
    output wire txd
    );

    reg tx_start;
    reg [7:0] sdata;
    wire tx_busy;

    wire rx_ready;
    wire [7:0] rdata;
    wire ferr;
    
    reg data_valid;
    wire reset1;
    assign reset1 = ~resetn;

    UartTx #(CLK_PER_HALF_BIT) tx(clock, reset1, tx_start, sdata, tx_busy, txd);
    UartRx #(CLK_PER_HALF_BIT) rx(clock, reset1, rxd, rx_ready, rdata, ferr);
    
    always @( posedge clock ) begin
        if (reset1) begin
            sdata <= 1'b0;
            tx_start <= 1'b0;
            data_valid <= 1'b0;
        end else begin
            if (rx_ready) begin
                sdata <= rdata;
                data_valid <= 1'b1;
            end

            if (~tx_busy & data_valid) begin
                tx_start <= 1'b1;
            end

            if (tx_start) begin
                data_valid <= 1'b0;
                tx_start <= 1'b0;
            end
        end
    end
endmodule