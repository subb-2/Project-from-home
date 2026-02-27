`timescale 1ns / 1ps

module tb_uart_tx();

    parameter BAUD_9600 = 104_160; // 1tick의 시간 

    reg clk, rst, btn_down; //btn_down 최소 100usec 끌어주기 
    wire uart_tx;

    uart_top dut (
        .clk(clk),
        .rst(rst),
        .btn_down(btn_down),
        .uart_tx(uart_tx)
    );

    //clock
    always #5 clk = ~clk;

    initial begin
        #0;
        clk = 0;
        rst = 1;
        btn_down = 1'b0;
        #20;
        //reset
        rst = 0;

        //btn down, tx start
        btn_down = 1'b1;
        #100_000; //100us
        btn_down = 1'b0;

        //#(104_160)
        #(BAUD_9600 * 16);
        $stop;

    end

endmodule