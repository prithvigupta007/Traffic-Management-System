// traffic_light_fsm.v
// -----------------------------------------------------------------------------
// PORT / INTEGRATION NOTES:
//   - emergency_request, pedestrian_request, priority_n/s/e/w  <- priority_controller.v
//   - green_time_ns, green_time_ew                              <- adaptive_controller.v
//   - phase_done                                                <- clock_timer.v
//   - phase_start, target_seconds                               -> clock_timer.v
//   - nightmode                                                 <- top-level input
//   - yellow_blink                                              <- night_mode.v
//   - red_*/yellow_*/green_*                                    -> traffic LEDs
//   - state, next_state                                         -> debug / testbench observability
// =============================================================================

module traffic_light_fsm (
    input  wire        clk,
    input  wire        rst,

    // From priority_controller.v
    input  wire        emergency_request,
    input  wire        pedestrian_request,
    input  wire        priority_n,
    input  wire        priority_s,
    input  wire        priority_e,
    input  wire        priority_w,

    // From adaptive_controller.v
    input  wire [5:0]  green_time_ns,
    input  wire [5:0]  green_time_ew,

    // Night mode
    input  wire        nightmode,     // mode-select, from top-level input
    input  wire        yellow_blink,  // blink pattern, from night_mode.v

    // Interface to clock_timer.v
    input  wire        phase_done,
    output reg         phase_start,
    output reg  [5:0]  target_seconds,

    // Debug / testbench observability
    output reg  [3:0]  state,
    output reg  [3:0]  next_state,

    // Traffic light outputs
    output reg red_n, yellow_n, green_n,
    output reg red_s, yellow_s, green_s,
    output reg red_e, yellow_e, green_e,
    output reg red_w, yellow_w, green_w
);

    // -------------------------------------------------------------------
    // State encoding
    // -------------------------------------------------------------------
    localparam [3:0]
        S_START       = 4'd0,
        S_NS_GREEN    = 4'd1,
        S_NS_YELLOW   = 4'd2,
        S_ALL_RED_1   = 4'd3,   // follows NS_YELLOW / startup ; defaults onward to EW_GREEN
        S_EW_GREEN    = 4'd4,
        S_EW_YELLOW   = 4'd5,
        S_ALL_RED_2   = 4'd6,   // follows EW_YELLOW ; defaults onward to NS_GREEN
        S_PEDESTRIAN  = 4'd7,
        S_EMERGENCY_N = 4'd8,
        S_EMERGENCY_S = 4'd9,
        S_EMERGENCY_E = 4'd10,
        S_EMERGENCY_W = 4'd11,
        S_NIGHT       = 4'd12;

    // -------------------------------------------------------------------
    // Phase durations (seconds). Yellow/all-red are fixed safety timings;
    // NS/EW green come from the adaptive controller; ped/emergency are
    // fixed per spec section 7.
    // -------------------------------------------------------------------
    localparam [5:0]
        STARTUP_SECONDS    = 6'd2,
        YELLOW_SECONDS     = 6'd3,
        ALL_RED_SECONDS    = 6'd2,
        PEDESTRIAN_SECONDS = 6'd10,
        EMERGENCY_SECONDS  = 6'd10,
        NIGHT_TICK_SECONDS = 6'd1;   // night mode doesn't "complete" a phase;
                                     // this just keeps clock_timer ticking.

    // Convenience: is there an active emergency on this axis?
    wire ns_emergency = emergency_request && (priority_n || priority_s);
    wire ew_emergency = emergency_request && (priority_e || priority_w);

    // -------------------------------------------------------------------
    // Arbitration used at every ALL_RED decision point.
    // Priority order (per spec section 7): emergency > pedestrian >
    // night mode > resume normal adaptive cycle.
    // `default_next` lets the caller say which normal-cycle phase comes
    // next (ALL_RED_1 -> EW_GREEN, ALL_RED_2 -> NS_GREEN) so the two
    // phases keep alternating fairly when nothing is interrupting.
    // -------------------------------------------------------------------
    function [3:0] arbitrate;
        input [3:0] default_next;
        begin
            if (emergency_request) begin
                if (priority_n)      arbitrate = S_EMERGENCY_N;
                else if (priority_s) arbitrate = S_EMERGENCY_S;
                else if (priority_e) arbitrate = S_EMERGENCY_E;
                else                 arbitrate = S_EMERGENCY_W;
            end else if (pedestrian_request) begin
                arbitrate = S_PEDESTRIAN;
            end else if (nightmode) begin
                arbitrate = S_NIGHT;
            end else begin
                arbitrate = default_next;
            end
        end
    endfunction

    // -------------------------------------------------------------------
    // Duration lookup for whatever state we are about to enter.
    // -------------------------------------------------------------------
    function [5:0] state_duration;
        input [3:0] s;
        begin
            case (s)
                S_START:       state_duration = STARTUP_SECONDS;
                S_NS_GREEN:    state_duration = green_time_ns;
                S_NS_YELLOW:   state_duration = YELLOW_SECONDS;
                S_ALL_RED_1:   state_duration = ALL_RED_SECONDS;
                S_EW_GREEN:    state_duration = green_time_ew;
                S_EW_YELLOW:   state_duration = YELLOW_SECONDS;
                S_ALL_RED_2:   state_duration = ALL_RED_SECONDS;
                S_PEDESTRIAN:  state_duration = PEDESTRIAN_SECONDS;
                S_EMERGENCY_N: state_duration = EMERGENCY_SECONDS;
                S_EMERGENCY_S: state_duration = EMERGENCY_SECONDS;
                S_EMERGENCY_E: state_duration = EMERGENCY_SECONDS;
                S_EMERGENCY_W: state_duration = EMERGENCY_SECONDS;
                S_NIGHT:       state_duration = NIGHT_TICK_SECONDS;
                default:       state_duration = ALL_RED_SECONDS; // safe fallback
            endcase
        end
    endfunction

    // -------------------------------------------------------------------
    // Next-state logic (combinational)
    // -------------------------------------------------------------------
    always @(*) begin
        case (state)

            S_START:
                next_state = phase_done ? S_ALL_RED_2 : S_START;

            // ---- NS GREEN -------------------------------------------------
            S_NS_GREEN: begin
                if (ew_emergency)
                    // Conflicting emergency: must not jump straight to EW.
                    // Begin the safe transition immediately.
                    next_state = S_NS_YELLOW;
                else if (pedestrian_request)
                    next_state = S_NS_YELLOW;
                else if (nightmode)
                    next_state = S_NS_YELLOW;
                else if (phase_done)
                    // Same-direction emergency: extend/continue this phase
                    // instead of leaving; otherwise proceed normally.
                    next_state = ns_emergency ? S_NS_GREEN : S_NS_YELLOW;
                else
                    next_state = S_NS_GREEN;
            end

            S_NS_YELLOW:
                next_state = phase_done ? S_ALL_RED_1 : S_NS_YELLOW;

            S_ALL_RED_1:
                next_state = phase_done ? arbitrate(S_EW_GREEN) : S_ALL_RED_1;

            // ---- EW GREEN ---------------------------------------------------
            S_EW_GREEN: begin
                if (ns_emergency)
                    next_state = S_EW_YELLOW;
                else if (pedestrian_request)
                    next_state = S_EW_YELLOW;
                else if (nightmode)
                    next_state = S_EW_YELLOW;
                else if (phase_done)
                    next_state = ew_emergency ? S_EW_GREEN : S_EW_YELLOW;
                else
                    next_state = S_EW_GREEN;
            end

            S_EW_YELLOW:
                next_state = phase_done ? S_ALL_RED_2 : S_EW_YELLOW;

            S_ALL_RED_2:
                next_state = phase_done ? arbitrate(S_NS_GREEN) : S_ALL_RED_2;

            // ---- PEDESTRIAN --------------------------------------------
            // Already all-red for vehicles on entry, so no yellow needed
            // going in or coming out -- just re-arbitrate afterward.
            S_PEDESTRIAN:
                next_state = phase_done ? S_ALL_RED_1 : S_PEDESTRIAN;

            // ---- EMERGENCIES ---------------------------------------------
            // Each emergency state drives the same light pattern as its
            // matching normal GREEN phase (NS or EW), just with a fixed
            // duration and a different trigger. A conflicting emergency
            // arriving mid-phase still has to go through YELLOW first.
            S_EMERGENCY_N: begin
                if (ew_emergency)
                    next_state = S_NS_YELLOW;
                else if (phase_done)
                    next_state = ns_emergency ? S_EMERGENCY_N : S_NS_YELLOW;
                else
                    next_state = S_EMERGENCY_N;
            end

            S_EMERGENCY_S: begin
                if (ew_emergency)
                    next_state = S_NS_YELLOW;
                else if (phase_done)
                    next_state = ns_emergency ? S_EMERGENCY_S : S_NS_YELLOW;
                else
                    next_state = S_EMERGENCY_S;
            end

            S_EMERGENCY_E: begin
                if (ns_emergency)
                    next_state = S_EW_YELLOW;
                else if (phase_done)
                    next_state = ew_emergency ? S_EMERGENCY_E : S_EW_YELLOW;
                else
                    next_state = S_EMERGENCY_E;
            end

            S_EMERGENCY_W: begin
                if (ns_emergency)
                    next_state = S_EW_YELLOW;
                else if (phase_done)
                    next_state = ew_emergency ? S_EMERGENCY_W : S_EW_YELLOW;
                else
                    next_state = S_EMERGENCY_W;
            end

            // ---- NIGHT MODE ---------------------------------------------
            // Exit on either nightmode deassertion or an emergency arriving
            // (real intersections still give emergency vehicles priority
            // at night). Both exits land in ALL_RED_2, which re-arbitrates.
            S_NIGHT:
                next_state = (!nightmode || emergency_request) ? S_ALL_RED_2 : S_NIGHT;

            // ---- Safety net: unreachable/corrupted state -> recover -------
            default:
                next_state = S_ALL_RED_1;

        endcase
    end

    // -------------------------------------------------------------------
    // State register + clock_timer control (synchronous)
    // -------------------------------------------------------------------
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state          <= S_START;
            phase_start    <= 1'b1;
            target_seconds <= STARTUP_SECONDS;
        end else begin
            state          <= next_state;
            phase_start    <= (next_state != state);
            target_seconds <= state_duration(next_state);
        end
    end

    // -------------------------------------------------------------------
    // Output logic (Moore -- depends only on registered `state`)
    // Default is all-red on every axis; this guarantees rule #1 (no
    // conflicting greens) and rule #6 (fail-safe on invalid state) by
    // construction -- only one branch below can ever turn a green bit on.
    // -------------------------------------------------------------------
    always @(*) begin
        {red_n, yellow_n, green_n} = 3'b100;
        {red_s, yellow_s, green_s} = 3'b100;
        {red_e, yellow_e, green_e} = 3'b100;
        {red_w, yellow_w, green_w} = 3'b100;

        case (state)
            S_NS_GREEN, S_EMERGENCY_N, S_EMERGENCY_S: begin
                {red_n, yellow_n, green_n} = 3'b001;
                {red_s, yellow_s, green_s} = 3'b001;
            end

            S_NS_YELLOW: begin
                {red_n, yellow_n, green_n} = 3'b010;
                {red_s, yellow_s, green_s} = 3'b010;
            end

            S_EW_GREEN, S_EMERGENCY_E, S_EMERGENCY_W: begin
                {red_e, yellow_e, green_e} = 3'b001;
                {red_w, yellow_w, green_w} = 3'b001;
            end

            S_EW_YELLOW: begin
                {red_e, yellow_e, green_e} = 3'b010;
                {red_w, yellow_w, green_w} = 3'b010;
            end

            S_NIGHT: begin
                {red_n, yellow_n, green_n} = {1'b0, yellow_blink, 1'b0};
                {red_s, yellow_s, green_s} = {1'b0, yellow_blink, 1'b0};
                {red_e, yellow_e, green_e} = {1'b0, yellow_blink, 1'b0};
                {red_w, yellow_w, green_w} = {1'b0, yellow_blink, 1'b0};
            end

            // S_START, S_ALL_RED_1, S_ALL_RED_2, S_PEDESTRIAN, and any
            // undefined state all fall through to the all-red default above.
            default: ;
        endcase
    end

endmodule