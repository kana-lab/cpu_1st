`timescale 1ps / 1ps

module RegisterFile(
    input wire clock,
    input wire [7:0] src1,
    input wire [7:0] src2,
    input wire [7:0] dest,
    input wire [31:0] write_data,
    input wire write_enable,
    // output reg [31:0] read1,
    // output reg [31:0] read2
    output wire [31:0] read1,
    output wire [31:0] read2
    );

    reg [31:0] regs[255:0];

    // always_ff @( posedge clock ) begin
    //     if (src1 != 8'd255) begin
    //         read1 <= regs[src1];
    //     end else begin  // zero registerの処理
    //         read1 <= 0;
    //     end

    //     if (src2 != 8'd255) begin
    //         read2 <= regs[src2];
    //     end else begin  // zero registerの処理
    //         read2 <= 0;
    //     end

    //     if (write_enable) begin
    //         regs[dest] <= write_data;
    //     end
    // end

    assign read1 = (src1 == 8'd255) ? 0 : regs[src1];
    assign read2 = (src2 == 8'd255) ? 0 : regs[src2];
    always_ff @( posedge clock ) begin
        if (write_enable) begin
            regs[dest] <= write_data;
        end
    end
endmodule
