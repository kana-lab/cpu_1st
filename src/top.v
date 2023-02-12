`timescale 1ps/1ps

module top(
    // input wire clock,
    // input wire mig_clock,
    // input wire resetn,
    // input wire rxd,
    // output wire txd,
    // output wire [15:0] led,
    input wire CLK100MHZ,
    input wire CPU_RESETN,
    input wire UART_TXD_IN,
    output wire UART_RXD_OUT,
    output wire [15:0] LED,
    input wire [15:0] SW,
    
    // output wire bram_en,
    // output wire bram_we,
    // output wire [31:0] bram_addr,
    // output wire [31:0] bram_wd,
    // input wire [31:0] bram_rd,
    
    // input wire ddr2_stall,
    // input wire [31:0] ddr2_rd,
    // output wire ddr2_en,
    // output wire ddr2_we,
    // output wire [31:0] ddr2_addr,
    // output wire [31:0] ddr2_wd

    // DDR2
    // (* X_INTERFACE_INFO = "xilinx.com:interface:ddrx_rtl:1.0 ddr2 ADDR" *) output wire [12:0] ddr2_addr,
    // (* X_INTERFACE_INFO = "xilinx.com:interface:ddrx_rtl:1.0 ddr2 BA" *) output wire [2:0] ddr2_ba,
    // (* X_INTERFACE_INFO = "xilinx.com:interface:ddrx_rtl:1.0 ddr2 CAS_N" *) output wire ddr2_cas_n,
    // (* X_INTERFACE_INFO = "xilinx.com:interface:ddrx_rtl:1.0 ddr2 CK_N" *) output wire [0:0] ddr2_ck_n,
    // (* X_INTERFACE_INFO = "xilinx.com:interface:ddrx_rtl:1.0 ddr2 CK_P" *) output wire [0:0] ddr2_ck_p,
    // (* X_INTERFACE_INFO = "xilinx.com:interface:ddrx_rtl:1.0 ddr2 CKE" *) output wire [0:0] ddr2_cke,
    // (* X_INTERFACE_INFO = "xilinx.com:interface:ddrx_rtl:1.0 ddr2 RAS_N" *) output wire ddr2_ras_n,
    // (* X_INTERFACE_INFO = "xilinx.com:interface:ddrx_rtl:1.0 ddr2 WE_N" *) output wire ddr2_we_n,
    // (* X_INTERFACE_INFO = "xilinx.com:interface:ddrx_rtl:1.0 ddr2 DQ" *) inout  wire [15:0] ddr2_dq,
    // (* X_INTERFACE_INFO = "xilinx.com:interface:ddrx_rtl:1.0 ddr2 DQS_N" *) inout  wire [1:0] ddr2_dqs_n,
    // (* X_INTERFACE_INFO = "xilinx.com:interface:ddrx_rtl:1.0 ddr2 DQS_P" *) inout  wire [1:0] ddr2_dqs_p,
    // (* X_INTERFACE_INFO = "xilinx.com:interface:ddrx_rtl:1.0 ddr2 CS_N" *) output wire [0:0] ddr2_cs_n,
    // (* X_INTERFACE_INFO = "xilinx.com:interface:ddrx_rtl:1.0 ddr2 DM" *) output wire [1:0] ddr2_dm,
    // (* X_INTERFACE_INFO = "xilinx.com:interface:ddrx_rtl:1.0 ddr2 ODT" *) output wire [0:0] ddr2_odt
    
    // DDR2
    output wire [12:0] ddr2_addr,
    output wire [2:0] ddr2_ba,
    output wire ddr2_cas_n,
    output wire [0:0] ddr2_ck_n,
    output wire [0:0] ddr2_ck_p,
    output wire [0:0] ddr2_cke,
    output wire ddr2_ras_n,
    output wire ddr2_we_n,
    inout  wire [15:0] ddr2_dq,
    inout  wire [1:0] ddr2_dqs_n,
    inout  wire [1:0] ddr2_dqs_p,
    output wire [0:0] ddr2_cs_n,
    output wire [1:0] ddr2_dm,
    output wire [0:0] ddr2_odt
);
    Board board(CLK100MHZ, CPU_RESETN, UART_TXD_IN, UART_RXD_OUT, LED, SW, //bram_en, bram_we, bram_addr, bram_wd, bram_rd,
    //ddr2_stall, ddr2_rd, ddr2_en, ddr2_we, ddr2_addr, ddr2_wd);
    ddr2_addr, ddr2_ba, ddr2_cas_n, ddr2_ck_n, ddr2_ck_p, ddr2_cke,
    ddr2_ras_n, ddr2_we_n, ddr2_dq, ddr2_dqs_n, ddr2_dqs_p, ddr2_cs_n,
    ddr2_dm, ddr2_odt);
endmodule