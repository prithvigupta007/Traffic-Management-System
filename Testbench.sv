
`timescale 1ns/1ps

module traffic_management_system_tb;

    // Clock and DUT inputs
    logic clk = 1'b0;
    logic rst = 1'b1;

    logic [3:0] traffic_n_in = 4'b0000;
    logic [3:0] traffic_s_in = 4'b0000;
    logic [3:0] traffic_e_in = 4'b0000;
    logic [3:0] traffic_w_in = 4'b0000;

    logic pedestrian = 1'b0;
    logic emergency_n = 1'b0;
    logic emergency_s = 1'b0;
    logic emergency_e = 1'b0;
    logic emergency_w = 1'b0;
    logic nightmode = 1'b0;

    // DUT outputs
    wire red_n, yellow_n, green_n;
    wire red_s, yellow_s, green_s;
    wire red_e, yellow_e, green_e;
    wire red_w, yellow_w, green_w;
    wire [6:0] seg;
    wire [3:0] an;

    integer pass_count = 0;
    integer fail_count = 0;
    integer i;

    bit saw_blink_low;
    bit saw_blink_high;

    // Device under test: complete top-level system
    top_traffic_system dut (
        .clk(clk),
        .rst(rst),

        .traffic_n_in(traffic_n_in),
        .traffic_s_in(traffic_s_in),
        .traffic_e_in(traffic_e_in),
        .traffic_w_in(traffic_w_in),

        .pedestrian(pedestrian),

        .emergency_n(emergency_n),
        .emergency_s(emergency_s),
        .emergency_e(emergency_e),
        .emergency_w(emergency_w),

        .nightmode(nightmode),

        .red_n(red_n),
        .yellow_n(yellow_n),
        .green_n(green_n),

        .red_s(red_s),
        .yellow_s(yellow_s),
        .green_s(green_s),

        .red_e(red_e),
        .yellow_e(yellow_e),
        .green_e(green_e),

        .red_w(red_w),
        .yellow_w(yellow_w),
        .green_w(green_w),

        .seg(seg),
        .an(an)
    );

    // Accelerate the timer for simulation.
    // Overrides the timer parameter only in this simulation.
    defparam dut.u4.CLK_FREQ = 4;

    // 10 ns clock period
    always #5 clk = ~clk;

    // Main FSM state encodings from traffic_light_fsm.v
    localparam logic [3:0] S_START       = 4'd0;
    localparam logic [3:0] S_NS_GREEN    = 4'd1;
    localparam logic [3:0] S_NS_YELLOW   = 4'd2;
    localparam logic [3:0] S_ALL_RED_1   = 4'd3;
    localparam logic [3:0] S_EW_GREEN    = 4'd4;
    localparam logic [3:0] S_EW_YELLOW   = 4'd5;
    localparam logic [3:0] S_ALL_RED_2   = 4'd6;
    localparam logic [3:0] S_PEDESTRIAN  = 4'd7;
    localparam logic [3:0] S_EMERGENCY_N = 4'd8;
    localparam logic [3:0] S_EMERGENCY_S = 4'd9;
    localparam logic [3:0] S_EMERGENCY_E = 4'd10;
    localparam logic [3:0] S_EMERGENCY_W = 4'd11;
    localparam logic [3:0] S_NIGHT       = 4'd12;

    // Common pass/fail checker
    task automatic check(
        input bit condition,
        input string message
    );
        begin
            if (condition) begin
                pass_count = pass_count + 1;
                $display("[PASS] %s", message);
            end
            else begin
                fail_count = fail_count + 1;
                $error(
                    "[FAIL] %s (time=%0t, state=%0d)",
                    message, $time, dut.state
                );
            end
        end
    endtask

    // Wait for a specified number of clock cycles
    task automatic wait_cycles(input integer count);
        integer k;
        begin
            for (k = 0; k < count; k = k + 1)
                @(posedge clk);
            #1;
        end
    endtask

    // Wait until the main FSM reaches a desired state
    task automatic wait_for_state(
        input logic [3:0] expected_state,
        input integer max_cycles,
        input string message
    );
        integer k;
        bit found;
        begin
            found = 1'b0;

            for (k = 0; k < max_cycles; k = k + 1) begin
                if (dut.state === expected_state) begin
                    found = 1'b1;
                    k = max_cycles;
                end
                else begin
                    @(posedge clk);
                    #1;
                end
            end

            check(found, message);
        end
    endtask

    // Reset the integrated system
    task automatic apply_reset;
        begin
            rst = 1'b1;

            pedestrian = 1'b0;

            emergency_n = 1'b0;
            emergency_s = 1'b0;
            emergency_e = 1'b0;
            emergency_w = 1'b0;

            nightmode = 1'b0;

            traffic_n_in = 4'b0000;
            traffic_s_in = 4'b0000;
            traffic_e_in = 4'b0000;
            traffic_w_in = 4'b0000;

            wait_cycles(3);

            check(
                dut.state == S_START,
                "Reset puts main FSM in S_START"
            );

            check(
                {red_n, red_s, red_e, red_w} == 4'b1111,
                "Startup/reset lights default to all red"
            );

            rst = 1'b0;
            wait_cycles(2);
        end
    endtask

    // Continuous safety checks
    // NS and EW road groups must never be green simultaneously.
    always @(negedge clk) begin
        if (!rst) begin

            if ((green_n || green_s) &&
                (green_e || green_w)) begin

                fail_count = fail_count + 1;

                $error(
                    "[FAIL] Conflicting NS and EW greens at time=%0t, state=%0d",
                    $time, dut.state
                );
            end

            // No direction should have multiple active lamp signals.
            // Night mode may intentionally turn all three signals off.
            if ((red_n && yellow_n) ||
                (red_n && green_n) ||
                (yellow_n && green_n) ||

                (red_s && yellow_s) ||
                (red_s && green_s) ||
                (yellow_s && green_s) ||

                (red_e && yellow_e) ||
                (red_e && green_e) ||
                (yellow_e && green_e) ||

                (red_w && yellow_w) ||
                (red_w && green_w) ||
                (yellow_w && green_w)) begin

                fail_count = fail_count + 1;

                $error(
                    "[FAIL] Multiple lamp signals active for one direction at time=%0t",
                    $time
                );
            end
        end
    end

    initial begin
        $dumpfile("traffic_management_system_tb.vcd");
        $dumpvars(0, traffic_management_system_tb);

        $display("================================================");
        $display(" Traffic Management System Testbench");
        $display(" Integrated top-level SystemVerilog simulation");
        $display(" Timer accelerated to 4 clock cycles per second");
        $display("================================================");

        // --------------------------------------------------------
        // TEST 1: RESET AND VEHICLE COUNTING
        // --------------------------------------------------------
        apply_reset();

        traffic_n_in = 4'b1011; // 3 vehicles
        traffic_s_in = 4'b1111; // 4 vehicles
        traffic_e_in = 4'b0101; // 2 vehicles
        traffic_w_in = 4'b0000; // 0 vehicles

        wait_cycles(2);

        check(
            dut.traffic_n_count == 3,
            "North sensor counts 3 asserted bits"
        );

        check(
            dut.traffic_s_count == 4,
            "South sensor counts 4 asserted bits"
        );

        check(
            dut.traffic_e_count == 2,
            "East sensor counts 2 asserted bits"
        );

        check(
            dut.traffic_w_count == 0,
            "West sensor counts 0 asserted bits"
        );

        check(
            dut.green_time_ns == 20,
            "NS adaptive green is 20 for demand 3+4"
        );

        check(
            dut.green_time_ew == 15,
            "EW adaptive green is 15 for demand 2+0"
        );

        // --------------------------------------------------------
        // TEST 2: ADAPTIVE CONTROLLER LOW-DEMAND BOUNDARY
        // --------------------------------------------------------
        traffic_n_in = 4'b0000;
        traffic_s_in = 4'b0000;
        traffic_e_in = 4'b0000;
        traffic_w_in = 4'b0000;

        wait_cycles(2);

        check(
            dut.green_time_ns == 10,
            "NS adaptive green is 10 for zero demand"
        );

        check(
            dut.green_time_ew == 10,
            "EW adaptive green is 10 for zero demand"
        );

        // --------------------------------------------------------
        // TEST 3: NORMAL TRAFFIC-LIGHT SEQUENCE
        // --------------------------------------------------------
        wait_for_state(
            S_NS_GREEN,
            80,
            "Normal sequence reaches NS_GREEN"
        );

        check(
            green_n && green_s && red_e && red_w,
            "NS_GREEN turns N/S green and E/W red"
        );

        check(
            !green_e && !green_w,
            "EW approaches are not green during NS phase"
        );

        // --------------------------------------------------------
        // TEST 4: EAST EMERGENCY REQUEST
        // --------------------------------------------------------
        emergency_e = 1'b1;

        wait_for_state(
            S_EMERGENCY_E,
            160,
            "East emergency reaches S_EMERGENCY_E"
        );

        check(
            green_e && green_w && !green_n && !green_s,
            "East emergency serves E/W green without NS green"
        );

        // Release the emergency request
        emergency_e = 1'b0;

        wait_for_state(
            S_EW_YELLOW,
            100,
            "Released east emergency exits through EW_YELLOW"
        );

        // --------------------------------------------------------
        // TEST 5: PEDESTRIAN REQUEST
        // --------------------------------------------------------
        pedestrian = 1'b1;

        wait_cycles(3);

        pedestrian = 1'b0;

        wait_for_state(
            S_PEDESTRIAN,
            180,
            "Pedestrian request reaches pedestrian phase"
        );

        check(
            !green_n && !green_s && !green_e && !green_w,
            "All vehicle greens are off during pedestrian phase"
        );

        // --------------------------------------------------------
        // TEST 6: NIGHT MODE AND YELLOW BLINKING
        // --------------------------------------------------------
        nightmode = 1'b1;

        wait_for_state(
            S_NIGHT,
            180,
            "Night mode reaches S_NIGHT"
        );

        check(
            !green_n && !green_s && !green_e && !green_w,
            "All vehicle greens are off in night mode"
        );

        saw_blink_low = 1'b0;
        saw_blink_high = 1'b0;

        for (i = 0; i < 32; i = i + 1) begin
            @(posedge clk);
            #1;

            if (dut.yellow_blink === 1'b0)
                saw_blink_low = 1'b1;

            if (dut.yellow_blink === 1'b1)
                saw_blink_high = 1'b1;
        end

        check(
            saw_blink_low && saw_blink_high,
            "Night-mode yellow_blink toggles between 0 and 1"
        );

        check(
            !green_n && !green_s && !green_e && !green_w,
            "Night mode never enables a green lamp"
        );

        // --------------------------------------------------------
        // TEST 7: SEVEN-SEGMENT DISPLAY OUTPUTS
        // --------------------------------------------------------
        check(
            ((^seg) !== 1'bx) && ((^an) !== 1'bx),
            "Seven-segment outputs contain no X values"
        );

        check(
            (an == 4'b1110) ||
            (an == 4'b1101) ||
            (an == 4'b1111),
            "Seven-segment anodes use valid active-low patterns"
        );

        // --------------------------------------------------------
        // FINAL TEST REPORT
        // --------------------------------------------------------
        wait_cycles(2);

        $display("================================================");
        $display(
            "TEST SUMMARY: %0d passed, %0d failed",
            pass_count, fail_count
        );
        $display("VCD waveform: traffic_management_system_tb.vcd");
        $display("================================================");

        if (fail_count != 0) begin
            $fatal(
                1,
                "TESTBENCH FAILED: %0d failure(s)",
                fail_count
            );
        end
        else begin
            $display("ALL DIRECTED TESTS PASSED");
            $finish;
        end
    end

endmodule
