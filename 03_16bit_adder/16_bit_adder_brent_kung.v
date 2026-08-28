//sundar
//top :) module
module adder16 (
    input             clk,
    input             rst_n,
    input      [15:0] a,
    input      [15:0] b,
    input             cin,
    output reg [15:0] sum,
    output reg        cout
);
    // Your implementation here
    wire [15:0]sum_comb;
    wire cout_comb;
    Brent_kung_16_bit #(.N(16)) uut (
        .a(a),
        .b(b),
        .cin(cin),
        .sum(sum_comb),
        .cout(cout_comb)
    );

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            sum <= 16'b0;
            cout <= 0;
        end
        else begin
            sum <= sum_comb;
            cout<= cout_comb;
        end
    end



endmodule

// bottom (; module 
// prefix tree logic
module Brent_kung_16_bit #(
    parameter N = 16)(
        input [N-1:0]a,
        input [N-1:0]b,
        input cin,
        output cout,
        output [N-1:0] sum
    );

    localparam LEVELS = 4;
    wire [N-1:0]g0;
    wire [N-1:0]p0;
    genvar i;

    generate 
        for (i= 0; i<N;i = i+1) begin
        assign g0[i] = a[i] & b[i];
        assign p0[i] = a[i] ^ b[i];
    end
    endgenerate

    wire [N-1:0] G [0:LEVELS];
    wire [N-1:0] P [0:LEVELS];
    
    assign G[0] = g0;
    assign P[0] = p0;

    genvar level;

    generate
        for(level = 0; level < LEVELS; level = level + 1) begin
            for(i=0; i<N;i++) begin
                if(i>= (1<<level)) begin 
                    assign G[level + 1][i] = G[level][i] | P[level][i] & G[level][i-(1<<level)];
                    assign P[level + 1][i] = P[level][i] & P[level][i - (1<<level)];
                end
                else begin
                    assign G[level+1][i] = G[level][i];
                    assign P[level+1][i] = P[level][i];
                end
            end
        end
    endgenerate

    wire [N:0]carry;
    assign carry[0] = cin;
    generate
        for(i = 0;i<N;i=i+1) begin
            assign carry[i+1] = G[LEVELS][i] | (P[LEVELS][i] & cin);
        end

    endgenerate


    generate
        for(i = 0;i<N;i = i+ 1) begin
            assign sum[i] = p0[i] ^ carry[i];
        end
    endgenerate
    assign cout = carry[N];
    endmodule
