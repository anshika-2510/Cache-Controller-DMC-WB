`timescale 1ns / 1ps
module handshake_fsm(
 input logic clk_cpu,
input logic rst_cpu,
input logic start,
output logic done,
input logic ack_sync,
output logic req
 );
    
    typedef enum logic [1:0]{
    IDLE=2'b00,
    REQ_A=2'b01,
    REQ_D=2'b10
    }state_t;
    state_t state;
    
    always_ff @(posedge clk_cpu)
    begin
    if(rst_cpu)
    begin
    done<=0;
    req<=0;
    state<=IDLE;
    end
    else
    begin

      case(state)
      IDLE:
      begin
      req<=0;
      done<=0;
      if(start)
      begin
      req<=1'b1;
      state<=REQ_A;
     end
     end
     
     REQ_A:
     begin
     if(ack_sync == 1'b1)
     begin
     req<=1'b0;
     state<=REQ_D;
     end
     end
     
     REQ_D:
     begin
     if(ack_sync == 1'b0)
     begin
     req<=1'b0;
     done<=1'b1;
     state<=IDLE;
     end
     end
     default: state <= IDLE;
     endcase
     end 
     end
     endmodule
     
     

