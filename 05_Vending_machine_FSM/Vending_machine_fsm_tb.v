`timescale 1ns/1ps
module tb;
    reg clk, rst_n;
    reg nickel_in, dime_in, quarter_in;
    reg select_a, select_b, select_c;
    wire dispense, change_nickel, change_dime, change_quarter;
    wire return_nickel, return_dime, return_quarter;

    vending_machine dut (
        .clk(clk), .rst_n(rst_n),
        .nickel_in(nickel_in), .dime_in(dime_in), .quarter_in(quarter_in),
        .select_a(select_a), .select_b(select_b), .select_c(select_c),
        .dispense(dispense),
        .change_nickel(change_nickel), .change_dime(change_dime), .change_quarter(change_quarter),
        .return_nickel(return_nickel), .return_dime(return_dime), .return_quarter(return_quarter)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    integer fail_count = 0;

    task coin; input n,d,q;
        begin @(posedge clk); #0.1;
            nickel_in=n; dime_in=d; quarter_in=q;
            select_a=0; select_b=0; select_c=0;
            @(posedge clk); #0.1;
            nickel_in=0; dime_in=0; quarter_in=0;
        end
    endtask

    task select; input sa,sb,sc;
        begin @(posedge clk); #0.1;
            nickel_in=0; dime_in=0; quarter_in=0;
            select_a=sa; select_b=sb; select_c=sc;
            @(posedge clk); #0.1;
            select_a=0; select_b=0; select_c=0;
        end
    endtask

    task idle; begin
        nickel_in=0; dime_in=0; quarter_in=0;
        select_a=0; select_b=0; select_c=0;
    end endtask

    initial begin
        rst_n=0; idle;
        repeat(2) @(posedge clk); rst_n=1; @(posedge clk);

        // T1: exact change for product A (30c = 3 dimes)
        coin(0,1,0); coin(0,1,0); coin(0,1,0);
        select(1,0,0);
        if (!dispense) begin $display("FAIL: T1 no dispense for A with exact 30c"); fail_count=fail_count+1; end
        if (change_nickel||change_dime||change_quarter)
            begin $display("FAIL: T1 unexpected change"); fail_count=fail_count+1; end

        // T2: overpay for product A (35c = quarter + dime), expect 5c change
        coin(0,0,1); coin(0,1,0);
        select(1,0,0);
        if (!dispense) begin $display("FAIL: T2 no dispense"); fail_count=fail_count+1; end
        if (!change_nickel) begin $display("FAIL: T2 expected nickel change"); fail_count=fail_count+1; end

        // T3: insufficient credit — select B before enough coins
        coin(0,1,0); coin(0,1,0); // 20c only
        select(0,1,0); // B=45c
        if (dispense) begin $display("FAIL: T3 should not dispense with 20c for B"); fail_count=fail_count+1; end
        // add enough: 3 more dimes
        coin(0,1,0); coin(0,1,0); coin(0,1,0); // now have 50c (the 20 + 30)
        // wait, credit accumulates. Need to be careful here.
        // We have 50c now, select B (45c)
        select(0,1,0);
        if (!dispense) begin $display("FAIL: T3b should dispense B with 50c"); fail_count=fail_count+1; end
        if (!change_nickel) begin $display("FAIL: T3b expected 5c change (50-45=5)"); fail_count=fail_count+1; end

        // T4: coin return when credit would exceed 75c
        // Insert 3 quarters = 75c exactly (no return yet)
        coin(0,0,1); coin(0,0,1); coin(0,0,1); // 75c
        // Now insert another nickel — should be returned
        coin(1,0,0);
        if (!return_nickel) begin $display("FAIL: T4 nickel should be returned at 75c"); fail_count=fail_count+1; end

        // T5: dispense C (60c), started with 75c, expect 15c change
        select(0,0,1);
        if (!dispense) begin $display("FAIL: T5 no dispense for C"); fail_count=fail_count+1; end

        // T6: reset clears credit
        rst_n=0; @(posedge clk); rst_n=1; @(posedge clk);
        if (dispense||change_nickel||change_dime||change_quarter)
            begin $display("FAIL: T6 outputs not cleared after reset"); fail_count=fail_count+1; end

        if (fail_count==0) $display("ALL_TESTS_PASSED");
        else                $display("TESTS_FAILED %0d", fail_count);
        $finish;
    end
    initial begin #500000; $display("TIMEOUT"); $finish; end
endmodule
