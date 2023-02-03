`timescale 1ps/1ps

module top(
    input wire clock,
    input wire resetn,
    input wire rxd,
    output wire txd,
    output wire [15:0] led
);
    Board board(clock, resetn, rxd, txd, led);
endmodule