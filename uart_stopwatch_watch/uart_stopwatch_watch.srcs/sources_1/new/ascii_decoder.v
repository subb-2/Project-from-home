`timescale 1ns / 1ps

//문자를 제어신호로 변환 
module ascii_decoder (
    input            clk,
    input            rst,
    input      [7:0] rx_data,
    input            rx_done,
    output reg [3:0] ascii_d
);

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            ascii_d <= 4'b0000;
        end else begin
            ascii_d <= 4'b0000;
            if (rx_done) begin
                case (rx_data)
                    8'h72: ascii_d <= 4'b0001;  //r
                    8'h6C: ascii_d <= 4'b0010;  //l
                    8'h75: ascii_d <= 4'b0100;  //u
                    8'h64: ascii_d <= 4'b1000;  //d
                endcase
            end
        end
    end

endmodule

module ascii_sw_set (
    input            clk,
    input            rst,
    input      [7:0] rx_data,
    input            rx_done,
    output reg       ascii_up_down,
    output reg       ascii_stopwatch_watch,
    output reg       ascii_hm_sms,
    output reg       ascii_watch_set
);

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            ascii_up_down         <= 0;
            ascii_stopwatch_watch <= 0;
            ascii_hm_sms          <= 0;
            ascii_watch_set       <= 0;
        end else begin
            if (rx_done) begin
                case (rx_data)
                    8'h30:   ascii_up_down <= ~ascii_up_down;
                    8'h31:   ascii_stopwatch_watch <= ~ascii_stopwatch_watch;
                    8'h32:   ascii_hm_sms <= ~ascii_hm_sms;
                    8'h33:   ascii_watch_set <= ~ascii_watch_set;
                    default: ;
                endcase
            end
        end
    end

endmodule
