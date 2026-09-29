module priority_controller(

    input  wire       clk,
    input  wire       rst,

    input  wire       pedestrian,

    input  wire       emergency_n,
    input  wire       emergency_s,
    input  wire       emergency_e,
    input  wire       emergency_w,

    // Current state of MAIN traffic-light FSM
    input  wire [3:0] current_state,

    // Outputs to MAIN traffic-light FSM
    output reg        emergency_request,
    output reg        pedestrian_request,

    output reg        priority_n,
    output reg        priority_s,
    output reg        priority_e,
    output reg        priority_w
);


    // =========================================================
    // MAIN TRAFFIC FSM STATE ENCODING
    // These values MUST match traffic_light_fsm.v
    // =========================================================

    localparam [3:0] S_START       = 4'd0;

    localparam [3:0] S_NS_GREEN    = 4'd1;
    localparam [3:0] S_NS_YELLOW   = 4'd2;

    localparam [3:0] S_ALL_RED_1   = 4'd3;

    localparam [3:0] S_EW_GREEN    = 4'd4;
    localparam [3:0] S_EW_YELLOW   = 4'd5;

    localparam [3:0] S_ALL_RED_2   = 4'd6;

    localparam [3:0] S_PEDESTRIAN  = 4'd7;

    localparam [3:0] S_EMERGENCY_N = 4'd8;
    localparam [3:0] S_EMERGENCY_S = 4'd9;
    localparam [3:0] S_EMERGENCY_E = 4'd10;
    localparam [3:0] S_EMERGENCY_W = 4'd11;

    localparam [3:0] S_NIGHT       = 4'd12;


    // =========================================================
    // PRIORITY CONTROLLER FSM STATES
    // =========================================================

    localparam [2:0] P_IDLE         = 3'd0;
    localparam [2:0] P_EMERGENCY_NS = 3'd1;
    localparam [2:0] P_EMERGENCY_EW = 3'd2;
    localparam [2:0] P_PEDESTRIAN   = 3'd3;


    reg [2:0] state;
    reg [2:0] next_state;


    // =========================================================
    // PENDING REQUEST REGISTERS
    // =========================================================

    reg pending_n;
    reg pending_s;
    reg pending_e;
    reg pending_w;
    reg pending_pedestrian;


    // =========================================================
    // SEQUENTIAL LOGIC
    // =========================================================

    always @(posedge clk) begin

        if (rst) begin

            state <= P_IDLE;

            pending_n <= 1'b0;
            pending_s <= 1'b0;
            pending_e <= 1'b0;
            pending_w <= 1'b0;

            pending_pedestrian <= 1'b0;

        end

        else begin

            // Update priority-controller FSM
            state <= next_state;


            // -------------------------------------------------
            // Capture new emergency requests
            // -------------------------------------------------

            if (emergency_n)
                pending_n <= 1'b1;

            if (emergency_s)
                pending_s <= 1'b1;

            if (emergency_e)
                pending_e <= 1'b1;

            if (emergency_w)
                pending_w <= 1'b1;


            // -------------------------------------------------
            // Capture pedestrian request
            // -------------------------------------------------

            if (pedestrian)
                pending_pedestrian <= 1'b1;


            // -------------------------------------------------
            // Clear N emergency after it has been served
            // -------------------------------------------------

            if ((current_state == S_EMERGENCY_N) &&
                !emergency_n)

                pending_n <= 1'b0;


            // -------------------------------------------------
            // Clear S emergency after it has been served
            // -------------------------------------------------

            if ((current_state == S_EMERGENCY_S) &&
                !emergency_s)

                pending_s <= 1'b0;


            // -------------------------------------------------
            // Clear E emergency after it has been served
            // -------------------------------------------------

            if ((current_state == S_EMERGENCY_E) &&
                !emergency_e)

                pending_e <= 1'b0;


            // -------------------------------------------------
            // Clear W emergency after it has been served
            // -------------------------------------------------

            if ((current_state == S_EMERGENCY_W) &&
                !emergency_w)

                pending_w <= 1'b0;


            // -------------------------------------------------
            // SAME-DIRECTION EMERGENCY
            //
            // NS emergency while NS_GREEN is being served.
            // Once emergency input goes LOW, request is cleared.
            // -------------------------------------------------

            if ((current_state == S_NS_GREEN) &&
                !emergency_n)

                pending_n <= 1'b0;


            if ((current_state == S_NS_GREEN) &&
                !emergency_s)

                pending_s <= 1'b0;


            // -------------------------------------------------
            // SAME-DIRECTION EMERGENCY
            //
            // EW emergency while EW_GREEN is being served.
            // -------------------------------------------------

            if ((current_state == S_EW_GREEN) &&
                !emergency_e)

                pending_e <= 1'b0;


            if ((current_state == S_EW_GREEN) &&
                !emergency_w)

                pending_w <= 1'b0;


            // -------------------------------------------------
            // Pedestrian request has been served
            // -------------------------------------------------

            if (current_state == S_PEDESTRIAN)

                pending_pedestrian <= 1'b0;

        end

    end


    // =========================================================
    // NEXT-STATE LOGIC
    // =========================================================

    always @(*) begin

        // Default: remain in current priority state
        next_state = state;


        case (state)


            // =================================================
            // IDLE
            // =================================================

            P_IDLE: begin

                // Don't start another priority request while
                // the main FSM is already inside an emergency.
                //
                // This prevents:
                //
                // EMERGENCY_N
                //      ↓
                // EMERGENCY_S immediately
                //
                // before the main FSM has completed N service.

                if ((current_state == S_EMERGENCY_N) ||
                    (current_state == S_EMERGENCY_S) ||
                    (current_state == S_EMERGENCY_E) ||
                    (current_state == S_EMERGENCY_W)) begin

                    next_state = P_IDLE;

                end

                // Emergency has highest priority

                else if (pending_n || pending_s) begin

                    next_state = P_EMERGENCY_NS;

                end

                else if (pending_e || pending_w) begin

                    next_state = P_EMERGENCY_EW;

                end

                // Pedestrian comes after emergency

                else if (pending_pedestrian) begin

                    next_state = P_PEDESTRIAN;

                end

                else begin

                    next_state = P_IDLE;

                end

            end


            // =================================================
            // N-S EMERGENCY
            // =================================================

            P_EMERGENCY_NS: begin

                // Main FSM has entered an emergency state.
                // Priority controller waits until it is served.

                if ((current_state == S_EMERGENCY_N) ||
                    (current_state == S_EMERGENCY_S)) begin

                    next_state = P_IDLE;

                end

                // Same-direction emergency has been released

                else if (!(pending_n || pending_s)) begin

                    next_state = P_IDLE;

                end

                else begin

                    next_state = P_EMERGENCY_NS;

                end

            end


            // =================================================
            // E-W EMERGENCY
            // =================================================

            P_EMERGENCY_EW: begin

                if ((current_state == S_EMERGENCY_E) ||
                    (current_state == S_EMERGENCY_W)) begin

                    next_state = P_IDLE;

                end

                else if (!(pending_e || pending_w)) begin

                    next_state = P_IDLE;

                end

                else begin

                    next_state = P_EMERGENCY_EW;

                end

            end


            // =================================================
            // PEDESTRIAN
            // =================================================

            P_PEDESTRIAN: begin

                if (current_state == S_PEDESTRIAN) begin

                    next_state = P_IDLE;

                end

                else begin

                    next_state = P_PEDESTRIAN;

                end

            end


            // =================================================
            // SAFETY FALLBACK
            // =================================================

            default: begin

                next_state = P_IDLE;

            end

        endcase

    end


    // =========================================================
    // OUTPUT LOGIC
    // =========================================================

    always @(*) begin

        // -----------------------------------------------------
        // Safe default
        // -----------------------------------------------------

        emergency_request  = 1'b0;
        pedestrian_request = 1'b0;

        priority_n = 1'b0;
        priority_s = 1'b0;
        priority_e = 1'b0;
        priority_w = 1'b0;


        case (state)


            // =================================================
            // IDLE
            // =================================================

            P_IDLE: begin

                emergency_request  = 1'b0;
                pedestrian_request = 1'b0;

            end


            // =================================================
            // N-S EMERGENCY
            // =================================================

            P_EMERGENCY_NS: begin

                emergency_request = 1'b1;


                // IMPORTANT:
                // Only ONE direction is requested at a time.

                if (pending_n) begin

                    priority_n = 1'b1;

                end

                else if (pending_s) begin

                    priority_s = 1'b1;

                end

            end


            // =================================================
            // E-W EMERGENCY
            // =================================================

            P_EMERGENCY_EW: begin

                emergency_request = 1'b1;


                // Only ONE direction is requested at a time.

                if (pending_e) begin

                    priority_e = 1'b1;

                end

                else if (pending_w) begin

                    priority_w = 1'b1;

                end

            end


            // =================================================
            // PEDESTRIAN
            // =================================================

            P_PEDESTRIAN: begin

                pedestrian_request = 1'b1;

            end


            // =================================================
            // SAFETY DEFAULT
            // =================================================

            default: begin

                emergency_request  = 1'b0;
                pedestrian_request = 1'b0;

                priority_n = 1'b0;
                priority_s = 1'b0;
                priority_e = 1'b0;
                priority_w = 1'b0;

            end

        endcase

    end

endmodule