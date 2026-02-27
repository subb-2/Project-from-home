`timescale 1ns / 1ps


module Top_10000_counter (
    input        clk,
    input        reset,
    input        sw,         //sw[0] up/down 
    input        btn_r,      //i_run_stop
    input        btn_l,      //i_clear 
    output [3:0] fnd_digit,
    output [7:0] fnd_data
);

    wire [13:0] w_counter_10000;
    wire w_tick_10hz;
    wire w_run_stop, w_clear, w_mode;
    wire o_btn_run_stop, o_btn_clear;

    btn_debounce U_BD_RUNSTOP (
        .clk(clk),
        .reset(reset),
        .i_btn(btn_r),
        .o_btn(o_btn_run_stop)
    );

    btn_debounce U_BD_CLEAR (
        .clk(clk),
        .reset(reset),
        .i_btn(btn_l),
        .o_btn(o_btn_clear)
    );

    control_unit U_CONTROL_UNIT (
        .clk(clk),
        .reset(reset),
        .i_mode(sw),
        .i_run_stop(o_btn_run_stop),
        .i_clear(o_btn_clear),
        .o_mode(w_mode),
        .o_run_stop(w_run_stop),
        .o_clear(w_clear)
    );

    tick_gen_10hz U_TICK_GEN (
        .clk(clk),
        .reset(reset),
        .i_run_stop(w_run_stop),
        .o_tick_10hz(w_tick_10hz)
    );

    fnd_controller U_FND_CNTL (
        .clk(clk),
        .reset(reset),
        .fnd_in_data(w_counter_10000),
        .fnd_digit(fnd_digit),
        .fnd_data(fnd_data)
    );

    counter_10000 U_COUNTER_10000 (
        .clk(clk),
        .reset(reset),
        .i_tick(w_tick_10hz),
        .mode(w_mode),
        .clear(w_clear),
        .run_stop(w_run_stop),
        .counter_10000(w_counter_10000)
    );

endmodule


module tick_gen_10hz (
    input clk,
    input reset,
    input i_run_stop,
    output reg o_tick_10hz
);
    reg [$clog2(10_000_000)-1:0] r_counter;

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            r_counter   <= 0;
            o_tick_10hz <= 1'b0;
        end else begin
            if (i_run_stop) begin
                r_counter <= r_counter + 1;
                if (r_counter == (10_000_000 - 1)) begin
                    r_counter   <= 0;
                    o_tick_10hz <= 1'b1;
                end else begin
                    o_tick_10hz <= 1'b0;
                end
            end 
        end
    end
endmodule

module counter_10000 (
    input         clk,
    input         reset,
    input         i_tick,
    input         mode,
    input         clear,
    input         run_stop,
    output [13:0] counter_10000
);

    reg [13:0] counter_r;

    assign counter_10000 = counter_r;

    always @(posedge clk, posedge reset) begin
        //reset init
        if (reset | clear) begin
            counter_r <= 14'd0;
        end else begin
            //to do
            if (run_stop) begin
                if (mode) begin
                    if (i_tick) begin
                        counter_r <= counter_r - 1;
                    end

                    if (counter_r == 0) begin
                        counter_r <= 14'd9999;
                    end
                end else begin
                    if (i_tick) begin
                        counter_r <= counter_r + 1;
                    end
                    if (counter_r == (10000 - 1)) begin
                        counter_r <= 14'd0;
                    end
                end
            end
        end

    end

endmodule


