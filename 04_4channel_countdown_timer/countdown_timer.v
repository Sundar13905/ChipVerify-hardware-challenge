/// AI USED - GEMINI {FOR OPTIMISATION}
// same code as Mr. Vinay Sharma  
module timer_channel_opt #(
    parameter WIDTH = 16
)(
    input  wire             clk,
    input  wire             rst_n,
    input  wire             load_grant,
    input  wire [WIDTH-1:0] load_val,
    input  wire             run,
    input  wire             stop,
    output reg  [WIDTH-1:0] count,
    output wire             expired
);

    // Reduction NOR logic for zero detection
    assign expired = ~(|count);

    // Combined enable control logic
    wire active = run & ~stop & ~expired;
    wire ce     = load_grant | active;

    // Flattened 2:1 multiplexer before register
    wire [WIDTH-1:0] next_count = load_grant ? load_val : (count - 1'b1);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            count <= {WIDTH{1'b0}};
        else if (ce)
            count <= next_count;
    end

endmodule

// Top-Level Optimized Timer Array
module timer_array (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [3:0]  load_en,
    input  wire [15:0] load_val,
    input  wire [3:0]  run,
    input  wire [3:0]  stop,
    output wire [15:0] count0,
    output wire [15:0] count1,
    output wire [15:0] count2,
    output wire [15:0] count3,
    output wire [3:0]  expired
);

    // Direct priority encoding (replaces 2's complement negation adder)
    wire [3:0] load_grant;
    assign load_grant[0] = load_en[0];
    assign load_grant[1] = load_en[1] & ~load_en[0];
    assign load_grant[2] = load_en[2] & ~load_en[1] & ~load_en[0];
    assign load_grant[3] = load_en[3] & ~load_en[2] & ~load_en[1] & ~load_en[0];

    timer_channel_opt #(16) ch0 (
        .clk(clk), .rst_n(rst_n), .load_grant(load_grant[0]), .load_val(load_val),
        .run(run[0]), .stop(stop[0]), .count(count0), .expired(expired[0])
    );

    timer_channel_opt #(16) ch1 (
        .clk(clk), .rst_n(rst_n), .load_grant(load_grant[1]), .load_val(load_val),
        .run(run[1]), .stop(stop[1]), .count(count1), .expired(expired[1])
    );

    timer_channel_opt #(16) ch2 (
        .clk(clk), .rst_n(rst_n), .load_grant(load_grant[2]), .load_val(load_val),
        .run(run[2]), .stop(stop[2]), .count(count2), .expired(expired[2])
    );

    timer_channel_opt #(16) ch3 (
        .clk(clk), .rst_n(rst_n), .load_grant(load_grant[3]), .load_val(load_val),
        .run(run[3]), .stop(stop[3]), .count(count3), .expired(expired[3])
    );

endmodule

