`timescale 1ns / 1ps

module tb_dht11_control();

    reg clk, rst, start;
    reg dht11_sensor_io, sensor_io_sel;
    wire dhtio;

    assign dhtio = (sensor_io_sel) ? 1'bz : dht11_sensor_io;

    
    dht11_top dut (
        .clk(clk),
        .rst(rst),
        .btn_r_start(start),
        .humidity(humidity),
        .temperature(temperature),
        .dht_done(dht_done),
        .dht_valid(dht_valid),
        .dht_debug_led(dht_debug_led),
        .dhtio(dhtio)
    );

   always #5 clk = ~clk;

    reg [39:0] test_data;
    integer i;

    // test data
    task bit_send(input data);
    begin
        //Low
        dht11_sensor_io = 1'b0;
        #(50_000); 
        
        //High
        dht11_sensor_io = 1'b1;
        if (data) begin
            #(70_000); // Logic '1' 
        end else begin
            #(30_000); // Logic '0'
        end
            
    end
    endtask

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
        #10_000_000;
        start = 0;

        //19msec + 30usec
        //저쪽에서 끊으니까 내가 넣어줘야 함
        #(1900*10*1000 + 30_000)
        sensor_io_sel = 0;

        //SYNCL, SYNCH
        dht11_sensor_io = 1'b0; 
        #(80_000);

        dht11_sensor_io = 1'b1; 
        #(80_000);

        //test data
        test_data = {8'h10, 8'h20, 8'h30, 8'h40, 8'ha0};

        //40비트 데이터
        for (i = 39; i >= 0; i = i - 1) begin
            bit_send(test_data[i]);
        end

        //전송 완료 후
        dht11_sensor_io = 1'b0;
        #(50_000); //stop
        sensor_io_sel = 1'b1; //다시 high
        dht11_sensor_io = 1'b1;

        
        #200_000;
        if (dut.dht_valid) 
            $display("SUCCESS: Humidity = %d.%d%%, Temperature = %d.%dC", dut.humidity[15:8], dut.humidity[7:0], dut.temperature[15:8], dut.temperature[7:0]);
        else 
            $display("ERROR: Checksum mismatch or data not received! Valid bit is 0.");


        #1000;
        $stop;
    end


endmodule
