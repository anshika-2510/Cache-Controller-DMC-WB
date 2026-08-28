`timescale 1ns / 1ps

module cdc(input logic clk_d , 
input logic rst_d,
input logic d_in,
output logic d_out
 );
 logic d_sync1;
 
 always_ff@(posedge clk_d)
 begin
 if(rst_d)
 begin
 d_sync1<=1'b0;
 d_out<=1'b0;
 end
 else
 begin
 d_sync1<=d_in;
 d_out<=d_sync1;
 end
 end
endmodule
