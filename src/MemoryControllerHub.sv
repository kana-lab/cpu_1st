`timescale 1ps/1ps

// `include "Memory.sv"
`include "MemoryInterface.sv"

module MemoryControllerHub #(
    WORD_NUM = 512,
    CODE_SEGMENT = 0,
    INPUT_DATA_SEGMENT = 256,
    INPUT_DATA_SEGMENT_SIZE = 256
) (
    input wire clock,
    input wire reset,

    // DMAに使用する信号線
    input wire instr_ready,
    input wire mem_ready,
    input wire [31:0] data,
    // input wire program_loaded,

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
    InstructionMemory.slave m_instr,
    // input wire write_enable,
    // input wire [31:0] address,
    // input wire [31:0] write_data,
    // output wire [31:0] read_data,
    // input wire [31:0] instr_address,
    // output wire [31:0] instr,

    // UartTxとの接続を表す信号線
    // DmaControllerもUartTxを利用するが、利用時期が重ならないので安全
    output reg tx_start,
    output reg [7:0] sdata,
    input wire tx_busy,

    output wire [7:0] led
);

    // ブート時に受信したinstructionを格納していく際に用いるポインタ
    reg [31:0] instr_end;
    // ブート終了後、受信したデータをリングバッファに格納する際に用いるポインタ
    reg [31:0] mem_start;
    reg [31:0] mem_end;
    wire [31:0] mem_size = (INPUT_DATA_SEGMENT_SIZE + mem_end - mem_start) % INPUT_DATA_SEGMENT_SIZE;
    // 現在の指示がリングバッファからポップであるか否か
    wire is_pop_queue = m_data.addr[31] & m_data.addr[0] & ~m_data.we & m_data.en;

    always_ff @(posedge clock) begin
        if (reset) begin
            instr_end <= 0;
            mem_start <= 0;
            mem_end <= 0;
        end else begin
            if (instr_ready) instr_end++;

            if (mem_ready) begin
                mem_end <= (mem_end + 32'b1) % INPUT_DATA_SEGMENT_SIZE;
                if (mem_size == INPUT_DATA_SEGMENT_SIZE - 1)
                    mem_start <= (mem_start + 32'b1) % INPUT_DATA_SEGMENT_SIZE;
            end

            if (is_pop_queue)
                mem_start <= (mem_start + 32'b1) % INPUT_DATA_SEGMENT_SIZE;
        end
    end

    // ブート終了後、送信したいデータをリングバッファに格納する際に用いるポインタ
    // このリングバッファはLUT上に実装する
    // reg [7:0] sbuf_start;
    // assign led = sbuf_start;
    // reg [7:0] sbuf_end;
    // wire [7:0] sbuf_size = (SEND_BUF_SIZE + sbuf_end - sbuf_start) % SEND_BUF_SIZE;
    // wire [7:0] sbuf_rest_size = SEND_BUF_SIZE - 1 - sbuf_size;
    // reg [31:0] sbuf[SEND_BUF_SIZE - 1:0];
    // reg [3:0] send_status;
    // wire [3:0] next_send_status = {send_status[2:0],send_status[3]};

    // 現在の指示がリングバッファへのプッシュであるか否か
    // wire is_push_queue = address[31] & address[2] & write_enable;
    wire is_uart_send = m_data.addr[31] & m_data.addr[2] & m_data.we & m_data.en;

    wire not_tx_busy = ~tx_busy;
    wire [31:0] sendable_size = {31'b0, not_tx_busy};

    // あらかじめsbufを分割しておく
    // wire [7:0] sbuf_to_byte[3:0];
    // assign {sbuf_to_byte[3], sbuf_to_byte[2], sbuf_to_byte[1], sbuf_to_byte[0]} = sbuf[sbuf_start];

    always_ff @( posedge clock ) begin
        if (reset) begin
            // sbuf_start <= 0;
            // sbuf_end <= 0;
            // send_status <= 4'b1;
            
            tx_start <= 0;
            sdata <= 0;
        end else begin
            if (tx_start) tx_start <= 0;

            if (is_uart_send & ~tx_busy) begin
                sdata <= m_data.wd[7:0];
                tx_start <= 1'b1;
            end

            // if (sbuf_start != sbuf_end && ~tx_busy) begin
            //     tx_start <= 1'b1;
            //     send_status <= next_send_status;

            //     if (send_status[0]) sdata <= sbuf_to_byte[0];
            //     if (send_status[1]) sdata <= sbuf_to_byte[1];
            //     if (send_status[2]) sdata <= sbuf_to_byte[2];
            //     if (send_status[3]) begin
            //         sdata <= sbuf_to_byte[3];
            //         sbuf_start <= (sbuf_start + 8'b1) % SEND_BUF_SIZE;
            //     end
            // end

            // if (is_push_queue && sbuf_rest_size != 0) begin
            //     sbuf[sbuf_end] <= write_data;
            //     sbuf_end <= (sbuf_end + 8'b1) % SEND_BUF_SIZE;
            // end
        end
    end

    // メタステーブル状態だと危険かも？多分大丈夫だとは思うが。。。
    wire mem_write_enable = m_data.we & ~m_data.addr[31] & m_data.en;
    wire [31:0] mem_address = (m_data.addr[31]) ? mem_start + INPUT_DATA_SEGMENT : m_data.addr;
    wire [31:0] mem_write_data = m_data.wd;
    wire mem_dma_enable = instr_ready | mem_ready;
    wire [31:0] mem_dma_address = (instr_ready) ? instr_end + CODE_SEGMENT : mem_end + INPUT_DATA_SEGMENT;
    wire [31:0] mem_dma_data = data;

    wire [31:0] mem_read_data;
    Memory #(WORD_NUM) m(
        .clock, .write_enable(mem_write_enable), .address(mem_address), .write_data(mem_write_data),
        .read_data(mem_read_data), .dma_enable(mem_dma_enable),
        .dma_address(mem_dma_address), .dma_data(mem_dma_data), .instr_address(m_instr.addr), .instr(m_instr.instr)
    );

    wire [31:0] uart_recv = (m_data.addr[0]) ? mem_read_data : 0;
    wire [31:0] uart_recv_size = (m_data.addr[1]) ? mem_size : 0;
    wire [31:0] uart_sendable = (m_data.addr[3]) ? sendable_size : 0;
    wire [31:0] mmio_res = uart_recv | uart_recv_size | uart_sendable;
    assign m_data.rd = (m_data.addr[31]) ?  mmio_res : mem_read_data;
    assign m_data.stall = 0;
    assign m_instr.stall = 0;
endmodule
