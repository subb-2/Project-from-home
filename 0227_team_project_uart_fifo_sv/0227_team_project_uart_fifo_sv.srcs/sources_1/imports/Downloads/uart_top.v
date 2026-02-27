`timescale 1ns / 1ps

module uart_top (
    input        clk,
    input        rst,
    input        uart_rx,
    output       uart_tx
);

    wire w_b_tick, w_rx_done;
    wire [7:0] w_rx_data, w_rx_fifo_pop_data, w_tx_fifo_pop_data;
    wire w_tx_fifo_full, w_rx_fifo_empty, w_tx_busy, w_tx_fifo_empty;

    uart_tx U_UART_TX (
        .clk(clk),
        .rst(rst),
        .tx_start(~w_tx_fifo_empty),
        .b_tick(w_b_tick),
        .tx_data(w_tx_fifo_pop_data),
        .tx_busy(w_tx_busy),
        .tx_done(),
        .uart_tx(uart_tx)
    );

    fifo U_FIFO_TX (
        .clk(clk),
        .rst(rst),
        .push(~w_rx_fifo_empty),
        .pop(~w_tx_busy),
        .push_data(w_rx_fifo_pop_data),
        .pop_data(w_tx_fifo_pop_data),
        .full(w_tx_fifo_full),
        .empty(w_tx_fifo_empty)
    );

    fifo U_FIFO_RX (
        .clk(clk),
        .rst(rst),
        .push(w_rx_done),
        .pop(~w_tx_fifo_full),
        .push_data(w_rx_data),
        .pop_data(w_rx_fifo_pop_data),
        .full(),
        .empty(w_rx_fifo_empty)
    );

    uart_rx U_UART_RX (
        .clk(clk),
        .rst(rst),
        .rx(uart_rx),
        .b_tick(w_b_tick),
        .rx_data(w_rx_data),
        .rx_done(w_rx_done)
    );

    baud_tick U_BAUD_TICK (
        .clk(clk),
        .rst(rst),
        .b_tick(w_b_tick)
    );

endmodule

module uart_rx (
    input        clk,
    input        rst,
    input        rx,
    input        b_tick,
    output [7:0] rx_data,
    output       rx_done
);

    localparam IDLE = 2'd0, START = 2'd1;
    localparam DATA = 2'd2, STOP = 2'd3;

    reg [1:0] c_state, n_state;
    reg [4:0] b_tick_cnt_reg, b_tick_cnt_next;
    reg [2:0] bit_cnt_next, bit_cnt_reg;
    reg done_reg, done_next;
    reg [7:0] buf_reg, buf_next;

    assign rx_data = buf_reg;
    assign rx_done = done_reg;

    //state register
    always @(posedge clk, posedge rst) begin
        if (rst) begin
            c_state        <= 2'd0;
            b_tick_cnt_reg <= 5'd0;
            bit_cnt_reg    <= 3'b0;
            done_reg       <= 1'b0;
            buf_reg        <= 8'd0;
        end else begin
            c_state        <= n_state;
            b_tick_cnt_reg <= b_tick_cnt_next;
            bit_cnt_reg    <= bit_cnt_next;
            done_reg       <= done_next;
            buf_reg        <= buf_next;
        end
    end

    //next, output
    always @(*) begin
        n_state         = c_state;
        b_tick_cnt_next = b_tick_cnt_reg;
        bit_cnt_next    = bit_cnt_reg;
        done_next       = done_reg;
        buf_next        = buf_reg;

        case (c_state)
            IDLE: begin
                b_tick_cnt_next = 5'd0;
                bit_cnt_next    = 3'd0;
                done_next       = 1'b0;
                
                if (b_tick & !rx) begin
                    buf_next        = 8'd0;
                    n_state = START;
                end
            end
            START: begin
                if (b_tick) begin
                    if (b_tick_cnt_reg == 7) begin
                        b_tick_cnt_next = 0;
                        n_state = DATA;
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
                end
            end
            DATA: begin
                if (b_tick) begin
                    if (b_tick_cnt_reg == 4'd15) begin
                        b_tick_cnt_next = 5'd0;
                        buf_next = {rx, buf_reg[7:1]};
                        if (bit_cnt_reg == 4'd7) begin
                            n_state = STOP;
                        end else begin
                            bit_cnt_next = bit_cnt_reg + 1;
                        end
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
                end
            end

            STOP : begin
                if (b_tick) begin
                    if (b_tick_cnt_reg == 16) begin
                        n_state   = IDLE;
                        done_next = 1'b1;
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
                end
            end
        endcase
    end


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

    localparam IDLE = 2'd0, START = 2'd1;
    localparam DATA = 2'd2, STOP = 2'd3;

    //state 관리할 register 필요 
    //state reg
    reg [1:0] c_state, n_state;  //current, next
    reg tx_reg, tx_next;  // output을 SL로 내보내기 위함 

    //bit_cnt
    reg [2:0] bit_cnt_reg, bit_cnt_next;
    //조합논리로만 바꾸면 래치 생기게 됨 그래서 피드백 구조로 만들기 *

    //baud tick counter
    reg [3:0] b_tick_cnt_reg, b_tick_cnt_next;

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
            b_tick_cnt_reg  <= 4'h0;
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
                tx_next         = 1'b1;
                bit_cnt_next    = 1'b0;
                b_tick_cnt_next = 4'h0;
                busy_next       = 1'b0;
                done_next       = 1'b0;
                if (tx_start == 1) begin
                    n_state          = START;
                    busy_next        = 1'b1;
                    //start 인지했을 때 넣기
                    data_in_buf_next = tx_data;
                end
            end

            START: begin
                //to start uart frame start bit
                tx_next = 1'b0;
                if (b_tick == 1) begin
                    if (b_tick_cnt_reg == 15) begin
                        n_state = DATA;
                        b_tick_cnt_next = 4'h0;
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end

                end
            end

            DATA: begin
                tx_next = data_in_buf_reg[0];
                if (b_tick == 1) begin
                    if (b_tick_cnt_reg == 15) begin
                        if (bit_cnt_next == 7) begin  //next였는데 바꿈 
                            b_tick_cnt_next = 4'h0;
                            n_state = STOP;
                        end else begin
                            b_tick_cnt_next = 4'h0;
                            bit_cnt_next = bit_cnt_reg + 1;
                            data_in_buf_next = {1'b0, data_in_buf_reg[7:1]};
                            n_state = DATA;
                        end
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
                end
            end

            STOP: begin
                tx_next = 1'b1;
                if (b_tick == 1) begin
                    if (b_tick_cnt_reg == 15) begin
                        done_next = 1'b1;
                        n_state   = IDLE;
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
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
    // 651, 6.51ns 마다 
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
