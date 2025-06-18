module seqdetc(input clock,reset,input_bit,output reg output_indicator,wire [2:0]present_state);
wire [2:0]qb;
wire[2:0]d;
assign d[2]=(~present_state[2]&present_state[1]&present_state[0]&~input_bit);
assign d[1]=(~present_state[2]&~present_state[1]&present_state[0]&~input_bit)
            |(~present_state[2]&present_state[1]&~present_state[0]&input_bit);
assign d[0]=input_bit&(~present_state[2]|(present_state[2]&~present_state[1]&~present_state[0])) 
            |present_state[2]&~present_state[1]&present_state[0]&~input_bit;
dff d0(clock,reset,d[2],present_state[2],qb[2]);
dff d1(clock,reset,d[1],present_state[1],qb[1]);
dff d2(clock,reset,d[0],present_state[0],qb[0]);
always @(posedge clock)
output_indicator<=present_state[2]&~present_state[1]&~present_state[0]&input_bit;
endmodule
