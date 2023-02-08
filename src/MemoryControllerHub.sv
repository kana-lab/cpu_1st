`timescale 1ps/1ps

// `include "Memory.sv"
`include "MemoryInterface.sv"

// module Mediator (
//     input wire clock,
//     input wire reset,

//     input wire data_ready,
//     input wire [31:0] data,

//     DataMemory.slave request,
//     DataMemory.master ddr2
// );
// endmodule

// module MemoryControllerHub # (
//     UART_SEG_BEGIN = 256,
//     UART_SEG_END = 511
// ) (
//     input wire clock,
//     input wire reset,

//     // DMAに使用する信号線
//     input wire dma_ready,
//     input wire [31:0] dma_data,

//     // Coreからのメモリ入出力要求を表す信号線
//     DataMemory.slave request,

//     // DDR2メモリにアクセスするためのバス
//     DataMemory.master ddr2,

//     // UartTxとの接続を表す信号線
//     output reg tx_start,
//     output reg [7:0] sdata,
//     input wire tx_busy
// );
//     localparam UART_SEG_SIZE = UART_SEG_END - UART_SEG_BEGIN + 1;

//     reg [31:0] uart_buf[7:0];
//     reg [2:0] uart_buf_begin;
//     reg [2:0] uart_buf_end;
//     wire [2:0] uart_buf_size = (8 + uart_buf_end - uart_buf_begin) % 8;
//     wire pop_pending;
//     always_ff @( posedge clock ) begin
//         if (reset) begin
//             uart_buf_begin <= 0;
//             uart_buf_end <= 0;
//         end else begin
//             if (dma_ready) begin
//                 uart_buf[uart_buf_end] <= dma_data;
//                 uart_buf_end <= (uart_buf_end + 1) % 8;

//                 if (uart_buf_size == 3'd7)
//                     uart_buf_begin <= (uart_buf_begin + 1) % 8;
//             end

//             if (pop_pending)
//                 uart_buf_begin <= (uart_buf_begin + 1) % 8;
//         end
//     end

//     wire send_uart = request.en & request.we & request.addr[31] & request.addr[2];
//     always_ff @( posedge clock ) begin
//         if (reset) begin
//             tx_start <= 0;
//             sdata <= 0;
//         end else begin
//             if (tx_start) tx_start <= 0;

//             if (send_uart & ~tx_busy) begin
//                 tx_start <= 1'b1;
//                 sdata <= request.wd[7:0];
//             end
//         end
//     end
    
//     reg [31:0] uart_data_begin;
//     reg [31:0] uart_data_end;
//     wire [31:0] uart_data_size = (UART_SEG_SIZE + uart_data_end - uart_data_begin) % UART_SEG_SIZE;

//     wire [31:0] uart_sendable_size = {31'b0, ~tx_busy};

// endmodule

module MemoryControllerHub (
    input wire clock,
    input wire reset,

    // DMAに使用する信号線
    input wire data_ready,
    input wire [31:0] data,

    // Coreからのメモリ入出力要求を表す信号線
    // [MMIOの仕様]
    //   - 0xfffffff1(-15): UARTで受信したデータがここに格納される
    //   - 0xfffffff2(-14): UARTで受信したが読みだしていないデータの数
    //   - 0xfffffff4(-12): UARTで送信したいデータをここに書き込む
    //   - 0xfffffff8 (-8): UARTで現在送信可能なデータの数
    // メモリ空間は0x7fffffffまでしか使えない仕様にする
    // それ以降はMMIOの空間とする (MMIOの判定を最上位ビットで行うという事情がある)
    // [MMIOのアセンブリ例]
    //     subi r0, zero, 15
    //     lw r0, r0
    DataMemory.slave m_data,

    // UartTxとの接続を表す信号線
    // DmaControllerもUartTxを利用するが、利用時期が重ならないので安全
    output reg tx_start,
    output reg [7:0] sdata,
    input wire tx_busy,

    // DDR2メモリにアクセスするためのバス
    DataMemory.master ddr2

    // output wire [7:0] led
);
    // SUPER TENUKI
    reg [31:0] received_data[511:0];

    // ブート終了後、受信したデータをリングバッファに格納する際に用いるポインタ
    reg [9:0] mem_start;
    reg [9:0] mem_end;
    wire [9:0] mem_size = (10'd512 + mem_end - mem_start) % 10'd512;
    // 現在の指示がリングバッファからポップであるか否か
    wire is_pop_queue = m_data.addr[31] & m_data.addr[0] & ~m_data.we & m_data.en;

    always_ff @(posedge clock) begin
        if (reset) begin
            mem_start <= 0;
            mem_end <= 0;
        end else begin
            if (data_ready) begin
                mem_end <= (mem_end + 10'b1) % 10'd512;
                received_data[mem_end] <= data;
                if (mem_size == 10'd512 - 1)
                    mem_start <= (mem_start + 10'b1) % 10'd512;
            end

            if (is_pop_queue)
                mem_start <= (mem_start + 10'b1) % 10'd512;
        end
    end

    // 現在の指示がUARTでの送信であるか否か
    wire is_uart_send = m_data.addr[31] & m_data.addr[2] & m_data.we & m_data.en;

    wire not_tx_busy = ~tx_busy;
    wire [31:0] sendable_size = {31'b0, not_tx_busy};

    always_ff @( posedge clock ) begin
        if (reset) begin
            tx_start <= 0;
            sdata <= 0;
        end else begin
            if (tx_start) tx_start <= 0;

            if (is_uart_send & ~tx_busy) begin
                sdata <= m_data.wd[7:0];
                tx_start <= 1'b1;
            end
        end
    end

    // メタステーブル状態だと危険かも？多分大丈夫だとは思うが。。。
    // DataMemory m_filtered();
    // assign m_filtered.en = m_data.en & (~m_data.addr[31] | is_pop_queue);
    // assign m_filtered.we = m_data.we & ~m_data.addr[31] & m_data.en;
    // assign m_filtered.addr = (m_data.addr[31]) ? mem_start + INPUT_DATA_SEGMENT : m_data.addr;
    // assign m_filtered.wd = m_data.wd;
    // wire [31:0] uart_recv = (m_data.addr[0]) ? m_filtered.rd : 0;
    // wire [31:0] uart_recv_size = (m_data.addr[1]) ? mem_size : 0;
    // wire [31:0] uart_sendable = (m_data.addr[3]) ? sendable_size : 0;
    // wire [31:0] mmio_res = uart_recv | uart_recv_size | uart_sendable;
    // assign m_data.rd = (m_data.addr[31]) ?  mmio_res : m_filtered.rd;
    // assign m_data.stall = m_filtered.stall;

    // reg waiting, en_saved, we_saved;
    // reg [31:0] addr_saved;
    // reg [31:0] wd_saved;
    // DataMemory m_actual();
    // assign m_actual.en = m_filtered.en | data_ready;
    // assign m_actual.we = m_filtered.we | data_ready;
    // assign m_actual.addr = (data_ready) ? mem_end + INPUT_DATA_SEGMENT : m_filtered.addr;
    // assign m_actual.wd = (data_ready) ? data : m_filtered.wd;

    // always @(posedge clock) begin
    //     if (reset) begin
    //         waiting <= 0;
    //     end else begin
    //         if (m_filtered.en & data_ready)
    //     end
    // end

    assign ddr2.en = m_data.en & ~m_data.addr[31];
    assign ddr2.we = m_data.we;
    assign ddr2.wd = m_data.wd;
    assign ddr2.addr = m_data.addr;
    assign m_data.stall = ddr2.stall;
    reg stall_1clock_behind;
    always_ff @( posedge clock )
        stall_1clock_behind <= ddr2.stall;
    
    // wire mem_write_enable = m_data.we & ~m_data.addr[31] & m_data.en;
    // wire [31:0] mem_address = (m_data.addr[31]) ? mem_start + INPUT_DATA_SEGMENT : m_data.addr;
    // wire [31:0] mem_write_data = m_data.wd;
    // wire mem_dma_enable = instr_ready | mem_ready;
    // wire [31:0] mem_dma_address = (instr_ready) ? instr_end + CODE_SEGMENT : mem_end + INPUT_DATA_SEGMENT;
    // wire [31:0] mem_dma_data = data;

    // wire [31:0] mem_read_data;
    // Memory #(WORD_NUM) m(
    //     .clock, .write_enable(mem_write_enable), .address(mem_address), .write_data(mem_write_data),
    //     .read_data(mem_read_data), .dma_enable(mem_dma_enable),
    //     .dma_address(mem_dma_address), .dma_data(mem_dma_data), .instr_address(m_instr.addr), .instr(m_instr.instr)
    // );

    wire [31:0] uart_recv = (m_data.addr[0]) ? received_data[mem_start] : 0;
    wire [31:0] uart_recv_size = (m_data.addr[1]) ? mem_size : 0;
    wire [31:0] uart_sendable = (m_data.addr[3]) ? sendable_size : 0;
    wire [31:0] mmio_res = uart_recv | uart_recv_size | uart_sendable;
    assign m_data.rd = (~stall_1clock_behind & m_data.addr[31]) ?  mmio_res : ddr2.rd;
    // assign m_data.stall = 0;
    // assign m_instr.stall = 0;
endmodule
