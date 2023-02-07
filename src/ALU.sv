`timescale 1ps / 1ps


module ALU(
    input wire is_imm,
    input wire [31:0] val1,
    input wire [31:0] val2,
    input wire [4:0] funct,
    output wire [31:0] result
);
    wire [31:0] addi = (funct[0]) ? val1 + val2 : 0;
    wire [31:0] subi = (funct[1]) ? val1 - val2 : 0;
    wire [31:0] slli = (funct[2]) ? val1 << val2 : 0;
    wire [31:0] srli = (funct[3]) ? val1 >> val2 : 0;
    wire [31:0] srai = (funct[4]) ? $signed(val1) >>> val2 : 0;
    wire [31:0] imm_result = addi | subi | slli | srli | srai;

    wire [31:0] addsub = (funct[0]) ? val1 + val2 : val1 - val2;
    wire [31:0] sll = (funct[0]) ? val1 << val2 : 0;
    wire [31:0] srl = (funct[1]) ? val1 >> val2 : 0;
    wire [31:0] sra = (funct[2]) ? $signed(val1) >>> val2 : 0;
    wire [31:0] shift = sll | srl | sra;
    wire [31:0] fispos = (funct[0]) ? {31'h0, ~val2[31]} : 0;
    wire [31:0] fisneg = (funct[1]) ? {31'h0, val2[31]} : 0;
    wire [31:0] fneg = (funct[2]) ? {~val2[31], val2[30:0]} : 0;
    wire [31:0] fop = fispos | fisneg | fneg;

    wire [1:0] f34 = funct[4:3];
    assign result = (is_imm) ? imm_result
                             : ((f34 == 2'b00) ? addsub :
                                ((f34 == 2'b01) ? shift : fop));
endmodule
