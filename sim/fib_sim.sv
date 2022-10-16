`timescale 1ps / 1ps

module fib_sim;
    reg clock;
    always begin
        clock <= 0;
        #5;
        clock <= 1;
        #5;
    end
    
    reg reset;
    initial begin
        reset <= 0;
        #100;
        reset <= 1;
        #10000;
        $finish();
    end
    
    board brd(.CLK100MHZ(clock), .CPU_RESETN(reset));
endmodule
