`timescale 1ns / 1ps

module uart_top (
    input  clk,
    input  rst,
    input  btn_down,
    output uart_tx
);

    wire w_b_tick, w_tx_start;

    btn_debounce U_BD_TX_START (
        .clk  (clk),
        .reset(rst),
        .i_btn(btn_down),
        .o_btn(w_tx_start)
    );

    uart_tx U_UART_TX (
        .clk(clk),
        .rst(rst),
        .tx_start(w_tx_start),
        .b_tick(w_b_tick),
        .tx_data(8'h30),
        .tx_busy(),
        .tx_done(),
        .uart_tx(uart_tx)
    );

    baud_tick U_BAUD_TICK (
        .clk(clk),
        .rst(rst),
        .b_tick(w_b_tick)
    );

endmodule

module uart_tx (
    input        clk,
    input        rst,
    input        tx_start,
    input        b_tick,
    input  [7:0] tx_data,
    output       tx_busy,
    output       tx_done,
    output       uart_tx
);

    localparam IDLE = 3'd0, WAIT = 3'd1, START = 3'd2;
    localparam DATA = 3'd3, STOP = 3'd4;

    //state 관리할 register 필요 
    //state reg
    reg [2:0] c_state, n_state;  //current, next
    reg tx_reg, tx_next;  // output을 SL로 내보내기 위함 

    //b_tick_cnt
    reg [4:0] b_tick_cnt_reg, b_tick_cnt_next;

    //bit_cnt
    reg [2:0] bit_cnt_reg, bit_cnt_next;
    //조합논리로만 바꾸면 래치 생기게 됨 그래서 피드백 구조로 만들기 *

    //busy, done
    reg busy_reg, busy_next, done_reg, done_next;
    //data_in_buf
    reg [7:0] data_in_buf_reg, data_in_buf_next;
    //출력으로 나가지만 않으면, 피드백 안해도 됨
    //조합논리의 출력인 경우 피드백을 해야 함 

    assign uart_tx = tx_reg;
    assign tx_busy = busy_reg;
    assign tx_done = done_reg;

    assign uart_tx = tx_reg;

    //state register SL
    always @(posedge clk, posedge rst) begin
        if (rst) begin
            c_state         <= IDLE;
            tx_reg          <= 1'b1;
            bit_cnt_reg     <= 1'b0;
            b_tick_cnt_reg  <= 1'b0;
            busy_reg        <= 1'b0;
            done_reg        <= 1'b0;
            data_in_buf_reg <= 8'h00;
        end else begin
            c_state         <= n_state;
            tx_reg          <= tx_next;
            bit_cnt_reg     <= bit_cnt_next;
            b_tick_cnt_reg  <= b_tick_cnt_next;
            busy_reg        <= busy_next;
            done_reg        <= done_next;
            data_in_buf_reg <= data_in_buf_next;
        end
    end

    //next CL
    //CL이 아니라 순차논리로 drive 하고 싶음 노이즈 줄이고 싶어서? 
    //피드백 구조로 순차논리가 됨 조합이 아니라 wire 
    always @(*) begin
        n_state          = c_state;
        tx_next          = tx_reg;
        bit_cnt_next     = bit_cnt_reg;
        b_tick_cnt_next  = b_tick_cnt_reg; 
        busy_next        = busy_reg;
        done_next        = done_reg;
        data_in_buf_next = data_in_buf_reg;

        case (c_state)
            IDLE: begin
                tx_next      = 1'b1;
                bit_cnt_next = 1'b0;
                b_tick_cnt_next = 1'b0;
                busy_next    = 1'b0;
                done_next    = 1'b0;
                if (tx_start == 1) begin
                    n_state          = WAIT;
                    busy_next        = 1'b1;
                    //start 인지했을 때 넣기
                    data_in_buf_next = tx_data;
                end
            end

            WAIT: begin
                if (b_tick == 1) begin
                    if (b_tick_cnt_next == 16) begin
                        n_state = START;
                        b_tick_cnt_next = 1'b0;
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                        n_state = WAIT;
                    end
                end
            end

            START: begin
                //to start uart frame start bit
                tx_next = 1'b0;
                if (b_tick == 1) begin
                    if (b_tick_cnt_next == 16) begin
                        n_state = DATA;
                        b_tick_cnt_next = 1'b0;
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                        n_state = START;
                    end
                end
            end

            DATA: begin
                tx_next = data_in_buf_reg[bit_cnt_reg]; //현재 비트가 나가야하므로 
                if (b_tick == 1) begin
                    if (b_tick_cnt_next == 16) begin
                        b_tick_cnt_next = 1'b0;
                        if (bit_cnt_next == 7) begin
                            n_state = STOP;
                        end else begin
                            bit_cnt_next = bit_cnt_reg + 1;
                            n_state = DATA;
                        end
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                        n_state = DATA;
                    end
                end
            end

            STOP: begin
                tx_next = 1'b1;
                if (b_tick == 1) begin
                    if (b_tick_cnt_next == 16) begin
                        done_next = 1'b1;
                        n_state = IDLE;
                        b_tick_cnt_next = 1'b0;
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                        n_state = STOP;
                    end
                end  //idle 가서 done을 떨군다고 해도 start 받는데 문제 없음
                //중간에 값이 변환되는 것을 막기 위해서 메모리를 위해 레지스터 8비트 버퍼 잡기
                //스타트 들어가면서 카피할 것임 
                //값을 카피해 놓고 스타트 조건에서 보내면 되니까 계속 값이 바뀌어도 상관 없음 
                //next start 갈 때 카피하기 
            end
        endcase
    end

endmodule


module baud_tick (
    // 주기 : 1/9600
    input      clk,
    input      rst,
    output reg b_tick
);

    //순차논리의 카운트 값으로 주기 돌리기 
    //100MHz / 9600 만큼 카운트해서 tick 1 만들기 
    parameter BAUDRATE = 9600 * 16;
    parameter F_COUNT = 100_000_000 / BAUDRATE;
    // reg for counter
    // clog2는 자동 올림되어 나타남 1.1 = 2 로 return 
    reg [$clog2(F_COUNT) - 1:0] counter_reg;

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            counter_reg <= 0;
            b_tick <= 1'b0;
        end else begin
            counter_reg <= counter_reg + 1;
            if (counter_reg == (F_COUNT - 1)) begin
                counter_reg <= 0;
                b_tick <= 1'b1;
            end else begin
                b_tick <= 1'b0;
            end
        end
    end

endmodule