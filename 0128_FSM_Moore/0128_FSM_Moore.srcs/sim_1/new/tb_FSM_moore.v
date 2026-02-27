`timescale 1ns / 1ps

module tb_FSM_moore();

reg clk, reset;
reg sw;
wire led;

FSM_moore dut(
    .clk(clk),
    .reset(reset),
    .sw(sw),
    .led(led)
);

always #5 clk = ~clk;

initial begin
    #0;
    clk = 0;
    reset = 1;
    sw = 1'b0;

    #10;
    reset = 0;
    sw = 1'b1;

    #20;
    sw = 1'b0;

    #20;
    sw = 1'b0;

    #20;
    sw = 1'b1;

    #20;
    sw = 1'b1;

    #20;
    sw = 1'b0;

    #20;
    sw = 1'b0;

    #100;
    $stop;

end

endmodule
