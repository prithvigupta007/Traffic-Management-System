module night_mode(
    input wire clk,
    input wire rst,
    input wire nightmode,
    input wire one_sec_tick,
    output reg yellow_blink
);
    always @(posedge clk)
    begin
        if(rst)
	begin
	    yellow_blink <= 0;
	end
	else if(!nightmode)
	begin
	    yellow_blink <= 0;
	end
	else if(one_sec_tick)
	begin
	    yellow_blink <= ~yellow_blink;
	end
    end
endmodule