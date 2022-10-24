`timescale 1ps/1ps

// `include "UartRx.sv"
// `include "UartTx.sv"
// `include "DmaController.sv"
// `include "core.sv"
// `include "MemoryControllerHub.sv"

module top #(parameter CLK_PER_HALF_BIT = 15) (
    input wire clock,
    input wire resetn,
    input wire rxd,
    output wire txd
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
    DmaController dma_controller(
        clock, reset, rx_ready, rdata, tx_busy, tx_start, sdata,
        instr_ready, mem_ready, data, program_loaded
    );

    wire write_enable;
    wire [31:0] address;
    wire [31:0] write_data;
    wire [31:0] read_data;
    wire [31:0] instr_address;
    wire [31:0] instr;
    Core core(
        clock, program_loaded, write_enable, address, write_data,
        read_data, instr_address, instr
    );

    MemoryControllerHub mch(
        clock, reset, instr_ready, mem_ready, data,
        write_enable, address, write_data, read_data, instr_address, instr,
        tx_start, sdata, tx_busy
    );
endmodule