module clock_timer #(parameter integer CLK_FREQ=100000000)(
    input wire clk,
    input wire rst,
    input wire [5:0]target_seconds,
    input wire phase_start,
    output reg one_sec_tick,
    output reg [5:0]remaining_time,
    output reg phase_done
);
    reg [31:0]clk_count;
	always @(posedge clk or posedge rst)
    begin
        if(rst)
	    begin
	        clk_count <= 32'd0;
            one_sec_tick <= 1'b0;
            remaining_time <= 6'd0;
            phase_done <= 1'b0;
	    end
	    else
	    begin
	        if(clk_count == CLK_FREQ-1)
	        begin
		        clk_count <= 32'd0;
		        one_sec_tick <= 1'b1;
	        end
	        else
	        begin
		        clk_count <= clk_count+1'b1;
		        one_sec_tick <= 1'b0;
	        end

	        if(phase_start)
	        begin
		        remaining_time <= target_seconds;
                phase_done <= 1'b0;
	        end
	        else if(one_sec_tick) 
	        begin
                if(remaining_time>1) 
		        begin
                    remaining_time <= remaining_time-1'b1;
					phase_done <= 1'b0;
                end
                else 
		        begin
                    remaining_time <= 6'd0;
                    phase_done <= 1'b1;
                end
	        end
	    end
    end
endmodule
