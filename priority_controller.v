module priority_controller(
    input  wire       clk,
    input  wire       rst,
    input  wire       pedestrian,
    input  wire       emergency_n,
    input  wire       emergency_s,
    input  wire       emergency_e,
    input  wire       emergency_w,
    // Current state of the MAIN traffic-light FSM
    input  wire [3:0] current_state,

    // Priority controller outputs
    output reg        emergency_request,
    output reg        pedestrian_request,

    output reg        priority_n,
    output reg        priority_s,
    output reg        priority_e,
    output reg        priority_w
);


    localparam [3:0] S_START       = 4'd0;

    localparam [3:0] S_NS_GREEN    = 4'd1;
    localparam [3:0] S_NS_YELLOW   = 4'd2;

    localparam [3:0] S_EW_GREEN    = 4'd3;
    localparam [3:0] S_EW_YELLOW   = 4'd4;

    localparam [3:0] S_ALL_RED_1   = 4'd5;
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

    reg pending_n;
    reg pending_s;
    reg pending_e;
    reg pending_w;

    reg pending_pedestrian;


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

            state <= next_state;

            if (emergency_n)
                pending_n <= 1'b1;

            if (emergency_s)
                pending_s <= 1'b1;

            if (emergency_e)
                pending_e <= 1'b1;

            if (emergency_w)
                pending_w <= 1'b1;

            if (pedestrian)
                pending_pedestrian <= 1'b1;

            // Clear emergency request AFTER it has been served
            // current_state comes from the main traffic FSM.

            if (current_state == S_EMERGENCY_N) begin

                if (!emergency_n)
                    pending_n <= 1'b0;

            end

            if (current_state == S_EMERGENCY_S) begin

                if (!emergency_s)
                    pending_s <= 1'b0;

            end

            if (current_state == S_EMERGENCY_E) begin

                if (!emergency_e)
                    pending_e <= 1'b0;

            end

            if (current_state == S_EMERGENCY_W) begin

                if (!emergency_w)
                    pending_w <= 1'b0;

            end

            if (current_state == S_PEDESTRIAN) begin

                pending_pedestrian <= 1'b0;

            end

        end

    end


    // =========================================================
    // NEXT-STATE LOGIC FOR PRIORITY FSM
    // =========================================================

    always @(*) begin

        // Default:
        // stay in current priority state
        next_state = state;


        case (state)

            P_IDLE: begin

                if (pending_n || pending_s) begin

                    next_state = P_EMERGENCY_NS;

                end

                else if (pending_e || pending_w) begin

                    next_state = P_EMERGENCY_EW;

                end

                else if (pending_pedestrian) begin

                    next_state = P_PEDESTRIAN;

                end

                else begin

                    next_state = P_IDLE;

                end

            end


            P_EMERGENCY_NS: begin

                if ((current_state == S_EMERGENCY_N) ||
                    (current_state == S_EMERGENCY_S)) begin

                    next_state = P_IDLE;

                end

                else begin

                    next_state = P_EMERGENCY_NS;

                end

            end

            P_EMERGENCY_EW: begin

                if ((current_state == S_EMERGENCY_E) ||
                    (current_state == S_EMERGENCY_W)) begin

                    next_state = P_IDLE;

                end

                else begin

                    next_state = P_EMERGENCY_EW;

                end

            end

            P_PEDESTRIAN: begin

                if (current_state == S_PEDESTRIAN) begin

                    next_state = P_IDLE;

                end

                else begin

                    next_state = P_PEDESTRIAN;

                end

            end

            default: begin

                next_state = P_IDLE;

            end

        endcase

    end


    always @(*) begin

        // -----------------------------------------------------
        // Default outputs
        // -----------------------------------------------------

        emergency_request  = 1'b0;
        pedestrian_request = 1'b0;

        priority_n = 1'b0;
        priority_s = 1'b0;
        priority_e = 1'b0;
        priority_w = 1'b0;


        case (state)

            P_IDLE: begin


                emergency_request  = 1'b0;
                pedestrian_request = 1'b0;

            end

            P_EMERGENCY_NS: begin

                emergency_request = 1'b1;
                // Request only the pending N/S emergencies.
                priority_n = pending_n;
                priority_s = pending_s;

                priority_e = 1'b0;
                priority_w = 1'b0;

            end

            P_EMERGENCY_EW: begin

                emergency_request = 1'b1;

                priority_n = 1'b0;
                priority_s = 1'b0;

                // Request only the pending E/W emergencies.
                priority_e = pending_e;
                priority_w = pending_w;

            end

            P_PEDESTRIAN: begin

                pedestrian_request = 1'b1;

                priority_n = 1'b0;
                priority_s = 1'b0;
                priority_e = 1'b0;
                priority_w = 1'b0;

            end

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