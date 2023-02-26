`default_nettype wire
//x1 < x2
module fless(
    input logic [31:0] x1,
    input logic [31:0] x2,
    output logic [31:0] y,
    output logic idle,
    input logic clk
);
    wire [7:0] e1;
    wire [22:0] m1;
    wire  s1;

    logic bool_y;

    assign e1 = x1[30:23];
    assign m1 = x1[22:0];
    assign s1 = x1[31];

    wire [7:0] e2;
    wire [22:0] m2;
    wire  s2;

    assign e2 = x2[30:23];
    assign m2 = x2[22:0];
    assign s2 = x2[31];
    assign bool_y = (s1==1'b0) ? ((s2==1'b0) ? ((e1==e2) ? (m1 < m2) : (e1 < e2))  : 1'b0)
                : ((s2 == 1'b0) ? 1'b1 : ((e1==e2) ? (m1 > m2) : (e1 > e2)));
    assign y = {31'b0, bool_y};
    assign idle = 1'b1;


endmodule