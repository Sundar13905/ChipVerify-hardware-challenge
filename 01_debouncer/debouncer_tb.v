`timescale 1ns/1ns
//------------------------------------------------------------------------------
// Self-checking testbench for the 5 ms counter-based button debouncer.
//
//   iverilog -o sim tb_debouncer.v debouncer.v && vvp sim
//
// Two layers of checking:
//   1. Background checkers that run every cycle for the whole simulation
//      (pulse alignment, one-cycle pulse width, X detection, reset state).
//   2. Directed scenarios that check acceptance timing and glitch rejection.
//------------------------------------------------------------------------------
module tb;

    localparam integer CLK_FREQ_KHZ = 100;
    localparam integer CLK_PERIOD   = 1000000 / CLK_FREQ_KHZ;  // 10000 ns
    localparam integer HALF_PERIOD  = CLK_PERIOD / 2;
    localparam integer DEB_CYCLES   = CLK_FREQ_KHZ * 5;        // 500
    localparam integer DEB_NS       = DEB_CYCLES * CLK_PERIOD; // 5_000_000 ns

    // Accepted latency from the last btn_in change to the btn_out edge.
    // Sampling granularity gives (500,501] cycles for the 1-flop sync version;
    // the window below also covers a 2-flop synchroniser variant.
    localparam integer LAT_MIN = DEB_NS - CLK_PERIOD;
    localparam integer LAT_MAX = DEB_NS + 3 * CLK_PERIOD;

    reg  clk, rst_n, btn_in;
    wire btn_out, btn_pressed, btn_released;

    integer errors   = 0;
    integer checks   = 0;
    integer seed     = 32'hC0FFEE;

    // Bookkeeping for the background checkers
    reg         chk_en      = 1'b0;  // structural checkers armed
    reg         lat_en      = 1'b0;  // latency checker armed
    reg         out_d       = 1'b0;
    reg         rst_n_d     = 1'b0;
    time        t_last_in   = 0;
    integer     n_pressed   = 0;
    integer     n_released  = 0;

    debouncer #(.CLK_FREQ_KHZ(CLK_FREQ_KHZ)) dut (
        .clk          (clk),
        .rst_n        (rst_n),
        .btn_in       (btn_in),
        .btn_out      (btn_out),
        .btn_pressed  (btn_pressed),
        .btn_released (btn_released)
    );

    initial begin
        clk = 1'b0;
        forever #(HALF_PERIOD) clk = ~clk;
    end

    //--------------------------------------------------------------------------
    // Reporting helpers
    //--------------------------------------------------------------------------
    task fail(input [1023:0] msg);
        begin
            errors = errors + 1;
            $display("  [FAIL @ %0t ns] %0s", $time, msg);
        end
    endtask

    task pass(input [1023:0] msg);
        begin
            checks = checks + 1;
            $display("  [ ok  @ %0t ns] %0s", $time, msg);
        end
    endtask

    task check(input cond, input [1023:0] msg);
        begin
            checks = checks + 1;
            if (!cond) begin
                checks = checks - 1;
                fail(msg);
            end
        end
    endtask

    //--------------------------------------------------------------------------
    // Background checker 1: pulse alignment and width.
    // Sampled on negedge so every signal has settled after the posedge.
    // btn_pressed must be high in exactly the cycle following a 0->1 edge on
    // btn_out, and low in every other cycle. Same for btn_released / 1->0.
    //--------------------------------------------------------------------------
    always @(negedge clk) begin
        if (chk_en && rst_n_d) begin
            if (^{btn_out, btn_pressed, btn_released} === 1'bx)
                fail("output is X or Z");

            if (btn_pressed !== (btn_out && !out_d))
                fail("btn_pressed not aligned to a single btn_out 0->1 edge");

            if (btn_released !== (!btn_out && out_d))
                fail("btn_released not aligned to a single btn_out 1->0 edge");

            if (btn_pressed && btn_released)
                fail("btn_pressed and btn_released asserted together");

            if (btn_pressed)  n_pressed  = n_pressed  + 1;
            if (btn_released) n_released = n_released + 1;
        end
        out_d = btn_out;
    end

    //--------------------------------------------------------------------------
    // Background checker 2: synchronous reset clears every output.
    //--------------------------------------------------------------------------
    always @(negedge clk) begin
        if (chk_en && !rst_n_d) begin
            if (btn_out || btn_pressed || btn_released)
                fail("outputs not cleared while rst_n low");
        end
        rst_n_d = rst_n;
    end

    //--------------------------------------------------------------------------
    // Background checker 3: acceptance latency.
    // Any btn_out edge must land inside the window measured from the last
    // btn_in change; an early edge means bounce was not filtered.
    //--------------------------------------------------------------------------
    always @(btn_in) t_last_in = $time;

    always @(btn_out) begin
        if (lat_en) begin
            if (($time - t_last_in) < LAT_MIN)
                fail("btn_out changed too early (window not honoured)");
            else if (($time - t_last_in) > LAT_MAX)
                fail("btn_out changed too late (window overshot)");
            else
                pass("btn_out edge inside the 5 ms acceptance window");
        end
    end

    //--------------------------------------------------------------------------
    // Stimulus helpers
    //--------------------------------------------------------------------------
    task do_reset;
        begin
            lat_en = 1'b0;
            rst_n  = 1'b0;
            repeat (3) @(posedge clk);
            @(negedge clk);
            chk_en = 1'b1;
            repeat (2) @(negedge clk);
            rst_n = 1'b1;
            t_last_in = $time;    // ← Reset the latency window reference here
            @(negedge clk);
            lat_en = 1'b1;
        end
    endtask

    // Bouncy edge: random chatter, then settle on final_lvl.
    task bounce_to(input final_lvl, input integer n_glitch);
        integer i, w;
        begin
            for (i = 0; i < n_glitch; i = i + 1) begin
                btn_in = $random(seed);
                w = 10 + ({$random(seed)} % 190);  // 10..199 us glitch
                #(w * 1000);
            end
            btn_in = final_lvl;
        end
    endtask

    task snapshot(output integer p, output integer r);
        begin
            p = n_pressed;
            r = n_released;
        end
    endtask

    integer p0, r0;

    //--------------------------------------------------------------------------
    // Tests
    //--------------------------------------------------------------------------
    initial begin
        $dumpfile("tb_debouncer.vcd");
        $dumpvars(0, tb);

        btn_in = 1'b0;
        rst_n  = 1'b0;

        $display("\n=== Debouncer TB : %0d kHz, %0d-cycle (%0d ns) window ===",
                 CLK_FREQ_KHZ, DEB_CYCLES, DEB_NS);

        //----------------------------------------------------------------------
        $display("\n-- T1: reset holds all outputs low");
        do_reset;
        check(btn_out === 1'b0 && btn_pressed === 1'b0 && btn_released === 1'b0,
              "outputs not 0 after reset release");

        //----------------------------------------------------------------------
        $display("\n-- T2: clean press is accepted after exactly 5 ms");
        snapshot(p0, r0);
        @(negedge clk) btn_in = 1'b1;
        repeat (DEB_CYCLES - 2) @(posedge clk);       // one cycle short
        @(negedge clk);
        check(btn_out === 1'b0, "btn_out asserted before the window expired");
        repeat (4) @(posedge clk);
        @(negedge clk);
        check(btn_out === 1'b1, "btn_out did not assert after the window");
        check((n_pressed - p0) == 1, "expected exactly one btn_pressed pulse");
        check((n_released - r0) == 0, "unexpected btn_released pulse");

        //----------------------------------------------------------------------
        $display("\n-- T3: clean release is accepted after exactly 5 ms");
        snapshot(p0, r0);
        @(negedge clk) btn_in = 1'b0;
        #(DEB_NS + 5 * CLK_PERIOD);
        check(btn_out === 1'b0, "btn_out did not deassert");
        check((n_released - r0) == 1, "expected exactly one btn_released pulse");
        check((n_pressed - p0) == 0, "unexpected btn_pressed pulse");

        //----------------------------------------------------------------------
        $display("\n-- T4: bouncy press (chatter then settle high)");
        snapshot(p0, r0);
        bounce_to(1'b1, 24);
        #(DEB_NS + 5 * CLK_PERIOD);
        check(btn_out === 1'b1, "btn_out did not settle high after bounce");
        check((n_pressed - p0) == 1, "bouncy press produced multiple pulses");
        check((n_released - r0) == 0, "bouncy press produced a release pulse");

        //----------------------------------------------------------------------
        $display("\n-- T5: bouncy release (chatter then settle low)");
        snapshot(p0, r0);
        bounce_to(1'b0, 24);
        #(DEB_NS + 5 * CLK_PERIOD);
        check(btn_out === 1'b0, "btn_out did not settle low after bounce");
        check((n_released - r0) == 1, "bouncy release produced multiple pulses");
        check((n_pressed - p0) == 0, "bouncy release produced a press pulse");

        //----------------------------------------------------------------------
        $display("\n-- T6: short glitch (1 ms high) is rejected");
        snapshot(p0, r0);
        @(negedge clk) btn_in = 1'b1;
        #(1_000_000);                                  // 1 ms
        @(negedge clk) btn_in = 1'b0;
        #(DEB_NS + 5 * CLK_PERIOD);
        check(btn_out === 1'b0, "1 ms glitch was accepted");
        check((n_pressed - p0) == 0 && (n_released - r0) == 0,
              "1 ms glitch generated pulses");

        //----------------------------------------------------------------------
        $display("\n-- T7: near-miss glitch (window minus 3 cycles) is rejected");
        snapshot(p0, r0);
        @(negedge clk) btn_in = 1'b1;
        repeat (DEB_CYCLES - 3) @(posedge clk);
        @(negedge clk) btn_in = 1'b0;
        #(DEB_NS + 5 * CLK_PERIOD);
        check(btn_out === 1'b0, "near-miss glitch was accepted");
        check((n_pressed - p0) == 0 && (n_released - r0) == 0,
              "near-miss glitch generated pulses");

        //----------------------------------------------------------------------
        $display("\n-- T8: counter restarts on every bounce, never accumulates");
        // Twelve pulses of 1 ms each: total high time is 12 ms but no single
        // stable stretch reaches 5 ms, so nothing may be accepted.
        snapshot(p0, r0);
        repeat (12) begin
            @(negedge clk) btn_in = 1'b1;
            #(1_000_000);
            @(negedge clk) btn_in = 1'b0;
            #(1_000_000);
        end
        #(DEB_NS + 5 * CLK_PERIOD);
        check(btn_out === 1'b0, "accumulated partial windows were accepted");
        check((n_pressed - p0) == 0 && (n_released - r0) == 0,
              "chatter without a stable window generated pulses");

        //----------------------------------------------------------------------
        $display("\n-- T9: reset mid-count clears state and restarts the window");
        @(negedge clk) btn_in = 1'b1;
        repeat (DEB_CYCLES / 2) @(posedge clk);        // halfway through
        do_reset;                                      // btn_in still high
        snapshot(p0, r0);
        repeat (DEB_CYCLES / 2) @(posedge clk);
        @(negedge clk);
        check(btn_out === 1'b0, "counter resumed instead of restarting after reset");
        #(DEB_NS + 5 * CLK_PERIOD);
        check(btn_out === 1'b1, "press not accepted after post-reset window");
        check((n_pressed - p0) == 1, "expected one pulse after reset restart");

        //----------------------------------------------------------------------
        $display("\n-- T10: reset while btn_out is high forces it low");
        @(negedge clk) rst_n = 1'b0;
        lat_en = 1'b0;
        repeat (2) @(negedge clk);
        check(btn_out === 1'b0, "btn_out not cleared by reset");
        @(negedge clk) rst_n = 1'b1;
        @(negedge clk) lat_en = 1'b1;

        //----------------------------------------------------------------------
        $display("\n-- T11: randomised stress, 20 bouncy edges");
        begin : stress
            integer k;
            reg lvl;
            lvl = 1'b0;
            btn_in = 1'b0;
            #(DEB_NS + 5 * CLK_PERIOD);
            for (k = 0; k < 20; k = k + 1) begin
                lvl = ~lvl;
                snapshot(p0, r0);
                bounce_to(lvl, 8 + ({$random(seed)} % 20));
                #(DEB_NS + 8 * CLK_PERIOD);
                check(btn_out === lvl, "stress: btn_out did not track settled level");
                if (lvl)
                    check((n_pressed - p0) == 1 && (n_released - r0) == 0,
                          "stress: wrong pulse count on press");
                else
                    check((n_released - r0) == 1 && (n_pressed - p0) == 0,
                          "stress: wrong pulse count on release");
                #(({$random(seed)} % 3000) * 1000);    // idle 0..3 ms
            end
        end

        //----------------------------------------------------------------------
        $display("\n-- T12: idle input produces no activity");
        snapshot(p0, r0);
        #(20 * DEB_NS);
        check((n_pressed - p0) == 0 && (n_released - r0) == 0,
              "spurious pulses while btn_in was idle");

        //----------------------------------------------------------------------
        $display("\n==========================================");
        if (errors == 0)
            $display(" TEST PASSED  (%0d checks, %0d press / %0d release pulses)",
                     checks, n_pressed, n_released);
        else
            $display(" TEST FAILED  (%0d errors in %0d checks)", errors, checks);
        $display("==========================================\n");
        $finish;
    end

    // Watchdog
    initial begin
        #(2000 * DEB_NS);
        $display(" TEST FAILED  (watchdog timeout)");
        $finish;
    end

endmodule
