`timescale 1ns / 1ps


module tb_adder_fnd();
    reg [7:0] a, b;
    wire [3:0] fnd_digit;
    wire [7:0] fnd_data;
    wire c;

        integer i = 0, j = 0;

        top_adder dut (
            .a(a),
            .b(b),
            .fnd_digit(fnd_digit),
            .fnd_data(fnd_data),
            .c(c)
        );

        initial begin
            #0;
            a = 8'b0000_0000;
            b = 8'b0000_0000;
            #10;

            for ( i = 0 ; i < 256 ; i = i + 1 ) begin
                for ( j = 0 ; j < 256 ; j = j + 1 ) begin
                    a = i;
                    b = j;
                    #10;
                end
                
            end

            $stop;
            #100;
            $finish;

        end

endmodule
