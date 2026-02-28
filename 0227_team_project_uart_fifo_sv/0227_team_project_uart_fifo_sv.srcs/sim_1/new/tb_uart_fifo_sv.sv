`timescale 1ns / 1ps

interface uf_interface (
    input logic clk
);

    parameter BAUD = 9600;
    parameter BAUD_PERIOD = (100_000_000 / BAUD) * 10;  // 예상 = 104_160

    logic       rst;
    logic       uart_rx;
    logic       uart_tx;

    //내부 관찰 
    logic [7:0] rx_data;
    logic [7:0] tx_data;
    logic       b_tick;
    logic       rx_push;
    logic       rx_pop;
    logic       tx_push;
    logic       tx_pop;
endinterface  //uf_interface

class transaction;

    rand bit [7:0] rx_data;

    logic          rx_push;
    logic          rx_pop;
    logic          tx_push;
    logic          tx_pop;

    logic          uart_rx;
    logic          uart_tx;
    logic          b_tick;
    logic    [7:0] tx_data;

    function void display(string name);
        $display("%t : [%s] ", $time, name);
    endfunction  //new()
endclass  //transaction

class generator;

    transaction tr;
    mailbox #(transaction) gen2drv_mbox;
    event gen_next_ev;

    function new(mailbox#(transaction) gen2drv_mbox, event gen_next_ev);
        this.gen2drv_mbox = gen2drv_mbox;
        this.gen_next_ev  = gen_next_ev;
    endfunction  //new()

    task run(int run_count);
        repeat (run_count) begin
            tr = new;
            tr.randomize();
            gen2drv_mbox.put(tr);
            tr.display("gen");
            @(gen_next_ev);
        end
    endtask  //run
endclass  //generator

class driver;

    transaction tr;
    mailbox #(transaction) gen2drv_mbox;
    virtual uf_interface uf_if;

    function new(mailbox#(transaction) gen2drv_mbox,
                 virtual uf_interface uf_if);
        this.gen2drv_mbox = gen2drv_mbox;
        this.uf_if = uf_if;
    endfunction  //new()

    task preset();
        uf_if.rst = 1;
        uf_if.uart_rx = 1;
        @(negedge uf_if.clk);
        @(negedge uf_if.clk);
        uf_if.rst = 0;
        @(negedge uf_if.clk);
    endtask  //preset

    task run();
        forever begin
            gen2drv_mbox.get(tr);
            @(posedge uf_if.clk);
            #1;
            tr.display("drv");

            uf_if.uart_rx = 1'b0; // rx 선을 0으로 내려서 통신 시작 알림
            #(uf_if.BAUD_PERIOD);

            //random data rx 선으로 밀어 넣기 
            for (int i = 0; i < 8; i++) begin
                uf_if.uart_rx = tr.rx_data[i];
                #(uf_if.BAUD_PERIOD);
            end
            uf_if.uart_rx = 1'b1;
            #(uf_if.BAUD_PERIOD);
        end
    endtask

endclass  //driver

class monitor;

    transaction tr;
    mailbox #(transaction) mon2scb_mbox;
    virtual uf_interface uf_if;

    function new(mailbox#(transaction) mon2scb_mbox,
                 virtual uf_interface uf_if);
        this.mon2scb_mbox = mon2scb_mbox;
        this.uf_if = uf_if;
    endfunction  //new()

    task run();
        forever begin
            tr = new;
            @(negedge uf_if.rx_push);
            #1;
            tr.rx_data = uf_if.rx_data;
            tr.uart_rx = uf_if.uart_rx;
            tr.uart_tx = uf_if.uart_tx;
            tr.tx_data = uf_if.tx_data;
            tr.b_tick  = uf_if.b_tick;
            tr.rx_push = uf_if.rx_push;
            tr.rx_pop  = uf_if.rx_pop;
            tr.tx_push = uf_if.tx_push;
            tr.tx_pop  = uf_if.tx_pop;
            tr.display("mon");
            mon2scb_mbox.put(tr);
        end
    endtask  //run

endclass  //monitor

class scorboard;

    transaction tr;
    mailbox #(transaction) mon2scb_mbox;
    event gen_next_ev;

    //queue 
    logic [7:0] uart_queue[$:16];  //size 지정 안하면 무한대 
    logic [7:0] compare_data;

    function new(mailbox#(transaction) mon2scb_mbox, event gen_next_ev);
        this.mon2scb_mbox = mon2scb_mbox;
        this.gen_next_ev  = gen_next_ev;
    endfunction  //new()

    task run();
        forever begin
            mon2scb_mbox.get(tr);
            tr.display("scb");

            ->gen_next_ev;
        end

    endtask  //run

endclass  //scorboard

class environment;
    function new();
        
    endfunction //new()
endclass //environment

module tb_uart_fifo_sv ();

    logic clk;

    uf_interface uf_if (clk);

    uart_top dut (
        .clk(clk),
        .rst(uf_if.rst),
        .uart_rx(uf_if.uart_rx),
        .uart_tx(uf_if.uart_tx)
    );

    // ===============================
    // 계층적 경로(.)를 통한 강제 연결
    // ===============================

    assign uf_if.rx_data = dut.w_rx_data;
    assign uf_if.tx_data = dut.w_tx_fifo_pop_data;
    assign uf_if.b_tick  = dut.w_b_tick;
    //assign uf_if.rx_done = dut.w_rx_done;
    assign uf_if.rx_push = dut.w_rx_done;
    assign uf_if.rx_pop  = ~dut.w_tx_fifo_full;
    assign uf_if.tx_push = ~dut.w_rx_fifo_empty;
    assign uf_if.tx_pop  = ~dut.w_tx_busy;

    always #5 clk = ~clk;

    initial begin
        clk = 0;
    end

endmodule
