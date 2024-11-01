`timescale 1ps/1ps

module UartTx #(CLK_PER_HALF_BIT = 5208) (
    input wire clock,
    input wire reset,
    input wire tx_start,
    input wire [7:0] sdata,
    output wire tx_busy,
    output reg txd
    );

    localparam CLK_PER_ONE_BIT = CLK_PER_HALF_BIT * 2;
    localparam CLK_TILL_STOP_BIT = CLK_PER_ONE_BIT * 9 / 10;

    // 送信状況を表すシフトレジスタ
    // 001: idle状態
    // 010: start bitを送った後、データを転送する直前の状態
    // 100: stop bitを送る直前の状態
    reg [2:0] state;
    wire [2:0] next_state = {state[1:0],state[2]};

    // データ転送のタイミングを判断するためのclockのカウンタ
    reg [31:0] counter;

    // 送信するデータのバッファと送信したbit数を表すシフトレジスタ
    reg [7:0] txbuf;
    wire [7:0] next_txbuf = {1'b1,txbuf[7:1]};
    reg [9:0] n_sent;
    wire [9:0] next_n_sent = {n_sent[8:0],n_sent[9]};

    reg tx_busy_1clock_behind;
    assign tx_busy = tx_busy_1clock_behind | tx_start;

    always_ff @(posedge clock) begin
        if (reset) begin
            tx_busy_1clock_behind <= 0;
            txd <= 1'b1;

            state <= 3'b1;
            n_sent <= 10'b1;
        end else begin
            if (state[0] & tx_start) begin
                counter <= 0;
                txbuf <= sdata;
                state <= next_state;
                tx_busy_1clock_behind <= 1'b1;
                txd <= 0;
            end

            if (state[1]) begin
                if (counter > CLK_PER_ONE_BIT - 1) begin
                    counter <= 0;
                    txd <= txbuf[0];
                    txbuf <= next_txbuf;
                    n_sent <= next_n_sent;
                end else begin
                    counter <= counter + 32'd1;
                end

                if (n_sent[9]) begin
                    n_sent <= next_n_sent;
                    state <= next_state;
                end
            end

            if (state[2]) begin
                if (counter > CLK_TILL_STOP_BIT - 1) begin
                    tx_busy_1clock_behind <= 0;
                    state <= next_state;
                end else begin
                    counter <= counter + 32'd1;
                end
            end
        end
    end
    
endmodule