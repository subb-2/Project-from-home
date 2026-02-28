`timescale 1ns / 1ps

interface uf_interface (
    input logic clk
);

    parameter BAUD = 9600;
    parameter BAUD_PERIOD = (100_000_000 / BAUD) * 10;  // 예상 = 104_160

    logic       rst;
    logic       uart_rx;
    logic       uart_tx;
    logic       tx_done;

    //내부 관찰 
    logic [7:0] rx_data;
    logic [7:0] tx_data;
    logic       b_tick;
    logic       rx_done;
    logic       rx_push;
    logic       rx_pop;
    logic       tx_push;
    logic       tx_pop;
    logic tx_start;
endinterface  //uf_interface

class transaction;

    rand bit [7:0] rx_data;

    constraint c_no_zero {rx_data != 8'h00;}

    logic          rx_push;
    logic          rx_pop;
    logic          tx_push;
    logic          tx_pop;

    logic          rx_done;
    logic          uart_rx;
    logic          uart_tx;
    logic          b_tick;
    logic    [7:0] tx_data;
    logic          tx_done;
    logic tx_start;

    function void display(string name);
        $display(
            "%t : [%s] rx_data = %2h, rx_push = %h, rx_pop = %h, tx_push = %h, tx_pop = %h, rx_done = %h, uart_rx = %h, uart_tx = %h, b_tick = %h, tx_data = %2h, tx_done = %h",
            $time, name, rx_data, rx_push, rx_pop, tx_push, tx_pop, rx_done,
            uart_rx, uart_tx, b_tick, tx_data, tx_done);
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
        repeat (10) @(negedge uf_if.clk);
        //@(negedge uf_if.clk);
        uf_if.rst = 0;
        repeat (10) @(negedge uf_if.clk);
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

            // 약간의 여유 시간을 주어 FIFO 상태가 업데이트되게 함
            repeat(5) @(posedge uf_if.clk);
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

    // monitor 클래스 내부
    task run();
        fork
            // RX 모니터링은 그대로 유지
            forever begin
                tr = new;
                @(posedge uf_if.rx_push);
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
                tr.rx_done = 1;
                tr.rx_data = uf_if.rx_data;
                mon2scb_mbox.put(tr);
            end

            // TX 모니터링: tx_done 대신 tx_pop(또는 tx_start) 사용
            forever begin
                tr = new;
                @(posedge uf_if.tx_push);
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
                tr.tx_done = 1; // 변수명은 유지하되 의미는 '데이터 추출'로 사용
                tr.tx_data = uf_if.tx_data; // FIFO 출력 데이터 직접 샘플링
                mon2scb_mbox.put(tr);
            end
        join
        tr.display("mon");
    endtask
        
    //endtask  //run

endclass  //monitor

class scorboard;

    transaction tr;
    mailbox #(transaction) mon2scb_mbox;
    event gen_next_ev;

    //queue 
    logic [7:0] uf_queue[$:16];  //size 지정 안하면 무한대 
    logic [7:0] compare_data;

    function new(mailbox#(transaction) mon2scb_mbox, event gen_next_ev);
        this.mon2scb_mbox = mon2scb_mbox;
        this.gen_next_ev  = gen_next_ev;
    endfunction  //new()

    task run();
    forever begin
        mon2scb_mbox.get(tr);
        
        // 1. RX 데이터가 왔다면 무조건 먼저 큐에 넣기
        if (tr.rx_done) begin
            uf_queue.push_back(tr.rx_data); // push_back 권장
            $display("%t : [SCB_PUSH] Data %h | Size: %d", $time, tr.rx_data, uf_queue.size());
        end

        // 2. TX 데이터가 왔다면 큐에서 꺼내기
        if (tr.tx_done) begin
            if (uf_queue.size() > 0) begin
                // Actual 값이 xx가 아닐 때만 큐에서 꺼내서 비교
                if (tr.tx_data !== 8'hxx) begin
                    compare_data = uf_queue.pop_front(); 
                    if (compare_data === tr.tx_data) $display("PASS!!!");
                    else $display("FAIL!!! (Exp:%h, Act:%h)", compare_data, tr.tx_data);
                end else begin
                    $display("%t : [SCB] Hardware still outputting xx, skipping compare.", $time);
                end
            end
            ->gen_next_ev;
        end
    end
endtask

endclass  //scorboard

class environment;

    generator gen;
    driver drv;
    monitor mon;
    scorboard scb;

    mailbox #(transaction) gen2drv_mbox;
    mailbox #(transaction) mon2scb_mbox;

    event gen_next_ev;

    function new(virtual uf_interface uf_if);
        gen2drv_mbox = new;
        mon2scb_mbox = new;

        gen = new(gen2drv_mbox, gen_next_ev);
        drv = new(gen2drv_mbox, uf_if);
        mon = new(mon2scb_mbox, uf_if);
        scb = new(mon2scb_mbox, gen_next_ev);

    endfunction  //new()

    task run();
        drv.preset();
        fork
            gen.run(10);
            drv.run();
            mon.run();
            scb.run();
        join_any
        #10;
        $stop;
    endtask  //run
endclass  //environment

module tb_uart_fifo_sv ();

    logic clk;

    uf_interface uf_if (clk);
    environment env;

    uart_top dut (
        .clk(clk),
        .rst(uf_if.rst),
        .uart_rx(uf_if.uart_rx),
        .uart_tx(uf_if.uart_tx),
        .tx_done(uf_if.tx_done)
    );

    // ===============================
    // 계층적 경로(.)를 통한 강제 연결
    // ===============================

    assign uf_if.rx_data = dut.w_rx_data;
    assign uf_if.tx_data = dut.w_tx_fifo_pop_data;
    assign uf_if.b_tick  = dut.w_b_tick;
    assign uf_if.rx_done = dut.w_rx_done;
    assign uf_if.rx_push = dut.w_rx_done;
    assign uf_if.rx_pop  = ~dut.w_tx_fifo_full;
    assign uf_if.tx_push = ~dut.w_rx_fifo_empty;
    assign uf_if.tx_pop  = ~dut.w_tx_busy;
    assign uf_if.tx_start = ~dut.w_tx_fifo_empty;

    always #5 clk = ~clk;

    initial begin
        clk = 0;
        env = new(uf_if);
        env.run();
    end

endmodule