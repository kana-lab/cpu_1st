`timescale 1ps / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2022/10/07 11:25:11
// Design Name: 
// Module Name: ALU
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module ALU(
    input wire [31:0] val1,
    input wire [31:0] val2,
    input wire [4:0] funct,
    output wire [31:0] result
    );
    wire [31:0] add_result;
    assign add_result = (funct[0]) ? val1 + val2 : 0;
    wire [31:0] sub_result;
    assign sub_result = (funct[1]) ? val1 - val2 : 0;
    wire [31:0] sll_result;
    assign sll_result = (funct[2]) ? val1 << val2 : 0;
    wire [31:0] srl_result;
    assign srl_result = (funct[3]) ? val1 >> val2 : 0;
    wire [31:0] sra_result;
    assign sra_result = (funct[4]) ? $signed(val1) >> $signed(val2) : 0;

    assign result = add_result | sub_result | sll_result | srl_result | sra_result;
endmodule
