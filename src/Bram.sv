`timescale 1ps/1ps
`include "MemoryInterface.sv"


// BRAM は直接 block ram generator を叩くつもりだったが、後に
// ram_style = "block"に任せることにしたためこのようなモジュールができた
module Bram # (
    BRAM_SIZE = 512
) (
    input wire clock,
    input wire reset,

    input wire bram_en,
    input wire bram_we,
    input wire [31:0] bram_addr,
    input wire [31:0] bram_wd,
    output reg [31:0] bram_rd
);
    (* ram_style = "block" *) reg [31:0] bram[BRAM_SIZE - 1:0];

    always_ff @(posedge clock) begin
        if (reset) begin
            bram_rd <= 0;
        end else if (bram_en) begin
            if (bram_we) begin
                bram[bram_addr] <= bram_wd;
            end else begin
                bram_rd <= bram[bram_addr];
            end
        end
    end
endmodule