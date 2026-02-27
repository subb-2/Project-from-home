`timescale 1ns / 1ps

module dht11_controller (
    input clk,
    input rst,
    input start,
    output [15:0] humidity,
    output [15:0] temperature,
    output dht11_done,
    output dht11_valid,
    output [3:0] debug,
    inout         dhtio         // wire 로 나가고 받아들여야 함 , reg로 내보내려면 mux 또는 3state buffer 사용해라 
);

    wire tick_10u;

    tick_gen_10u U_TICK_10u (
        .clk(clk),
        .rst(rst),
        .tick_10u(tick_10u)
    );

    //state
    parameter IDLE = 0, START = 1, WAIT = 2, SYNC_L = 3, SYNC_H = 4, DATA_SYNC = 5,
                DATA_C = 6, STOP = 7;
    reg [2:0] c_state, n_state;
    reg dhtio_reg, dhtio_next;
    reg
        io_sel_reg,
        io_sel_next; //fsm로직 안에서 제어, 조합으로 내보내도 됨 /한 비트짜리 먹스?

    //for 19msec count by 10usec tick
    reg [$clog2(1900)-1:0]
        tick_cnt_reg, tick_cnt_next;  //내부 사용은 무조건 FF 구조 

    assign dhtio = (io_sel_reg) ? dhtio_reg : 1'bz;

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            c_state      <= 3'b000;
            dhtio_reg    <= 1'b1;
            tick_cnt_reg <= 0;
            io_sel_reg   <= 1'b1;
        end else begin
            c_state      <= n_state;
            dhtio_reg    <= dhtio_next;
            tick_cnt_reg <= tick_cnt_next;
            io_sel_reg   <= io_sel_next;
        end
    end

    //next, output
    always @(*) begin
        n_state       = c_state;
        tick_cnt_next = tick_cnt_reg;
        dhtio_next    = dhtio_reg;
        io_sel_next   = io_sel_reg;
        case (c_state)
            IDLE: begin
                if (start) begin
                    n_state = START;
                end
            end
            START: begin
                dhtio_next = 1'b0;
                if (tick_10u) begin
                    tick_cnt_next = tick_cnt_reg + 1;
                    if (tick_cnt_reg == 1900) begin
                        tick_cnt_next = 0;
                        n_state = WAIT;
                    end
                end
            end
            WAIT: begin
                dhtio_next = 1'b1;
                if (tick_10u) begin
                    tick_cnt_next = tick_cnt_reg + 1;
                    if (tick_cnt_reg == 3) begin
                        //for output to high-z
                        n_state = SYNC_L;
                        io_sel_next = 1'b0; //read 쪽은 트라이 써도 되고 안 써도 됨 
                        //끊고 연결 안해도 됨 지금은 , 버스제어에서는 필요하기도 함 
                        //force 릴리즈? 
                    end
                end
            end
            SYNC_L: begin
                if (tick_10u) begin
                    //if 안하면 100MHz에서 읽게 됨 메타 스테이블 발생 가능 커짐
                    //tick 들어올 때마다 dhtio를 읽어
                    //edge detection logic 을 사용하던가 2가지 상태로 쪼개던가 btn_debounce랑 동일 
                    if (dhtio == 1) begin
                        n_state = SYNC_H;
                    end
                end
            end
            SYNC_H: begin
                if (tick_10u) begin
                    if (dhtio == 0) begin
                        n_state = DATA_SYNC;
                        //dhtio 앞단에 싱크로나이즈 넣으면 노이즈 잡기 가능 
                        //노이즈 때문에 싱크가 지나가버릴 수도 있음 
                        //50u를 제대로 본 것이 아니므로 
                    end
                end
            end
            DATA_SYNC: begin
                if (tick_10u) begin
                    if (dhtio == 1) begin
                        n_state = DATA_C;
                    end
                end
            end
            DATA_C: begin
                if (tick_10u) begin
                    if (dhtio == 1) begin
                        //tick count 돌리기
                        tick_cnt_next = tick_cnt_reg + 1;
                    end else begin
                        n_state = STOP;
                    end
                end
            end
            STOP: begin
                if (tick_10u) begin
                    tick_cnt_next = tick_cnt_reg + 1;
                    if (tick_cnt_reg == 5) begin
                        //output mode 
                        dhtio_next  = 1'b1;
                        io_sel_next = 1'b1;
                        n_state     = IDLE;
                    end
                end
            end
        endcase
    end

endmodule

module tick_gen_10u (
    input      clk,
    input      rst,
    output reg tick_10u
);

    parameter F_COUNT = 100_100_000 / 100_000;
    reg [$clog2(F_COUNT)-1:0] counter_reg;

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            counter_reg <= 0;
            tick_10u <= 1'b0;
        end else begin
            counter_reg <= counter_reg + 1;
            if (counter_reg == F_COUNT - 1) begin
                counter_reg <= 0;
                tick_10u <= 1'b1;
            end else begin
                tick_10u <= 1'b0;
            end
        end
    end

endmodule