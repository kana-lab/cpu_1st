`timescale 1ps/1ps
// `include "MemoryInterface.sv"


// BRAM は直接 block ram generator を叩くつもりだったが、後に
// ram_style = "block"に任せることにしたためこのようなモジュールができた
module Bram # (
    BRAM_SIZE = 16'h5000
) (
    input wire clock,
    input wire reset,

    input wire bram_en,
    input wire bram_we,
    input wire [31:0] bram_addr,
    input wire [31:0] bram_wd,
    output reg [31:0] bram_rd,

    // 応急処置
    DataMemory.slave port2
);
    (* ram_style = "block" *) reg [31:0] bram[BRAM_SIZE - 1:0];

    // 応急処置、なんという非効率ｗ
    (* ram_style = "block" *) reg [31:0] bram_copy[BRAM_SIZE - 1:0];

    // 本当は連続読み出しが可能であるが、応急処置のため1clockおきにしか読み書きできない仕様
    reg [31:0] port2_result;
    reg port2_stall;  // 読み出し中の1clock以外は常に0である保証
    assign port2.rd = port2_result;
    assign port2.stall = port2_stall;

    always_ff @(posedge clock) begin
        if (reset) begin
            bram_rd <= 0;
            port2_result <= 0;
            port2_stall <= 0;
        end else begin
            if (port2_stall) port2_stall <= 0;

            if (bram_en) begin 
                if (bram_we) begin
                    bram[bram_addr] <= bram_wd;
                end else begin
                    bram_rd <= bram[bram_addr];
                end
            end

            // if (port2.en & ~port2_stall) begin
            //     port2_stall <= 1'b1;

            //     if (port2.we) begin
            //         bram[port2.addr] <= port2.wd;
            //     end else begin
            //         port2_result <= bram[port2.addr];
            //     end
            // end

            if (bram_en & bram_we) begin
                bram_copy[bram_addr] <= bram_wd;
            end else if (port2.en & ~port2_stall) begin
                port2_stall <= 1'b1;
                port2_result <= bram_copy[port2.addr];
            end
        end
    end
endmodule