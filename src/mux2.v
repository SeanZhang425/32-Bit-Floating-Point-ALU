module mux2(
            input d0, d1,
            input s,
            output mux2_out
            );
        
       assign mux2_out = s ? d1 : d0;
endmodule