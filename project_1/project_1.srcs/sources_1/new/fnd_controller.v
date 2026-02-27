`timescale 1ns / 1ps

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
module fnd_controller (
    input  [7:0] sum,
    input [1:0] btn,
    output [3:0] fnd_digit,
    output [7:0] fnd_data
);
    wire [3:0] w_digit_1, w_digit_10, w_digit_100, w_digit_1000, w_mux_4x1_out; //bit 맞추어야 함
    // ssign fnd_digit = 4'b1110;  // to fnd an[3:0]
    digit_splitter U_DIGIT_SPL (
        .in_data(sum),
        .digit_1(w_digit_1),
        .digit_10(w_digit_10),
        .digit_100(w_digit_100),
        .digit_1000(w_digit_1000)
    );
    Decoder2x4 U_Decoder_2x4 (
        .digit_sel(btn),
        .fnd_digit_D(fnd_digit)
    );
    mux_4x1 U_Mux_4x1 (
    .sel(btn),
    .digit_1(w_digit_1),
    .digit_10(w_digit_10),
    .digit_100(w_digit_100),
    .digit_1000(w_digit_1000),
    .mux_out(w_mux_4x1_out)
   
    );  
    bcd U_BCD (
        .bcd(w_mux_4x1_out),  //sum 8bit 중에서 4bit만 사용하겠음
        .fnd_data(fnd_data) //reg가 아니라, instance 이후 왜 wire인 것일까 bcd에서 선택되었고, controller에서는 값을 연결만 하는 것  
    );
endmodule
module mux_4x1 (
    input [1:0] sel,
    input [3:0] digit_1,
    input [3:0] digit_10,
    input [3:0] digit_100,
    input [3:0] digit_1000,
    output reg [3:0] mux_out
   
);
    // reg o_mux_out;
    // assign mux_out = o_mux_out;
 
    always @(*) begin //*을 사용 = 모든 입력을 감시하겠다는 의미
        case (sel) //선택만 하면 되는 것이므로
            2'b00: mux_out = digit_1;
            2'b01: mux_out = digit_10;
            2'b10: mux_out = digit_100;
            2'b11: mux_out = digit_1000;
           
        endcase
       
    end
   
endmodule
module digit_splitter (
    input  [7:0] in_data,
    output [3:0] digit_1,
    output [3:0] digit_10,
    output [3:0] digit_100,
    output [3:0] digit_1000
);
//들어오는 값 바로 연산 - assign 문 사용
    assign digit_1 = in_data % 10;
    assign digit_10 = (in_data/10) % 10;
    assign digit_100 = (in_data/100) % 10;
    assign digit_1000 = (in_data/1000) % 10; //10bit 이상 되어야지 나타남 지금은 gnd 연결 sum 이 8bit 이기 때문
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
            4'd1: fnd_data = 8'hf9; //bcd data 1이 들어오면 fnd_data f9가 출력됨 8'hf9를 유지한다는 의미
            4'd2: fnd_data = 8'ha4;
            4'd3: fnd_data = 8'hb0;
            4'd4: fnd_data = 8'h99;
            4'd5: fnd_data = 8'h92;
            4'd6: fnd_data = 8'h82;
            4'd7: fnd_data = 8'hf8;
            4'd8: fnd_data = 8'h80;
            4'd9: fnd_data = 8'h90;
            default:
            fnd_data = 8'hFF; //위의 경우 외의 경우에는 FF 출력 유지
        endcase
    end
endmodule