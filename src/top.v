`timescale 1ps/1ps

module top(
    input wire clock,
    input wire resetn,
    input wire rxd,
    output wire txd,
    output wire [15:0] led,
    
    // output wire bram_en,
    // output wire bram_we,
    // output wire [31:0] bram_addr,
    // output wire [31:0] bram_wd,
    // input wire [31:0] bram_rd,
    
    input wire ddr2_stall,
    input wire [31:0] ddr2_rd,
    output wire ddr2_en,
    output wire ddr2_we,
    output wire [31:0] ddr2_addr,
    output wire [31:0] ddr2_wd
);
    Board board(clock, resetn, rxd, txd, led, //bram_en, bram_we, bram_addr, bram_wd, bram_rd,
    ddr2_stall, ddr2_rd, ddr2_en, ddr2_we, ddr2_addr, ddr2_wd);
endmodule