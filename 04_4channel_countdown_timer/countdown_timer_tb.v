`timescale 1ns/1ps
module tb;
    reg        clk, rst_n;
    reg  [3:0] load_en, run, stop;
    reg [15:0] load_val;
    wire [3:0]  expired;
    wire [15:0] count0, count1, count2, count3;

    timer_array dut (
        .clk(clk), .rst_n(rst_n),
        .load_en(load_en), .load_val(load_val),
        .run(run), .stop(stop),
        .expired(expired), .count0(count0), .count1(count1),
        .count2(count2), .count3(count3)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    integer fail_count = 0;

    task tick; begin @(posedge clk); #0.1; end endtask

    initial begin
        rst_n=0; load_en=0; load_val=0; run=0; stop=0;
        repeat(2) @(posedge clk); rst_n=1; tick;

        // T1: reset state — all expired
        if (expired!==4'hF) begin $display("FAIL: T1 expired=%0b exp=1111", expired); fail_count=fail_count+1; end

        // T2: load channel 0 with 4, run, check countdown and expiry
        load_en=4'b0001; load_val=16'd4; run=4'b0001; tick; load_en=0;
        tick; // count=3
        tick; // count=2
        tick; // count=1
        tick; // count=0, expired[0] should be 1
        if (!expired[0]) begin $display("FAIL: T2 ch0 not expired at 0"); fail_count=fail_count+1; end
        if (count0!==0) begin $display("FAIL: T2 count0=%0d exp=0", count0); fail_count=fail_count+1; end

        // T3: counter does not go below 0
        run=4'b0001;
        tick; tick;
        if (count0!==0) begin $display("FAIL: T3 count0 went below 0: %0d", count0); fail_count=fail_count+1; end

        // T4: stop halts decrement
        load_en=4'b0010; load_val=16'd10; tick; load_en=0;
        run=4'b0010; stop=4'b0010; tick; tick; tick;
        if (count1!==10) begin $display("FAIL: T4 stop did not halt ch1: %0d", count1); fail_count=fail_count+1; end
        stop=0; tick; tick;
        if (count1!==8) begin $display("FAIL: T4 ch1 should decrement after stop clears: %0d", count1); fail_count=fail_count+1; end

        // T5: two channels independent
        load_en=4'b0100; load_val=16'd3; tick; load_en=0;
        load_en=4'b1000; load_val=16'd6; tick; load_en=0;
        run=4'b1100; stop=0;
        tick; tick; tick;
        if (!expired[2]) begin $display("FAIL: T5 ch2 not expired after 3 ticks"); fail_count=fail_count+1; end
        if (expired[3]) begin $display("FAIL: T5 ch3 should not be expired yet"); fail_count=fail_count+1; end

        // T6: load priority — set all 4 load_en, only lowest (ch0) should load
        load_en=4'b1111; load_val=16'd99; tick; load_en=0;
        if (count0!==99) begin $display("FAIL: T6 ch0 not loaded with priority"); fail_count=fail_count+1; end
        // ch1-3 should retain old values (not overwritten)
        if (count1===99) begin $display("FAIL: T6 ch1 should not have loaded"); fail_count=fail_count+1; end

        if (fail_count==0) $display("ALL_TESTS_PASSED");
        else                $display("TESTS_FAILED %0d", fail_count);
        $finish;
    end
    initial begin #500000; $display("TIMEOUT"); $finish; end
endmodule
