module adaptive_controller(input wire[2:0]traffic_n_count ,input wire[2:0]traffic_s_count , input wire[2:0]traffic_e_count,
                           input wire[2:0]traffic_w_count, output reg[5:0]green_time_ns, output reg[5:0]green_time_ew);

  reg [3:0] ns_demand;
  reg [3:0] ew_demand;

  
  
  always @(*) begin

    // calculate total traffic demand 
    ns_demand = traffic_n_count + traffic_s_count;
    ew_demand = traffic_e_count + traffic_w_count;
    
    // giving green time on the basis traffic density 

    // for ns
    if(ns_demand <=1)
      green_time_ns=10;
    else if (ns_demand<=3)
      green_time_ns=15;
    else
      green_time_ns=20;

  // for ew
    if(ew_demand<=1)
      green_time_ew=10;
    else if(ew_demand<=3)
      green_time_ew=15;
    else
      green_time_ew=20;

  end
  endmodule
  
    
