`default_nettype wire
// 0 == -0
module feq(
    input logic [31:0] x1,
    input logic [31:0] x2,
    output logic [31:0] y,
    output logic idle,
    input logic clk
);
    logic bool_y;
    assign bool_y = (x1[30:0] == 30'b0 && x2[22:0] == 30'b0) ? 1'b1 : (x1[31:0] == x2[31:0]) ? 1'b1 : 1'b0;
    assign y = {31'b0, bool_y};

endmodule