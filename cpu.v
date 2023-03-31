`timescale 1ps/1ps

module main();

    initial begin
        $dumpfile("cpu.vcd");
        $dumpvars(0,main);
    end

    // clock
    wire clk;
    clock c0(clk);

    reg halt = 0;

    counter ctr(halt,clk);

    // PC
    reg [15:0]pc = 16'h0000;

    // memory
    wire [15:0] instruction;
    wire [15:0] m_raddr1;
    wire [15:0] m_rdata1;
    reg m_wen = 0;
    wire [15:0] m_waddr;
    wire [15:0] m_wdata;

    mem mem(
        .clk(clk),
        .raddr0_(pc[15:1]),
        .rdata0_(instruction),
        .raddr1_(m_raddr1[15:1]),
        .rdata1_(m_rdata1),
        .wen(m_wen),
        .waddr(m_waddr[15:1]),
        .wdata(m_wdata)
    );


    // registers
    // wire [3:0] r_raddr0;
    // wire [15:0] r_rdata0;
    // wire [3:0] r_raddr1;
    // wire [15:0] r_rdata1;
    // reg r_wen = 0;
    // wire [3:0] r_waddr;
    // wire [15:0] r_wdata;

    // regs regs(
    //     .clk(clk),
    //     .raddr0_(r_raddr0), 
    //     .rdata0(r_rdata0),
    //     .raddr1_(r_raddr1), 
    //     .rdata1(r_rdata1),
    //     .wen(r_wen), 
    //     .waddr(r_waddr), 
    //     .wdata(r_wdata)
    // );
    wire [3:0] r_raddr0;
    wire [3:0] r_raddr1;
    wire [15:0] r_rdata0;
    wire [15:0] r_rdata1;
    wire [3:0] r_waddr;
    wire [15:0] r_wdata;
    reg r_wen;

    regs regs(clk,
        r_raddr0, r_rdata0,
        r_raddr1, r_rdata1,
        r_wen, r_waddr, vwdata);


    //fetch

    //fetch1
    reg [15:0] f1_pc;
    reg f1_valid = 0;

    always @(posedge clk) begin
        f1_pc <= pc;
        f1_valid <= 1;
    end

    //fetch2
    reg [15:0] f2_pc;
    reg f2_valid = 0;

    always @(posedge clk) begin
        f2_pc <= f1_pc;
        f2_valid <= f1_valid;
    end

    // //decode

    //decode1
    reg [15:0] d1_pc;
    reg d1_valid = 0;
    reg [16:0] d1_instruct_info;

    wire [3:0] opcode = instruction[15:12];
    wire [3:0] ra = instruction[11:8];
    wire [3:0] rb = instruction[7:4];
    wire [3:0] rt = instruction[3:0];

    //is there a better way of doing this?
    wire is_sub = opcode == 4'b0000;
    wire is_movl = opcode == 4'b1000;
    wire is_movh = opcode == 4'b1001;
    wire is_jump = opcode == 4'b1110;
    wire is_mem_access = opcode == 4'b1111;
    wire is_ld = rb == 4'b0000;
    wire is_str = rb == 4'b0001;
    wire is_halt = !(is_sub | is_movl | is_movh | is_jump | (is_mem_access && (is_ld | is_str)));

    //same here
    wire [16:0] instruct_info = {ra, rb, rt, is_sub, is_movl, is_movh, is_jump, is_mem_access, is_ld, is_str, is_halt};

    assign r_raddr0 = is_movh ? rt : ra;
    assign r_raddr1 = is_sub ? rb : rt;

    always @(posedge clk) begin
        d1_pc <= f2_pc;
        d1_valid <= f2_valid;
        d1_instruct_info <= instruct_info;
    end

    //decode 2
    reg [15:0] d2_pc;
    reg d2_valid = 0;
    reg [16:0] d2_instruct_info;

    always @(posedge clk) begin
        d2_pc <= d1_pc;
        d2_valid <= d1_valid;
        d2_instruct_info <= d1_instruct_info;
    end

    assign m_raddr1 = r_rdata0;

    always @(posedge clk) begin
        if (pc == 12) halt <= 1;
        $display("pc: %h", pc);
        $display("r_rdata0: %h", r_rdata0);
        pc <= pc + 2;
    end


endmodule
