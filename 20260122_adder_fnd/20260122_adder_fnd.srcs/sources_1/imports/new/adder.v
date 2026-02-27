`timescale 1ns / 1ps

module top_adder (
    input  [7:0] a,
    input  [7:0] b,
    output [3:0] fnd_digit,
    output [7:0] fnd_data,
    output       c
);

    wire [7:0] w_sum;
    fnd_controller U_FND_CNTL (
        .sum      (w_sum),
        .fnd_digit(fnd_digit),
        .fnd_data (fnd_data)
    );
    adder U_ADDER (
        .a  (a),
        .b  (b),
        .sum(w_sum),
        .c  (c)
    );
endmodule

module adder (
    input  [7:0] a,
    input  [7:0] b,
    output [7:0] sum,
    output       c
);

    wire w_fa4_0_c;
    full_adder_4bit U_FA4_1 (
        .a0(a[4]),
        .b0(b[4]),
        .a1(a[5]),
        .b1(b[5]),
        .a2(a[6]),
        .b2(b[6]),
        .a3(a[7]),
        .b3(b[7]),
        .cin(w_fa4_0_c),
        .sum0(sum[4]),
        .sum1(sum[5]),
        .sum2(sum[6]),
        .sum3(sum[7]),
        .c(c)
    );
    full_adder_4bit U_FA4_0 (
        .a0(a[0]),
        .b0(b[0]),
        .a1(a[1]),
        .b1(b[1]),
        .a2(a[2]),
        .b2(b[2]),
        .a3(a[3]),
        .b3(b[3]),
        .cin(1'b0),
        .sum0(sum[0]),
        .sum1(sum[1]),
        .sum2(sum[2]),
        .sum3(sum[3]),
        .c(w_fa4_0_c)
    );

endmodule

module full_adder_4bit (
    input  a0,
    input  b0,
    input  a1,
    input  b1,
    input  a2,
    input  b2,
    input  a3,
    input  b3,
    input  cin,
    output sum0,
    output sum1,
    output sum2,
    output sum3,
    output c
);

    wire w_fA0_c, w_fA1_c, w_fA2_c;

    full_adder U_FA3 (
        .a  (a3),
        .b  (b3),
        .cin(w_fA2_c),
        .sum(sum3),
        .c  (c)
    );
    full_adder U_FA2 (
        .a  (a2),
        .b  (b2),
        .cin(w_fA1_c),
        .sum(sum2),
        .c  (w_fA2_c)
    );
    full_adder U_FA1 (
        .a  (a1),
        .b  (b1),
        .cin(w_fA0_c),
        .sum(sum1),
        .c  (w_fA1_c)
    );
    full_adder U_FA0 (
        .a  (a0),
        .b  (b0),
        .cin(cin),
        .sum(sum0),
        .c  (w_fA0_c)
    );


endmodule

module full_adder (
    input  a,
    input  b,
    input  cin,
    output sum,
    output c
);

    wire w_ha_sum, w_ha0_c, w_ha1_c;
    assign c = w_ha0_c | w_ha1_c;  /*to full adder output c*/

    half_adder U_HA1 (
        .a    (w_ha_sum  /* from half adder0 output sum */),
        .b    (cin),
        .sum  (sum  /* to full adder output sum  */),
        .carry(w_ha1_c)
    );
    half_adder U_HA0 (
        .a    (a  /* from full adder input a*/),
        .b    (b),
        .sum  (w_ha_sum),
        .carry(w_ha0_c)
    );

endmodule


module half_adder (
    input  a,
    input  b,
    output sum,
    output carry
);
    // half adder
    //assign sum   = a ^ b;
    //assign carry = a & b;

    // half adder
    xor (sum, a, b);
    and (carry, a, b);

endmodule
