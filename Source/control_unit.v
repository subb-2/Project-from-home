`timescale 1ns / 1ps

module control_unit (
    input      clk,
    input      reset,
    input      i_mode,
    input      i_run_stop,
    input      i_clear,
    input      i_set_watch,
    output     o_mode,
    output reg o_run_stop,
    output reg o_clear,
    output reg o_set_watch
);

    localparam STOP = 2'b00, RUN = 2'b01, CLEAR = 2'b10, SET_WATCH = 2'b11;

    // reg variable 
    reg [1:0] current_st, next_st;

    assign o_mode = i_mode;

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
        o_run_stop = 1'b0;
        o_clear    = 1'b0;
        o_set_watch = 1'b0;
        case (current_st)
            STOP: begin
                //moore output
                o_run_stop = 1'b0;
                o_clear = 1'b0;
                o_set_watch = 1'b0;
                if (i_run_stop == 1) begin
                    next_st = RUN;
                end else if (i_clear == 1) begin
                    next_st = CLEAR;
                end else if (i_set_watch == 1) begin
                    next_st = SET_WATCH;
                end
            end

            RUN: begin
                o_run_stop = 1'b1;
                o_clear = 1'b0;
                o_set_watch = 1'b0;
                if (i_run_stop == 1) begin
                    next_st = STOP;
                end
            end

            CLEAR: begin
                o_run_stop = 1'b0;
                o_clear = 1'b1;
                o_set_watch = 1'b0;
                next_st = STOP;
            end

            SET_WATCH: begin
                o_run_stop = 1'b0;
                o_clear = 1'b0;
                o_set_watch = 1'b1;
                if (i_set_watch == 0) begin
                    next_st = STOP;
                end
            end
        endcase
    end

endmodule
