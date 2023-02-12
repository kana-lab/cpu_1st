`timescale 1ns/1ps
// `include "UartTx.sv"
// `include "UartRx.sv"
// `include "top.v"

// コードサイズが分からないとダメ
// -> 定数にしてサボる
// SLDファイルをバイナリにしなければならない
// -> 予めバイナリにしておいてサボる

module Server # (
    CLOCK_PER_HALF_BIT = 10,
    INSTR_CODE_SIZE = 32'd21,
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
        $readmemh("D:/cpu_ex/cpu_1st/asm/fpu_cache_mixed.dat", instr_buf);
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

    always @(posedge rx_ready) begin
        $display("%h", rdata);
    end
endmodule

module DDR2(
    input wire clock,
    input wire reset,

    DataMemory.slave request
);
    reg [31:0] m[511:0];
    reg [7:0] stall_count;
    reg stall;
    reg [31:0] result;
    assign request.stall = stall;
    assign request.rd = result;

    always_ff @(posedge clock) begin
        if (reset) begin
            stall_count <= 0;
            stall <= 0;
            result <= 0;
        end else begin
            if (stall) begin
                if (stall_count == 8'd10) begin
                    stall_count <= 0;
                    stall <= 0;
                end else begin
                    stall_count++;
                end
            end else if (request.en) begin
                stall <= 1'b1;
                result <= m[request.addr];
                if (request.we)
                    m[request.addr] <= request.wd;
            end
        end
    end
endmodule

module BramSim(
    input wire clock,
    input wire reset,

    DataMemory.slave request
);
    reg [31:0] m[511:0];
    assign request.rd = m[request.addr];
    assign request.stall = 0;
    always_ff @( posedge clock ) begin
        if (request.en & request.we)
            m[request.addr] <= request.wd;
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
        #100;
        resetn <= 1;
        #1000000;
        $finish();
    end

    reg reset;  // for Server
    initial begin
        reset <= 1;
        #500;
        reset <= 0;
        #1000000;
        $finish();
    end

    wire rxd;
    wire txd;
    wire [15:0] led;

    Server server(.clock, .reset, .rxd(txd), .txd(rxd));

    // DataMemory bram_bus();
    // BramSim bram(.clock, .reset, .request(bram_bus.slave));
    // DataMemory ddr2_bus();
    // DDR2 ddr2(.clock, .reset, .request(ddr2_bus));
    
    // DDR2 wires
    wire [12:0] ddr2_addr;
    wire [2:0] ddr2_ba;
    wire ddr2_cas_n;
    wire [0:0] ddr2_ck_n;
    wire [0:0] ddr2_ck_p;
    wire [0:0] ddr2_cke;
    wire ddr2_ras_n;
    wire ddr2_we_n;
    wire [15:0] ddr2_dq;
    wire [1:0] ddr2_dqs_n;
    wire [1:0] ddr2_dqs_p;
    wire [0:0] ddr2_cs_n;
    wire [1:0] ddr2_dm;
    wire [0:0] ddr2_odt;

    // DDR2 model
    ddr2 ddr2 (
        .ck(ddr2_ck_p),
        .ck_n(ddr2_ck_n),
        .cke(ddr2_cke),
        .cs_n(ddr2_cs_n),
        .ras_n(ddr2_ras_n),
        .cas_n(ddr2_cas_n),
        .we_n(ddr2_we_n),
        .dm_rdqs(ddr2_dm),
        .ba(ddr2_ba),
        .addr(ddr2_addr),
        .dq(ddr2_dq),
        .dqs(ddr2_dqs_p),
        .dqs_n(ddr2_dqs_n),
        .rdqs_n(),
        .odt(ddr2_odt)
    );
    
    top t(.CLK100MHZ(clock), .CPU_RESETN(resetn), .UART_TXD_IN(rxd), .UART_RXD_OUT(txd), .LED(led),
    //bram_bus.en, bram_bus.we, bram_bus.addr, bram_bus.wd, bram_bus.rd,
    //ddr2_bus.stall, ddr2_bus.rd, ddr2_bus.en, ddr2_bus.we, ddr2_bus.addr, ddr2_bus.wd);
    .*);
endmodule