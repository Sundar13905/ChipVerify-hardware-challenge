`timescale 1ns/1ps
module tb;
    reg  clk, rst_n, emergency;
    wire [1:0] ns_light, ew_light;

    traffic_light dut (.clk(clk), .rst_n(rst_n), .emergency(emergency),
                       .ns_light(ns_light), .ew_light(ew_light));

    initial clk = 0;
    always #5 clk = ~clk;

    integer fail_count = 0;
    integer cyc;

    localparam GREEN  = 2'b10;
    localparam YELLOW = 2'b01;
    localparam RED    = 2'b00;

    initial begin
        rst_n=0; emergency=0;
        repeat(2) @(posedge clk); rst_n=1; @(posedge clk); #0.1;

        // T1: initial state is NS_GREEN
        if (ns_light!==GREEN || ew_light!==RED) begin
            $display("FAIL: T1 initial state ns=%0b ew=%0b", ns_light, ew_light);
            fail_count=fail_count+1;
        end

        // T2: hold NS_GREEN for exactly 30 cycles
        repeat(29) begin
            @(posedge clk); #0.1;
            if (ns_light!==GREEN || ew_light!==RED) begin
                $display("FAIL: T2 left NS_GREEN too early"); fail_count=fail_count+1;
            end
        end
        @(posedge clk); #0.1;
        // cycle 30: transition to NS_YELLOW
        if (ns_light!==YELLOW || ew_light!==RED) begin
            $display("FAIL: T2 did not enter NS_YELLOW after 30 cyc ns=%0b", ns_light);
            fail_count=fail_count+1;
        end

        // T3: hold NS_YELLOW for 5 cycles then EW_GREEN
        repeat(4) @(posedge clk); #0.1;
        @(posedge clk); #0.1;
        if (ns_light!==RED || ew_light!==GREEN) begin
            $display("FAIL: T3 did not enter EW_GREEN after yellow ns=%0b ew=%0b", ns_light, ew_light);
            fail_count=fail_count+1;
        end

        // T4: skip through EW_GREEN and EW_YELLOW, check cycle back to NS_GREEN
        repeat(30) @(posedge clk); // end of EW_GREEN
        #0.1;
        if (ns_light!==RED || ew_light!==YELLOW) begin
            $display("FAIL: T4 EW_YELLOW expected ew=%0b", ew_light);
            fail_count=fail_count+1;
        end
        repeat(5) @(posedge clk); #0.1;
        if (ns_light!==GREEN || ew_light!==RED) begin
            $display("FAIL: T4 cycle back to NS_GREEN failed ns=%0b", ns_light);
            fail_count=fail_count+1;
        end

        // T5: emergency mode — both go RED, then resume
        repeat(5) @(posedge clk); // partway into NS_GREEN
        emergency=1; @(posedge clk); #0.1;
        if (ns_light!==RED || ew_light!==RED) begin
            $display("FAIL: T5 emergency: lights not both red ns=%0b ew=%0b", ns_light, ew_light);
            fail_count=fail_count+1;
        end
        repeat(10) @(posedge clk); #0.1; // hold emergency
        if (ns_light!==RED || ew_light!==RED) begin
            $display("FAIL: T5 emergency not sustained"); fail_count=fail_count+1;
        end
        emergency=0; @(posedge clk); #0.1;
        // should resume NS_GREEN
        if (ns_light!==GREEN || ew_light!==RED) begin
            $display("FAIL: T5 resume: expected NS_GREEN ns=%0b ew=%0b", ns_light, ew_light);
            fail_count=fail_count+1;
        end

        if (fail_count==0) $display("ALL_TESTS_PASSED");
        else                $display("TESTS_FAILED %0d", fail_count);
        $finish;
    end
    initial begin #2000000; $display("TIMEOUT"); $finish; end
endmodule
