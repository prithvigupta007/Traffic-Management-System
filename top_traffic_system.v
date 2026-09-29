module top_traffic_system(
    input wire clk,
    input wire rst,
    input wire [3:0]traffic_n_in,
    input wire [3:0]traffic_s_in,
    input wire [3:0]traffic_e_in,
    input wire [3:0]traffic_w_in,
    input wire pedestrian,
    input wire emergency_n,
    input wire emergency_s,
    input wire emergency_e,
    input wire emergency_w,
    input wire nightmode,
    output wire red_n,yellow_n,green_n,
    output wire red_s,yellow_s,green_s,
    output wire red_e,yellow_e,green_e,
    output wire red_w,yellow_w,green_w,
    output wire [6:0]seg,
    output wire [3:0]an
);
    wire [2:0]traffic_n_count;
    wire [2:0]traffic_s_count;
    wire [2:0]traffic_e_count;
    wire [2:0]traffic_w_count;
    wire [5:0]green_time_ns;
    wire [5:0]green_time_ew;
    wire emergency_request;
    wire pedestrian_request;
    wire priority_n;
    wire priority_s;
    wire priority_e;
    wire priority_w;
    wire phase_start;
    wire one_sec_tick;
    wire [5:0]remaining_time;
    wire phase_done;
    wire yellow_blink;
    wire [5:0]target_seconds;
    wire [3:0]state;
    wire [3:0]next_state;

    //traffic_input.v
    traffic_input u1(.clk(clk),.rst(rst),
        .traffic_n_in(traffic_n_in),.traffic_s_in(traffic_s_in),.traffic_e_in(traffic_e_in),.traffic_w_in(traffic_w_in),
        .traffic_n_count(traffic_n_count),.traffic_s_count(traffic_s_count),.traffic_e_count(traffic_e_count),.traffic_w_count(traffic_w_count)
    );


    //adaptive_controller.v
    adaptive_controller u2(.traffic_n_count(traffic_n_count),.traffic_s_count(traffic_s_count),.traffic_e_count(traffic_e_count),.traffic_w_count(traffic_w_count),
	.green_time_ns(green_time_ns),.green_time_ew(green_time_ew)
    );
    

    //priority_controller.v
    priority_controller u3(.clk(clk),.rst(rst),.pedestrian(pedestrian),
	.emergency_n(emergency_n),.emergency_s(emergency_s),.emergency_e(emergency_e),.emergency_w(emergency_w),
	.current_state(state),.emergency_request(emergency_request),.pedestrian_request(pedestrian_request),
	.priority_n(priority_n),.priority_s(priority_s),.priority_e(priority_e),.priority_w(priority_w)
    );


    //clock_timer.v
    clock_timer #(.CLK_FREQ(100000000)) u4(.clk(clk),.rst(rst),.target_seconds(target_seconds),.phase_start(phase_start),
	.one_sec_tick(one_sec_tick),.remaining_time(remaining_time),.phase_done(phase_done)
    );


    //night_mode.v
    night_mode u5(.clk(clk),.rst(rst),.nightmode(nightmode),.one_sec_tick(one_sec_tick),.yellow_blink(yellow_blink));


    //main fsm
    traffic_light_fsm u6(.clk(clk),.rst(rst),.emergency_request(emergency_request),.pedestrian_request(pedestrian_request),
	.priority_n(priority_n),.priority_s(priority_s),.priority_e(priority_e),.priority_w(priority_w),
	.green_time_ns(green_time_ns),.green_time_ew(green_time_ew),
	.nightmode(nightmode),.yellow_blink(yellow_blink),
	.phase_done(phase_done),.phase_start(phase_start),.target_seconds(target_seconds),.state(state),.next_state(next_state),
	.red_n(red_n),.yellow_n(yellow_n),.green_n(green_n),
	.red_s(red_s),.yellow_s(yellow_s),.green_s(green_s),
	.red_e(red_e),.yellow_e(yellow_e),.green_e(green_e),
	.red_w(red_w),.yellow_w(yellow_w),.green_w(green_w)
    );


    //seven_seg
    seven_seg_driver u7(.clk(clk),.rst(rst),.remaining_time(remaining_time),.seg(seg),.an(an));

endmodule