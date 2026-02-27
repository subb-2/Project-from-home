`timescale 1ns / 1ps

//문자를 제어신호로 변환 
module ascii_decoder (
    input            clk,
    input            rst,
    input      [7:0] rx_data,
    input            rx_done,
    output reg [4:0] ascii_d
);

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            ascii_d <= 4'b0000;
        end else begin
            ascii_d <= 4'b0000;
            if (rx_done) begin
                case (rx_data)
                    8'h72: ascii_d <= 4'b00001;  //r
                    8'h6C: ascii_d <= 4'b00010;  //l
                    8'h75: ascii_d <= 4'b00100;  //u
                    8'h64: ascii_d <= 4'b01000;  //d
                    8'h73: ascii_d <= 5'b10000;  //s
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
            ascii_up_down <= 0;
            ascii_stopwatch_watch <= 0;
            ascii_hm_sms <= 0;
            ascii_watch_set <= 0;
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

module ascii_sender (
    input             clk,
    input             rst,
    input      [23:0] mux_2x1_set,
    input             ascii_d_s,
    input             tx_done,
    output reg        tx_start,
    output reg [ 7:0] tx_data
);

    wire [7:0] ascii_hour_10, ascii_hour_1, ascii_min_10, ascii_min_1,
                ascii_sec_10, ascii_sec_1, ascii_msec_10, ascii_msec_1;
    wire [7:0] send_hour_10, send_hour_1, send_min_10, send_min_1,
                send_sec_10, send_sec_1, send_msec_10, send_msec_1;

    bcd_sender U_BCD_SENDER_HOUR_10 (
        .bcd_sender(send_hour_10),
        .send_data(ascii_hour_10)
    );
    bcd_sender U_BCD_SENDER_HOUR_1 (
        .bcd_sender(send_hour_1),
        .send_data(ascii_hour_1)
    );
    bcd_sender U_BCD_SENDER_MIN_10 (
        .bcd_sender(send_min_10),
        .send_data(ascii_min_10)
    );
    bcd_sender U_BCD_SENDER_MIN_1 (
        .bcd_sender(send_min_1),
        .send_data(ascii_min_1)
    );
    bcd_sender U_BCD_SENDER_SEC_10 (
        .bcd_sender(send_sec_10),
        .send_data(ascii_sec_10)
    );
    bcd_sender U_BCD_SENDER_SEC_1 (
        .bcd_sender(send_sec_1),
        .send_data(ascii_sec_1)
    );
    bcd_sender U_BCD_SENDER_MSEC_10 (
        .bcd_sender(send_msec_10),
        .send_data(ascii_msec_10)
    );
    bcd_sender U_BCD_SENDER_MSEC_1 (
        .bcd_sender(send_msec_1),
        .send_data(ascii_msec_1)
    );

    parameter IDLE = 4'd0, SEND = 4'd1, WAIT = 4'd2;

    reg [3:0] c_state, n_state;
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

    assign send_hour_10 = (data_cap_r[23:19]/10) % 10;
    assign send_hour_1 = data_cap_r[23:19] % 10;

    assign send_min_10 = (data_cap_r[18:13]/10) % 10;
    assign send_min_1 = data_cap_r[18:13] % 10;

    assign send_sec_10 = (data_cap_r[12:7]/10) % 10;
    assign send_sec_1 = data_cap_r[12:7] % 10;

    assign send_msec_10 = (data_cap_r[6:0]/10) % 10;
    assign send_msec_1 = data_cap_r[6:0] % 10;


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
        tx_data = 0;
        tx_start = 0;

        case (c_state)
            IDLE: begin
                if (ascii_d_s) begin
                    n_state = SEND;
                end
            end
            SEND: begin
                case (send_cnt_reg)
                    4'd0: begin
                        tx_data = ascii_hour_10;
                        tx_start = 1;
                        n_state = WAIT;
                    end
                    4'd1: begin
                        tx_data = ascii_hour_1;
                        tx_start = 1;
                        n_state = WAIT;
                    end
                    4'd2: begin
                        tx_data = 8'h3A;
                        tx_start = 1;
                        n_state = WAIT;
                    end
                    4'd3: begin
                        tx_data = ascii_min_10;
                        tx_start = 1;
                        n_state = WAIT;
                    end
                    4'd4: begin
                        tx_data = ascii_min_1;
                        tx_start = 1;
                        n_state = WAIT;
                    end
                    4'd5: begin
                        tx_data = 8'h3A;
                        tx_start = 1;
                        n_state = WAIT;
                    end
                    4'd6: begin
                        tx_data = ascii_sec_10;
                        tx_start = 1;
                        n_state = WAIT;
                    end
                    4'd7: begin
                        tx_data = ascii_sec_1;
                        tx_start = 1;
                        n_state = WAIT;
                    end
                    4'd8: begin
                        tx_data = 8'h3A;
                        tx_start = 1;
                        n_state = WAIT;
                    end
                    4'd9: begin
                        tx_data = ascii_msec_10;
                        tx_start = 1;
                        n_state = WAIT;
                    end
                    4'd10: begin
                        tx_data = ascii_msec_1;
                        tx_start = 1;
                        n_state = WAIT;
                    end
                    4'd11: begin
                        tx_data = 8'h0A;
                        tx_start = 1;
                        n_state = WAIT;
                    end
                endcase
            end
            
            WAIT: begin
                if (tx_done) begin
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
