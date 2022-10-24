`timescale 1ps/1ps

module Memory #(WORD_NUM = 2048) (
    input wire clock,

    input wire write_enable,
    input wire [31:0] address,
    input wire [31:0] write_data,
    output wire [31:0] read_data,
    input wire dma_enable,
    input wire [31:0] dma_address,
    input wire [31:0] dma_data,
    input wire [31:0] instr_address,
    output wire [31:0] instr
);
    localparam nop = 32'b00100001000000000000000000000000;

    reg [31:0] m[WORD_NUM-1:0];
    assign read_data = (address >= WORD_NUM) ? 0 : m[address];
    assign instr = (instr_address >= WORD_NUM) ? nop : m[instr_address];

    always_ff @(posedge clock) begin
        if (write_enable && address < WORD_NUM)
            m[address] <= write_data;
        if (dma_enable && dma_address < WORD_NUM)
            m[dma_address] <= dma_data;
    end

endmodule