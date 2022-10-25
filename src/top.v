`timescale 1ps/1ps

// `include "UartRx.sv"
// `include "UartTx.sv"
// `include "DmaController.sv"
// `include "core.sv"
// `include "MemoryControllerHub.sv"

module top #(parameter CLK_PER_HALF_BIT = 10) (
    input wire clock,
    input wire resetn,
    input wire rxd,
    output wire txd,
    output wire [15:0] led
);
    wire reset = ~resetn;

    wire rx_ready;
    wire [7:0] rdata;
    wire ferr;
    UartRx #(CLK_PER_HALF_BIT) uart_rx(clock, reset, rxd, rx_ready, rdata, ferr);

    wire tx_start;
    wire [7:0] sdata;
    wire tx_busy;
    UartTx #(CLK_PER_HALF_BIT) uart_tx(clock, reset, tx_start, sdata, tx_busy, txd);

    wire instr_ready;
    wire mem_ready;
    wire [31:0] data;
    wire program_loaded;
    wire w_tx_start1;
    wire [7:0] w_sdata1;
    DmaController dma_controller(
        clock, reset, rx_ready, rdata, tx_busy, w_tx_start1, w_sdata1,
        instr_ready, mem_ready, data, program_loaded
    );

    wire write_enable;
    wire [31:0] address;
    wire [31:0] write_data;
    wire [31:0] read_data;
    wire [31:0] instr_address;
    wire [31:0] instr;
    wire cpu_reset = ~program_loaded;
    Core core(
        clock, cpu_reset, write_enable, address, write_data,
        read_data, instr_address, instr, led
    );

    wire w_tx_start2;
    wire [7:0] w_sdata2;
    MemoryControllerHub mch(
        clock, reset, instr_ready, mem_ready, data,
        write_enable, address, write_data, read_data, instr_address, instr,
        w_tx_start2, w_sdata2, tx_busy
    );

    assign tx_start = w_tx_start1 | w_tx_start2;
    assign sdata = (w_tx_start1) ? w_sdata1 : w_sdata2;
endmodule