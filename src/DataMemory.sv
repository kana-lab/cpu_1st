`timescale 1ps / 1ps

module DataMemory
    #(
        WORD_NUM = 1024
    )
    (
    input wire clock,
    input wire write_enable,
    input wire [31:0] address,
    input wire [31:0] write_data,
    // output logic [31:0] read_data
    output wire [31:0] read_data
    );
    logic [31:0] m[WORD_NUM - 1:0];  // 4KiB

    // initial begin
    //     for(int i = 0; i < WORD_NUM; ++i) begin
    //         m[i] = 0;
    //     end
    // end

    always_ff @( posedge clock ) begin
        if (write_enable) begin
            m[address] <= write_data;
        end

        // if (address >= WORD_NUM) begin
        //     read_data <= 0;
        // end else begin
        //     read_data <= m[address];
        // end
    end

    assign read_data = (address >= WORD_NUM) ? 0 : m[address];
endmodule
