`timescale 1ps / 1ps
`include "MemoryInterface.sv"


module IFStage(
    input wire clock,
    input wire reset,

    InstructionMemory.master m_instr,  // IMは0クロックで中身の取得ができると仮定

    output wire instr_stall,
    input wire data_stall,  // stallが発生したときは必ずbranch_taken = false
    input wire branch_taken,
    input wire [31:0] new_pc,

    output wire [31:0] instruction,
    output reg [31:0] prev_pc
);
    localparam NOP = 32'h21000000;  // addi r0, r0, 0

    reg reset_1clock_behind;
    reg flash_1clock_behind;
    reg [31:0] new_pc_1clock_behind;
    assign instruction = (reset_1clock_behind) ? NOP : ((flash_1clock_behind) ? NOP : m_instr.instr);
    assign instr_stall = m_instr.stall;
    wire stall = m_instr.stall | data_stall;

    reg [31:0] pc;
    wire [31:0] true_pc = (stall) ? prev_pc : ((flash_1clock_behind) ? new_pc_1clock_behind : pc);
    assign m_instr.addr = true_pc;


    wire [31:0] next_pc = true_pc + 1;//(branch_taken) ? new_pc + 1 : pc + 1;

    always_ff @( posedge clock ) begin
        reset_1clock_behind <= reset;
        flash_1clock_behind <= branch_taken;
        new_pc_1clock_behind <= new_pc;
        prev_pc <= true_pc;

        if (reset) begin
            pc <= 0;
            // prev_pc <= 0;
            // instruction <= NOP;
        end else if (~stall) begin
            pc <= next_pc;
            // instruction <= (branch_taken) ? NOP : m_instr.instr;
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

    // レジスタファイルの宣言、フォールスルーはこの中で行う
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
        // src1 <= src1_w;
        // read1 <= read1_w;
        // read2 <= read2_w;
        // pc_out <= pc_in;
        // imm_ext10 <= (offset[9]) ? {22'h3fffff, offset} : {22'b0, offset};
        // imm_ext26 <= (long_offset[25]) ? {6'h3f, long_offset} : {6'b0, long_offset};

        if (~stall) begin
            src1 <= src1_w;
            src2_or_imm8 <= src2_w;
            dest <= dest_w;
            // read1 <= (wb_enable == 1'b1 && src1_w == wb_dest) ? wb_data : read1_w;
            // read2 <= (wb_enable == 1'b1 && src2_w == wb_dest) ? wb_data : read2_w;
            // read1 <= read1_w;
            // read2 <= read2_w;
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
                // [追記]
                //     パイプラインではプログラムの末尾で2命令分オーバーフローして
                //     読むので、src1_wに依存すると未定義動作となる…
                //     blt zero, zero, 0などが安牌か
                // src2_or_imm8 <= 0;
                // dest <= src1_w;
                read1 <= 0;
                read2 <= 0;
                // op <= 3'b1;  // imm命令
                // funct5 <= 5'b1;  // addi
                op <= 3'b100;  // b命令
                funct5 <= 5'b01000;  // blt
            end else begin
                // src2_or_imm8 <= src2_w;
                // dest <= dest_w;
                read1 <= read1_w;
                read2 <= read2_w;
                op <= op_w;
                funct5 <= funct_arith;
            end
        end else begin
            
        end
    end
endmodule


// en = 0 の場合のnew_pcの値は不定
module BranchUnit(
    input wire en,
    input wire no_cond,
    input wire [2:0] funct3,
    input wire [31:0] val1,
    input wire [31:0] val2,
    input wire [31:0] imm_ext10,
    input wire [31:0] imm_ext26,
    input wire [31:0] pc,

    output wire branch_taken,
    output wire [31:0] new_pc
);
    wire beq_stsfy = (funct3[0]) ? ((val1 == val2) ? 1'b1 : 0) : 0;
    wire blt_stsfy = (funct3[1]) ? (($signed(val1) < $signed(val2)) ? 1'b1 : 0) : 0;
    wire ble_stsfy = (funct3[2]) ? (($signed(val1) <= $signed(val2)) ? 1'b1 : 0) : 0;
    wire stsfy = beq_stsfy | blt_stsfy | ble_stsfy;
    assign branch_taken = (stsfy | no_cond) & en;
    assign new_pc = (no_cond) 
                    ? (funct3[0] ? val2 : (pc + imm_ext26))
                    : (stsfy ? (pc + imm_ext10) : 0);
endmodule


// wrapper for actual fpu
module FPU (
    input wire clock,

    input wire [31:0] val1,
    input wire [31:0] val2,
    input wire [4:0] funct,
    input wire enable,
    output wire stall,
    output wire [31:0] result,
    output wire [31:0] result_comb
);
    assign stall = 0;
    assign result = 32'hffffffff;
    assign result_comb = 32'haaaaaaaa;

    // wire valid, idle;
    // fpu fpu_i(
    //     .clk(clock), .bram_clk(clock), .funct, .x1(val1), .x2(val2),
    //     .y(result), .inst_y(result_comb), .en(enable), .valid, .idle
    // );
    // assign stall = idle | (enable & ~(funct[4] & funct[0]));
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
    
    // input wire wb_enable_in,
    // input wire [7:0] wb_dest_in,
    // input wire [31:0] wb_data_in,
    
    DataMemoryWithMMIO.master m_data,  // DMは0クロックで中身の取得が出来ると仮定
    
    input wire instr_stall,
    output wire data_stall,
    output wire branch_taken,
    output wire [31:0] new_pc,
    
    // FPU, メモリはWBステージを飛ばすというちょっと面倒なことをする
    // そのためここのoutputのみwireにしてある
    output wire wb_enable,
    output wire [7:0] wb_dest,
    output wire [31:0] wb_data
);
    // フォールスルー
    wire [31:0] data1 = (wb_enable == 1'b1 && src1 == wb_dest) ? wb_data : read1;
    wire [31:0] data2 = (wb_enable == 1'b1 && src2_or_imm8 == wb_dest) ? wb_data : read2;
    
    // ALUの宣言
    wire [31:0] alu_result;
    wire [31:0] alu_data2 = (op[0]) ? {24'b0, src2_or_imm8} : data2;
    ALU alu(.is_imm(op[0]), .val1(data1), .val2(alu_data2), .funct(funct5), .result(alu_result));
    
    // FPUの宣言
    wire [31:0] fpu_result;
    wire [31:0] fpu_comb_result;
    wire fpu_stall;
    FPU fpu_i(
        .clock, .val1(data1), .val2(data2), .funct(funct5), .enable(~op[2] & op[1]),
        .stall(fpu_stall), .result(fpu_result), .result_comb(fpu_comb_result)
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
    // wire [31:0] ex_result = (op[2]) ? m_data.rd : ((op[1]) ? fpu_result : alu_result);
    // stallするか否か
    assign data_stall = fpu_stall | m_data.stall;
    // WBするか否か
    // wire wb_enable_w = ((~op[2]) | (op[1] & op[0])) & (~data_stall);


    // これらのレジスタにはストールなしで結果が返るもののみを格納する
    reg reg_wb_enable;
    reg [7:0] reg_wb_dest;
    reg [31:0] reg_wb_data;

    reg stall_1clock_behind;
    reg op2_before_stall;
    reg [7:0] dest_before_stall;
    
    always_ff @( posedge clock ) begin
        if (~data_stall) begin
            reg_wb_dest <= dest;
            reg_wb_enable <= (~op[2]) | (op[1] & op[0]);
            op2_before_stall <= op[2];
        end

        reg_wb_data <= (op[2]) ? m_data.rd_inst : ((op[1]) ? fpu_comb_result : alu_result);
        stall_1clock_behind <= data_stall;
    end

    // ストールが必要なものの結果を格納
    wire [31:0] ex_stall_result = (op2_before_stall) ? m_data.rd : fpu_result;
    wire forwarding = ~data_stall & stall_1clock_behind;
    assign wb_enable = ~data_stall & reg_wb_enable;
    assign wb_data = (forwarding) ? ex_stall_result : reg_wb_data;
    assign wb_dest = reg_wb_dest;
endmodule


module Core(
    input wire clock,
    input wire reset,

    InstructionMemory.master m_instr,
    DataMemoryWithMMIO.master m_data
);
    wire instr_stall;
    wire data_stall;
    wire branch_taken;
    wire [31:0] new_pc;

    wire [31:0] instruction;
    wire [31:0] prog_counter;

    IFStage if_stage(
        .clock, .reset, .m_instr, .instr_stall, .data_stall,
        .branch_taken, .new_pc, .instruction, .prev_pc(prog_counter)
    );

    wire wb_enable;
    wire [7:0] wb_dest;
    wire [31:0] wb_data;

    wire [7:0] src1;
    wire [7:0] src2_or_imm8;
    wire [31:0] read1;
    wire [31:0] read2;
    wire [7:0] dest;
    wire [31:0] prog_counter2;
    wire [31:0] imm_ext10;
    wire [31:0] imm_ext26;
    wire [2:0] op;
    wire [4:0] funct5;

    IDStage id_stage(
        .clock, .reset, .instruction, .pc_in(prog_counter),
        .stall(instr_stall | data_stall), .flash(branch_taken),
        .wb_enable, .wb_dest, .wb_data, .src1, .src2_or_imm8,
        .read1, .read2, .dest, .pc_out(prog_counter2),
        .imm_ext10, .imm_ext26, .op, .funct5
    );

    EX_MEMStage ex_mem_stage(
        .clock, .reset, .src1, .src2_or_imm8, .read1, .read2, .dest,
        .pc(prog_counter2), .imm_ext10, .imm_ext26, .op, .funct5,
        // .wb_enable_in(wb_enable), .wb_dest_in(wb_dest), .wb_data_in(wb_data),
        .m_data, .instr_stall, .data_stall, .branch_taken, .new_pc,
        .wb_enable, .wb_dest, .wb_data
    );
endmodule