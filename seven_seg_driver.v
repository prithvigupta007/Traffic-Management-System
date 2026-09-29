module seven_seg_driver(
    input wire clk,
    input wire rst,
    input wire [5:0]remaining_time,
    output reg [6:0]seg,
    output reg [3:0]an
);
    reg [1:0]digit_select;
    reg [3:0]digit_value;
    reg [16:0]refresh_count;
    always @(posedge clk or posedge rst) begin
        if (rst) 
        begin
            refresh_count <= 17'd0;
            digit_select  <= 2'd0;
        end
        else 
        begin //1ms=100000*10ns
            if (refresh_count == 17'd99999) 
            begin
                refresh_count <= 17'd0;
                digit_select  <= digit_select +1'b1;
            end
            else 
            begin
                refresh_count <= refresh_count +1'b1;
            end
        end
    end
  
    always @(*) begin
        case (digit_select)
            2'd0: 
            begin //unit digit
                an = 4'b1110;
                digit_value = remaining_time%10;
            end
            2'd1: 
            begin //tens digit
                an = 4'b1101;
                digit_value = remaining_time/10;
            end
            2'd2: 
            begin //unused
                an = 4'b1111;
                digit_value = 4'd0;
            end
            2'd3: 
            begin //unused
                an = 4'b1111;
                digit_value = 4'd0;
            end
            default: 
            begin
                an = 4'b1111;
                digit_value = 4'd0;
            end
        endcase
    end
  
    always @(*) begin
      case (digit_value) //for basys 3
            4'd0: seg = 7'b1000000;
            4'd1: seg = 7'b1111001;
            4'd2: seg = 7'b0100100;
            4'd3: seg = 7'b0110000;
            4'd4: seg = 7'b0011001;
            4'd5: seg = 7'b0010010;
            4'd6: seg = 7'b0000010;
            4'd7: seg = 7'b1111000;
            4'd8: seg = 7'b0000000;
            4'd9: seg = 7'b0010000;
            default: seg = 7'b1111111;
       endcase
    end
endmodule
