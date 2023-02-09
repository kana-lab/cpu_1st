interface DataMemory;
    wire en;
    wire stall;
    wire we;
    wire [31:0] addr;
    wire [31:0] wd;
    wire [31:0] rd;

    modport master (
        input stall, rd,
        output en, we, addr, wd
    );

    modport slave (
        input en, we, addr, wd,
        output stall, rd
    );
endinterface //DataMemory


interface InstructionMemory;
    wire stall;
    wire [31:0] addr;
    wire [31:0] instr;

    modport master (
        input stall, instr,
        output addr
    );

    modport slave (
        input addr,
        output stall, instr
    );
endinterface //InstructionMemory

// interface BramPort;
//     wire en;
//     wire we;
//     wire [31:0] addr;
//     wire [31:0] wd;
//     wire [31:0] rd;
// endinterface

interface DataMemoryWithMMIO;
    wire en;
    wire stall;
    wire we;
    wire [31:0] addr;
    wire [31:0] wd;
    wire [31:0] rd;
    wire [31:0] rd_inst;

    modport master (
        input stall, rd, rd_inst,
        output en, we, addr, wd
    );

    modport slave (
        input en, we, addr, wd,
        output stall, rd, rd_inst
    );
endinterface