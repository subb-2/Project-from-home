`timescale 1ns / 1ps

//문자를 제어신호로 변환 
module ascii_decoder (
    input            clk,
    input            rst,
    input      [7:0] pop_data,
    input            empty,
    output reg       pop, 
    output reg [4:0] ascii_d
);

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            ascii_d <= 5'b0000;
            pop     <= 1'b0;
        end else begin
            ascii_d <= 5'b0000;
            pop     <= 1'b0;
            if (!empty) begin
                pop <= 1'b1;
                case (pop_data)
                    8'h72: ascii_d <= 5'b00001;  //r
                    8'h6C: ascii_d <= 5'b00010;  //l
                    8'h75: ascii_d <= 5'b00100;  //u
                    8'h64: ascii_d <= 5'b01000;  //d
                    8'h73: ascii_d <= 5'b10000;  //s
                endcase
            end
        end
    end

endmodule

module ascii_sw_set (
    input            clk,
    input            rst,
    input      [7:0] pop_data,
    input            empty,
    output reg       pop,
    output reg       ascii_up_down,
    output reg       ascii_stopwatch_watch,
    output reg       ascii_hm_sms,
    output reg       ascii_watch_set,
    output reg       ascii_humi_temp
);

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            pop                   <= 1'b0;
            ascii_up_down         <= 0;
            ascii_stopwatch_watch <= 0;
            ascii_hm_sms          <= 0;
            ascii_watch_set       <= 0;
            ascii_humi_temp       <= 0;
        end else begin
            if (!empty) begin
                pop <= 1'b1;
                case (pop_data)
                    8'h30:   ascii_up_down <= ~ascii_up_down;
                    8'h31:   ascii_stopwatch_watch <= ~ascii_stopwatch_watch;
                    8'h32:   ascii_hm_sms <= ~ascii_hm_sms;
                    8'h33:   ascii_watch_set <= ~ascii_watch_set;
                    8'h35:   ascii_humi_temp <= ~ascii_humi_temp;
                    default: ;
                endcase
            end
        end
    end

endmodule

module ascii_sender (
    input             clk,
    input             rst,
    input      [31:0] mux_2x1_set,
    input             ascii_d_s,
    input             full,
    output reg        push_start,
    output reg [ 7:0] push_data
);

    wire [7:0] ascii_hour_10, ascii_hour_1, ascii_min_10, ascii_min_1,
                ascii_sec_10, ascii_sec_1, ascii_msec_10, ascii_msec_1;
    wire [3:0] send_hour_10, send_hour_1, send_min_10, send_min_1,
                send_sec_10, send_sec_1, send_msec_10, send_msec_1;

    bcd_sender U_BCD_SENDER_HOUR_10 (
        .bcd_sender(send_hour_10),
        .send_data (ascii_hour_10)
    );
    bcd_sender U_BCD_SENDER_HOUR_1 (
        .bcd_sender(send_hour_1),
        .send_data (ascii_hour_1)
    );
    bcd_sender U_BCD_SENDER_MIN_10 (
        .bcd_sender(send_min_10),
        .send_data (ascii_min_10)
    );
    bcd_sender U_BCD_SENDER_MIN_1 (
        .bcd_sender(send_min_1),
        .send_data (ascii_min_1)
    );
    bcd_sender U_BCD_SENDER_SEC_10 (
        .bcd_sender(send_sec_10),
        .send_data (ascii_sec_10)
    );
    bcd_sender U_BCD_SENDER_SEC_1 (
        .bcd_sender(send_sec_1),
        .send_data (ascii_sec_1)
    );
    bcd_sender U_BCD_SENDER_MSEC_10 (
        .bcd_sender(send_msec_10),
        .send_data (ascii_msec_10)
    );
    bcd_sender U_BCD_SENDER_MSEC_1 (
        .bcd_sender(send_msec_1),
        .send_data (ascii_msec_1)
    );

    parameter IDLE = 2'd0, SEND = 2'd1;

    reg [2:0] c_state, n_state;
    reg [3:0] send_cnt_reg, send_cnt_next;


    reg [23:0] data_cap_r;
    always @(posedge clk, posedge rst) begin
        if (rst) begin
            data_cap_r <= 24'd0;
        end else begin
            if (ascii_d_s & c_state == IDLE) begin
                data_cap_r <= mux_2x1_set;
            end
        end
    end

    assign send_hour_10 = (data_cap_r[23:19] / 10) % 10;
    assign send_hour_1  = data_cap_r[23:19] % 10;

    assign send_min_10  = (data_cap_r[18:13] / 10) % 10;
    assign send_min_1   = data_cap_r[18:13] % 10;

    assign send_sec_10  = (data_cap_r[12:7] / 10) % 10;
    assign send_sec_1   = data_cap_r[12:7] % 10;

    assign send_msec_10 = (data_cap_r[6:0] / 10) % 10;
    assign send_msec_1  = data_cap_r[6:0] % 10;


    always @(posedge clk, posedge rst) begin
        if (rst) begin
            c_state <= IDLE;
            send_cnt_reg <= 4'd0;
        end else begin
            c_state <= n_state;
            send_cnt_reg <= send_cnt_next;
        end
    end

    always @(*) begin
        n_state = c_state;
        send_cnt_next = send_cnt_reg;
        push_data = 0;
        push_start = 1'b0;

        case (c_state)
            IDLE: begin
                if (ascii_d_s) begin
                    n_state = SEND;
                end
            end
            SEND: begin
                if (!full) begin
                    push_start = 1'b1;
                    case (send_cnt_reg)
                        4'd0:  push_data = ascii_hour_10;
                        4'd1:  push_data = ascii_hour_1;
                        4'd2:  push_data = 8'h3A;
                        4'd3:  push_data = ascii_min_10;
                        4'd4:  push_data = ascii_min_1;
                        4'd5:  push_data = 8'h3A;
                        4'd6:  push_data = ascii_sec_10;
                        4'd7:  push_data = ascii_sec_1;
                        4'd8:  push_data = 8'h3A;
                        4'd9:  push_data = ascii_msec_10;
                        4'd10: push_data = ascii_msec_1;
                        4'd11: push_data = 8'h0A;
                    endcase

                    if (send_cnt_reg == 10) begin
                        send_cnt_next = 0;
                        n_state = IDLE;
                    end else begin
                        send_cnt_next = send_cnt_reg + 1;
                        n_state = SEND;
                    end
                end
            end
        endcase
    end
endmodule

module bcd_sender (
    input [3:0] bcd_sender,
    output reg [7:0] send_data
);

    always @(bcd_sender) begin
        case (bcd_sender)
            4'd0: send_data = 8'h30;
            4'd1: send_data = 8'h31;
            4'd2: send_data = 8'h32;
            4'd3: send_data = 8'h33;
            4'd4: send_data = 8'h34;
            4'd5: send_data = 8'h35;
            4'd6: send_data = 8'h36;
            4'd7: send_data = 8'h37;
            4'd8: send_data = 8'h38;
            4'd9: send_data = 8'h39;
            default: send_data = 8'h20;
        endcase
    end

endmodule
