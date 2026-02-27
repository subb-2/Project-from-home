`timescale 1ns / 1ps

module tb_stopwatch_watch_3();

    parameter BAUD = 9600;
    parameter BAUD_PERIOD = (100_000_000/BAUD) * 10; // 예상 = 104_160

    reg clk, reset;
    reg [4:0] sw;
    reg btn_r, btn_l, btn_u, btn_d;
    reg rx;  
    wire tx;
    wire [3:0] fnd_digit;
    wire [7:0] fnd_data;

    reg [7:0] test_data;

    integer i, j;

    stopwatch_watch dut (
        .clk(),
        .reset(),
        .sw(),             //sw[0] up/down
        .btn_r(),          //i_run_stop
        .btn_l(),          //i_clear
        .btn_u(),
        .btn_d(),
        .uart_rx(),
        .echo(),
        .trigger(),
        .fnd_digit(),
        .fnd_data(),
        .uart_tx(),
        .dht_valid(),
        .dht_debug_led(),
        .dhtio()
    );

    //stopwatch_watch dut (
    //    .clk(clk),
    //    .reset(reset),
    //    .sw(sw),         //sw[0] up/down
    //    .btn_r(btn_r),      //i_run_stop
    //    .btn_l(btn_l),      //i_clear
    //    .btn_u(btn_u),
    //    .btn_d(btn_d),
    //    .uart_rx(rx),
    //    .fnd_digit(fnd_digit),
    //    .fnd_data(fnd_data),
    //    .uart_tx(tx)
    //);

    always #5 clk = ~clk;

    task uart_sender(); 
        begin
            //uart test pattern
            //start
            rx = 0; 
            #(BAUD_PERIOD);

            for(i = 0; i < 8; i = i + 1) begin
                rx = test_data[i];

                #(BAUD_PERIOD);
            end

            //stop
            rx = 1'b1;
            #(BAUD_PERIOD);
        end
    endtask

    initial begin
        #0;
        clk = 0;
        reset = 1;

        sw = 4'b0000;
        btn_r = 0;
        btn_l = 0;
        btn_u = 0;
        btn_d = 0;
        rx = 1'b1;

        i = 0;
        j = 0;

        test_data =  8'h30;

        repeat (10) @(posedge clk);
        reset = 0;

        sw[0] = 0;  // up 모드
        sw[1] = 0;  // 스톱워치 선택
        sw[2] = 0;  // 초.밀리초 모드

        for(j = 0;j < 100;j = j + 1) begin
            #(BAUD_PERIOD);
        end

        test_data = 8'h72; //r
        uart_sender();

        for(j = 0;j < 1000;j = j + 1) begin
            #(BAUD_PERIOD);
        end

        test_data = 8'h72; //r
        uart_sender();

        for(j = 0;j < 1000;j = j + 1) begin
            #(BAUD_PERIOD);
        end

        test_data = 8'h6C; //l
        uart_sender();

        for(j = 0;j < 100;j = j + 1) begin
            #(BAUD_PERIOD);
        end

        sw[4] = 1;
        #1000;

        test_data = 8'h30; // sw[0]
        uart_sender();

        test_data = 8'h31; // sw[1]
        uart_sender();

        test_data = 8'h32; // sw[2]
        uart_sender();

        for(j = 0;j < 1000;j = j + 1) begin
            #(BAUD_PERIOD);
        end

        test_data = 8'h72; //r
        uart_sender();

        for(j = 0;j < 1000;j = j + 1) begin
            #(BAUD_PERIOD);
        end

        test_data = 8'h75; // u
        uart_sender();

        #(BAUD_PERIOD);

        test_data = 8'h75; // u
        uart_sender();

        #(BAUD_PERIOD);

        for(j = 0;j < 1000;j = j + 1) begin
            #(BAUD_PERIOD);
        end

        test_data = 8'h64; //d
        uart_sender();

        #(BAUD_PERIOD);

        test_data = 8'h64; //d
        uart_sender();

        #(BAUD_PERIOD);

        test_data = 8'h33; // sw[3]
        uart_sender();

        test_data = 8'h75; // u
        uart_sender();

        #(BAUD_PERIOD);

        test_data = 8'h75; // u
        uart_sender();

        #(BAUD_PERIOD);

        test_data = 8'h64; //d
        uart_sender();

        #(BAUD_PERIOD);

        test_data = 8'h64; //d
        uart_sender();

        #(BAUD_PERIOD);

        for(j = 0;j < 1000;j = j + 1) begin
            #(BAUD_PERIOD);
        end

        for(j = 0;j < 12;j = j + 1) begin
            #(BAUD_PERIOD);
        end

        $stop; 



    end

endmodule