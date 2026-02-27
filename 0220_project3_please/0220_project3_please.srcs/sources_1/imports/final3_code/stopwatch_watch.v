`timescale 1ns / 1ps

module stopwatch_watch (
    input        clk,
    input        reset,
    input  [5:0] sw,             //sw[0] up/down
    input        btn_r,          //i_run_stop
    input        btn_l,          //i_clear
    input        btn_u,
    input        btn_d,
    input        uart_rx,
    input        echo,
    output       trigger,
    output [3:0] fnd_digit,
    output [7:0] fnd_data,
    output       uart_tx,
    output       dht_valid,
    output [3:0] dht_debug_led,
    output [3:0] btn_debug_led,
    inout        dhtio
);

    wire [13:0] w_counter_10000;
    wire w_set_watch;
    wire o_btn_run_stop, o_btn_clear;
    wire o_btn_u, o_btn_d;
    wire [31:0] o_mux_set_4;
    wire [23:0] o_mux_set;
    wire [23:0] w_watch_time;
    //wire [31:0] w_watch_time_32 = {8'd0, w_watch_time};
    wire [23:0] w_stopwatch_time;
    //wire [31:0] w_stopwatch_time_32 = {8'd0, w_stopwatch_time};
    //wire [31:0] w_sr04_data;
    //wire [31:0] w_dht11_data;
    wire [8:0] w_sr04_data;
    wire [15:0] w_dht11_humi_data;
    wire [15:0] w_dht11_temp_data;
    wire [ 4:0] w_ascii_d;
    wire [ 7:0] w_rx_data;
    wire [ 7:0] w_tx_data;
    wire        w_rx_done;
    wire w_tx_start, w_tx_done;
    wire w_run_stop_or, w_clear_or, w_btn_u_or, w_btn_d_or;
    wire w_up_down_mux, w_stopwatch_watch_mux, w_hm_sms_mux, w_watch_set_mux, w_humi_temp_mux;
    wire w_ascii_up_down, w_ascii_stopwatch_watch, w_ascii_hm_sms, w_ascii_watch_set, w_ascii_humi_temp;

    wire [7:0] w_push_data, w_pop_data;
    wire w_empty_fifo_rx, w_pop_fifo_rx;
    wire w_pop_fifo_rx_decoder, w_pop_fifo_rx_sw_set;
    assign w_pop_fifo_rx = w_pop_fifo_rx_decoder | w_pop_fifo_rx_sw_set;
    wire w_push_fifo_tx, w_full_fifo_tx;

    wire [1:0] w_sel_set_4;

    wire w_btn_r_dht11; // 신규 와이어
    wire w_btn_l_sr04;  // 신규 와이어

    //추가

    // SR04 data

    wire [3:0] w_dist_0 = (w_sr04_data) % 10;
    wire [3:0] w_dist_1 = (w_sr04_data / 10) % 10;
    wire [3:0] w_dist_2 = (w_sr04_data / 100) % 10;
    wire [3:0] w_dist_3 = w_sr04_data / 1000;

    // {[S] [r] [0] [4] / [X] [X] [X] [X]}
    wire [23:0] w_dist_data = {8'd0, w_dist_3, w_dist_2, w_dist_1, w_dist_0}; // distance display
    wire [23:0] w_sr04_label = {8'd0, 4'd10, 4'd11, 4'd0, 4'd4}; // label display
    wire [23:0] fnd_data_sr04 = (sw[2] ? w_sr04_label : w_dist_data); // toggle (label / distance)



    // DHT11 data / formats
    //wire [15:0] w_dht11_temp, w_dht11_humi;
    //wire w_dht11_done, w_dht11_valid;

    wire [3:0] w_dht11_temp_1i = w_dht11_temp_data[15:8] % 10;
    wire [3:0] w_dht11_temp_10i = w_dht11_temp_data[15:8] / 10;
    // wire [3:0] w_dht11_temp_d = w_dht11_temp % 10; // temperature decimal
    wire [3:0] w_dht11_humi_1i = w_dht11_humi_data[15:8] % 10;
    wire [3:0] w_dht11_humi_10i = w_dht11_humi_data[15:8] / 10;
    // wire [3:0] w_dht11_hum_d  = w_dht11_hum  % 10; // humidity decimal

// {[h] [10] [1] [0.1] / [t] [10] [1] [0.1]}
    wire [23:0] w_fnd_dht11_temp = {8'd0, 4'd12, w_dht11_temp_10i, w_dht11_temp_1i, 4'd0};
    wire [23:0] w_fnd_dht11_humi  = {8'd0, 4'd13, w_dht11_humi_10i, w_dht11_humi_1i, 4'd0};
    wire [23:0] fnd_data_dht11 = (sw[2] ? w_fnd_dht11_humi : w_fnd_dht11_temp); // toggle (humidity / temperature)

    assign btn_debug_led[0] = btn_r;
    assign btn_debug_led[1] = btn_l;
    assign btn_debug_led[2] = (w_sel_set_4 == 2'b10); // SR04 모드 표시
    assign btn_debug_led[3] = (w_sel_set_4 == 2'b11); // DHT 모드 표시

// ==========================================================

    uart_top U_UART_TOP (
        .clk(clk),
        .rst(reset),
        .uart_rx(uart_rx),
        .tx_start(w_tx_start),
        .tx_data(w_tx_data),
        .pop_fifo_rx(w_pop_fifo_rx),
        .push_fifo_tx(w_push_fifo_tx),
        .push_data_fifo_tx(w_push_data),
        .pop_data_fifo_rx(w_pop_data),
        .full_fifo_tx(w_full_fifo_tx),
        .empty_fifo_rx(w_empty_fifo_rx),
        .tx_done(w_tx_done),
        .rx_data(w_rx_data),
        .rx_done(w_rx_done),
        .uart_tx(uart_tx)
    );

// =======================================
// ASCII decoder, sw_set, sender
// =======================================

    ascii_decoder U_ASCII_DECODER (
        .clk(clk),
        .rst(reset),
        .pop_data(w_pop_data),
        .empty(w_empty_fifo_rx),
        .pop(w_pop_fifo_rx_decoder),
        .ascii_d(w_ascii_d)
    );

    ascii_sw_set U_ASCII_SW_SET (
        .clk(clk),
        .rst(reset),
        .pop_data(w_pop_data),
        .empty(w_empty_fifo_rx),
        .pop(w_pop_fifo_rx_sw_set),
        .ascii_up_down(w_ascii_up_down),
        .ascii_stopwatch_watch(w_ascii_stopwatch_watch),
        .ascii_hm_sms(w_ascii_hm_sms),
        .ascii_watch_set(w_ascii_watch_set),
        .ascii_humi_temp(w_ascii_humi_temp)
    );

    ascii_sender U_ASCII_SENDER (
        .clk(clk),
        .rst(reset),
        .mux_2x1_set(o_mux_set_4),
        .ascii_d_s(w_ascii_d[4]),
        .full(w_full_fifo_tx),
        .push_start(w_push_fifo_tx),
        .push_data(w_push_data)
    );

// ==========================================

    btn_all U_BTN_ALL (
        .clk(clk),
        .reset(reset),
        .btn_r(btn_r),
        .btn_l(btn_l),
        .btn_u(btn_u),
        .btn_d(btn_d),
        .o_btn_run_stop(o_btn_run_stop),
        .o_btn_clear(o_btn_clear),
        .o_btn_u(o_btn_u),
        .o_btn_d(o_btn_d)
    );

    control_unit U_CONTROL_UNIT (
        .clk(clk),
        .reset(reset),
        .sw(sw),
        .ascii_d(w_ascii_d),
        .btn_r(o_btn_run_stop),
        .btn_l(o_btn_clear),
        .btn_u(o_btn_u),
        .btn_d(o_btn_d),
        .ascii_up_down(w_ascii_up_down),
        .ascii_stopwatch_watch(w_ascii_stopwatch_watch),
        .ascii_hm_sms(w_ascii_hm_sms),
        .ascii_watch_set(w_ascii_watch_set),
        .ascii_humi_temp(w_ascii_humi_temp),
        .o_up_down_mux(w_up_down_mux),
        .o_stopwatch_watch_mux(w_stopwatch_watch_mux),
        .o_hm_sms_mux(w_hm_sms_mux),
        .o_watch_set_mux(w_watch_set_mux),
        .o_humi_temp_mux(w_humi_temp_mux),
        .o_run_stop_or(w_run_stop_or),
        .o_clear_or(w_clear_or),
        .o_btn_u_or(w_btn_u_or),
        .o_btn_d_or(w_btn_d_or),
        .sel_set_4(w_sel_set_4)
        //.o_btn_r_dht11(w_btn_r_dht11), // 새로 만든 신호 연결
        //.o_btn_l_sr04(w_btn_l_sr04)   // 새로 만든 신호 연결
    );

// ==================================================
// 
// ==================================================

    watch_datapath U_WATCH_DATAPATH (
        .clk(clk),
        .reset(reset),
        .mode(w_up_down_mux),
        .clear(1'b0),
        .run_stop(1'b1),
        .sw_3(w_watch_set_mux),
        .o_btn_u(w_btn_u_or),
        .o_btn_d(w_btn_d_or),
        .msec(w_watch_time[6:0]),
        .sec(w_watch_time[12:7]),
        .min(w_watch_time[18:13]),
        .hour(w_watch_time[23:19])
    );

    stopwatch_datapath U_STOPWATCH_DATAPATH (
        .clk     (clk),
        .reset   (reset),
        .mode    (w_up_down_mux),
        .clear   (w_clear_or),
        .run_stop(w_run_stop_or),
        .msec    (w_stopwatch_time[6:0]),    //7bit
        .sec     (w_stopwatch_time[12:7]),   //6bit
        .min     (w_stopwatch_time[18:13]),  //6bit
        .hour    (w_stopwatch_time[23:19])   // 5bit
    );

    sr04_control_top U_SR04_TOP (
        .clk(clk),
        .rst(reset),
        .echo(echo),
        .btn_l(btn_l), //btn_l
        .trigger(trigger),
        .dist(w_sr04_data)
    );

    // dht11_top U_DHT11_TOP (
    //     .clk(clk),
    //     .rst(reset),
    //     .btn_r_start(w_btn_r_dht11), //btn_r
    //     .dht_data(w_dht11_data),
    //     .dht_done(dht_done),
    //     .dht_valid(dht_valid),
    //     .dht_debug_led(dht_debug_led),
    //     .dhtio(dhtio)
    // );

    dht11_top U_DHT11_TOP(
        .clk(clk),
        .rst(reset),
        .btn_r_start(btn_r),
        .humidity_data(w_dht11_humi_data),
        .temperature_data(w_dht11_temp_data),
        .dht_done(dht_done),
        .dht_valid(dht_valid),
        .dht_debug_led(dht_debug_led),
        .dhtio(dhtio)
    );

// ===================================================

    // mux_4x1_sw_w_sr_dht U_MUX_4x1_SW_W_SR_DHT (
    //     .sel_set_4(w_sel_set_4),
    //     .i_sel0_stopwatch(w_stopwatch_time),
    //     .i_sel1_watch(w_watch_time),
    //     .i_sel2_sr04(fnd_data_sr04),
    //     .i_sel3_dht11(fnd_data_dht11),
    //     .o_mux_set_4(o_mux_set_4)
    // );

    // mux_2x1_stopwatch_watch U_MUX_2x1_STOPWATCH_WATCH (
    //     .sel_set(), //w_set_watch
    //     .i_sel0_stopwatch(w_stopwatch_time),
    //     .i_sel1_watch(w_watch_time),
    //     .o_mux_set(o_mux_set)
    // );

    fnd_controller U_FND_CNTL (
        .clk        (clk),
        .reset      (reset),
        .sel_display(w_hm_sms_mux),
        .sel_set_4(w_sel_set_4),
        .fnd_in_data_sw(w_stopwatch_time),
        .fnd_in_data_w(w_watch_time),
        .fnd_in_data_sr04(fnd_data_sr04),
        .fnd_in_data_dht11(fnd_data_dht11),
        .fnd_digit  (fnd_digit),
        .fnd_data   (fnd_data)
    );


endmodule



//     fnd_controller U_FND_CNTL (
//         .clk        (clk),
//         .reset      (reset),
//         .sel_display(w_hm_sms_mux),
//         .fnd_in_data(o_mux_set),
//         .fnd_digit  (fnd_digit),
//         .fnd_data   (fnd_data)
//     );
// 
// endmodule

// module mux_2x1_stopwatch_watch (
//     input         sel_set,
//     input  [23:0] i_sel0_stopwatch,
//     input  [23:0] i_sel1_watch,
//     output [23:0] o_mux_set
// );
//     //sel 1 : output i_sel1 , 0 : i_sel0
//     assign o_mux_set = (sel_set) ? i_sel1_watch : i_sel0_stopwatch;
// 
// endmodule




module watch_datapath (
    input        clk,
    input        reset,
    input        mode,
    input        clear,
    input        run_stop,
    input        sw_3,
    input        o_btn_u,
    input        o_btn_d,
    output [6:0] msec,
    output [5:0] sec,
    output [5:0] min,
    output [4:0] hour
);
    wire w_tick_100hz, w_sec_tick, w_min_tick, w_hour_tick;
    wire w_set_min, w_set_hour;
    reg w_min_set_tick, w_hour_set_tick;
    reg w_min_set_mode, w_hour_set_mode;

    always @(*) begin
        w_min_set_tick  = w_min_tick;
        w_hour_set_tick = w_hour_tick;
        w_min_set_mode  = mode;
        w_hour_set_mode = mode;

        if (sw_3 == 0) begin
            if (o_btn_u) begin
                w_min_set_mode = 1'b0;
                w_min_set_tick = 1'b1;
            end else if (o_btn_d) begin
                w_min_set_mode = 1'b1;
                w_min_set_tick = 1'b1;
            end
        end else if (sw_3 == 1) begin
            if (o_btn_u) begin
                w_hour_set_mode = 1'b0;
                w_hour_set_tick = 1'b1;
            end else if (o_btn_d) begin
                w_hour_set_mode = 1'b1;
                w_hour_set_tick = 1'b1;
            end
        end
    end

    tick_counte #(
        .BIT_WIDTH(5),
        .TIMES(24)
    ) hour_counter (
        .clk(clk),
        .reset(reset),
        .i_tick(w_hour_set_tick),
        .mode(w_hour_set_mode),
        .clear(1'b0),
        .run_stop(run_stop),
        .o_count(hour),
        .o_tick()
    );

    tick_counte #(
        .BIT_WIDTH(6),
        .TIMES(60)
    ) min_counter (
        .clk(clk),
        .reset(reset),
        .i_tick(w_min_set_tick),
        .mode(w_min_set_mode),
        .clear(1'b0),
        .run_stop(run_stop),
        .o_count(min),
        .o_tick(w_hour_tick)
    );

    tick_counte #(
        .BIT_WIDTH(6),
        .TIMES(60)
    ) sec_counter (
        .clk(clk),
        .reset(reset),
        .i_tick(w_sec_tick),
        .mode(mode),
        .clear(1'b0),
        .run_stop(run_stop),
        .o_count(sec),
        .o_tick(w_min_tick)
    );

    tick_counte #(
        .BIT_WIDTH(7),
        .TIMES(100)
    ) msec_counter (
        .clk(clk),
        .reset(reset),
        .i_tick(w_tick_100hz),
        .mode(mode),
        .clear(1'b0),
        .run_stop(run_stop),
        .o_count(msec),
        .o_tick(w_sec_tick)
    );

    tick_gen_100hz U_TICK_GEN (
        .clk(clk),
        .reset(reset),
        .i_run_stop(run_stop),
        .o_tick_100hz(w_tick_100hz)
    );

endmodule

module stopwatch_datapath (
    input        clk,
    input        reset,
    input        mode,
    input        clear,
    input        run_stop,
    output [6:0] msec,
    output [5:0] sec,
    output [5:0] min,
    output [4:0] hour
);
    wire w_tick_100hz, w_sec_tick, w_min_tick, w_hour_tick;

    tick_counte #(
        .BIT_WIDTH(5),
        .TIMES(24)
    ) hour_counter (
        .clk(clk),
        .reset(reset),
        .i_tick(w_hour_tick),
        .mode(mode),
        .clear(clear),
        .run_stop(run_stop),
        .o_count(hour),
        .o_tick()
    );

    tick_counte #(
        .BIT_WIDTH(6),
        .TIMES(60)
    ) min_counter (
        .clk(clk),
        .reset(reset),
        .i_tick(w_min_tick),
        .mode(mode),
        .clear(clear),
        .run_stop(run_stop),
        .o_count(min),
        .o_tick(w_hour_tick)
    );

    tick_counte #(
        .BIT_WIDTH(6),
        .TIMES(60)
    ) sec_counter (
        .clk(clk),
        .reset(reset),
        .i_tick(w_sec_tick),
        .mode(mode),
        .clear(clear),
        .run_stop(run_stop),
        .o_count(sec),
        .o_tick(w_min_tick)
    );

    tick_counte #(
        .BIT_WIDTH(7),
        .TIMES(100)
    ) msec_counter (
        .clk(clk),
        .reset(reset),
        .i_tick(w_tick_100hz),
        .mode(mode),
        .clear(clear),
        .run_stop(run_stop),
        .o_count(msec),
        .o_tick(w_sec_tick)
    );

    tick_gen_100hz U_TICK_GEN (
        .clk(clk),
        .reset(reset),
        .i_run_stop(run_stop),
        .o_tick_100hz(w_tick_100hz)
    );

endmodule

//msec, sec, min, hour
//tick counter

module tick_counte #(
    parameter BIT_WIDTH = 7,
    TIMES = 100
) (
    input                            clk,
    input                            reset,
    input                            i_tick,
    input                            mode,
    input                            clear,
    input                            run_stop,
    output     [(BIT_WIDTH - 1) : 0] o_count,
    output reg                       o_tick
);

    //counter reg
    reg [(BIT_WIDTH - 1) : 0] counter_reg, counter_next;

    assign o_count = counter_reg;

    //state reg SL
    always @(posedge clk, posedge reset) begin
        if (reset | clear) begin
            counter_reg <= 0;
        end else begin
            counter_reg <= counter_next;
        end
    end

    //next CL
    always @(*) begin
        counter_next = counter_reg;
        o_tick = 1'b0;
        if (i_tick & run_stop) begin
            if (mode == 1'b1) begin
                //down
                if (counter_reg == 0) begin
                    counter_next = (TIMES - 1);
                    o_tick = 1'b1;
                end else begin
                    counter_next = counter_reg - 1;
                    o_tick = 1'b0;
                end
            end else begin
                //up
                if (counter_reg == (TIMES - 1)) begin
                    counter_next = 0;
                    o_tick = 1'b1;
                end else begin
                    counter_next = counter_reg + 1;
                    o_tick = 1'b0;
                end
            end
        end
    end

endmodule

module tick_gen_100hz (
    input clk,
    input reset,
    input i_run_stop,
    output reg o_tick_100hz
);
    parameter F_COUNT = 100_000_000 / 100;
    reg [$clog2(F_COUNT)-1:0] r_counter;

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            r_counter <= 0;
            o_tick_100hz <= 1'b0;
        end else begin
            if (i_run_stop) begin
                r_counter <= r_counter + 1;
                if (r_counter == (F_COUNT - 1)) begin
                    r_counter <= 0;
                    o_tick_100hz <= 1'b1;
                end else begin
                    o_tick_100hz <= 1'b0;
                end
            end
        end
    end
endmodule
