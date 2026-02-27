`timescale 1ns / 1ps

module btn_debounce (
    input  clk,
    input  reset,
    input  i_btn,
    output o_btn
);
    parameter CLK_DIV = 100_000;
    parameter F_COUNT = 100_000_000 / CLK_DIV;
    reg [$clog2(F_COUNT)-1:0] counter_reg;
    reg                       clk_100khz_reg;

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            counter_reg <= 0;
            clk_100khz_reg <= 1'b0;
        end else begin
            counter_reg <= counter_reg + 1;
            if (counter_reg == (F_COUNT - 1)) begin
                counter_reg <= 0;
                clk_100khz_reg <= 1'b1;
            end else begin
                clk_100khz_reg <= 1'b0;
            end
        end
    end

    reg [7:0] q_reg, q_next;
    wire debounce;

    always @(posedge clk_100khz_reg, posedge reset) begin
        if (reset) begin
            q_reg <= 0;
        end else begin
            q_reg <= q_next;  //출력은 q_reg 
        end
    end

    //next CL
    always @(*) begin
        q_next = {i_btn, q_reg[7:1]};
    end

    //debounce 8input AND 
    assign debounce = &q_reg;
    reg edge_reg;

    //edge detection
    always @(posedge clk, posedge reset) begin  // edge는 100M에 하나 감 
        if (reset) begin
            edge_reg <= 1'b0;
        end else begin
            edge_reg <= debounce;
        end
    end

    //여기까지 Q5 신호까지 제작함 
    assign o_btn = debounce & (~edge_reg);

    //debounce는 제작 끝 

endmodule
