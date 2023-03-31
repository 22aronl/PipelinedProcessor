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
    wire m_wen;
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


    //registers
    wire [3:0] r_raddr0;
    wire [15:0] r_rdata0;
    wire [3:0] r_raddr1;
    wire [15:0] r_rdata1;
    wire r_wen;
    wire [3:0] r_waddr;
    wire [15:0] r_wdata;

    regs regs(
        .clk(clk),
        .raddr0_(r_raddr0), 
        .rdata0(r_rdata0),
        .raddr1_(r_raddr1), 
        .rdata1(r_rdata1),
        .wen(r_wen), 
        .waddr(r_waddr), 
        .wdata(r_wdata)
    );


    //fetch

    //fetch1
    reg [15:0] f1_pc;
    reg f1_valid = 1'b0;

    always @(posedge clk) begin
        f1_pc <= pc;
        f1_valid <= 1'b1;
    end

    //fetch2
    reg [15:0] f2_pc;
    reg f2_valid = 1'b0;

    always @(posedge clk) begin
        f2_pc <= f1_pc;
        f2_valid <= f1_valid;
    end

    // //decode

    //decode1
    reg [15:0] d1_pc;
    reg d1_valid = 1'b0;
    reg [18:0] d1_instruct_info;

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

    assign r_raddr0 = is_movh ? rt : ra;
    assign r_raddr1 = is_sub ? rb : rt;

    wire is_r00 = r_raddr0 == 4'b0000;
    wire is_r10 = r_raddr1 == 4'b0000;
    //same here
    wire [18:0] instruct_info = {ra, rb, rt, is_sub, is_movl, is_movh, is_jump, is_mem_access, is_ld, is_str, is_halt, is_r00, is_r10};

    always @(posedge clk) begin
        d1_pc <= f2_pc;
        d1_valid <= f2_valid;
        d1_instruct_info <= instruct_info;
    end

    //decode 2
    reg [15:0] d2_pc;
    reg d2_valid = 1'b0;
    reg [18:0] d2_instruct_info;

    always @(posedge clk) begin
        d2_pc <= d1_pc;
        d2_valid <= d1_valid;
        d2_instruct_info <= d1_instruct_info;
    end

    //memory fetch
    //mem1
    reg [15:0] m1_pc;
    reg m1_valid = 1'b0;
    reg [18:0] m1_instruct_info;

    assign m_raddr1 = m1_instruct_info[1] ? r_rdata0 : 16'h0000;

    always @(posedge clk) begin
        m1_pc <= d2_pc;
        m1_valid <= d2_valid;
        m1_instruct_info <= d2_instruct_info;
    end

    //mem2
    reg [15:0] m2_pc;
    reg m2_valid = 1'b0;
    reg [18:0] m2_instruct_info;

    always @(posedge clk) begin
        m2_pc <= m1_pc;
        m2_valid <= m1_valid;
        m2_instruct_info <= m1_instruct_info;
    end

    //execute
    reg [15:0] e_pc;
    reg e_valid = 0;
    reg [18:0] e_instruct_info;

    wire [3:0] e_ra = e_instruct_info[18:16];
    wire [3:0] e_rb = e_instruct_info[15:13];
    wire [3:0] e_rt = e_instruct_info[12:10];
    wire e_is_sub = e_instruct_info[9];
    wire e_is_movl = e_instruct_info[8];
    wire e_is_movh = e_instruct_info[7];
    wire e_is_jump = e_instruct_info[6];
    wire e_is_mem_access = e_instruct_info[5];
    wire e_is_ld = e_instruct_info[4];
    wire e_is_str = e_instruct_info[3];
    wire e_is_halt = e_instruct_info[2];
    wire e_is_r00 = e_instruct_info[1];
    wire e_is_r10 = e_instruct_info[0];

    wire [15:0] z_rdata0 = e_is_r00 ? 16'h0000 : r_rdata0;
    wire [15:0] z_rdata1 = e_is_r10 ? 16'h0000 : r_rdata1;

    wire [15:0] result = e_is_sub ? z_rdata0 - z_rdata1 :
                            e_is_movl ? {{7{e_ra[3]}}, e_ra, e_rb} :
                            e_is_movh ? (z_rdata0 & 16'h00ff) | ({e_ra, e_rb} << 8) :
                            e_is_str ? z_rdata0 : m_rdata1;

    wire [15:0] jump_addr = e_is_jump ? ((e_rb == 4'b0000 ? z_rdata0 == 0 :
                                        e_rb == 4'b0001 ? z_rdata0 != 0 :
                                        e_rb == 4'b0010 ? z_rdata0 < 0 : z_rdata0 >= 0) ? z_rdata1 : e_pc + 2) :
                                e_pc + 2;

    always @(posedge clk) begin
        e_pc <= m2_pc;
        e_valid <= m2_valid;
        e_instruct_info <= m2_instruct_info;
    end

    //writeback

    assign m_waddr = z_rdata0;
    assign m_wdata = z_rdata1;
    assign r_waddr = e_rt;
    assign r_wdata = result;
    assign m_wen = e_is_mem_access & e_is_str;
    assign r_wen = (r_waddr != 4'b0000) & (e_is_sub | e_is_movl | e_is_movh | e_is_mem_access & e_is_ld);

    
    //do something with the pc
    always @(posedge clk) begin
        if (e_is_halt) halt <= 1;
        if(r_waddr == 4'b0000) $write("%c", r_wdata[7:0]);
        //pc <= jump_addr;
    end

    always @(posedge clk) begin
        if(pc == 20) halt <= 1;
        pc <= pc + 2;
    end
endmodule
