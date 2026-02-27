`timescale 1ns / 1ps

module tb_counter();

reg clk, reset;
   // wire [7:0] fnd_data;
   // wire [3:0] fnd_digit;




   // top_10000_counter dut(
   //     .clk(clk),
   //     .reset(reset),
   //     .fnd_digit(fnd_digit),
   //     .fnd_data(fnd_data)
   // );


    reg mode, i_tick, clear, run_stop;
    wire [13:0] counter;

    counter_10000 dut (
    .clk(clk),
    .reset(reset),
    .i_tick(i_tick),
    .mode(mode),
    .clear(clear),
    .run_stop(run_stop),
    .counter_10000(counter)
);


    //generate clock
    always #5 clk = ~clk;


    always #10 i_tick = ~i_tick;
    // integer i;


    initial begin
        #0;
        clk = 0;
        reset = 1;
        mode = 0;
        i_tick = 1;
        run_stop = 1;
        clear = 0;

        #10;
        reset = 0;

        #50000;
        clear = 1;
        #50000;
        clear = 0;

        #200_000;
        mode = 1;

        #200_000;
        $stop;

    end

endmodule
