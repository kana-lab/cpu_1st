`timescale 1ps/1ps

// `include "UartRx.sv"
// `include "UartTx.sv"
// `include "DmaController.sv"
// `include "core.sv"
// `include "MemoryControllerHub.sv"

module Board #(parameter CLK_PER_HALF_BIT = 10) (
    input wire clock,
    input wire resetn,
    input wire rxd,
    output wire txd,
    output wire [15:0] led,

    // output wire bram_en,
    // output wire bram_we,
    // output wire [31:0] bram_addr,
    // output wire [31:0] bram_wd,
    // input wire [31:0] bram_rd,

    input wire ddr2_stall,
    input wire [31:0] ddr2_rd,
    output wire ddr2_en,
    output wire ddr2_we,
    output wire [31:0] ddr2_addr,
    output wire [31:0] ddr2_wd
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

    // wire write_enable;
    // wire [31:0] address;
    // wire [31:0] write_data;
    // wire [31:0] read_data;
    // wire [31:0] instr_address;
    // wire [31:0] instr;
    // wire cpu_reset = ~program_loaded;
    // Core core(
    //     clock, cpu_reset, write_enable, address, write_data,
    //     read_data, instr_address, instr, led[7:0]
    // );
    InstructionMemory m_instr();
    DataMemoryWithMMIO m_data();
    wire cpu_reset = ~program_loaded;
    Core core(clock, cpu_reset, m_instr.master, m_data);
    assign led[7:0] = 8'b10101010;

    wire w_tx_start2;
    wire [7:0] w_sdata2;
    DataMemory ddr2();
    MemoryControllerHub mch(
        clock, reset, /*instr_ready,*/ mem_ready, data,
        // write_enable, address, write_data, read_data, instr_address, instr,
        m_data,// m_instr,
        w_tx_start2, w_sdata2, tx_busy, ddr2.master//, led[15:8]
    );

    assign tx_start = w_tx_start1 | w_tx_start2;
    assign sdata = (w_tx_start1) ? w_sdata1 : w_sdata2;
    assign led[15:8] = 8'hab;

    reg [31:0] counter;
    // assign bram_en = instr_ready | program_loaded;
    // assign bram_we = instr_ready;
    // assign bram_wd = data;
    // assign bram_addr = (instr_ready) ? counter : m_instr.addr;
    // assign m_instr.instr = bram_rd;
    // assign m_instr.stall = 0;
    wire bram_en = instr_ready | program_loaded;
    wire bram_we = instr_ready;
    wire [31:0] bram_wd = data;
    wire [31:0] bram_addr = (instr_ready) ? counter : m_instr.addr;
    wire [31:0] bram_rd;
    assign m_instr.instr = bram_rd;
    assign m_instr.stall = 0;
    Bram bram(clock, reset, bram_en, bram_we, bram_addr, bram_wd, bram_rd);

    always_ff @( posedge clock ) begin
        if (reset) begin
            counter <= 0;
        end else begin
            if (instr_ready)
                counter <= counter + 1;
        end
    end

    assign ddr2_en = ddr2.en;
    assign ddr2_we = ddr2.we;
    assign ddr2_addr = ddr2.addr;
    assign ddr2_wd = ddr2.wd;
    assign ddr2.stall = ddr2_stall;
    assign ddr2.rd = ddr2_rd;
endmodule