`timescale 1ns / 1ps

interface uf_interface (
    input logic clk
);
    logic       rst;
    logic       uart_rx;
    logic       uart_tx;
    
    //내부 관찰 
    logic [7:0] rx_data;
    logic [7:0] tx_data;
endinterface  //uf_interface

class transaction;
    function void display(string name);
        $display("%t : [%s] ", $time, name );
    endfunction //new()
endclass //transaction

module tb_uart_fifo_sv ();

    logic clk;

    uf_interface uf_if (clk);

    uart_top dut (
        .clk(clk),
        .rst(uf_if.rst),
        .uart_rx(uf_if.uart_rx),
        .uart_tx(uf_if.uart_rx)
    );

// ===============================
// 계층적 경로(.)를 통한 강제 연결
// ===============================

    assign uf_if.rx_data = dut.w_rx_data;
    assign uf_if.tx_data = dut.w_tx_fifo_pop_data;

    always #5 clk = ~clk;
    
    initial begin
        clk = 0;
    end

endmodule
