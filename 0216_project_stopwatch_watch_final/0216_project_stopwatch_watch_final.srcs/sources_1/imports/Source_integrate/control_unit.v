`timescale 1ns / 1ps

module control_unit (
    input       clk,
    input       reset,
    input [5:0] sw,
    input [4:0] ascii_d,

    input btn_r,
    input btn_l,
    input btn_u,
    input btn_d,

    input ascii_up_down,
    input ascii_stopwatch_watch,
    input ascii_hm_sms,
    input ascii_watch_set,
    input ascii_humi_temp,

    output o_up_down_mux,
    output o_stopwatch_watch_mux,
    output o_hm_sms_mux,
    output o_watch_set_mux,
    output o_humi_temp_mux,

    output reg       o_run_stop_or,
    output reg       o_clear_or,
    output           o_btn_u_or,
    output           o_btn_d_or,
    output     [1:0] sel_set_4
);

    //FSM
    localparam STOP = 2'b00, RUN = 2'b01, CLEAR = 2'b10;

    // reg variable
    reg [1:0] current_st, next_st;
    wire i_run_stop_or, i_clear_or;
    wire i_btn_u_or, i_btn_d_or;
    wire uart_sw_sel;

    //btn and ascii input
    assign i_run_stop_or = btn_r | ascii_d[0];
    assign i_clear_or = btn_l | ascii_d[1];
    assign i_btn_u_or = btn_u | ascii_d[2];
    assign i_btn_d_or = btn_d | ascii_d[3];

    assign o_btn_u_or = i_btn_u_or;
    assign o_btn_d_or = i_btn_d_or;

    assign sel_set_4 = {sw[1], sw[5]};
    assign uart_sw_sel = sw[4];

    //uart vs sw 
    assign o_up_down_mux = uart_sw_sel ? ascii_up_down : sw[0];
    assign o_stopwatch_watch_mux = uart_sw_sel ? ascii_stopwatch_watch : sw[1];
    assign o_hm_sms_mux = uart_sw_sel ? ascii_hm_sms : sw[2];
    assign o_watch_set_mux = uart_sw_sel ? ascii_watch_set : sw[3];
    assign o_humi_temp_mux = uart_sw_sel ? ascii_humi_temp : sw[5];


    //state register SL
    always @(posedge clk, posedge reset) begin
        if (reset) begin
            current_st <= STOP;
        end else begin
            current_st <= next_st;
        end
    end


    //next CL
    always @(*) begin
        next_st    = current_st;
        o_run_stop_or = 1'b0;
        o_clear_or    = 1'b0;
        case (current_st)
            STOP: begin
                //moore output
                o_run_stop_or = 1'b0;
                o_clear_or = 1'b0;
                if (i_run_stop_or == 1) begin
                    next_st = RUN;
                end else if (i_clear_or == 1) begin
                    next_st = CLEAR;
                end
            end

            RUN: begin
                o_run_stop_or = 1'b1;
                o_clear_or = 1'b0;
                if (i_run_stop_or == 1) begin
                    next_st = STOP;
                end
            end

            CLEAR: begin
                o_run_stop_or = 1'b0;
                o_clear_or = 1'b1;
                next_st = STOP;
            end
        endcase
    end
endmodule
