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
    wire use_q;
    //why do used variables in a module have to be declared before?
    wire [15:0] d1_instruction;
    wire flush;

    stall_queue buffers (
        .clk(clk),
        .flush(flush),
        .stall(d1_stall),
        .cur_instruction(instruction),
        .use_q(use_q),
        .out_instruction(d1_instruction)
    );

    wire [15:0] d1_instruction_wire = d1_instruction;//use_q ? d1_instruction : instruction;

    wire [3:0] opcode = d1_instruction_wire[15:12];
    wire [3:0] ra = d1_instruction_wire[11:8];
    wire [3:0] rb = d1_instruction_wire[7:4];
    wire [3:0] rt = d1_instruction_wire[3:0];

    //is there a better way of doing this?
    wire is_sub = opcode == 4'b0000;
    wire is_movl = opcode == 4'b1000;
    wire is_movh = opcode == 4'b1001;
    //add check for the individual jumps
    wire is_jump = opcode == 4'b1110;
    wire is_mem_access = opcode == 4'b1111;
    wire is_ld = is_mem_access && rb == 4'b0000;
    wire is_str = is_mem_access && rb == 4'b0001;
    wire is_halt = !(is_sub | is_movl | is_movh | (is_jump & rb >= 4'b0000 & rb <= 4'b0011) | (is_mem_access && (is_ld | is_str)));

    assign r_raddr0 = is_movh ? rt : ra;
    assign r_raddr1 = is_sub ? rb : rt;

    wire is_r00 = r_raddr0 == 4'b0000;
    wire is_r10 = r_raddr1 == 4'b0000;


    //same here
    wire [29:0] instruct_info = {r_raddr0, r_raddr1, ra, rb, rt, is_sub, is_movl, is_movh, is_jump, is_mem_access, is_ld, is_str, is_halt, is_r00, is_r10};

    always @(posedge clk) begin
        d1_pc <= d1_stall ? d1_pc : f1_pc;
        d1_valid <= d1_stall ? d1_valid : f1_valid & !flush;
        //d1_instruction <= d1_stall ? d1_instruction : instruction;

        //d1_instruct_info <= instruct_info;
    end

    // //decode 2
    // reg [15:0] d2_pc;
    // reg d2_valid = 1'b0;
    // reg [21:0] d2_instruct_info;

    // always @(posedge clk) begin
    //     d2_pc <= d1_pc;
    //     d2_valid <= d1_valid & !flush & !d1_stall;
    //     d2_instruct_info <= instruct_info;
    //     if(!d1_stall & d1_valid & !is_jump)
    //         reg_in_use[rt] <= reg_in_use[rt] + 1;
    // end

    //memory fetch
    //mem1
    reg [15:0] m1_pc;
    reg m1_valid = 1'b0;
    reg [29:0] m1_instruct_info;
    reg [15:0] m1_rdata0;
    reg [15:0] m1_rdata1;
    reg m1_is_ld = 1'b0;
    reg [3:0] m1_ra;
    reg [3:0] m1_rt;


    //TODO: Load forwarding is not correct
    //wire pull_forward = m1_valid & e_valid & m1_is_ld & (m1_ra == e_rt);
    wire [15:0] m1_r3_rdata0 = (e_forward3_valid & m1_ra == e_forward3_addr & !e3_is_str) ? e_forward3_data : r_rdata0;
    wire [15:0] m1_r0_rdata0 = (e_forward2_valid & m1_ra == e_forward2_addr & !e2_is_str) ? e_forward2_data : m1_r3_rdata0;
    wire [15:0] m1_r1_rdata0 = (e_forward_valid & m1_ra == e_forward_addr & !e_is_str) ? e_forward_data : m1_r0_rdata0;

    assign m_raddr1 = m1_r1_rdata0;//pull_forward ? result : m1_instruct_info[1] ? r_rdata0 : 16'h0000;

    //wire next_stall = m1_valid & m2_valid & m1_is_ld & (m1_ra == m2_rt);
    assign d1_stall = m1_valid & m2_valid & m1_is_ld & (m1_ra == m2_rt) & m2_is_ld;

    always @(posedge clk) begin
        m1_pc <= d1_stall ? m1_pc : d1_pc;
        m1_valid <= d1_stall ? m1_valid : d1_valid & !flush;
        m1_instruct_info <= d1_stall ? m1_instruct_info : instruct_info;
        m1_is_ld <= d1_stall ? m1_is_ld : is_ld;
        m1_ra <= d1_stall ? m1_ra : ra;
        m1_rt <= d1_stall ? m1_rt : rt;
        m1_rdata0 <= r_rdata0;
        m1_rdata1 <= r_rdata1;
    end

    //mem2
    reg [15:0] m2_pc;
    reg m2_valid = 1'b0;
    reg [29:0] m2_instruct_info;
    reg [15:0] m2_rdata0;
    reg [15:0] m2_rdata1;

    wire [3:0] m2_r0 = m2_instruct_info[29:26];
    wire [3:0] m2_r1 = m2_instruct_info[25:22];
    wire [3:0] m2_ra = m2_instruct_info[21:18];
    wire [3:0] m2_rb = m2_instruct_info[17:14];
    wire [3:0] m2_rt = m2_instruct_info[13:10];
    wire m2_is_sub = m2_instruct_info[9];
    wire m2_is_movl = m2_instruct_info[8];
    wire m2_is_movh = m2_instruct_info[7];
    wire m2_is_jump = m2_instruct_info[6];
    wire m2_is_mem_access = m2_instruct_info[5];
    wire m2_is_ld = m2_instruct_info[4];
    wire m2_is_str = m2_instruct_info[3];
    wire m2_is_halt = m2_instruct_info[2];
    wire m2_is_r00 = m2_instruct_info[1];
    wire m2_is_r10 = m2_instruct_info[0];

    wire [15:0] m2_r0_rdata0 = (e_forward3_valid & m2_r0 == e_forward3_addr & !e3_is_str) ? e_forward3_data : m2_rdata0;
    wire [15:0] m2_r0_rdata1 = (e_forward3_valid & m2_r1 == e_forward3_addr & !e3_is_str) ? e_forward3_data : m2_rdata1;

    wire [15:0] m2_data0 = (e_forward2_valid & m2_r0 == e_forward2_addr & !e2_is_str) ? e_forward2_data : m2_r0_rdata0;
    wire [15:0] m2_data1 = (e_forward2_valid & m2_r1 == e_forward2_addr & !e2_is_str) ? e_forward2_data : m2_r0_rdata1;

    wire [15:0] m2_result = m2_is_sub ? m2_data0 - m2_data1 :
                            m2_is_movl ? {{7{m2_ra[3]}}, m2_ra, m2_rb} :
                            m2_is_movh ? (m2_data0 & 16'h00ff) | ({m2_ra, m2_rb} << 8) :
                            m2_is_str ? m2_data0 : m_rdata1;

    wire m2_jump_taken = (m2_rb == 4'b0000 ? m2_data0 == 0 :
                            m2_rb == 4'b0001 ? m2_data0 != 0 :
                            m2_rb == 4'b0010 ? m2_data0[15] == 1 : m2_data0[15] == 0);

    wire [15:0] m2_jump_addr =  m2_is_jump & m2_jump_taken ? m2_data1 : m2_pc + 2;

    assign flush = m2_valid & m1_valid & m2_jump_addr != m1_pc;

    assign m_waddr = m2_data0;
    assign m_wdata = m2_data1;
    assign m_wen = m2_valid & m2_is_mem_access & m2_is_str;


    always @(posedge clk) begin
        m2_pc <= m1_pc;
        m2_valid <= m1_valid & !flush & !d1_stall;
        m2_instruct_info <= m1_instruct_info;
        m2_rdata0 <= r_rdata0;
        m2_rdata1 <= r_rdata1;
    end

    //execute
    reg [15:0] e_pc;
    reg e_valid = 0;
    reg [3:0] e_rt = 1'b0;
    reg [15:0] e_result = 1'b0;
    reg e_reg_write;
    reg e_is_halt;
    reg e_is_ld;

    wire e_forward_valid = m2_valid;
    wire [15:0] e_forward_data = m2_rt == 4'b0000 ? 16'h0000 : m2_result;
    wire [3:0] e_forward_addr = m2_rt;
    wire e_is_str = m2_is_str;

    reg e_forward2_valid = 1'b0;
    reg [15:0] e_forward2_data_;
    wire [15:0] e_forward2_data = e_forward2_addr == 4'b0000 ? 16'h0000 : e_is_ld ? e_forward2_use_mdata ? e_forward2_mdata : m_rdata1 : e_forward2_data_;
    reg [3:0] e_forward2_addr;
    reg e2_is_str = 1'b0;
    reg [15:0] e_forward2_mdata;
    reg e_forward2_use_mdata;

    reg e_forward3_valid = 1'b0;
    reg [15:0] e_forward3_data;
    reg [3:0] e_forward3_addr;
    reg e3_is_str = 1'b0;

    always @(posedge clk) begin
        e_forward2_valid <= !m2_valid ? e_forward2_valid : e_forward_valid;
        e_forward2_data_ <= !m2_valid ? e_forward2_data : (e_forward_addr == 4'b0000) ? 16'h0000 : e_forward_data;
        e_forward2_addr <= !m2_valid ? e_forward2_addr : e_forward_addr;
        e_forward2_mdata <= m_rdata1;
        e_forward2_use_mdata <= !m2_valid;
        e2_is_str <= !m2_valid ? e2_is_str : e_is_str;

        e_forward3_valid <= !m2_valid ? e_forward3_valid : e_forward2_valid;
        e_forward3_data <= !m2_valid ? e_forward3_data : e_forward2_data;
        e_forward3_addr <= !m2_valid ? e_forward3_addr : e_forward2_addr;
        e3_is_str <= !m2_valid ? e3_is_str : e2_is_str;
    end

    always @(posedge clk) begin
        e_pc <= m2_pc;
        e_valid <= m2_valid;
        e_rt <= m2_rt;
        e_result <= m2_result;
        e_reg_write <= m2_is_sub | m2_is_movl | m2_is_movh | m2_is_ld & m2_is_mem_access;
        e_is_halt <= m2_is_halt;
        e_is_ld <= m2_valid ? m2_is_ld & m2_is_mem_access : e_is_ld;
    end

    reg zeroAssign = 1'b1;

    assign r_waddr = e_rt;
    assign r_wdata = e_valid & e_is_ld ? m_rdata1 : e_result;
    assign r_wen = zeroAssign | (e_valid & (r_waddr != 4'b0000) & e_reg_write);


    // //execute
    // reg [15:0] e_pc;
    // reg e_valid = 0;
    // reg [29:0] e_instruct_info;
    // reg [15:0] e_rdata0;
    // reg [15:0] e_rdata1;
    // reg [15:0] 

    // wire [3:0] e_r0 = e_instruct_info[29:26];
    // wire [3:0] e_r1 = e_instruct_info[25:22];
    // wire [3:0] e_ra = e_instruct_info[21:18];
    // wire [3:0] e_rb = e_instruct_info[17:14];
    // wire [3:0] e_rt = e_instruct_info[13:10];
    // wire e_is_sub = e_instruct_info[9];
    // wire e_is_movl = e_instruct_info[8];
    // wire e_is_movh = e_instruct_info[7];
    // wire e_is_jump = e_instruct_info[6];
    // wire e_is_mem_access = e_instruct_info[5];
    // wire e_is_ld = e_instruct_info[4];
    // wire e_is_str = e_instruct_info[3];
    // wire e_is_halt = e_instruct_info[2];
    // wire e_is_r00 = e_instruct_info[1];
    // wire e_is_r10 = e_instruct_info[0];

    // wire [15:0] e0_rdata0 = e_is_r00 ? 16'h0000 : e_rdata0;
    // wire [15:0] e0_rdata1 = e_is_r10 ? 16'h0000 : e_rdata1;

    // wire [15:0] e3_rdata0 = (for3_valid && for3_rt == e_r0) ? for3_data : e0_rdata0;
    // wire [15:0] e3_rdata1 = (for3_valid && for3_rt == e_r1) ? for3_data : e0_rdata1;

    // wire [15:0] e2_rdata0 = (for2_valid && for2_rt == e_r0) ? for2_data : e3_rdata0;
    // wire [15:0] e2_rdata1 = (for2_valid && for2_rt == e_r1) ? for2_data : e3_rdata1;

    // wire [15:0] e1_rdata0 = (for1_valid && for1_rt == e_r0) ? for1_data : e2_rdata0;
    // wire [15:0] e1_rdata1 = (for1_valid && for1_rt == e_r1) ? for1_data : e2_rdata1;

    // wire [15:0] z_rdata0 = e1_rdata0;
    // wire [15:0] z_rdata1 = e1_rdata1;

    // wire [15:0] result = e_is_sub ? z_rdata0 - z_rdata1 :
    //                         e_is_movl ? {{7{e_ra[3]}}, e_ra, e_rb} :
    //                         e_is_movh ? (z_rdata0 & 16'h00ff) | ({e_ra, e_rb} << 8) :
    //                         e_is_str ? z_rdata0 : m_rdata1;

    // wire [15:0] jump_addr = e_is_jump ? ((e_rb == 4'b0000 ? z_rdata0 == 0 :
    //                                     e_rb == 4'b0001 ? z_rdata0 != 0 :
    //                                     e_rb == 4'b0010 ? z_rdata0 < 0 : z_rdata0 >= 0) ? z_rdata1 : e_pc + 2) :
    //                             e_pc + 2;



    // always @(posedge clk) begin
    //     e_pc <= m2_pc;
    //     e_valid <= m2_valid & !flush;
    //     e_instruct_info <= m2_instruct_info;
    //     e_rdata0 <= m2_rdata0;
    //     e_rdata1 <= m2_rdata1;
    // end

    // //forwarding
    // //TODO: only forward when execute is valid
    // reg [15:0] for1_data;
    // reg [3:0] for1_rt;
    // reg [1:0] for1_valid = 2'b00;

    // reg [15:0] for2_data;
    // reg [3:0] for2_rt;
    // reg [1:0] for2_valid = 2'b00;

    // reg [15:0] for3_data;
    // reg [3:0] for3_rt;
    // reg [1:0] for3_valid = 2'b00;

    // always @(posedge clk) begin
    //     //$display("m_rdata1: %h", m_rdata1);
    //     //$display("for1_data: %h, for1_rt: %h, for1_valid: %h", for1_data, for1_rt, for1_valid);
    //     for1_data <= e_valid ? (e_rt==4'b0000) ? 0 : result : for1_data;
    //     for1_rt <= e_valid  ? e_rt : for1_rt;
    //     for1_valid <= e_valid ? 1'b1 : for1_valid;

    //     //$display("for2_data: %h, for2_rt: %h, for2_valid: %h", for2_data, for2_rt, for2_valid);
    //     for2_data <= e_valid ? for1_data : for2_data;
    //     for2_rt <= e_valid ? for1_rt : for2_rt;
    //     for2_valid <= e_valid ? for1_valid : for2_valid;

    //     for3_data <= e_valid ? for2_data : for3_data;
    //     for3_rt <= e_valid  ? for2_rt : for3_rt;
    //     for3_valid <= e_valid ? for2_valid : for3_valid;

    // end

    // reg [15:0] stored_jump_addr;
    // reg check_valid = 1'b0;

    // always @(posedge clk) begin
    //     stored_jump_addr <= e_valid ? jump_addr : stored_jump_addr;
    //     check_valid <= e_valid;
    // end

    //Todo: i have no idea if this works or not
    //writeback
    //assign flush = 0;//((jump_addr != m2_pc) & e_valid & m2_valid) | (check_valid & !e_valid & m2_valid & (stored_jump_addr != m2_pc));

    
    
    reg should_write_more = 1'b1;
    //do something with the pc
    always @(posedge clk) begin
	if (e_valid & e_is_halt) begin 
	    halt <= 1;
        should_write_more <= 0;
	end
        // $display("pc: %h", e_pc);
        // $display("is_sub %b", e_is_sub);
        // $display("is_movl %b", e_is_movl);
        // $display("%h", r_wdata);
        // $display("%h", r_waddr);
        if(should_write_more & e_valid & r_waddr == 4'b0000) $write("%c", r_wdata[7:0]);
    end

    always @(posedge clk) begin
        // if(pc > 50)
        //     halt <= 1;

        if(zeroAssign)
            zeroAssign <= zeroAssign - 1;
        // $display("flush: %b", flush);
        // $display("jump_addr: %h", jump_addr);
        if(flush) begin
            pc <= m2_jump_addr;
        end
        else if(d1_stall) pc <= pc;
        else pc <= pc + 2;
    end
endmodule
