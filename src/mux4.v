module mux4(
             input d0,d1,d2,d3,
             input [1:0]s,
             output mux4_out 
            );
           assign mux4_out = s[1] ? (s[0]?d3:d2)
                                  : (s[0]?d1:d0);
endmodule