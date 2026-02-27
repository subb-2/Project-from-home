`timescale 1ns / 1ps

module tb_dht_control();

 reg clk, rst, start;
    reg dht11_sensor_io, sensor_io_sel;
    wire dhtio;

    assign dhtio = (sensor_io_sel) ? 1'bz : dht11_sensor_io;

    dht11_controller dut (
        .clk(clk),
        .rst(rst),
        .start(start),
        .humidity(),
        .temperature(),
        .dht11_done(),
        .dht11_valid(),
        .debug(),
        .dhtio(dhtio)       
    );

    always #5 clk = ~clk;

    initial begin
        #0;
        clk = 0;
        rst = 1;
        start = 0;
        dht11_sensor_io = 1'b0;
        sensor_io_sel = 1'b1;
        //저쪽에서 나오고 있으니까 테스트는 끊어놓는 것 
        //동시에 나가면 X 나옴 

        //reset
        #20;
        rst = 0;
        #20;
        start = 1;
        #10;
        start = 0;

        //19msec + 30usec
        //저쪽에서 끊으니까 내가 넣어줘야 함
        #(1900*10*1000 + 30_000)
        sensor_io_sel = 0;

        #1000;
        $stop;
    end

endmodule
