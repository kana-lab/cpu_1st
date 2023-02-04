`timescale 1ps/1ps
// `include "UartTx.sv"
// `include "UartRx.sv"
// `include "top.v"

// コードサイズが分からないとダメ
// -> 定数にしてサボる
// SLDファイルをバイナリにしなければならない
// -> 予めバイナリにしておいてサボる

module Server # (
    CLOCK_PER_HALF_BIT = 10,
    INSTR_CODE_SIZE = 32'd15,
    DATA_CODE_SIZE = 3
) (
    input wire clock,
    input wire reset,
    input wire rxd,
    output wire txd
);
    reg [31:0] instr_buf[INSTR_CODE_SIZE - 1:0];
    reg [31:0] data_buf[DATA_CODE_SIZE - 1:0];

    initial begin
        $readmemh("D:/cpu_ex/cpu_1st/asm/laytrace.dat", instr_buf);
        $readmemh("D:/cpu_ex/cpu_1st/asm/lsd.dat", data_buf);
    end

    reg tx_start;
    reg [7:0] sdata;
    wire tx_busy;
    UartTx #(CLOCK_PER_HALF_BIT) uart_tx(
        .clock, .reset, .tx_start, .sdata, .tx_busy, .txd
    );

    wire rx_ready;
    wire [7:0] rdata;
    wire ferr;
    UartRx #(CLOCK_PER_HALF_BIT) uart_rx(
        .clock, .reset, .rxd_orig(rxd), .rx_ready, .rdata, .ferr
    );

    // 00001: 0x99を待っている状態
    // 00010: プログラムサイズを送っている状態
    // 00100: プログラムを送っている状態
    // 01000: 0xaaを待っている状態
    // 10000: データを送りつつ結果を受け取っている状態
    // 00000: 全て完了した状態
    reg [4:0] state;
    wire [4:0] next_state = {state[3:0], state[4]};
    reg [3:0] n_byte;
    wire [4:0] next_n_byte = {n_byte[2:0], n_byte[3]};
    reg [31:0] counter;
    reg [31:0] prog_size;


    always_ff @(posedge clock) begin
        if (reset) begin
            tx_start <= 0;
            sdata <= 0;

            state <= 5'b1;
            n_byte <= 4'b1;
            counter <= 0;
            prog_size <= INSTR_CODE_SIZE * 4;
        end else begin
            if (tx_start) tx_start <= 0;

            if (state[0] & rx_ready)
                state <= next_state;

            if (state[1] & ~tx_busy) begin
                tx_start <= 1'b1;
                sdata <= prog_size[7:0];

                prog_size <= prog_size >> 32'd8;
                n_byte <= next_n_byte;

                if (n_byte[3]) begin
                    state <= next_state;
                    counter <= 0;
                end
            end

            if (state[2] & ~tx_busy) begin
                tx_start <= 1'b1;
                sdata <= instr_buf[counter][7:0];

                instr_buf[counter] <= instr_buf[counter] >> 32'd8;
                n_byte <= next_n_byte;
                if (n_byte[3]) counter++;

                if (counter == INSTR_CODE_SIZE && n_byte[3])
                    state <= next_state;
            end

            if (state[3] & rx_ready) begin
                state <= next_state;
                counter <= 0;
            end

            if (state[4] & ~tx_busy) begin
                tx_start <= 1'b1;
                sdata <= data_buf[counter][7:0];

                data_buf[counter] <= data_buf[counter] >> 32'h8;
                n_byte <= next_n_byte;
                if (n_byte[3]) counter++;
                
                if (counter == DATA_CODE_SIZE && n_byte[3])
                    state <= 0;
            end
        end
    end

    always @(state) begin
        $display("state changed: %h", state);
    end

    always @(rx_ready) begin
        $display("%h", rdata);
    end
endmodule

module pipeline_sim;
    reg clock;
    always begin
        clock <= 0;
        #5;
        clock <= 1;
        #5;
    end

    reg resetn;  // for top
    initial begin
        resetn <= 0;
        #200;
        resetn <= 1;
        #1000000;
        $finish();
    end

    reg reset;  // for Server
    initial begin
        reset <= 1;
        #100;
        reset <= 0;
        #1000000;
        $finish();
    end

    wire rxd;
    wire txd;
    wire [15:0] led;

    Server server(.clock, .reset, .rxd(txd), .txd(rxd));

    top t(clock, resetn, rxd, txd, led);
endmodule