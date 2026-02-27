`timescale 1ns / 1ps


module top_10000_counter (
    input        clk,
    input        reset,
    input  [2:0] sw,         //sw[0] up/down sw[1] run_stop, se[2] clear
    output [3:0] fnd_digit,
    output [7:0] fnd_data
);


    wire [13:0] w_counter_10000;
    wire w_tick_10hz;


    tick_gen_10hz U_TICK_GEN (
        .clk(clk),
        .reset(reset),
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
        .mode(sw[0]),
        .clear(sw[2]),
        .run_stop(sw[1]),
        .counter_10000(w_counter_10000)
    );


endmodule


module tick_gen_10hz (
    input clk,
    input reset,
    output reg o_tick_10hz
);
    reg [$clog2(10_000_000)-1:0] r_counter;


    always @(posedge clk, posedge reset) begin
        if (reset) begin
            r_counter   <= 0;
            o_tick_10hz <= 1'b0;
        end else begin
            r_counter <= r_counter + 1;
            if (r_counter == (10_000_000 - 1)) begin
                r_counter   <= 0;
                o_tick_10hz <= 1'b1;
            end else begin
                o_tick_10hz <= 1'b0;
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
                        if (counter_r == 0) begin
                        counter_r <= 14'd9999;
                        end
                    end

                end else begin
                    if (i_tick) begin
                        counter_r <= counter_r + 1;
                        if (counter_r == (10000 - 1)) begin
                        counter_r <= 14'd0;
                        end
                    end   
                end
            end
        end
    end
endmodule


