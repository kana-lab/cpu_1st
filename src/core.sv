`timescale 1ps / 1ps

// `include "RegisterFile.sv"
// `include "InstructionMemory.sv"
// `include "DataMemory.sv"
// `include "ALU.sv"

module Core(
    input wire clock,
    input wire reset,

    // メモリとの通信用の信号線
    // メモリ以外のI/Oアクセスも全てこれを介して行う予定 (MMIO)
    output wire mem_write_enable,
    output wire [31:0] mem_address,
    output wire [31:0] mem_write_data,
    input wire [31:0] mem_read_data,
    output wire [31:0] mem_instr_address,
    input wire [31:0] mem_instr
    );

    // instruction memoryとの接続
    reg [31:0] pc;  // TODO: set input
    wire [31:0] instruction = mem_instr;
    assign mem_instr_address = pc;
    // InstructionMemory im(.address(pc), .instruction);

    // opの単離
    wire [2:0] op;
    wire [28:0] body;
    assign {op, body} = instruction;

    // 算術演算命令の解析
    wire [7:0] dest;
    wire [7:0] src1;
    wire [7:0] src2;
    wire [4:0] funct_arith;
    assign {funct_arith, dest, src1, src2} = body;

    // レジスタファイルの宣言
    wire [31:0] read1;
    wire [31:0] read2;
    wire [31:0] write_data;  // TODO: set input
    RegisterFile rf(
        .clock, .src1, .src2, .dest,
        .write_data, .write_enable(~op[2] | (&op)),
        .read1, .read2
    );

    // ALUへの入力の選択 (即値か否か、即値なら符号拡張)
    wire [31:0] val1;
    assign val1 = read1;
    wire [31:0] imm_ext;
    assign imm_ext = (src2[7]) ? {24'hffffff, src2} : {24'b0, src2};  // 符号拡張あってる？
    wire [31:0] val2;
    assign val2 = (op[0]) ? imm_ext : read2;

    // ALU/FPUの宣言
    wire [31:0] alu_result;
    ALU alu(.val1, .val2, .funct(funct_arith), .result(alu_result));
    wire [31:0] fpu_result;
    ALU fpu(.val1, .val2, .funct(funct_arith), .result(fpu_result));  // TODO: implement FPU

    // ブランチ
    wire [2:0] funct_ctrl;
    wire [9:0] offset;
    assign {funct_ctrl, offset} = instruction[28:16];
    wire [31:0] tmp_offset_ext;
    assign tmp_offset_ext = (offset[9]) ? {22'h3fffff, offset} : {22'b0, offset};  // 符号拡張あってる？

    wire [31:0] offset_beq;
    assign offset_beq = (funct_ctrl[0]) ? ((read1 == read2) ? tmp_offset_ext : 32'd1) : 0;
    wire [31:0] offset_blt;
    assign offset_blt = (funct_ctrl[1]) ? ((read1 < read2) ? tmp_offset_ext : 32'd1) : 0;
    wire [31:0] offset_ble;
    assign offset_ble = (funct_ctrl[2]) ? ((read1 <= read2) ? tmp_offset_ext : 32'd1) : 0;

    wire [31:0] offset_ext;
    assign offset_ext = offset_beq | offset_blt | offset_ble;

    // 無条件ジャンプ
    wire [25:0] long_offset;
    assign long_offset = body[25:0];
    wire [31:0] long_offset_ext;
    assign long_offset_ext = (long_offset[25]) ? {6'h3f, long_offset} : {6'b0, long_offset};
    wire [31:0] absolute_addr;
    assign absolute_addr = (funct_ctrl[0]) ? read2 : (pc + long_offset_ext);

    // pcの更新
    always_ff @( posedge clock ) begin
        if (reset) begin
            pc <= 0;
        end else begin
            if (op[2] && ~op[1]) begin
                if (op[0]) begin
                    pc <= absolute_addr;
                end else begin
                    pc <= pc + offset_ext;
                end
            end else begin
                pc <= pc + 32'd1;
            end
        end
    end

    // data memoryとの接続
    wire [31:0] load_result;
    assign mem_write_enable = op[2] & op[1] & ~op[0];
    assign mem_address = read2;
    assign mem_write_data = read1;
    assign load_result = mem_read_data;
    // DataMemory dm(
    //     .clock, .write_enable(op[2] & op[1] & ~op[0]),
    //     .address(read2), .write_data(read1), .read_data(load_result)
    // );

    // レジスタファイルに書き込むデータの選択
    assign write_data = (op[2]) ? load_result : ((op[1]) ? fpu_result : alu_result);
endmodule
