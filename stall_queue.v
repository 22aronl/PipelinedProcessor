module stall_queue(
    input clk, input flush, input stall, input [15:0] cur_instruction,
    output use_q, output [15:0] out_instruction);

    parameter SIZE = 5;
    reg [15:0] buffer [0: SIZE - 1];
    reg [3:0] head = 3'b000;
    reg [3:0] tail = 3'b000;
    reg [1:0] stall_time = 2'b00;
    reg [1:0] stall_counter = 2'b00;
    reg [15:0] previous;

    //Assume that stalls are always 1 cycle long.
    assign use_q = stall | stall_time != 2'b00;
    assign out_instruction = stall ? previous : cur_instruction;//

    wire [15:0] a = buffer[0];
    wire [15:0] b = buffer[1];
    wire [15:0] c = buffer[2];
    wire [15:0] d = buffer[3];
    wire [15:0] e = buffer[4];


    always @(posedge clk) begin
        previous <= cur_instruction;
        if(flush) begin
            stall_time <= 2'b00;
            stall_counter <= 2'b00;
            head <= 3'b000;
            tail <= 3'b000;
        end
        else if (stall) begin
            if(stall_counter == 2'b00)
                stall_counter <= 2'b01;
        end

        if(!stall) head <= (head + 1) % SIZE;

        if(stall_counter == 2'b00) begin
            buffer[tail] <= cur_instruction;
            tail <= (tail + 1) % SIZE;
        end
        else if(stall_counter != 2'b00 && stall_counter <= 2'b10) begin
            buffer[tail] <= cur_instruction;
            tail <= (tail + 1) % SIZE;
            stall_counter <= stall_counter + 1;
        end
        else if(stall_counter > 2'b10) begin
            stall_counter <= 2'b00;
        end

    end

endmodule