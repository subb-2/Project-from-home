`timescale 1ns / 1ps

module fnd_controller (
    input  [7:0] sum,
    output [3:0] fnd_digit,
    output [7:0] fnd_data
);

    assign fnd_digit = 4'b1110;  // to fnd an[3:0] 

    bcd U_BCD (
        .bcd(sum[3:0]),
        .fnd_data(fnd_data)
    );

endmodule

module bcd (
    input      [3:0] bcd,
    output reg [7:0] fnd_data
);

    always @(bcd) begin
        case (bcd)
            4'd0: fnd_data = 8'hC0;
            4'd1: fnd_data = 8'hf9;
            4'd2: fnd_data = 8'ha4;
            4'd3: fnd_data = 8'hB0;
            4'd4: fnd_data = 8'h99;
            4'd5: fnd_data = 8'h92;
            4'd6: fnd_data = 8'h82;
            4'd7: fnd_data = 8'hf8;
            4'd8: fnd_data = 8'h80;
            4'd9: fnd_data = 8'h90;
            default: fnd_data = 8'hFF;
        endcase
    end
endmodule
