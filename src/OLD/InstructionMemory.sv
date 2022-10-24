`timescale 1ps / 1ps

module InstructionMemory
    #(
        NUM_WORDS = 1024
    )
    (
    input wire [31:0] address,
    output wire [31:0] instruction
    );
    reg [31:0] m[NUM_WORDS - 1:0];  // 4KiB
    
    initial begin
        $readmemh("D:/cpu_ex/cpu_1st/asm/gcd.dat", m);
        $display("loaded fib.dat");
    end

    localparam nop = 32'b00100001000000000000000000000000;
    assign instruction = (address >= NUM_WORDS) ? nop : m[address];
endmodule
