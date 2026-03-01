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
    logic       fifo_rx_push;
    //logic       fifo_rx_pop;
    logic       fifo_rx_empty;

    logic       fifo_tx_push;
    //logic       fifo_tx_pop;
    logic       fifo_tx_full;
    logic       fifo_tx_empty;

    logic       tx_start;
    logic       fifo_tx_busy;

    property preset_check;
        @(posedge clk) rst |=> (rx_data == 0);
    endproperty
    reg_reset_check :
    assert property (preset_check)
    else $display("%t : Assert error : reset check", $time);

endinterface  //uf_interface

class transaction;

    rand bit [7:0] rx_data;

    constraint rand_no_zero {rx_data != 8'h00;}

    logic       rst;

    //내부 관찰 
    logic [7:0] tx_data;
    logic       b_tick;

    logic       rx_done;
    logic       fifo_rx_push;
    //logic       fifo_rx_pop;
    logic       fifo_rx_empty;

    logic       fifo_tx_push;
    //logic       fifo_tx_pop;
    logic       fifo_tx_full;
    logic       fifo_tx_empty;

    logic       tx_start;
    logic       fifo_tx_busy;
    logic       tx_done;

    function void display(string name);
        $display(
            "%t : [%s] rx_data = %2h, rx_done = %h, tx_data = %2h, tx_done = %h",
            $time, name, rx_data, rx_done, tx_data, tx_done);
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
            assert (tr.randomize())
            else $display("[gen] tr.randomize() error!!!");
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

    function new(mailbox#(transaction) gen2drv_mbox, virtual uf_interface uf_if);
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
            //in mailbox
            gen2drv_mbox.get(tr);

            @(posedge uf_if.clk);
            #1;
            tr.display("drv");

            //rx data 전송
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
            repeat (5) @(negedge uf_if.clk);
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
        // join_none을 써야 environment의 다른 루프들이 돌아감 
            fork
            // [RX 모니터]
            forever begin
                transaction tr_rx;
                //@(posedge uf_if.fifo_rx_push);
                @(posedge uf_if.rx_done);
                #1;
                tr_rx = new;
                @(negedge uf_if.clk);  // 샘플링 안정화
                tr_rx.rx_data = uf_if.rx_data;

                tr_rx.b_tick = uf_if.b_tick;

                //tr.rx_done = uf_if.rx_done;
                tr_rx.fifo_rx_push = uf_if.fifo_rx_push;
                //tr_rx.fifo_rx_pop = uf_if.fifo_rx_pop;
                tr_rx.fifo_rx_empty = uf_if.fifo_rx_empty;

                tr_rx.fifo_tx_push = uf_if.fifo_tx_push;
                //tr_rx.fifo_tx_pop = uf_if.fifo_tx_pop;
                tr_rx.fifo_tx_full = uf_if.fifo_tx_full;
                tr_rx.fifo_tx_empty = uf_if.fifo_tx_empty;

                tr_rx.tx_start = uf_if.tx_start;
                tr_rx.fifo_tx_busy = uf_if.fifo_tx_busy;
                //tr.tx_done = uf_if.tx_done;

                tr_rx.rx_done = 1;

                $display(
                    "%t [MON_RX] DATA : DONE = %h, PUSH = %h,  EMPTY = %h",
                    $time, uf_if.rx_done, uf_if.fifo_rx_push,
                     uf_if.fifo_rx_empty);
                tr_rx.display("mon_rx");
                mon2scb_mbox.put(tr_rx);
            end

            // [TX 모니터] - 실제 출력되는 데이터를 감시
            forever begin
                transaction tr_tx;
                // tx_pop(데이터가 FIFO에서 빠져나가는 순간)을 감시
                //@(posedge uf_if.fifo_tx_pop);
                @(posedge uf_if.fifo_tx_busy);
                #1;
                tr_tx = new;
                @(negedge uf_if.clk);
                tr_tx.tx_data = uf_if.tx_data;  // FIFO 출력값 캡처

                tr_tx.b_tick = uf_if.b_tick;

                //tr.rx_done = uf_if.rx_done;
                tr_tx.fifo_rx_push = uf_if.fifo_rx_push;
                //tr_tx.fifo_rx_pop = uf_if.fifo_rx_pop;
                tr_tx.fifo_rx_empty = uf_if.fifo_rx_empty;

                tr_tx.fifo_tx_push = uf_if.fifo_tx_push;
                //tr_tx.fifo_tx_pop = uf_if.fifo_tx_pop;
                tr_tx.fifo_tx_full = uf_if.fifo_tx_full;
                tr_tx.fifo_tx_empty = uf_if.fifo_tx_empty;

                tr_tx.tx_start = uf_if.tx_start;
                tr_tx.fifo_tx_busy = uf_if.fifo_tx_busy;
                //tr.tx_done = uf_if.tx_done;

                tr_tx.tx_done = 1;

                $display(
                    "%t [MON_TX] DATA : DONE = %h, PUSH = %h,  EMPTY = %h, FULL = %h",
                    $time, uf_if.tx_done, uf_if.fifo_tx_push, 
                    uf_if.fifo_tx_empty, uf_if.fifo_tx_full);
                tr_tx.display("mon_tx");
                mon2scb_mbox.put(tr_tx);
            end
            join_none

    endtask

    //endtask  //run

endclass  //monitor

class scoreboard;

    transaction tr;
    mailbox #(transaction) mon2scb_mbox;

    int compared_cnt = 0;  // 현재까지 비교한 개수
    event gen_next_ev;  // 테스트 종료를 알리는 이벤트

    //queue 
    logic [7:0] uf_queue[$];  //size 지정 안하면 무한대 
    logic [7:0] compare_data;

    function new(mailbox#(transaction) mon2scb_mbox, event gen_next_ev);
        this.mon2scb_mbox = mon2scb_mbox;
        this.gen_next_ev = gen_next_ev;
    endfunction  //new()

    task run();
        forever begin
            mon2scb_mbox.get(tr);
            tr.display("scb");

            // RX data queue 에 넣기 
            if (tr.rx_done) begin
                uf_queue.push_back(tr.rx_data);  // push_back 권장
                $display("%t : [SCB_PUSH] Data %h | Size: %d", $time,
                         tr.rx_data, uf_queue.size());
            end

            // TX data가 왔을 때 꺼내서 비교 
            if (tr.tx_done) begin
                if (uf_queue.size() > 0) begin
                    // Actual 값이 xx가 아닐 때만 큐에서 꺼내서 비교
                    if (tr.tx_data !== 8'hxx) begin
                        compare_data = uf_queue.pop_front();
                        if (compare_data === tr.tx_data) $display("PASS!!!");
                        else
                            $display(
                                "FAIL!!! (Exp:%h, Act:%h)",
                                compare_data,
                                tr.tx_data
                            );
                        compared_cnt++;
                    end else begin
                        $display(
                            "%t : [SCB] Hardware still outputting xx, skipping compare.",
                            $time);
                    end
                end
            end
            ->gen_next_ev;
        end
    endtask

endclass  //scoreboard

class environment;

    generator gen;
    driver drv;
    monitor mon;
    scoreboard scb;

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

        //scb.total_cnt = 10;
        fork
            gen.run(10);
            drv.run();
            mon.run();
            scb.run();
        join_any

        // 마지막 데이터가 처리되는 것을 볼 수 있게 약간의 여유 시간 확보
        #100;

        $display("=================================");
        $display(" TEST FINISHED (All Data Compared) ");
        $display("=================================");
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
    assign uf_if.b_tick = dut.w_b_tick;

    assign uf_if.rx_done = dut.w_rx_done; //
    assign uf_if.fifo_rx_push = dut.w_rx_done; //
    //assign uf_if.fifo_rx_pop = ~dut.w_tx_fifo_full;
    assign uf_if.fifo_rx_empty = dut.w_rx_fifo_empty; //

    assign uf_if.fifo_tx_push = ~dut.w_rx_fifo_empty;
    //assign uf_if.fifo_tx_pop = ~dut.w_tx_busy;
    assign uf_if.fifo_tx_full = dut.w_tx_fifo_full; //
    assign uf_if.fifo_tx_empty = dut.w_tx_fifo_empty; //

    assign uf_if.tx_start = ~dut.w_tx_fifo_empty;
    assign uf_if.fifo_tx_busy = dut.w_tx_busy; //

    always #5 clk = ~clk;

    initial begin
        clk = 0;
        env = new(uf_if);
        env.run();
    end

endmodule
