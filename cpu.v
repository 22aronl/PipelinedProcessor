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

    // read from memory
    wire [15:0]something;

    wire [15:0] m_raddr1;
    wire [15:0] m_rdata1;
    reg m_wen;
    wire [15:0] m_wdata;
    wire [15:0] m_waddr;

    // memory
    mem mem(clk,
         pc[15:1],something,m_raddr1[15:1],m_rdata1,m_wen,m_waddr[15:1],m_wdata);


    // registers
    wire [3:0] raddr0;
    wire [3:0] raddr1;
    wire [15:0] rdata0;
    wire [15:0] rdata1;
    wire [3:0] waddr;
    wire [15:0] wdata;
    reg wen;

    regs regs(clk,
        raddr0, rdata0,
        raddr1, rdata1,
        wen, waddr, wdata);

    // fetch
    reg [3:0] counter = 0;

    //decode
    wire [3:0] opcode = something[15:12];
    wire [3:0] ra = something[11:8];
    wire [3:0] rb = something[7:4];
    wire [3:0] rt = something[3:0];

    wire is_sub = opcode == 4'b0000;
    wire is_movl = opcode == 4'b1000;
    wire is_movh = opcode == 4'b1001;
    wire is_jump = opcode == 4'b1110;
    wire is_mem_access = opcode == 4'b1111;
    wire is_str = rb == 4'b0001;

    assign raddr0 = is_sub ? ra :
                    is_movh ? rt : 
                    is_jump ? ra :
                    ra;
    assign raddr1 = rt;

    assign m_raddr1 = rdata0;

    wire [15:0] mov = is_str;
    //execute
    wire [15:0] result = is_sub ? rdata0 - rdata1 : 
                        is_movl ? {{7{ra[3]}}, ra, rb} : 
                        is_movh ?  (rdata0 & 8'hff) | (something[11:4] << 8): //(rdata0 & 0xff) | (something[11:4] << 8)
                        is_str ? raddr1 : m_rdata1;

    wire [15:0] jump_addr = (rb == 4'b0000 ? rdata0 == 0 : rb == 4'b0001 ? rdata0 != 0 :
                                    rb == 4'b0010 ? rdata0 < 0 : rdata0 >= 0) ? rdata1 : pc + 2;
    assign m_wdata = rdata0;
    assign m_wdata = rdata1;
    assign waddr = rt;
    assign wdata = result;
    always @(posedge clk) begin
        if (pc == 10) begin
            halt <= 1;
        end
        $write("pc = %d\n",pc);

        counter <= counter + 1;

        if (counter == 7) begin
            if(is_jump) pc <= jump_addr;
            else begin 
                pc <= pc + 1;
                if(is_mem_access && is_str) begin
                    m_wen <= 1;
                end
                else begin
                    wen <= 1;
                end
            end
        end

        if(counter == 8) begin
            counter <= 0;
        end
    end


endmodule
