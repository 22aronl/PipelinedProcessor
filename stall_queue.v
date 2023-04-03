module stall_queue(
    input clk, input flush, input stall, input [15:0] cur_instruction,
    output use_q, output [15:0] out_instruction);

    reg [15:0] buffer [0:1];
    reg [1:0] head = 2'b00;
    reg [1:0] tail = 2'b00;
    reg [1:0] stall_time = 2'b00;

    //I think max stall time is 2 cycles
    assign out_instruction = buffer[(head + 1)%2];
    assign use_q = (stall) | stall_time != 2'b00;

    always @(posedge clk) begin
        if(flush) begin
            head <= 2'b00;
            tail <= 2'b00;
            stall_time <= 2'b00;
        end
        else if (stall) begin
            stall_time <= stall_time + 1;
            buffer[tail] <= cur_instruction;
            tail <= (tail + 1) % 2;
        end
        else if(stall_time > 2'b00) begin
            stall_time <= stall_time - 1;
            head <= (head + 1) % 2;
        end
    end

endmodule