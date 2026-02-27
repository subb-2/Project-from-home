`timescale 1ns / 1ps

module fifo #(
    parameter DEPTH = 4,
    BIT_WIDTH = 8
 ) (
    input        clk,
    input        rst,
    input        push,
    input        pop,
    input  [7:0] push_data,
    output [7:0] pop_data,
    output       full,
    output       empty
);

    wire [$clog2(DEPTH) - 1:0] w_wptr, w_rptr;

    register_file #(
        .DEPTH(DEPTH), 
        .BIT_WIDTH(BIT_WIDTH)
        ) U_REG_FILE (
        .clk(clk),
        .push_data(push_data),
        .w_addr(w_wptr),
        .r_addr(w_rptr),
        .we(push & (~full)),
        .pop_data(pop_data)
    );

    control_unit_fifo #(
        .DEPTH(DEPTH)
    )U_CONTROL_UNIT_FIFO (
        .clk(clk),
        .rst(rst),
        .push(push),
        .pop(pop),
        .wptr(w_wptr),
        .rptr(w_rptr),
        .full(full),
        .empty(empty)
    );

endmodule

module register_file #(
    parameter DEPTH = 4,
    BIT_WIDTH = 8
) (
    input                        clk,
    input  [    BIT_WIDTH - 1:0] push_data,
    input  [$clog2(DEPTH) - 1:0] w_addr,
    input  [$clog2(DEPTH) - 1:0] r_addr,
    input                        we,
    output [    BIT_WIDTH - 1:0] pop_data
);

    //ram
    reg [BIT_WIDTH - 1:0] register_file[0:(DEPTH - 1)];
    //메모리는 초기화 안함 
    //push, to register_file
    always @(posedge clk) begin
        if (we) begin
            //push
            register_file[w_addr] <= push_data; //w_addr는 control 로직에서 알려줌
        end 
    end

    //pop
    assign pop_data = register_file[r_addr];
endmodule

module control_unit_fifo #(
    parameter DEPTH = 4
) (
    input                        clk,
    input                        rst,
    input                        push,
    input                        pop,
    output [$clog2(DEPTH) - 1:0] wptr,
    output [$clog2(DEPTH) - 1:0] rptr,
    output                       full,
    output                       empty
);

    //state 선언
    reg [1:0] c_state, n_state;
    reg [$clog2(DEPTH)-1:0] wptr_reg, wptr_next, rptr_reg, rptr_next;
    reg full_reg, full_next, empty_reg, empty_next;

    assign wptr  = wptr_reg;
    assign rptr  = rptr_reg;
    assign full  = full_reg;
    assign empty = empty_reg;

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            c_state = 2'b00;
            wptr_reg  <= 0;
            rptr_reg  <= 0;
            full_reg  <= 0;
            empty_reg <= 1'b1;  //초기상태 이걸로 대체 
        end else begin
            c_state   <= n_state;
            wptr_reg  <= wptr_next;
            rptr_reg  <= rptr_next;
            full_reg  <= full_next;
            empty_reg <= empty_next;
        end
    end

    //next st, output
    always @(*) begin
        n_state    = c_state;
        wptr_next  = wptr_reg;
        rptr_next  = rptr_reg;
        full_next  = full_reg;
        empty_next = empty_reg;
        case ({
            push, pop
        })
            //push 
            2'b10: begin
                if(!full) begin
                    wptr_next = wptr_reg + 1;
                    empty_next = 1'b0;
                    if (wptr_next == rptr_reg) begin
                        //왜 next와 비교해?
                        full_next = 1'b1;
                    end
                end
            end
            //pop
            2'b01: begin
                if(!empty) begin
                    rptr_next = rptr_reg + 1;
                    full_next = 1'b0;
                    if (wptr_reg == rptr_next) begin
                        empty_next = 1'b1;
                    end
                end
            end
            //push,pop
            2'b11: begin
                if (full_reg == 1'b1) begin
                    rptr_next = rptr_reg + 1;
                    full_next = 1'b0;
                end else if (empty_reg == 1'b1) begin
                    wptr_next = wptr_reg + 1;
                    empty_next = 1'b0;
                end else begin
                    wptr_next = wptr_reg + 1;
                    rptr_next = rptr_reg + 1;
                end
            end

        endcase
    end

endmodule