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

    reg [3:0] reg_in_use[0:15];
    integer i;
    initial begin
        for(i = 0; i < 16; i = i + 1) begin
            reg_in_use[i] = 4'b0000;
        end
    end

    wire [3:0] reg0 = reg_in_use[0];
    wire [3:0] reg1 = reg_in_use[1];
    wire [3:0] reg2 = reg_in_use[2];
    wire [3:0] reg3 = reg_in_use[3];
    wire [3:0] reg4 = reg_in_use[4];

    //fetch

    //fetch1
    reg [15:0] f1_pc;
    reg f1_valid = 1'b0;

    always @(posedge clk) begin
        f1_pc <= d1_stall ? f1_pc : pc;
        f1_valid <= 1'b1 & !flush;
    end

    // //decode
    wire d1_stall;
    //decode1
    reg [15:0] d1_pc;
    reg d1_valid = 1'b0;
    reg [18:0] d1_instruct_info;

    wire [15:0] d1_instruction_wire = d1_stall ? d1_instruction : instruction;
    reg [15:0] d1_instruction;

    wire [3:0] opcode = instruction[15:12];
    wire [3:0] ra = instruction[11:8];
    wire [3:0] rb = instruction[7:4];
    wire [3:0] rt = instruction[3:0];

    //is there a better way of doing this?
    wire is_sub = opcode == 4'b0000;
    wire is_movl = opcode == 4'b1000;
    wire is_movh = opcode == 4'b1001;
    //add check for the individual jumps
    wire is_jump = opcode == 4'b1110;
    wire is_mem_access = opcode == 4'b1111;
    wire is_ld = rb == 4'b0000;
    wire is_str = rb == 4'b0001;
    wire is_halt = !(is_sub | is_movl | is_movh | is_jump | (is_mem_access && (is_ld | is_str)));

    assign r_raddr0 = is_movh ? rt : ra;
    assign r_raddr1 = is_sub ? rb : rt;

    wire is_r00 = r_raddr0 == 4'b0000;
    wire is_r10 = r_raddr1 == 4'b0000;

    //can be optimized to only use reg when it is actually beign used
    assign d1_stall = 0;//d1_valid & ((!is_r00 & reg_in_use[r_raddr0] != 4'b0000) | (!is_r10 & reg_in_use[r_raddr1] != 4'b0000));

    //same here
    wire [29:0] instruct_info = {r_raddr0, r_raddr1, ra, rb, rt, is_sub, is_movl, is_movh, is_jump, is_mem_access, is_ld, is_str, is_halt, is_r00, is_r10};

    always @(posedge clk) begin
        d1_pc <= d1_stall ? d1_pc : f1_pc;
        d1_valid <= d1_stall ? d1_valid : f1_valid & !flush;
        d1_instruction <= d1_stall ? d1_instruction : instruction;

        //d1_instruct_info <= instruct_info;
    end

    // //decode 2
    // reg [15:0] d2_pc;
    // reg d2_valid = 1'b0;
    // reg [29:0] d2_instruct_info;

    // always @(posedge clk) begin
    //     d2_pc <= d1_pc;
    //     d2_valid <= d1_valid & !flush & !d1_stall;
    //     d2_instruct_info <= instruct_info;
    //     if(!d1_stall & d1_valid & !is_jump)
    //         reg_in_use[rt] <= reg_in_use[rt] + 1;
    // end


    // //memory fetch
    // //mem1
    // reg [15:0] m1_pc;
    // reg m1_valid = 1'b0;
    // reg [29:0] m1_instruct_info;
    // reg [15:0] m1_rdata0;
    // reg [15:0] m1_rdata1;



    // always @(posedge clk) begin
    //     m1_pc <= d2_pc;
    //     m1_valid <= d2_valid & !flush;
    //     m1_instruct_info <= d2_instruct_info;
    //     m1_rdata0 <= r_rdata0;
    //     m1_rdata1 <= r_rdata1;
    // end

    // //mem2
    // reg [15:0] m2_pc;
    // reg m2_valid = 1'b0;
    // reg [29:0] m2_instruct_info;
    // reg [15:0] m2_rdata0;
    // reg [15:0] m2_rdata1;

    // always @(posedge clk) begin
    //     m2_pc <= m1_pc;
    //     m2_valid <= m1_valid & !flush;
    //     m2_instruct_info <= m1_instruct_info;
    //     m2_rdata0 <= m1_rdata0;
    //     m2_rdata1 <= m1_rdata1;
    // end

    assign m_raddr1 = z_rdata0;


    //execute
    reg [15:0] e_pc;
    reg e_valid = 0;
    reg [29:0] e_instruct_info;
    reg [15:0] e_rdata0;
    reg [15:0] e_rdata1;

    wire [3:0] e_r0 = e_instruct_info[29:26];
    wire [3:0] e_r1 = e_instruct_info[25:22];
    wire [3:0] e_ra = e_instruct_info[21:18];
    wire [3:0] e_rb = e_instruct_info[17:14];
    wire [3:0] e_rt = e_instruct_info[13:10];
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

    wire [15:0] e0_rdata0 = e_is_r00 ? 16'h0000 : r_rdata0;
    wire [15:0] e0_rdata1 = e_is_r10 ? 16'h0000 : r_rdata1;

    wire [15:0] e1_rdata0 = (for1_valid && for1_rt == e_r0) ? for1_data : e0_rdata0;
    wire [15:0] e1_rdata1 = (for1_valid && for1_rt == e_r1) ? for1_data : e0_rdata1;

    wire [15:0] e2_rdata0 = (for2_valid && for2_rt == e_r0) ? for2_data : e1_rdata0;
    wire [15:0] e2_rdata1 = (for2_valid && for2_rt == e_r1) ? for2_data : e1_rdata1;

    wire [15:0] e3_rdata0 = (for3_valid && for3_rt == e_r0) ? for3_data : e2_rdata0;
    wire [15:0] e3_rdata1 = (for3_valid && for3_rt == e_r1) ? for3_data : e2_rdata1;

    wire [15:0] e4_rdata0 = (for4_valid && for4_rt == e_r0) ? for4_data : e3_rdata0;
    wire [15:0] e4_rdata1 = (for4_valid && for4_rt == e_r1) ? for4_data : e3_rdata1;

    wire [15:0] z_rdata0 = e4_rdata0;
    wire [15:0] z_rdata1 = e4_rdata1;

    wire [15:0] result = e_is_sub ? z_rdata0 - z_rdata1 :
                            e_is_movl ? {{7{e_ra[3]}}, e_ra, e_rb} :
                            e_is_movh ? (z_rdata0 & 16'h00ff) | ({e_ra, e_rb} << 8) :
                            e_is_str ? z_rdata0 : m_rdata1;

    wire [15:0] jump_addr = e_is_jump ? ((e_rb == 4'b0000 ? z_rdata0 == 0 :
                                        e_rb == 4'b0001 ? z_rdata0 != 0 :
                                        e_rb == 4'b0010 ? z_rdata0 < 0 : z_rdata0 >= 0) ? z_rdata1 : e_pc + 2) :
                                e_pc + 2;

    always @(posedge clk) begin
        e_pc <= d1_pc;
        e_valid <= d1_valid & !flush;
        e_instruct_info <= instruct_info;
        // e_rdata0 <= m2_rdata0;
        // e_rdata1 <= m2_rdata1;
    end

    //forward
    reg [15:0] for1_data;
    reg [3:0] for1_rt;
    reg for1_valid = 1'b0;

    reg [15:0] for2_data;
    reg [3:0] for2_rt;
    reg for2_valid = 1'b0;

    reg [15:0] for3_data;
    reg [3:0] for3_rt;
    reg for3_valid = 1'b0;

    reg [15:0] for4_data;
    reg [3:0] for4_rt;
    reg for4_valid = 1'b0;

    always @(posedge clk) begin
        for1_data <= result;
        for1_rt <= e_rt;
        for1_valid <= e_valid;

        for2_data <= for1_data;
        for2_rt <= for1_rt;
        for2_valid <= for1_valid;

        for3_data <= for2_data;
        for3_rt <= for2_rt;
        for3_valid <= for2_valid;

        for4_data <= for3_data;
        for4_rt <= for3_rt;
        for4_valid <= for3_valid;
    end

    //memory
    reg [15:0] m1_pc;
    reg m1_valid = 1'b0;
    reg [15:0] m1_result;
    reg [15:0] m1_jump_addr;
    reg [15:0] m1_rdata0;
    reg [15:0] m1_rdata1;
    reg [15:0] m1_rt;
    reg m1_is_ld;
    reg m1_m_wen;
    reg m1_r_wen;
    reg m1_is_halt;

    always @(posedge clk) begin
        m1_pc <= e_pc;
        m1_valid <= e_valid;
        m1_result <= result;
        m1_jump_addr <= jump_addr;
        m1_rdata0 <= z_rdata0;
        m1_rdata1 <= z_rdata1;
        m1_rt <= e_rt;
        m1_is_ld <= e_valid & e_is_mem_access & e_is_ld;
        m1_m_wen <= e_valid & e_is_mem_access & e_is_str;
        m1_r_wen <= e_valid & (e_rt != 4'b0000) & (e_is_sub | e_is_movl | e_is_movh | e_is_mem_access & e_is_ld);
        m1_is_halt <= e_valid & e_is_halt;
    end

    //mem2
    reg [15:0] m2_pc;
    reg m2_valid = 1'b0;
    reg [15:0] m2_result;
    reg [15:0] m2_jump_addr;
    reg [15:0] m2_rdata0;
    reg [15:0] m2_rdata1;
    reg [15:0] m2_rt;
    reg m2_m_wen;
    reg m2_r_wen;
    reg m2_is_halt;
    reg m2_is_ld;

    always @(posedge clk) begin
        m2_pc <= m1_pc;
        m2_valid <= m1_valid;
        m2_result <= m1_result;
        m2_jump_addr <= m1_jump_addr;
        m2_rdata0 <= m1_rdata0;
        m2_rdata1 <= m1_rdata1;
        m2_rt <= m1_rt;
        m2_m_wen <= m1_m_wen;
        m2_r_wen <= m1_r_wen;
        m2_is_ld <= m1_is_ld;
        m2_is_halt <= m1_is_halt;
    end


    //writeback
    wire flush = (m2_jump_addr != m1_pc) & m2_valid;

    assign m_waddr = m2_rdata0;
    assign m_wdata = m2_rdata1;
    assign r_waddr = m2_rt;
    assign r_wdata = m2_is_ld ? m_rdata1 : m2_result;
    assign m_wen = m2_m_wen;
    assign r_wen = m2_r_wen;

    
    //do something with the pc
    always @(posedge clk) begin
        if (m2_valid & m2_is_halt) halt <= 1;
        // $display("pc: %h", e_pc);
        // $display("is_sub %b", e_is_sub);
        // $display("is_movl %b", e_is_movl);
        // $display("%h", r_wdata);
        // $display("%h", r_waddr);
        if(m2_valid & r_waddr == 4'b0000) $write("%c", r_wdata[7:0]);
    end

    always @(posedge clk) begin
        if(pc == 50) halt <= 1;
        // $display("flush: %b", flush);
        // $display("jump_addr: %h", jump_addr);
        if(flush) begin
            pc <= m2_jump_addr;
            for(i = 0; i < 16; i = i + 1) reg_in_use[i] <= 0;
        end
        else if(d1_stall) pc <= pc;
        else pc <= pc + 2;
    end
endmodule
