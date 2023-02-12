`timescale 1ps/1ps

// `include "UartRx.sv"
// `include "UartTx.sv"
// `include "DmaController.sv"
// `include "core.sv"
// `include "MemoryControllerHub.sv"

module CoreCacheInterconnect(
    input wire clock,
    input wire mig_clock,
    input wire cpu_reset,
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
    output wire [0:0] ddr2_odt,
    // for core
    DataMemory.slave request  // request.enはreset中、data_stall中にONにならない保証あり
);  
    reg [31:0] wd_saved;
    reg [26:0] addr_saved;
    always_ff @( posedge clock ) begin
        if (cpu_reset) begin
            wd_saved <= 0;
            addr_saved <= 0;
        end else if (request.en) begin
            wd_saved <= request.wd;
            addr_saved <= request.addr[26:0];
        end
    end
    wire [31:0] w_data = (request.en) ? request.wd : wd_saved;
    wire [26:0] addr = (request.en) ? request.addr[26:0] : addr_saved;

    // interfaces
    master_fifo master_fifo ();
    slave_fifo slave_fifo ();

    logic r_data_valid;  // dummy
    wire idle;

    // master
    cache_controller_idx12_w16 cache_controller_idx12_w16 (
        .wr(request.we),//1:write,0:read
        .w_data,
        .r_data(request.rd),
        // .en(request.en & ~request.stall & ~cpu_reset),  // この＆必要？
        .en(request.en),
        .addr,
        .r_data_valid(r_data_valid),
        .fifo(master_fifo),
        .cache_clk(clock),//
        .idle(idle),
        .clk(clock)
    );

    // reg right_after_en;
    // always_ff @( posedge clock ) begin
    //     right_after_en <= request.en & idle;
    // end
    assign request.stall = ~idle;// | right_after_en;

    // fifo
    dram_buf dram_buf (
        .master(master_fifo),
        .slave(slave_fifo)
    );

    // slave
    dram_controller dram_controller (
        // DDR2
        .*,
        // others
        .sys_clk(mig_clock),
        .fifo(slave_fifo)
    );
endmodule

module ClockingWiz (
    input wire CLK100MHZ,
    input wire CPU_RESETN,
    
    output wire cpu_clock,
    output wire bram_clock,
    output wire reset
);
    wire locked;
    clk_wiz_0 c_wiz(
        .clk_in1(CLK100MHZ), .clk_out1(bram_clock), .clk_out2(cpu_clock),
        .resetn(CPU_RESETN), .locked
    );

    wire resetn;
    // wire mb = 0;
    proc_sys_reset_0 rst_wiz(
        .slowest_sync_clk(cpu_clock), .ext_reset_in(CPU_RESETN),
        .dcm_locked(locked), .peripheral_aresetn(resetn),
        .aux_reset_in(~CPU_RESETN), .mb_debug_sys_rst(~CPU_RESETN),
        .mb_reset(), .bus_struct_reset(), .peripheral_reset(),
        .interconnect_aresetn()
    );

    assign reset = ~resetn;
endmodule

// 5Mbaudにしたい
// clockが100MHzならCLK_PER_HALF_BIT=10, clockが40MHzならCLK_PER_HALF_BIT=4
// 逆にclock=40MHz, CLK_PER_HALF_BIT=10なら2Mbaud
module Board #(parameter CLK_PER_HALF_BIT = 100) (
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
    wire clock, mig_clock, reset;
    ClockingWiz w(.CLK100MHZ, .CPU_RESETN, .cpu_clock(clock), .bram_clock(mig_clock), .reset);
    wire rxd = UART_TXD_IN;
    wire txd;
    assign UART_RXD_OUT = txd;

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
    wire [15:0] led1;
    DmaController dma_controller(
        clock, reset, rx_ready, rdata, tx_busy, w_tx_start1, w_sdata1,
        instr_ready, mem_ready, data, program_loaded, led1
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
    wire [15:0] led2;
    Core core(clock, cpu_reset, m_instr.master, m_data, led2, SW[15:1]);

    wire w_tx_start2;
    wire [7:0] w_sdata2;
    wire [15:0] led3;
    DataMemory ddr2();
    DataMemory instr_bram();
    MemoryControllerHub mch(
        clock, reset, /*instr_ready,*/ mem_ready, data,
        // write_enable, address, write_data, read_data, instr_address, instr,
        m_data,// m_instr,
        w_tx_start2, w_sdata2, tx_busy, ddr2.master, instr_bram, led3, SW[2]//, led[15:8]
    );

    assign tx_start = w_tx_start1 | w_tx_start2;
    assign sdata = (w_tx_start1) ? w_sdata1 : w_sdata2;

    reg [31:0] counter;
    // assign LED = counter[15:0];
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
    Bram bram(clock, reset, bram_en, bram_we, bram_addr, bram_wd, bram_rd, instr_bram);

    always_ff @( posedge clock ) begin
        if (reset) begin
            counter <= 0;
        end else begin
            if (instr_ready)
                counter <= counter + 32'd1;
        end
    end

    // assign ddr2_en = ddr2.en;
    // assign ddr2_we = ddr2.we;
    // assign ddr2_addr = ddr2.addr;
    // assign ddr2_wd = ddr2.wd;
    // assign ddr2.stall = ddr2_stall;
    // assign ddr2.rd = ddr2_rd;
    CoreCacheInterconnect conn(
        .clock, .mig_clock, .cpu_reset,
        .*,  // DDR2
        .request(ddr2)
    );

    assign LED = (SW[0]) ? led2 : ((SW[1]) ? led3 : led1);
endmodule