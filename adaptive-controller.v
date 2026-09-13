module adaptive_controller(input wire[2:0]traffic_a_count , input wire[2:0]traffic_b_count,
                           output reg[5:0]green_time_a, output reg[5:0]green_time_b);

  // giving green time on the basis of traffic density
  
  always @(*) begin
    if(traffic_a_count<=1)
      green_time_a=10;
    else if (traffic_a_count<=3)
      green_time_a=15;
    else
      green_time_a=20;


    if(traffic_b_count<=1)
      green_time_b=10;
    else if(traffic_b_count<=3)
      green_time_b=15;
    else
      green_time_b=20;

  end
  endmodule
  
    
