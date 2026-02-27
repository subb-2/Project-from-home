`timescale 1ns / 1ps

module stopwatch_watch(

    input        clk,
    input        reset,
    input  [4:0] sw,         //sw[0] up/down
    input        btn_r,      //i_run_stop
    input        btn_l,      //i_clear
    input        btn_u,
    input        btn_d,
    input        uart_rx,
    output [3:0] fnd_digit,
    output [7:0] fnd_data,
    output       uart_tx
);

    wire [13:0] w_counter_10000;
    wire w_run_stop, w_clear, w_mode;
    wire w_set_watch;
    wire o_btn_run_stop, o_btn_clear; 
    wire o_btn_u, o_btn_d;
    wire [23:0] o_mux_set;
    wire        o_mux_watch_set;
    wire [23:0] w_watch_time;
    wire [23:0] w_stopwatch_time;
    wire [ 3:0] w_ascii_d;
    wire [ 7:0] w_rx_data;
    wire        w_rx_done;
    wire w_run_stop_or, w_clear_or, w_btn_u_or, w_btn_d_or;
    wire w_ascii_up_down, w_ascii_stopwatch_watch, w_ascii_hm_sms, w_ascii_watch_set;

    assign w_run_stop_or = o_btn_run_stop | w_ascii_d[0];
    assign w_clear_or = o_btn_clear | w_ascii_d[1];
    assign w_btn_u_or = o_btn_u | w_ascii_d[2];
    assign w_btn_d_or = o_btn_d | w_ascii_d[3];

    assign w_uart_sw_sel = sw[4];

    assign w_up_down_mux = w_uart_sw_sel ? w_ascii_up_down : sw[0];
    assign w_stopwatch_watch_mux =  w_uart_sw_sel ? w_ascii_stopwatch_watch : sw[1];
    assign w_hm_sms_mux =  w_uart_sw_sel ? w_ascii_hm_sms : sw[2];
    assign w_watch_set_mux =  w_uart_sw_sel ? w_ascii_watch_set : sw[3];

    uart_top U_UART_TOP (
        .clk(clk),
        .rst(reset),
        .uart_rx(uart_rx),
        .rx_data(w_rx_data),
        .rx_done(w_rx_done),
        .uart_tx(uart_tx)
    );

    ascii_decoder U_ASCII_DECODER (
        .clk(clk),
        .rst(reset),
        .rx_data(w_rx_data),
        .rx_done(w_rx_done),
        .ascii_d(w_ascii_d)
    );

    ascii_sw_set U_ASCII_SW_SET (
        .clk(clk),
        .rst(reset),
        .rx_data(w_rx_data),
        .rx_done(w_rx_done),
        .ascii_up_down(w_ascii_up_down),
        .ascii_stopwatch_watch(w_ascii_stopwatch_watch),
        .ascii_hm_sms(w_ascii_hm_sms),
        .ascii_watch_set(w_ascii_watch_set)
    );

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
        .clk        (clk),
        .reset      (reset),
        .i_mode     (w_up_down_mux),
        .i_run_stop (w_run_stop_or),
        .i_clear    (w_clear_or),
        .i_set_watch(w_stopwatch_watch_mux),
        .o_mode     (w_mode),
        .o_run_stop (w_run_stop),
        .o_clear    (w_clear),
        .o_set_watch(w_set_watch)
    );

    watch_datapath U_WATCH_DATAPATH (
        .clk(clk),
        .reset(reset),
        .mode(w_mode),
        .clear(w_clear),
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
        .mode    (w_mode),
        .clear   (w_clear),
        .run_stop(w_run_stop),
        .msec    (w_stopwatch_time[6:0]),    //7bit
        .sec     (w_stopwatch_time[12:7]),   //6bit
        .min     (w_stopwatch_time[18:13]),  //6bit
        .hour    (w_stopwatch_time[23:19])   // 5bit
    );

    mux_2x1_stopwatch_watch U_MUX_2x1_STOPWATCH_WATCH (
        .sel_set(w_set_watch),
        .i_sel0_stopwatch(w_stopwatch_time),
        .i_sel1_watch(w_watch_time),
        .o_mux_set(o_mux_set)
    );

    fnd_controller U_FND_CNTL (
        .clk        (clk),
        .reset      (reset),
        .sel_display(w_hm_sms_mux),
        .fnd_in_data(o_mux_set),
        .fnd_digit  (fnd_digit),
        .fnd_data   (fnd_data)
    );

endmodule

module mux_2x1_stopwatch_watch (
    input         sel_set,
    input  [23:0] i_sel0_stopwatch,
    input  [23:0] i_sel1_watch,
    output [23:0] o_mux_set
);
    //sel 1 : output i_sel1 , 0 : i_sel0
    assign o_mux_set = (sel_set) ? i_sel1_watch : i_sel0_stopwatch;

endmodule

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