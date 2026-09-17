`timescale 1ns/1ps


// ============================================================
// TOP MODULE
// ============================================================

module vending_machine (

    input      clk,
    input      rst_n,

    input      nickel_in,
    input      dime_in,
    input      quarter_in,

    input      select_a,
    input      select_b,
    input      select_c,

    output     dispense,

    output     change_nickel,
    output     change_dime,
    output     change_quarter,

    output     return_nickel,
    output     return_dime,
    output     return_quarter

);

    wire [3:0] credit;
    wire [3:0] effective_credit;
    wire [3:0] next_credit;

    wire coin_return_nickel;
    wire coin_return_dime;
    wire coin_return_quarter;

    wire product_dispense;
    wire product_change_nickel;
    wire product_change_dime;
    wire product_change_quarter;


    // ========================================================
    // COIN HANDLER
    // ========================================================

    coin_handler coin_handler_inst (

        .credit(credit),

        .nickel_in(nickel_in),
        .dime_in(dime_in),
        .quarter_in(quarter_in),

        .effective_credit(effective_credit),

        .return_nickel(coin_return_nickel),
        .return_dime(coin_return_dime),
        .return_quarter(coin_return_quarter),

        .rst_n(rst_n)

    );


    // ========================================================
    // PRODUCT CONTROLLER
    // ========================================================

    product_controller product_controller_inst (

        .effective_credit(effective_credit),

        .select_a(select_a),
        .select_b(select_b),
        .select_c(select_c),

        .dispense(product_dispense),

        .change_nickel(product_change_nickel),
        .change_dime(product_change_dime),
        .change_quarter(product_change_quarter),

        .next_credit(next_credit),

        .rst_n(rst_n)

    );


    // ========================================================
    // CREDIT REGISTER
    // ========================================================

    credit_register credit_register_inst (

        .clk(clk),
        .rst_n(rst_n),

        .next_credit(next_credit),

        .credit(credit)

    );


    // ========================================================
    // OUTPUT REGISTER
    // ========================================================

    output_register output_register_inst (

        .clk(clk),
        .rst_n(rst_n),

        .product_dispense(product_dispense),

        .product_change_nickel(product_change_nickel),
        .product_change_dime(product_change_dime),
        .product_change_quarter(product_change_quarter),

        .coin_return_nickel(coin_return_nickel),
        .coin_return_dime(coin_return_dime),
        .coin_return_quarter(coin_return_quarter),

        .dispense(dispense),

        .change_nickel(change_nickel),
        .change_dime(change_dime),
        .change_quarter(change_quarter),

        .return_nickel(return_nickel),
        .return_dime(return_dime),
        .return_quarter(return_quarter)

    );

endmodule



// ============================================================
// COIN HANDLER
// ============================================================

module coin_handler (

    input  wire [3:0] credit,

    input  wire       nickel_in,
    input  wire       dime_in,
    input  wire       quarter_in,

    input  wire       rst_n,

    output reg [3:0]  effective_credit,

    output reg        return_nickel,
    output reg        return_dime,
    output reg        return_quarter

);

    always @(*) begin

        effective_credit = credit;

        return_nickel  = 1'b0;
        return_dime    = 1'b0;
        return_quarter = 1'b0;


        // ----------------------------------------------------
        // COIN INSERTION
        // ----------------------------------------------------

        if (nickel_in) begin

            if (credit == 4'd15) begin

                return_nickel = 1'b1;

            end
            else begin

                effective_credit = credit + 4'd1;

            end

        end

        else if (dime_in) begin

            if (credit >= 4'd14) begin

                return_dime = 1'b1;

            end
            else begin

                effective_credit = credit + 4'd2;

            end

        end

        else if (quarter_in) begin

            if (credit >= 4'd11) begin

                return_quarter = 1'b1;

            end
            else begin

                effective_credit = credit + 4'd5;

            end

        end


        // ----------------------------------------------------
        // RESET
        // ----------------------------------------------------

        if (!rst_n) begin

            effective_credit = 4'd0;

            return_nickel  = 1'b0;
            return_dime    = 1'b0;
            return_quarter = 1'b0;

        end

    end

endmodule



// ============================================================
// PRODUCT CONTROLLER
// ============================================================

module product_controller (

    input  wire [3:0] effective_credit,

    input  wire       select_a,
    input  wire       select_b,
    input  wire       select_c,

    input  wire       rst_n,

    output reg        dispense,

    output reg        change_nickel,
    output reg        change_dime,
    output reg        change_quarter,

    output reg [3:0]  next_credit

);

    always @(*) begin

        // ----------------------------------------------------
        // DEFAULTS
        // ----------------------------------------------------

        next_credit = effective_credit;

        dispense = 1'b0;

        change_nickel  = 1'b0;
        change_dime    = 1'b0;
        change_quarter = 1'b0;


        // ====================================================
        // PRODUCT A = 30c
        // ====================================================

        if (select_a && (effective_credit >= 4'd6)) begin

            dispense = 1'b1;
            next_credit = 4'd0;

            case (effective_credit)

                4'd7: begin
                    change_nickel = 1'b1;
                end

                4'd8: begin
                    change_dime = 1'b1;
                end

                4'd9: begin
                    change_dime = 1'b1;
                    change_nickel = 1'b1;
                end

                4'd10: begin
                    change_dime = 1'b1;
                end

                4'd11: begin
                    change_quarter = 1'b1;
                end

                4'd12: begin
                    change_quarter = 1'b1;
                    change_nickel = 1'b1;
                end

                4'd13: begin
                    change_quarter = 1'b1;
                    change_dime = 1'b1;
                end

                4'd14: begin
                    change_quarter = 1'b1;
                    change_dime = 1'b1;
                    change_nickel = 1'b1;
                end

                4'd15: begin
                    change_quarter = 1'b1;
                    change_dime = 1'b1;
                end

                default: begin
                end

            endcase

        end


        // ====================================================
        // PRODUCT B = 45c
        // ====================================================

        else if (select_b && (effective_credit >= 4'd9)) begin

            dispense = 1'b1;
            next_credit = 4'd0;

            case (effective_credit)

                4'd10: begin
                    change_nickel = 1'b1;
                end

                4'd11: begin
                    change_dime = 1'b1;
                end

                4'd12: begin
                    change_dime = 1'b1;
                    change_nickel = 1'b1;
                end

                4'd13: begin
                    change_dime = 1'b1;
                end

                4'd14: begin
                    change_quarter = 1'b1;
                end

                4'd15: begin
                    change_quarter = 1'b1;
                    change_nickel = 1'b1;
                end

                default: begin
                end

            endcase

        end


        // ====================================================
        // PRODUCT C = 60c
        // ====================================================

        else if (select_c && (effective_credit >= 4'd12)) begin

            dispense = 1'b1;
            next_credit = 4'd0;

            case (effective_credit)

                4'd13: begin
                    change_nickel = 1'b1;
                end

                4'd14: begin
                    change_dime = 1'b1;
                end

                4'd15: begin
                    change_dime = 1'b1;
                    change_nickel = 1'b1;
                end

                default: begin
                end

            endcase

        end


        // ----------------------------------------------------
        // RESET
        // ----------------------------------------------------

        if (!rst_n) begin

            dispense = 1'b0;

            change_nickel  = 1'b0;
            change_dime    = 1'b0;
            change_quarter = 1'b0;

            next_credit = 4'd0;

        end

    end

endmodule



// ============================================================
// CREDIT REGISTER
// ============================================================

module credit_register (

    input  wire       clk,
    input  wire       rst_n,

    input  wire [3:0] next_credit,

    output reg  [3:0] credit

);

    always @(posedge clk or negedge rst_n) begin

        if (!rst_n)
            credit <= 4'd0;

        else
            credit <= next_credit;

    end

endmodule



// ============================================================
// OUTPUT REGISTER
// ============================================================

module output_register (

    input  wire       clk,
    input  wire       rst_n,

    input  wire       product_dispense,

    input  wire       product_change_nickel,
    input  wire       product_change_dime,
    input  wire       product_change_quarter,

    input  wire       coin_return_nickel,
    input  wire       coin_return_dime,
    input  wire       coin_return_quarter,

    output reg        dispense,

    output reg        change_nickel,
    output reg        change_dime,
    output reg        change_quarter,

    output reg        return_nickel,
    output reg        return_dime,
    output reg        return_quarter

);

    always @(posedge clk or negedge rst_n) begin

        if (!rst_n) begin

            dispense <= 1'b0;

            change_nickel  <= 1'b0;
            change_dime    <= 1'b0;
            change_quarter <= 1'b0;

            return_nickel  <= 1'b0;
            return_dime    <= 1'b0;
            return_quarter <= 1'b0;

        end
        else begin

            dispense <= product_dispense;

            change_nickel  <= product_change_nickel;
            change_dime    <= product_change_dime;
            change_quarter <= product_change_quarter;

            return_nickel  <= coin_return_nickel;
            return_dime    <= coin_return_dime;
            return_quarter <= coin_return_quarter;

        end

    end

endmodule
