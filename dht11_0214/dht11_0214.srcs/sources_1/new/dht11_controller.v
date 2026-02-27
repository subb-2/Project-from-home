`timescale 1ns / 1ps

module dht11_top (
    input         clk,
    input         rst,
    input         btn_r_start,

    //output [31:0] dht_data,
    output [15:0] humidity,
    output [15:0] temperature,

    output        dht_done,
    output        dht_valid,
    output [ 3:0] dht_debug_led,

    inout         dhtio
);

    wire w_tick_10us_dht;
    wire w_dhtio_edge_rise, w_dhtio_edge_fall;
    wire w_btn_r_start;
    //wire [15:0] w_humidity, w_temperature;

    btn_debounce U_BTN_DHT11 (
        .clk  (clk),
        .reset(rst),
        .i_btn(btn_r_start),
        .o_btn(w_btn_r_start)
    );

    dht11_controller U_DHT11_CONTROL (
        .clk(clk),
        .rst(rst),
        .tick_10us_dht(w_tick_10us_dht),
        .dht_start(w_btn_r_start),
        .humidity(humidity),
        .temperature(temperature),
        .dht_done(dht_done),
        .dht_valid(dht_valid),
        .dht_debug_led(dht_debug_led),
        .dhtio(dhtio)
    );

    tick_gen_10us_dht U_TICK_GEN_1us_DHT (
        .clk(clk),
        .rst(rst),
        .o_tick_10us(w_tick_10us_dht)
    );

endmodule

module dht11_controller (
    input         clk,
    input         rst,
    input         tick_10us_dht,
    input         dht_start,

    output [15:0] humidity,
    output [15:0] temperature,
    output        dht_done,
    output        dht_valid,
    output [ 3:0] dht_debug_led,
    inout         dhtio
);

    //state
    parameter IDLE = 3'd0, START = 3'd1, WAIT = 3'd2, SYNCL = 3'd3,
                SYNCH = 3'd4, DATA_SYNC = 3'd5, DATA = 3'd6, STOP = 3'd7;

    reg [2:0] c_state, n_state;

    //tick count
    reg [$clog2(19000)-1:0] tick_gen_cnt_reg, tick_gen_cnt_next;

    //bit count
    reg [5:0] bit_cnt_reg, bit_cnt_next;

    //data
    reg [39:0] dht_buf_reg, dht_buf_next;
    reg [5:0] buf_index_reg, buf_index_next;

    assign humidity = dht_buf_reg[39:24];
    assign temperature = dht_buf_reg[23:8];

    //valid
    reg dht_valid_reg, dht_valid_next;

    assign dht_valid = dht_valid_reg;

    //done
    reg dht_done_reg, dht_done_next;

    assign dht_done = dht_done_reg;

    //dhtio tri-state buffer
    reg dhtio_reg, dhtio_next;
    reg io_sel_reg, io_sel_next;

    assign dhtio = (io_sel_reg) ? dhtio_reg : 1'bz;

    //led
    assign dht_debug_led = {dht_valid, c_state};

    //synchronizer & edge 
    reg dht_edge_reg;  // 이전값 / dhtio : 현재값
    reg dhtio_edge_rise, dhtio_edge_fall;

    reg echo_q1, echo_q2;

    wire echo_sync;

    assign echo_sync = echo_q2;

    
    //echo synchronizer
    always @(posedge clk, posedge rst) begin
        if (rst) begin
            echo_q1 <= 0;
            echo_q2 <= 0;
        end else begin
            echo_q1 <= dhtio;
            echo_q2 <= echo_q1;
        end
    end

    //edge detection
    always @(posedge clk, posedge rst) begin
        if (rst) begin
            dht_edge_reg <= 1'b0;
            dhtio_edge_rise <= 1'b0;
            dhtio_edge_fall <= 1'b0;
        end else begin
            dhtio_edge_rise <= (~dht_edge_reg) & echo_sync;
            dhtio_edge_fall <= dht_edge_reg & (~echo_sync);
            dht_edge_reg <= echo_sync;
        end
    end

// ================= FSM =================================

    //CL
    always @(posedge clk, posedge rst) begin
        if (rst) begin
            c_state          <= 3'd0;
            tick_gen_cnt_reg <= 0;
            bit_cnt_reg      <= 6'd0;
            dhtio_reg        <= 1'b1;
            io_sel_reg       <= 1'b1;
            dht_valid_reg    <= 1'b0;
            dht_buf_reg      <= 40'd0;
            buf_index_reg    <= 6'd0;
            dht_done_reg     <= 1'b0;
        end else begin
            c_state          <= n_state;
            tick_gen_cnt_reg <= tick_gen_cnt_next;
            bit_cnt_reg      <= bit_cnt_next;
            dhtio_reg        <= dhtio_next;
            io_sel_reg       <= io_sel_next;
            dht_valid_reg    <= dht_valid_next;
            dht_buf_reg      <= dht_buf_next;
            buf_index_reg    <= buf_index_next;
            dht_done_reg     <= dht_done_next;
        end
    end

    //SL
    always @(*) begin
        n_state           = c_state;
        tick_gen_cnt_next = tick_gen_cnt_reg;
        bit_cnt_next      = bit_cnt_reg;
        dhtio_next        = dhtio_reg;
        io_sel_next       = io_sel_reg;
        dht_valid_next    = dht_valid_reg;
        buf_index_next    = buf_index_reg;
        dht_buf_next      = dht_buf_reg;
        dht_done_next     = dht_done_reg;
        case (c_state)
            IDLE: begin
                dht_done_next  = 0;
                if (dht_start) begin
                    n_state = START;
                    dht_valid_next = 0;
                end
            end
            START: begin
                dhtio_next = 1'b0;
                if (tick_10us_dht == 1) begin
                    tick_gen_cnt_next = tick_gen_cnt_reg + 1;
                    if (tick_gen_cnt_reg == 1900) begin
                        tick_gen_cnt_next = 0;
                        n_state = WAIT;
                    end
                end
            end
            WAIT: begin
                dhtio_next = 1'b1;
                if (tick_10us_dht == 1) begin
                    tick_gen_cnt_next = tick_gen_cnt_reg + 1;
                    if (tick_gen_cnt_reg == 3) begin
                        tick_gen_cnt_next = 0;
                        n_state = SYNCL;
                        io_sel_next = 1'b0;
                    end
                end
            end
            SYNCL: begin
                if (dhtio_edge_rise) begin
                    n_state = SYNCH;
                end
            end
            SYNCH: begin
                if (dhtio_edge_fall) begin
                    n_state = DATA_SYNC;
                end
            end
            DATA_SYNC: begin
                if (dhtio_edge_rise) begin
                   n_state = DATA; 
                end
            end
            DATA: begin
                if (dhtio_edge_fall) begin
                    //40bit
                    if (tick_gen_cnt_reg >= 4) begin
                        dht_buf_next = {dht_buf_reg[38:0], 1'b1};
                    end else if (tick_gen_cnt_reg < 5) begin
                        dht_buf_next = {dht_buf_reg[38:0], 1'b0};
                    end
                    tick_gen_cnt_next = 0;
                    bit_cnt_next   = bit_cnt_reg + 1;
                    buf_index_next = buf_index_reg + 1;
                    if (bit_cnt_reg == 39) begin
                        dht_done_next = 1;
                        n_state = STOP;
                    end else begin
                        n_state = DATA_SYNC;
                    end 
                end else if (echo_sync && tick_10us_dht) begin
                        tick_gen_cnt_next = tick_gen_cnt_reg + 1;
                end
            end
            STOP: begin
                if (tick_10us_dht == 1) begin
                    if (tick_gen_cnt_reg == 0) begin
                        //checksum
                        if (dht_buf_reg[7:0] == (dht_buf_reg[39:32] + dht_buf_reg[31:24] + 
                                                dht_buf_reg[23:16] + dht_buf_reg[15:8]) & 8'hFF) begin
                            dht_valid_next = 1;
                        end else begin
                            dht_valid_next = 0;
                        end
                    end
                    tick_gen_cnt_next = tick_gen_cnt_reg + 1;
                    if (tick_gen_cnt_reg == 5) begin
                        tick_gen_cnt_next = 0;
                        //output mode 
                        dhtio_next = 1'b1;
                        io_sel_next = 1'b1;
                        n_state = IDLE;
                    end
                end
            end
        endcase
    end

endmodule





module tick_gen_10us_dht (
    input      clk,
    input      rst,
    output reg o_tick_10us
);

    parameter F_COUNT = 100_000_000 / 100_000;
    reg [$clog2(F_COUNT)-1:0] counter_reg;

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            counter_reg <= 0;
            o_tick_10us <= 1'b0;
        end else begin
            counter_reg <= counter_reg + 1;
            if (counter_reg == F_COUNT - 1) begin
                counter_reg <= 0;
                o_tick_10us <= 1'b1;
            end else begin
                o_tick_10us <= 1'b0;
            end
        end
    end

endmodule



// `timescale 1ns / 1ps
// 
// module dht11_top (
//     input         clk,
//     input         rst,
//     input         start,
//     output [15:0] humidity,
//     output [15:0] temperature,
//     output        dht_done,
//     output        dht_valid,
//     output [ 3:0] dht_debug_led,
//     inout         dhtio
// );
// 
//     wire w_dhtio_sync, w_tick_1us_dht;
//     wire w_dhtio_edge_rise, w_dhtio_edge_fall;
// 
//     dht11_controller U_DHT11_CONTROL (
//         .clk(clk),
//         .rst(rst),
//         .tick_1us_dht(w_tick_1us_dht),
//         .dht_start(start),
//         .dhtio_edge_rise(w_dhtio_edge_rise),
//         .dhtio_edge_fall(w_dhtio_edge_fall),
//         .humidity(humidity),
//         .temperature(temperature),
//         .dht_done(dht_done),
//         .dht_valid(dht_valid),
//         .dht_debug_led(dht_debug_led),
//         .dhtio_sync(w_dhtio_sync),
//         .dhtio(dhtio)
//     );
// 
//     dhtio_edge U_DHTIO_EDGE (
//         .clk(clk),
//         .rst(rst),
//         .i_dhtio_sync(w_dhtio_sync),
//         .i_tick_1us_dht(w_tick_1us_dht),
//         .o_dhtio_edge_rise(w_dhtio_edge_rise),
//         .o_dhtio_edge_fall(w_dhtio_edge_fall)
//     );
// 
//     dhtio_synchronizer U_DHTIO_SYNC (
//         .clk(clk),
//         .rst(rst),
//         .dhtio(dhtio),
//         .o_dhtio_sync(w_dhtio_sync)
//     );
// 
//     tick_gen_1us U_TICK_GEN_1us (
//         .clk(clk),
//         .rst(rst),
//         .o_tick_gen_1us(w_tick_1us_dht)
//     );
// 
// endmodule
// 
// module dht11_controller (
//     input         clk,
//     input         rst,
//     input         tick_1us_dht,
//     input         dht_start,
//     input         dhtio_edge_rise,
//     input         dhtio_edge_fall,
//     input         dhtio_sync,
//     output [15:0] humidity,
//     output [15:0] temperature,
//     output        dht_done,
//     output        dht_valid,
//     output [ 3:0] dht_debug_led,
//     inout         dhtio
// );
// 
//     //state
//     parameter IDLE = 3'd0, START = 3'd1, WAIT = 3'd2, SYNCL = 3'd3,
//                 SYNCH = 3'd4, DATA_SYNC = 3'd5, DATA = 3'd6, STOP = 3'd7;
// 
//     reg [2:0] c_state, n_state;
// 
//     //tick count
//     reg [$clog2(19000)-1:0] tick_gen_cnt_reg, tick_gen_cnt_next;
// 
//     //bit count
//     reg [5:0] bit_cnt_reg, bit_cnt_next;
// 
//     //data
//     reg [39:0] dht_buf_reg, dht_buf_next;
//     reg [5:0] buf_index_reg, buf_index_next;
// 
//     assign humidity = dht_buf_reg[39:24];
//     assign temperature = dht_buf_reg[23:8];
// 
//     //valid
//     reg dht_valid_reg, dht_valid_next;
// 
//     assign dht_valid = dht_valid_reg;
// 
//     //done
//     reg dht_done_reg, dht_done_next;
// 
//     assign dht_done = dht_done_reg;
// 
//     //dhtio tri-state buffer
//     reg dhtio_reg, dhtio_next;
//     reg io_sel_reg, io_sel_next;
// 
//     assign dhtio = (io_sel_reg) ? dhtio_reg : 1'bz;
// 
//     //led
//     assign dht_debug_led = {1'b0, c_state};
// 
//     //CL
//     always @(posedge clk, posedge rst) begin
//         if (rst) begin
//             c_state          <= 3'd0;
//             tick_gen_cnt_reg <= 0;
//             bit_cnt_reg      <= 6'd0;
//             dhtio_reg        <= 1'b1;
//             io_sel_reg       <= 1'b1;
//             dht_valid_reg    <= 1'b0;
//             dht_buf_reg      <= 40'd0;
//             buf_index_reg    <= 6'd0;
//             dht_done_reg     <= 1'b0;
//         end else begin
//             c_state          <= n_state;
//             tick_gen_cnt_reg <= tick_gen_cnt_next;
//             bit_cnt_reg      <= bit_cnt_next;
//             dhtio_reg        <= dhtio_next;
//             io_sel_reg       <= io_sel_next;
//             dht_valid_reg    <= dht_valid_next;
//             dht_buf_reg      <= dht_buf_next;
//             buf_index_reg    <= buf_index_next;
//             dht_done_reg     <= dht_done_next;
//         end
//     end
// 
//     //SL
//     always @(*) begin
//         n_state           = c_state;
//         tick_gen_cnt_next = tick_gen_cnt_reg;
//         bit_cnt_next      = bit_cnt_reg;
//         dhtio_next        = dhtio_reg;
//         io_sel_next       = io_sel_reg;
//         dht_valid_next    = dht_valid_reg;
//         buf_index_next    = buf_index_reg;
//         dht_buf_next      = dht_buf_reg;
//         dht_done_next     = dht_done_reg;
//         case (c_state)
//             IDLE: begin
//                 dht_done_next  = 0;
//                 dht_valid_next = 0;
//                 if (dht_start) begin
//                     n_state = START;
//                 end
//             end
//             START: begin
//                 dhtio_next = 1'b0;
//                 if (tick_1us_dht == 1) begin
//                     tick_gen_cnt_next = tick_gen_cnt_reg + 1;
//                     if (tick_gen_cnt_reg == 19000) begin
//                         tick_gen_cnt_next = 0;
//                         n_state = WAIT;
//                     end
//                 end
//             end
//             WAIT: begin
//                 dhtio_next = 1'b1;  //이해 안됨 
//                 if (tick_1us_dht == 1) begin
//                     tick_gen_cnt_next = tick_gen_cnt_reg + 1;
//                     if (tick_gen_cnt_reg == 30) begin
//                         tick_gen_cnt_next = 0;
//                         n_state = SYNCL;
//                         io_sel_next = 1'b0;
//                     end
//                 end
//             end
//             SYNCL: begin
//                 if (tick_1us_dht == 1) begin
//                     if (dhtio_edge_rise) begin
//                         n_state = SYNCH;
//                     end
//                 end
//             end
//             SYNCH: begin
//                 if (tick_1us_dht == 1) begin
//                     if (dhtio_edge_fall) begin
//                         n_state = DATA_SYNC;
//                     end
//                 end
//             end
//             DATA_SYNC: begin
//                 if (tick_1us_dht == 1) begin
//                     if (dhtio_edge_rise) begin
//                         n_state = DATA;
//                     end
//                 end
//             end
//             DATA: begin
//                 if (dhtio_sync == 1 && tick_1us_dht) begin
//                     //tick count
//                     tick_gen_cnt_next = tick_gen_cnt_reg + 1;
//                 end else if (dhtio_edge_fall) begin
//                     tick_gen_cnt_next = 0;
//                     //40bit
//                     if (tick_gen_cnt_reg >= 40) begin
// 
//                         dht_buf_next = {dht_buf_reg[38:0], 1'b1};
//                     end else if (tick_gen_cnt_reg < 40) begin
//                         dht_buf_next = {dht_buf_reg[38:0], 1'b0};
//                     end
//                     buf_index_next = buf_index_reg + 1;
//                     bit_cnt_next   = bit_cnt_reg + 1;
//                     if (bit_cnt_reg == 39) begin
//                         dht_done_next = 1;
//                         n_state = STOP;
//                     end else begin
//                         n_state = DATA_SYNC;
//                     end
//                 end
//             end
//             STOP: begin
//                 if (tick_1us_dht == 1) begin
//                     if (tick_gen_cnt_reg == 0) begin
//                         //checksum
//                         if (dht_buf_reg[7:0] == (dht_buf_reg[39:32] + dht_buf_reg[31:24] + 
//                                                 dht_buf_reg[23:16] + dht_buf_reg[15:8]) & 8'hFF) begin
//                             dht_valid_next = 1;
//                         end else begin
//                             dht_valid_next = 0;
//                         end
//                     end
//                     tick_gen_cnt_next = tick_gen_cnt_reg + 1;
//                     if (tick_gen_cnt_reg == 50) begin
//                         tick_gen_cnt_next = 0;
//                         //output mode 
//                         dhtio_next = 1'b1;
//                         io_sel_next = 1'b1;
//                         n_state = IDLE;
//                     end
//                 end
//             end
//         endcase
//     end
// 
// endmodule
// 
// module dhtio_edge (
//     input  clk,
//     input  rst,
//     input  i_dhtio_sync,
//     input  i_tick_1us_dht,
//     output o_dhtio_edge_rise,
//     output o_dhtio_edge_fall
// );
//     //edge detection
//     reg dht_edge_reg;  // 이전값 / dhtio : 현재값
// 
//     always @(posedge clk, posedge rst) begin
//         if (rst) begin
//             dht_edge_reg <= 1'b0;
//         end else begin
//             if (i_tick_1us_dht) begin
//                 dht_edge_reg <= i_dhtio_sync;
//             end
//         end
//     end
// 
//     assign o_dhtio_edge_rise = i_dhtio_sync & (~dht_edge_reg);
//     assign o_dhtio_edge_fall = (~i_dhtio_sync) & dht_edge_reg;
// 
//     // assign o_dhtio_edge_rise = (i_dhtio_sync & (~dht_edge_reg)) & i_tick_1us_dht;
//     // assign o_dhtio_edge_fall = ((~i_dhtio_sync) & dht_edge_reg) & i_tick_1us_dht;
// 
// endmodule
// 
// module dhtio_synchronizer (
//     input  clk,
//     input  rst,
//     input  dhtio,
//     output o_dhtio_sync
// );
// 
//     reg dht_q1, dht_q2;
// 
//     always @(posedge clk, posedge rst) begin
//         if (rst) begin
//             dht_q1 <= 0;
//             dht_q2 <= 0;
//         end else begin
//             dht_q1 <= dhtio;
//             dht_q2 <= dht_q1;
//         end
//     end
// 
//     assign o_dhtio_sync = dht_q2;
// 
// endmodule
// 
// module tick_gen_1us (
//     input      clk,
//     input      rst,
//     output reg o_tick_gen_1us
// );
// 
//     parameter F_COUNT = 100_000_000 / 1000_000;
//     reg [$clog2(F_COUNT)-1:0] counter_reg;
// 
//     always @(posedge clk, posedge rst) begin
//         if (rst) begin
//             counter_reg <= 0;
//             o_tick_gen_1us <= 1'b0;
//         end else begin
//             counter_reg <= counter_reg + 1;
//             if (counter_reg == F_COUNT - 1) begin
//                 counter_reg <= 0;
//                 o_tick_gen_1us <= 1'b1;
//             end else begin
//                 o_tick_gen_1us <= 1'b0;
//             end
//         end
//     end
// 
// endmodule
// 