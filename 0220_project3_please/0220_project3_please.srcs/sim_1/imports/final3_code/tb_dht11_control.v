`timescale 1ns / 1ps

module tb_dht11_control();

    reg clk, rst, start;
    reg dht11_sensor_io, sensor_io_sel;
    reg [5:0] sw;
    reg btn_r, btn_l, btn_u, btn_d;
    reg rx;
    wire tx;
    reg echo;
    wire trigger;
    wire [3:0] fnd_digit;
    wire [7:0] fnd_data; 
    wire dht_valid;
    wire [10:0] dht_debug_led, btn_debug_led;
    wire dhtio;

    assign dhtio = (sensor_io_sel) ? 1'bz : dht11_sensor_io;

    stopwatch_watch dut (
        .clk(clk),
        .reset(rst),
        .sw(sw),             //sw[0] up/down
        .btn_r(btn_r),          //i_run_stop
        .btn_l(btn_l),          //i_clear
        .btn_u(btn_u),
        .btn_d(btn_d),
        .uart_rx(rx),
        .echo(echo),
        .trigger(trigger),
        .fnd_digit(fnd_digit),
        .fnd_data(fnd_data),
        .uart_tx(tx),
        .dht_valid(dht_valid),
        .dht_debug_led(dht_debug_led),
        .btn_debug_led(btn_debug_led),
        .dhtio(dhtio)
    );
    
    //dht11_top dut (
    //    .clk(clk),
    //    .rst(rst),
    //    .btn_r_start(start),
    //    .humidity(humidity),
    //    .temperature(temperature),
    //    .dht_done(dht_done),
    //    .dht_valid(dht_valid),
    //    .dht_debug_led(dht_debug_led),
    //    .dhtio(dhtio)
    //);

    always #5 clk = ~clk;

    reg [39:0] dht11_sensor_data;
    reg [39:0] dht11_sensor_data_fail;
    integer i;

    initial begin
        #0;
        clk = 0;
        rst = 1;
        start = 0;
        dht11_sensor_io = 1'b0;
        sensor_io_sel = 1'b1;
        //저쪽에서 나오고 있으니까 테스트는 끊어놓는 것 
        //동시에 나가면 X 나옴 
        sw = 0;
        btn_r = 0; 
        btn_l = 0; 
        btn_u = 0; 
        btn_d = 0;
        rx = 1'b1;     // UART idle 보통 1
        echo = 1'b0;
        i = 0;
        dht11_sensor_io = 1'b0;
        sensor_io_sel = 1'b1;
        //huminity integral, decimal, temperature integral, decimal. checksum
        //huminity 50.00 / temperature 32.00
        dht11_sensor_data = {8'h32, 8'h00, 8'h19, 8'h00, 8'h4b};
        dht11_sensor_data_fail = {8'h32, 8'h00, 8'h19, 8'h00, 8'h3c};
        //저쪽에서 나오고 있으니까 테스트는 끊어놓는 것 
        //동시에 나가면 X 나옴 

        //reset
        #20;
        rst = 0;
        #20;

        sw[1] = 1;
        sw[4] = 1;
        // sw[2] = 1 : humidity
        // sw[2] = 0 : temperature 

        //success

        btn_r = 1;
        #1_000_000;
        btn_r = 0;

        //19msec + 30usec
        //저쪽에서 끊으니까 내가 넣어줘야 함
        //start signal + wait
        #(1900 * 10 * 1000 + 30_000);

        //to output, sensor to fpga
        sensor_io_sel   = 0; 

        //sync_L, sync_H
        dht11_sensor_io = 1'b0;
        #(80_000);
        dht11_sensor_io = 1'b1;
        #(80_000);

        //40bit data pattern

        for (i = 39; i >= 0; i = i - 1) begin
            //data sync
            dht11_sensor_io = 1'b0;
            #(50_000);
            //data value
            if (dht11_sensor_data[i] == 0) begin
                dht11_sensor_io = 1'b1;
                #(28_000);
            end else begin
                dht11_sensor_io = 1'b1;
                #(70_000);
            end
        end

        dht11_sensor_io = 1'b0;
        #(50_000);

        //to output, fpga to sensor
        sensor_io_sel = 1;

        #100_000;

// ==============================================

        //valid fail

        btn_r = 1;
        #1_000_000;
        btn_r = 0;

        //19msec + 30usec
        //저쪽에서 끊으니까 내가 넣어줘야 함
        //start signal + wait
        #(1900 * 10 * 1000 + 30_000);

        //to output, sensor to fpga
        sensor_io_sel   = 0; 

        //sync_L, sync_H
        dht11_sensor_io = 1'b0;
        #(80_000);
        dht11_sensor_io = 1'b1;
        #(80_000);

        //40bit data pattern

        for (i = 39; i >= 0; i = i - 1) begin
            //data sync
            dht11_sensor_io = 1'b0;
            #(50_000);
            //data value
            if (dht11_sensor_data_fail[i] == 0) begin
                dht11_sensor_io = 1'b1;
                #(28_000);
            end else begin
                dht11_sensor_io = 1'b1;
                #(70_000);
            end
        end

        dht11_sensor_io = 1'b0;
        #(50_000);

        //to output, fpga to sensor
        sensor_io_sel = 1;

        #100_000;

// ===============================================

        //state fail

        btn_r = 1;
        #1_000_000;
        btn_r = 0;

        //19msec + 30usec
        //저쪽에서 끊으니까 내가 넣어줘야 함
        //start signal + wait
        #(1900 * 10 * 1000 + 30_000);

        //to output, sensor to fpga
        sensor_io_sel   = 0; 

        //sync_L, sync_H
        dht11_sensor_io = 1'b0;
        #(80_000);
        dht11_sensor_io = 1'b1;
        #(80_000);

        //40bit data pattern

        for (i = 30; i >= 0; i = i - 1) begin
            //data sync
            dht11_sensor_io = 1'b0;
            #(50_000);
            //data value
            if (dht11_sensor_data[i] == 0) begin
                dht11_sensor_io = 1'b1;
                #(28_000);
            end else begin
                dht11_sensor_io = 1'b1;
                #(70_000);
            end
        end

        dht11_sensor_io = 1'b0;
        #(50_000);

        //to output, fpga to sensor
        sensor_io_sel = 1;

        #1_010_000_000; //1.1초 대기 
        
        //reset 이후 시간 보내기 자동 시작

        rst = 1;
        #20;
        rst = 0;
        #20;

        #1_200_000_000;

        #(1900 * 10 * 1000 + 30_000);

        //to output, sensor to fpga
        sensor_io_sel   = 0; 

        //sync_L, sync_H
        dht11_sensor_io = 1'b0;
        #(80_000);
        dht11_sensor_io = 1'b1;
        #(80_000);

        //40bit data pattern

        for (i = 39; i >= 0; i = i - 1) begin
            //data sync
            dht11_sensor_io = 1'b0;
            #(50_000);
            //data value
            if (dht11_sensor_data[i] == 0) begin
                dht11_sensor_io = 1'b1;
                #(28_000);
            end else begin
                dht11_sensor_io = 1'b1;
                #(70_000);
            end
        end

        dht11_sensor_io = 1'b0;
        #(50_000);

        //to output, fpga to sensor
        sensor_io_sel = 1;

        #100_000;


        repeat (60) begin
            #1_000_000_000;   // 1초
        end
        
        $stop;
    end

endmodule