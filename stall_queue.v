module stall_queue(
    input clk, input flush, input stall, input [15:0] cur_instruction,
    output use_q, output [15:0] out_instruction);

    parameter SIZE = 5;
    reg [15:0] buffer [0: SIZE - 1];
    reg [2:0] head = 3'b000;
    reg [2:0] tail = 3'b000;
    reg [2:0] stall_time = 3'b000;
    reg [1:0] stall_counter = 2'b00;
    reg [2:0] overall_counter = 3'b000;
    reg [15:0] previous;
    reg [2:0] delay = 3'b000;

    //Assume that stalls are always 1 cycle long.
    assign use_q = stall | stall_time != 2'b00;
    assign out_instruction = stall ? previous : 
                        (stall_time == 3'b000) ? cur_instruction :
                        buffer[(head + SIZE - delay) % SIZE];

    reg p1 = 1'b1;
    reg p2 = 1'b1;
    reg p3 = 1'b1;

    always @(posedge clk) begin
        previous <= cur_instruction;
        if(flush) begin
            head <= 3'b000;
            tail <= 3'b000;
            stall_time <= 3'b000;
            stall_counter <= 2'b00;
            overall_counter <= 3'b000;
            p1 <= 1'b1;
            p2 <= 1'b1;
            p3 <= 1'b1;
        end

        if(stall) begin
            stall_time <= (stall_time + 1) % SIZE;
            stall_counter <= stall_counter + 1;
            p1 <= 1'b0;
        end
        else begin
            p1 <= 1'b1;
            head <= (head + 1) % (SIZE);
        end

        p2 <= p1;
        p3 <= p2;
        if(p3) begin
            buffer[tail] <= cur_instruction;
            tail <= (tail + 1) % SIZE;
        end
        else 
            stall_time <= (stall_time + SIZE - 1) % SIZE;
    end
endmodule