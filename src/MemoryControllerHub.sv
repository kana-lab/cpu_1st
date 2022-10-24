`timescale 1ps/1ps

`include "Memory.sv"

module MemoryControllerHub #(
    WORD_NUM = 2048,
    CODE_SEGMENT = 0,
    INPUT_DATA_SEGMENT = 1024,
    INPUT_DATA_SEGMENT_SIZE = 512,
    OUTPUT_DATA_SEGMENT = 1536,
    OUTPUT_DATA_SEGMENT_SIZE = 512
) (
    input wire clock,
    input wire reset,

    // DMAに使用する信号線
    input wire instr_ready,
    input wire mem_ready,
    input wire [31:0] data,
    // input wire program_loaded,

    // Coreからのメモリ入出力要求を表す信号線
    // MMIOの仕様
    //   - 0xfffffff1: UARTで受信したデータがここに格納される
    //   - 0xfffffff2: UARTで受信したが読みだしていないデータの数
    //   - 0xfffffff4: UARTで送信したいデータをここに書き込む
    //   - 0xfffffff8: UARTで現在送信可能なデータの数
    // メモリ空間は0x7fffffffまでしか使えない仕様にする
    // それ以降はMMIOの空間とする (MMIOの判定を最上位ビットで行うという事情がある)
    input wire write_enable,
    input wire [31:0] address,
    input wire [31:0] write_data,
    output wire [31:0] read_data,
    input wire [31:0] instr_addr,
    output wire [31:0] instr,

    // UartTxとの接続を表す信号線
    // DmaControllerもUartTxを利用するが、利用時期が重ならないので安全
    output wire tx_start,
    output wire [7:0] sdata,
    input wire tx_busy
);

    // ブート時に受信したinstructionを格納していく際に用いるポインタ
    reg [31:0] instr_start;
    // ブート終了後、受信したデータをリングバッファに格納する際に用いるポインタ
    reg [31:0] mem_start;
    reg [31:0] mem_end;
    wire [31:0] mem_size = (INPUT_DATA_SEGMENT_SIZE + mem_end - mem_start) % INPUT_DATA_SEGMENT_SIZE;
    // 現在の指示がリングバッファからポップであるか否か
    wire is_pop_queue = address[31] & address[0] & ~write_enable;

    always_ff @(posedge clock) begin
        if (reset) begin
            instr_start <= 0;
            mem_start <= 0;
            mem_end <= 0;
        end else begin
            if (instr_ready) instr_start++;

            if (mem_ready) begin
                mem_end <= (mem_end + 32'b1) % INPUT_DATA_SEGMENT_SIZE;
                if (mem_size == INPUT_DATA_SEGMENT_SIZE - 1 || is_pop_queue) begin
                    mem_start <= (mem_start + 32'b1) % INPUT_DATA_SEGMENT_SIZE;
                end
            end
        end
    end

    // メタステーブル状態だと危険かも？多分大丈夫だとは思うが。。。
    wire mem_write_enable = write_enable & ~address[31];
    wire [31:0] mem_address = address;
    wire [31:0] mem_write_data = write_data;
    wire mem_dma_enable = instr_ready | mem_ready;
    wire [31:0] mem_dma_address = (instr_ready) ? instr_start + CODE_SEGMENT
                                                : mem_start + INPUT_DATA_SEGMENT;
    wire [31:0] mem_dma_data = data;

    wire [31:0] mem_read_data;
    Memory #(WORD_NUM) m(
        .clock, .write_enable(we), .address(mem_address), .write_data(mem_write_data),
        .read_data(mem_read_data), .dma_enable(mem_dma_enable),
        .dma_address(mem_dma_address), .dma_data(mem_dma_data), .instr_address, .instr
    );

    
endmodule