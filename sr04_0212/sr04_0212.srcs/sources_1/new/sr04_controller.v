`timescale 1ns / 1ps

module sr04_control_top (
    input  clk,
    input  rst,
    input  echo,
    input  btn_r,
    output trigger,
    output [8:0] dist
);

    wire w_sr04_tick, w_sr04_start;

    btn_debounce U_BTN_SR04_START (
        .clk  (clk),
        .reset(rst),
        .i_btn(btn_r),
        .o_btn(w_sr04_start)
    );

    sr04_controller U_SR04_CONTROLLER (
        .clk(clk),
        .rst(rst),
        .sr04_tick(w_sr04_tick),
        .sr04_start(w_sr04_start),
        .echo(echo),
        .trigger(trigger),
        .sr04_dist(dist)
    );

    tick_gen_1us U_TICK_GEN_1US (
        .clk(clk),
        .rst(rst),
        .o_tick_1us(w_sr04_tick)
    );
endmodule

module sr04_controller (
    input clk,
    input rst,
    input sr04_tick,
    input sr04_start,
    input echo,
    output trigger,
    output [8:0] sr04_dist
);

    localparam IDLE = 2'd0, START = 2'd1;
    localparam WAIT = 2'd2, DISTANCE = 2'd3;

    //state
    reg [1:0] c_state, n_state;
    reg [23:0] sr04_dist_reg, sr04_dist_next;
    //tick count
    reg [3:0] sr04_tick_cnt_reg, sr04_tick_cnt_next;
    //trigger
    reg trigger_reg, trigger_next;
    //echo count
    reg [21:0] echo_cnt_reg, echo_cnt_next;
    reg [8:0] distance_cm_reg, distance_cm_next;
    reg calcu_done_reg, calcu_done_next;

    assign trigger = trigger_reg; // 이거 안하면, 노란 박스로 나옴 출력이 연결 안되어 있기 때문 
    assign sr04_dist = distance_cm_reg;

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            c_state           <= IDLE;
            sr04_dist_reg     <= 24'd0;
            sr04_tick_cnt_reg <= 4'd0;
            trigger_reg       <= 1'd0;
            echo_cnt_reg      <= 22'd0;
            distance_cm_reg   <= 9'd0;
            calcu_done_reg    <= 1'd0;
        end else begin
            c_state           <= n_state;
            sr04_dist_reg     <= sr04_dist_next;
            sr04_tick_cnt_reg <= sr04_tick_cnt_next;
            trigger_reg       <= trigger_next;
            echo_cnt_reg      <= echo_cnt_next;
            distance_cm_reg   <= distance_cm_next;
            calcu_done_reg    <= calcu_done_next;
        end
    end

    always @(*) begin
        n_state            = c_state;
        sr04_dist_next     = sr04_dist_reg;
        sr04_tick_cnt_next = sr04_tick_cnt_reg;
        trigger_next       = trigger_reg;
        echo_cnt_next      = echo_cnt_reg;
        distance_cm_next   = distance_cm_reg;
        calcu_done_next    = calcu_done_reg;

        case (c_state)
            IDLE: begin
                sr04_dist_next     = 24'd0;
                sr04_tick_cnt_next = 4'd0;
                trigger_next       = 1'd0;
                echo_cnt_next      = 22'd0;
                distance_cm_next   = 9'd0;
                calcu_done_next    = 1'd0;
                
                if (sr04_start == 1) begin
                    n_state = START;
                end
            end
            START: begin
                trigger_next = 1'd1;
                if (sr04_tick) begin
                    if (sr04_tick_cnt_reg == 10) begin
                        sr04_tick_cnt_next = 0;
                        n_state = WAIT;
                        trigger_next = 1'd0;
                    end else begin
                        sr04_tick_cnt_next = sr04_tick_cnt_reg + 1;
                    end 
                end
            end
            WAIT: begin  
                if (echo == 1) begin
                    n_state = DISTANCE;
                end
            end
            DISTANCE: begin
                if (sr04_tick) begin
                    if (echo == 1) begin
                        echo_cnt_next = echo_cnt_reg + 1;
                    end else begin
                        distance_cm_next = ((echo_cnt_reg + 1) / 58);
                        calcu_done_next = 1;
                        n_state = IDLE;
                    end
                end
            end
        endcase
    end

endmodule


module tick_gen_1us (
    input      clk,
    input      rst,
    output reg o_tick_1us
);
    reg [$clog2(100)-1:0] r_counter;

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            r_counter  <= 0;
            o_tick_1us <= 1'b0;
        end else begin
            r_counter <= r_counter + 1;
            if (r_counter == (100 - 1)) begin
                r_counter  <= 0;
                o_tick_1us <= 1'b1;
            end else begin
                o_tick_1us <= 1'b0;
            end
        end
    end
endmodule