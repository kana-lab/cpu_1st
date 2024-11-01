`timescale 1ps/1ps

// UARTのレシーバやセンダーはDmaControllerの外部に置くことにする
module DmaController # (
    INTERVAL_0x99 = 100
) (
    input wire clock,
    input wire reset,

    // UARTのレシーバからの信号
    input wire rx_ready,
    input wire [7:0] rdata,

    // UARTのセンダーからの/への信号
    input wire tx_busy,
    output reg tx_start,
    output reg [7:0] sdata,

    output reg instr_ready,
    output reg mem_ready,
    output reg [31:0] data,
    output wire program_loaded,

    output wire [15:0] led
    );

    // server/readme.pdfの仕様に従って実装する

    // 0001: 初期状態
    // 0010: 0x99を送った後、プログラムサイズを取得しようとしている状態
    // 0100: プログラムを取得しようとしている状態
    // 1000: プログラムを取得して0xaaを送った後、データを取得している状態
    reg [3:0] state;
    wire [3:0] next_state = {state[2:0], 1'b0};
    assign program_loaded = state[3];

    // 0001: int型の値の1byte目を取得しようとしている状態
    // ...
    // 1000: int型の値の4byte目を取得しようとしている状態
    reg [3:0] n_byte;
    wire [3:0] next_n_byte = {n_byte[2:0],n_byte[3]};

    wire [31:0] next_data = {rdata,data[31:8]};

    // プログラムサイズ(little endian)
    reg [31:0] program_size;
    reg [31:0] program_received;

    // 0x99を送り続ける間隔
    reg [7:0] counter;
    wire [1:0] state_short = (state[0])?2'b0:(state[1]?2'b1:(state[2]?2'd2:2'd3));
    assign led = {state_short,program_received[13:0]};

    always_ff @(posedge clock) begin
        if (reset) begin
            state <= 4'b1;
            n_byte <= 4'b1;
            program_size <= 0;
            program_received <= 0;
            // program_size_debug <= 0;
            counter <= 0;

            tx_start <= 0;
            instr_ready <= 0;
            mem_ready <= 0;
        end else begin
            if (tx_start) tx_start <= 0;
            if (instr_ready) instr_ready <= 0;
            if (mem_ready) mem_ready <= 0;

            // 最初に0x99を繰り返し送り、PC側が反応を示すのを待つ
            // ...と思ったが、PCとのstart bitの認識の齟齬が起きたら死ぬのでやめる
            // [追記] これを防ぐため間隔を開けて0x99を送り続けることにした
            if (state[0]) begin
                if (counter >= INTERVAL_0x99 && ~tx_busy) begin
                    tx_start <= 1'b1;
                    sdata <= 8'h99;
                    counter <= 0;
                end else begin
                    counter <= counter + 8'd1;
                end
                // state <= next_state;
                if (rx_ready)
                    state <= next_state;
            end

            // if (state[2] == 1'b1 && program_size == program_received) begin
            //     if (counter >= INTERVAL_0x99 && ~tx_busy) begin
            //         tx_start <= 1'b1;
            //         sdata <= 8'haa;
            //         counter <= 0;
            //     end else begin
            //         counter <= counter + 8'd1;
            //     end

            //     if (rx_ready)  // これが無いと信号を送るタイミングが早すぎて伝わらなかったりする
            //         state <= next_state;
            // end
            if (state[2] == 1'b1 && program_size == program_received) begin
                if (~tx_busy) begin
                    tx_start <= 1'b1;
                    sdata <= 8'haa;
                    state <= next_state;
                end
            end
            
            // 仕様を満たさない余分な受信データがあった場合正常に動作しない
            // また、プログラムおよびデータは4の倍数byteでないと正確に受信されない
            if (rx_ready) begin
                data <= next_data;
                n_byte <= next_n_byte;

                if (state[1] & n_byte[3]) begin
                    program_size <= next_data;
                    // program_size_debug <= next_data;
                    state <= next_state;
                end

                if (state[2]) begin
                    program_received <= program_received + 32'd1;
                    if (n_byte[3]) instr_ready <= 1'b1;
                end

                if (state[3] & n_byte[3]) begin
                    mem_ready <= 1'b1;
                end
            end
        end
    end
endmodule