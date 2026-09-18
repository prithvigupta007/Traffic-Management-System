module traffic_input(
    input wire clk,
    input wire rst,
    input wire[3:0] traffic_n_in,
    input wire[3:0] traffic_s_in,
    input wire[3:0] traffic_e_in,
    input wire[3:0] traffic_w_in,

    output reg[2:0] traffic_n_count,
    output reg[2:0] traffic_s_count,
    output reg[2:0] traffic_e_count,
    output reg[2:0] traffic_w_count
);
always @(posedge clk or posedge rst) begin
if (rst) begin
traffic_n_count <= 3'd0; 
traffic_s_count <= 3'd0; 
traffic_e_count <= 3'd0; 
traffic_w_count <= 3'd0; 
end
else begin
traffic_n_count<= traffic_n_in[0]+traffic_n_in[1]+traffic_n_in[2]+traffic_n_in[3];
traffic_s_count<= traffic_s_in[0]+traffic_s_in[1]+traffic_s_in[2]+traffic_s_in[3];
traffic_e_count<= traffic_e_in[0]+traffic_e_in[1]+traffic_e_in[2]+traffic_e_in[3];
traffic_w_count<= traffic_w_in[0]+traffic_w_in[1]+traffic_w_in[2]+traffic_w_in[3];
end
end
endmodule