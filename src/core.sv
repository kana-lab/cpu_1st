`timescale 1ps / 1ps


interface DataMemory;
    wire en;
    wire stall;
    wire we;
    wire [31:0] addr;
    wire [31:0] wd;
    wire [31:0] rd;

    modport master (
        input stall, rd,
        output en, we, addr, wd
    );

    modport slave (
        input en, we, addr, wd,
        output stall, rd
    );
endinterface //DataMemory


interface InstructionMemory;
    wire stall;
    wire [31:0] addr;
    wire [31:0] instr;

    modport master (
        input stall, instr,
        output addr
    );

    modport slave (
        input addr,
        output stall, instr
    );
endinterface //InstructionMemory


module IFStage(
    input wire clock,
    input wire reset,

    InstructionMemory.master m_instr,  // IMは0クロックで中身の取得ができると仮定

    output wire instr_stall,
    input wire data_stall,  // stallが発生したときは必ずbranch_taken = false
    input wire branch_taken,
    input wire [31:0] new_pc,

    output reg [31:0] instruction,
    output reg [31:0] prog_counter
);
    localparam NOP = 32'h21000000;  // addi r0, r0, 0

    reg [31:0] pc;
    assign m_instr.addr = pc;

    assign instr_stall = m_instr.stall;
    wire stall = m_instr.stall | data_stall;
    wire next_pc = (branch_taken) ? new_pc : ((stall) ? pc : pc + 1);

    always_ff @( posedge clock ) begin
        if (reset) begin
            pc <= 0;
            instruction <= NOP;
            prog_counter <= 0;
        end else begin
            pc <= next_pc;
            isntruction <= (branch_taken) ? NOP : m_instr.instr;
            prog_counter <= pc;
        end
    end
endmodule


module IDStage(
    input wire clock,
    input wire reset,

    input wire [31:0] instruction,
    input wire [31:0] pc_in,

    input wire stall,
    input wire flash,
    input wire wb_enable,
    input wire [7:0] wb_dest,
    input wire [31:0] wb_data,
    
    output reg [7:0] src1,
    output reg [7:0] src2_or_imm8,
    output reg [31:0] read1,
    output reg [31:0] read2,
    output reg [7:0] dest,
    output reg [31:0] pc_out,
    output reg [31:0] imm_ext10,
    output reg [31:0] imm_ext26,
    output reg [2:0] op,
    output reg [4:0] funct5  // funct3はEXMEMステージでここから取り出すこと
);
    // opの単離
    wire [2:0] op_w;
    wire [28:0] body;
    assign {op_w, body} = instruction;

    // 算術演算命令の解析
    wire [7:0] dest_w;
    wire [7:0] src1_w;
    wire [7:0] src2_w;
    wire [4:0] funct_arith;
    assign {funct_arith, dest_w, src1_w, src2_w} = body;

    // レジスタファイルの宣言
    wire [31:0] read1_w;
    wire [31:0] read2_w;
    RegisterFile rf(
        .clock, .src1(src1_w), .src2(src2_w), .dest(wb_dest),
        .write_data(wb_data), .write_enable(wb_enable),
        .read1(read1_w), .read2(read2_w)
    );

    // ブランチ
    wire [9:0] offset = body[25:16];

    // 無条件ジャンプ
    wire [25:0] long_offset = body[25:0];

    always_ff @( posedge clock ) begin
        if (~stall | reset | flash) begin
            src1 <= src1_w;
            read1 <= (wb_enable == 1'b1 && src1_w == wb_dest) ? wb_data : read1_w;
            read2 <= (wb_enable == 1'b1 && src2_w == wb_dest) ? wb_data : read2_w;
            pc_out <= pc_in;
            imm_ext10 <= (offset[9]) ? {22'h3fffff, offset} : {22'b0, offset};
            imm_ext26 <= (long_offset[25]) ? {6'h3f, long_offset} : {6'b0, long_offset};

            // 優先度はstallよりflashの方が高い
            if (reset | flash) begin
                // NOPの扱いについて:
                //     addi r0, r0, 0は今回は使えない
                //     r0を読み出しに行くとクリティカルパスが長くなる可能性があるため
                //     1つの案としてはゼロレジスタに何かを書き込むことでNOPとすること
                //     ただし書き込む値が0でないと未定義動作
                //     一番無難なのはaddi, sec1, src1, 0とすることだと思われる
                //     src1がゼロレジスタの場合ゼロレジスタへの書き込みが発生するが、
                //     書き込まれる値は0なので無問題
                src2_or_imm8 <= 0;
                dest <= src1_w;
                op <= 3'b1;  // imm命令
                funct5 <= 5'b1;  // addi
            end else begin
                src2_or_imm8 <= src2_w;
                dest <= dest_w;
                op <= op_w;
                funct5 <= funct_arith;
            end
        end
    end
endmodule


// en = 0 の場合のnew_pcの値は不定
module BranchUnit(
    input wire en,
    input wire no_cond,
    input wire [2:0] funct3,
    input wire [2:0] val1,
    input wire [31:0] val2,
    input wire [31:0] imm_ext10,
    input wire [31:0] imm_ext26,
    input wire [31:0] pc,

    output wire branch_taken,
    output wire [31:0] new_pc
);
    wire beq_stsfy = (funct[0]) ? ((val1 == val2) ? 1 : 0) : 0;
    wire blt_stsfy = (funct[1]) ? ((val1 < val2) ? 1 : 0) : 0;
    wire ble_stsfy = (funct[2]) ? ((val1 <= val2) ? 1 : 0) : 0;
    wire stsfy = beq_stsfy | blt_stsfy | ble_stsfy;
    assign branch_taken = (stsfy | no_cond) & en;
    assign new_pc = (no_cond) 
                    ? (funct3[0] ? val2 : (pc + imm_ext26))
                    : (stsfy ? (pc + imm_ext10) : 0);
endmodule


module EX_MEMStage(
    input wire clock,
    input wire reset,
    
    input wire [7:0] src1,
    input wire [7:0] src2_or_imm8,
    input wire [31:0] read1,
    input wire [31:0] read2,
    input wire [7:0] dest,
    input wire [31:0] pc,
    input wire [31:0] imm_ext10,
    input wire [31:0] imm_ext26,
    input wire [2:0] op,
    input wire [4:0] funct5,  // funct3はここから取り出すこと
    
    input wire wb_enable_in,
    input wire [7:0] wb_dest_in,
    input wire [31:0] wb_data_in,
    
    DataMemory.master m_data,  // DMは0クロックで中身の取得が出来ると仮定
    
    input wire instr_stall,
    output wire data_stall,
    output wire branch_taken,
    output wire [31:0] new_pc,
    
    output reg wb_enable,
    output reg [7:0] wb_dest,
    output reg [31:0] wb_data
);
    // フォールスルー
    wire [31:0] data1 = (wb_enable_in == 1'b1 && src1 == wb_dest_in) ? wb_data_in : read1;
    wire [31:0] data2 = (wb_enable_in == 1'b1 && src2_or_imm8 == wb_dest_in) ? wb_data_in : read2;
    
    // ALUの宣言
    wire [31:0] alu_result;
    wire [31:0] alu_data2 = (op[0]) ? {24'b0, src2_or_imm8} : data2;
    ALU alu(.is_imm(op[0]), .val1(data1), .val2(alu_data2), .funct(funct5), .result(alu_result));
    
    // FPUの宣言
    wire [31:0] fpu_result;
    wire fpu_stall;
    FPU fpu(
        .val1(data1), .val2(data2), .funct(funct5), .enable(~op[2] & op[1]),
        .stall(fpu_stall), .result(fpu_result)
    );
    
    // データメモリとの接続
    assign m_data.en = op[2] & op[1];
    assign m_data.we = ~op[0];
    assign m_data.addr = data2;
    assign m_data.wd = data1;

    // ブランチユニットの宣言
    BranchUnit bu(
        .en(op[2] & ~op[1]), .no_cond(op[0]), .funct3(funct5[4:2]),
        .val1(data1), .val2(data2), .imm_ext10, .imm_ext26, .pc,
        .branch_taken, .new_pc
    );
    
    // WBする結果の選択
    wire [31:0] ex_result = (op[2]) ? m_data.rd : ((op[1]) ? fpu_result : alu_result);
    // stallするか否か
    assign data_stall = fpu_stall | m_data.stall;
    // WBするか否か
    wire wb_enable_w = ((~op[2]) | (op[1] & op[0])) & (~data_stall);
    
    always_ff @( posedge clock ) begin
        wb_dest <= dest;
        wb_data <= ex_result;
        wb_enable <= wb_enable_w;
    end
endmodule
