`timescale 1ns / 1ps

module fnd_controller (
    input         clk,
    input         reset,
    input         sel_display,
    input  [ 1:0] sel_set_4,
    input  [23:0] fnd_in_data_sw,
    input [23:0] fnd_in_data_w,
    input  [23:0] fnd_in_data_sr04,
    input  [23:0] fnd_in_data_dht11,
    output [ 3:0] fnd_digit,
    output [ 7:0] fnd_data
);

    wire [3:0] w_digit_msec_1, w_digit_msec_10;
    wire [3:0] w_digit_sec_1, w_digit_sec_10;
    wire [3:0] w_digit_min_1, w_digit_min_10;
    wire [3:0] w_digit_hour_1, w_digit_hour_10;

    wire [23:0] o_mux_set_4_mode;

    //BCD data for SR04, DHT11
    wire [3:0] w_digit_sr04_dht_3 = o_mux_set_4_mode[15:12];
    wire [3:0] w_digit_sr04_dht_2 = o_mux_set_4_mode[11:8];
    wire [3:0] w_digit_sr04_dht_1 = o_mux_set_4_mode[7:4];
    wire [3:0] w_digit_sr04_dht_0 = o_mux_set_4_mode[3:0];

    wire [3:0] w_mux_sr04_dht_out;

    wire in_sr04 = (sel_set_4 == 2'b10); // SR04 display mode
    wire in_dht  = (sel_set_4 == 2'b11); // DHT11 display mode

    //wire [8:0] dist_9bit = fnd_in_data[8:0];

    // wire [3:0] w_dist_dist_1 = dist_9bit % 10;
    // wire [3:0] w_dist_dist_10 = (dist_9bit / 10) % 10;
    // wire [3:0] w_dist_dist_100 = (dist_9bit / 100) % 10;
    // wire [3:0] w_dist_dist_1000 = 4'd0;

    // wire [3:0] w_digit_humi_int_1, w_digit_humi_int_10;
    // wire [3:0] w_digit_humi_dec_1, w_digit_humi_dec_10;
    // wire [3:0] w_digit_temp_int_1, w_digit_temp_int_10;
    // wire [3:0] w_digit_temp_dec_1, w_digit_temp_dec_10;

    // wire [3:0] w_mux_hour_min_out, w_mux_sec_msec_out;  //bit 맞추어야 함
    // wire [3:0] w_mux_sr04_out;
    // wire [3:0] w_mux_humi_out, w_mux_temp_out;
    // wire [3:0] w_hm_sms_out, w_hmdi_temp_out;
// 
    // wire [3:0] sel_bcd = (sel_set_4 == 2'b10) ? w_mux_sr04_out : // SR04 모드일 때
    // (sel_display) ? 
    //                             ((sel_set_4 == 2'b11) ? w_mux_temp_out : w_mux_hour_min_out) : // h.m 또는 Temp
    // ((sel_set_4 == 2'b11) ? w_mux_humi_out : w_mux_sec_msec_out);  // s.ms 또는 Humi

    wire [2:0] w_digit_sel;

    wire w_clk_1khz;
    wire w_dot_onoff;

    wire [3:0] w_mux_hour_min_out;
    wire [3:0] w_mux_sec_msec_out;
    wire [3:0] w_mux_hm_sms_out; 

    mux_4x1_sw_w_sr_dht U_MUX_4x1 (
        .sel_set_4(sel_set_4),
        .i_sel0_stopwatch(fnd_in_data_sw),
        .i_sel1_watch(fnd_in_data_w),
        .i_sel2_sr04(fnd_in_data_sr04),
        .i_sel3_dht11(fnd_in_data_dht11),
        .o_mux_set_4(o_mux_set_4_mode)
    );

    mux_8x1 U_MUX_SR_DHT (
        .sel           (w_digit_sel),
        .digit_1       (w_digit_sr04_dht_0),
        .digit_10      (w_digit_sr04_dht_1),
        .digit_100     (w_digit_sr04_dht_2),
        .digit_1000    (w_digit_sr04_dht_3),
        .digit_dot_1   (4'hf),
        .digit_dot_10  (4'he),
        .digit_dot_100 (4'hf),
        .digit_dot_1000(4'hf),
        .mux_out       (w_mux_sr04_dht_out)
    );

    // mux_8x1 U_Mux_SR04 (
    //     .sel(w_digit_sel),
    //     .digit_1(w_dist_dist_1),
    //     .digit_10(w_dist_dist_10),
    //     .digit_100(w_dist_dist_100),
    //     .digit_1000(w_dist_dist_1000),
    //     .digit_dot_1(4'hf),
    //     .digit_dot_10(4'hf),
    //     .digit_dot_100(4'he),
    //     .digit_dot_1000(4'hf),
    //     .mux_out(w_mux_sr04_out)
    // );

    // // dht11_humidity_integral
    // digit_splitter #(
    //     .BIT_WIDTH(8)
    // ) U_DHT11_HUMI_INT_DS (
    //     .in_data (fnd_in_data[31:24]),
    //     .digit_1 (w_digit_humi_int_1),
    //     .digit_10(w_digit_humi_int_10)
    // );
// 
    // // dht11_humidity_decimal
    // digit_splitter #(
    //     .BIT_WIDTH(8)
    // ) U_DHT11_HUMI_DEC_DS (
    //     .in_data (fnd_in_data[23:16]),
    //     .digit_1 (w_digit_humi_dec_1),
    //     .digit_10(w_digit_humi_dec_10)
    // );
// 
    // // dht11_temperature_integral
    // digit_splitter #(
    //     .BIT_WIDTH(8)
    // ) U_DHT11_TEMP_INT_DS (
    //     .in_data (fnd_in_data[15:8]),
    //     .digit_1 (w_digit_temp_int_1),
    //     .digit_10(w_digit_temp_int_10)
    // );
// 
    // // dht11_temperature_decimal
    // digit_splitter #(
    //     .BIT_WIDTH(8)
    // ) U_DHT11_TEMP_DEC_DS (
    //     .in_data (fnd_in_data[7:0]),
    //     .digit_1 (w_digit_temp_dec_1),
    //     .digit_10(w_digit_temp_dec_10)
    // );
// 
    // mux_8x1 U_Mux_HUMI (
    //     .sel(w_digit_sel),
    //     .digit_1(w_digit_humi_dec_1),
    //     .digit_10(w_digit_humi_dec_10),
    //     .digit_100(w_digit_humi_int_1),
    //     .digit_1000(w_digit_humi_int_10),
    //     .digit_dot_1(4'hf),
    //     .digit_dot_10(4'hf),
    //     .digit_dot_100(4'he),
    //     .digit_dot_1000(4'hf),
    //     .mux_out(w_mux_humi_out)
    // );
// 
    // mux_8x1 U_Mux_TEMP (
    //     .sel(w_digit_sel),
    //     .digit_1(w_digit_temp_dec_1),
    //     .digit_10(w_digit_temp_dec_10),
    //     .digit_100(w_digit_temp_int_1),
    //     .digit_1000(w_digit_temp_int_10),
    //     .digit_dot_1(4'hf),
    //     .digit_dot_10(4'hf),
    //     .digit_dot_100(4'he),
    //     .digit_dot_1000(4'hf),
    //     .mux_out(w_mux_temp_out)
    // );

    // ==============================
    // stopwatch, watch splitter
    // ==============================

    // hour
    digit_splitter #(
        .BIT_WIDTH(5)
    ) U_HOUR_DS (
        .in_data (o_mux_set_4_mode[23:19]),
        .digit_1 (w_digit_hour_1),
        .digit_10(w_digit_hour_10)
    );
    // min
    digit_splitter #(
        .BIT_WIDTH(6)
    ) U_MIN_DS (
        .in_data (o_mux_set_4_mode[18:13]),
        .digit_1 (w_digit_min_1),
        .digit_10(w_digit_min_10)
    );
    // sec
    digit_splitter #(
        .BIT_WIDTH(6)
    ) U_SEC_DS (
        .in_data (o_mux_set_4_mode[12:7]),
        .digit_1 (w_digit_sec_1),
        .digit_10(w_digit_sec_10)
    );
    //msec
    digit_splitter #(
        .BIT_WIDTH(7)
    ) U_MSEC_DS (
        .in_data (o_mux_set_4_mode[6:0]),
        .digit_1 (w_digit_msec_1),
        .digit_10(w_digit_msec_10)
    );

    dot_onoff_comp U_DOT_COMP (
        .msec(o_mux_set_4_mode[6:0]),
        .dot_onoff(w_dot_onoff)
    );

    mux_8x1 U_Mux_HOUR_MIN (
        .sel(w_digit_sel),
        .digit_1(w_digit_min_1),
        .digit_10(w_digit_min_10),
        .digit_100(w_digit_hour_1),
        .digit_1000(w_digit_hour_10),
        .digit_dot_1(4'hf),
        .digit_dot_10(4'hf),
        .digit_dot_100({3'b111, w_dot_onoff}),  //4bit 값 생성 
        .digit_dot_1000(4'hf),
        .mux_out(w_mux_hour_min_out)
    );

    mux_8x1 U_Mux_SEC_MSEC (
        .sel(w_digit_sel),
        .digit_1(w_digit_msec_1),
        .digit_10(w_digit_msec_10),
        .digit_100(w_digit_sec_1),
        .digit_1000(w_digit_sec_10),
        .digit_dot_1(4'hf),
        .digit_dot_10(4'hf),
        .digit_dot_100({3'b111, w_dot_onoff}),
        .digit_dot_1000(4'hf),
        .mux_out(w_mux_sec_msec_out)
    );

    // ========================================

    clk_div U_CLK_DIV (
        .clk(clk),
        .reset(reset),
        .o_1khz(w_clk_1khz)
    );

    counter_8 U_COUNTER_8 (
        .clk(clk),
        .reset(reset),
        .enable(w_clk_1khz),
        .digit_sel(w_digit_sel)
    );

    Decoder2x4 U_Decoder_2x4 (
        .digit_sel  (w_digit_sel[1:0]),  //3bit 이니까 2bit로 확실하게
        .fnd_digit_D(fnd_digit)
    );


    mux_2x1_stopwatch_watch U_MUX_2x1_SW_W (
        .sel(sel_display),
        .i_sel0_hm(w_mux_hour_min_out),
        .i_sel1_sms(w_mux_sec_msec_out),
        .o_mux_set(w_mux_hm_sms_out)
    );

    wire [3:0] sel_bcd = (in_sr04 || in_dht) ? w_mux_sr04_dht_out : w_mux_hm_sms_out;

    bcd U_BCD (
        .bcd(sel_bcd),  //sum 8bit 중에서 4bit만 사용하겠음
        .fnd_data(fnd_data) //reg가 아니라, instance 이후 왜 wire인 것일까 bcd에서 선택되었고, controller에서는 값을 연결만 하는 것  
    );

endmodule

module mux_2x1_stopwatch_watch (
     input         sel,
     input  [3:0] i_sel0_hm,
     input  [3:0] i_sel1_sms,
     output [3:0] o_mux_set
 );
     //sel 1 : output i_sel1 , 0 : i_sel0
     assign o_mux_set = (sel) ? i_sel1_sms : i_sel0_hm;
 
 endmodule

module mux_4x1_sw_w_sr_dht (
    input      [ 1:0] sel_set_4,
    input      [23:0] i_sel0_stopwatch,
    input      [23:0] i_sel1_watch,
    input      [23:0] i_sel2_sr04,
    input      [23:0] i_sel3_dht11,
    output reg [23:0] o_mux_set_4
);

    always @(*) begin
        case (sel_set_4)
            2'b00: begin
                o_mux_set_4 = i_sel0_stopwatch;
            end
            2'b01: begin
                o_mux_set_4 = i_sel1_watch;
            end
            2'b10: begin
                o_mux_set_4 = i_sel2_sr04;
            end
            2'b11: begin
                o_mux_set_4 = i_sel3_dht11;
            end
            //default: o_mux_set_4 = i_sel0_stopwatch;
        endcase
    end

endmodule


module dot_onoff_comp (
    input [6:0] msec,
    output dot_onoff
);
    assign dot_onoff = (msec < 50);  //참 1 거짓 0
endmodule

module clk_div (
    input clk,
    input reset,
    output reg o_1khz
);
    // reg [16:0] counter_r; //module 다르니 다른 변수
    reg [$clog2(
100_000
):0] counter_r;  //로그로 하면 알아서 bit로 바꿔줌

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            counter_r <= 0; // 초기화 안 하면 그냥 X로 출력함 - 일을 안함
            o_1khz <= 1'b0;
        end else begin
            if (counter_r == 99999) begin
                counter_r <= 0;
                o_1khz <= 1'b1;
            end else begin
                counter_r <= counter_r + 1; //9999까지만 가야하므로 조건 필요함
                o_1khz <= 1'b0;
            end
        end
    end
endmodule

module counter_8 (
    input        clk,
    input        reset,
    input        enable,
    output [2:0] digit_sel
);
    // 순차논리는 항상 always 구문 사용
    reg [2:0] counter_r;

    assign digit_sel = counter_r; // reg 다음에 assign 나오기 이래야지 오류 안남

    always @(posedge clk, posedge reset) begin
        //초기화 먼저
        if (reset == 1) begin
            counter_r <= 0;
        end else if (enable) begin
            //to do
            counter_r <= counter_r + 1'b1;  //2bit이므로, 0~3으로만 나옴
        end
    end
endmodule

//to select to fnd digit display
module Decoder2x4 (
    input [1:0] digit_sel,
    output reg [3:0] fnd_digit_D
);
    always @(digit_sel) begin
        case (digit_sel)
            2'b00: fnd_digit_D = 4'b1110;
            2'b01: fnd_digit_D = 4'b1101;
            2'b10: fnd_digit_D = 4'b1011;
            2'b11: fnd_digit_D = 4'b0111;
        endcase
    end

endmodule

module mux_8x1 (
    input [2:0] sel,
    input [3:0] digit_1,
    input [3:0] digit_10,
    input [3:0] digit_100,
    input [3:0] digit_1000,
    input [3:0] digit_dot_1,
    input [3:0] digit_dot_10,
    input [3:0] digit_dot_100,
    input [3:0] digit_dot_1000,
    output reg [3:0] mux_out
);
    // reg o_mux_out;
    // assign mux_out = o_mux_out;
    always @(*) begin //*을 사용 = 모든 입력을 감시하겠다는 의미
        case (sel)  //선택만 하면 되는 것이므로
            3'b000: mux_out = digit_1;
            3'b001: mux_out = digit_10;
            3'b010: mux_out = digit_100;
            3'b011: mux_out = digit_1000;
            3'b100: mux_out = digit_dot_1;
            3'b101: mux_out = digit_dot_10;
            3'b110: mux_out = digit_dot_100;
            3'b111: mux_out = digit_dot_1000;
        endcase
    end
endmodule

module digit_splitter #(
    parameter BIT_WIDTH = 7
) (
    input [(BIT_WIDTH - 1):0] in_data,
    output [3:0] digit_1,
    output [3:0] digit_10
);
    //들어오는 값 바로 연산 - assign 문 사용
    assign digit_1  = in_data % 10;
    assign digit_10 = (in_data / 10) % 10;
    //연산기 , 연산은 assign하고 always 문 둘 다 사용 가능
endmodule

module bcd (
    input [3:0] bcd,
    output reg [7:0] fnd_data // bcd에서 나와서 fnd로 들어가서 4bit라고 생각했는데, 아님, 8bit
    // reg 안 쓰면, 기본인 wire로 연결
);

    always @(bcd) begin
        case (bcd)
            4'd0: fnd_data = 8'hc0;  //fnd_data가 output data
            4'd1:
            fnd_data = 8'hf9; //bcd data 1이 들어오면 fnd_data f9가 출력됨 8'hf9를 유지한다는 의미
            4'd2: fnd_data = 8'ha4;
            4'd3: fnd_data = 8'hb0;
            4'd4: fnd_data = 8'h99;
            4'd5: fnd_data = 8'h92;
            4'd6: fnd_data = 8'h82;
            4'd7: fnd_data = 8'hf8;
            4'd8: fnd_data = 8'h80;
            4'd9: fnd_data = 8'h90;
            4'd10: fnd_data = 8'h92;  // s
            4'd11: fnd_data = 8'haf;  // r
            4'd12: fnd_data = 8'h87;  // t
            4'd13: fnd_data = 8'h8b;  // h
            4'd14: fnd_data = 8'h7f;  // dot
            4'd15: fnd_data = 8'hff;
            default:
            fnd_data = 8'hFF; //위의 경우 외의 경우에는 FF 출력 유지
        endcase
    end
endmodule
