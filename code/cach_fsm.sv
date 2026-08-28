`timescale 1ns / 1ps
module cache_cdc #(
    parameter ADDR_W = 8,
    parameter DATA_W = 8,
    parameter NL  = 4,
    parameter WL = 1
)(
    input logic clk_cpu,
    input  logic rst_cpu,                                                  // CPU interface
    input logic cpu_valid,
    input  logic cpu_wr,
    input  logic [ADDR_W-1:0] cpu_addr,
    input  logic [DATA_W-1:0] cpu_wdata,
    output logic [DATA_W-1:0] cpu_rdata,
    output logic cpu_ready,
    
    output logic start,
    input logic done, 
    input logic [DATA_W-1:0] rdata_out,
    output logic [ADDR_W-1:0] miss_addr,
   output logic miss_wr,
   output logic [DATA_W-1:0] miss_wdata
);
    // Address widths
    localparam INDEX_W = $clog2(NL);
    localparam OFFSET_W = $clog2(WL);
    localparam TAG_W = ADDR_W - INDEX_W - OFFSET_W;
    // Cache storage
    logic [DATA_W-1:0] data_array [0:NL-1];
    logic [TAG_W-1:0]  tag_array  [0:NL-1];
    logic valid_array[0:NL-1];
    logic dirty_array[0:NL-1];
    
    logic [INDEX_W-1:0] index;
    assign index=cpu_addr [INDEX_W-1:0];
    
    logic[TAG_W-1:0] tag;
    assign tag =cpu_addr [ADDR_W-1:INDEX_W + OFFSET_W];
    
    logic hit;
    assign hit = valid_array[index] && (tag_array[index] == tag);
    
integer i;
typedef enum logic [2:0] {
    IDLE=3'b000,
    MEM_READ=3'b001,
    REFILL=3'b010,
    RESPOND=3'b011,
    WRITE_BACK=3'b100,
    MEM_START =3'b101,
    WRITE_BACK_START=3'b110
} state_t;
state_t state;


logic [INDEX_W-1:0] miss_index;
logic [TAG_W-1:0]   miss_tag;

assign miss_index = miss_addr[INDEX_W-1:0];
assign miss_tag = miss_addr[ADDR_W-1 : INDEX_W + OFFSET_W];

logic[ADDR_W-1:0] org_addr;
logic [INDEX_W-1:0] org_index;
logic [TAG_W-1:0]   org_tag;
logic [DATA_W-1:0] org_wdata;
logic org_wr;
assign org_index = org_addr[INDEX_W-1:0];
assign org_tag = org_addr[ADDR_W-1 : INDEX_W + OFFSET_W];


always_ff @(posedge clk_cpu) begin
    if (rst_cpu)
     begin
        state     <= IDLE;
        miss_addr <= 0;
        cpu_ready <= 1'b0;
        start <=1'b0;
        miss_wr<=1'b0;
        org_addr <=1'b0;
        org_wr<=1'b0;
        for (i = 0; i < NL; i = i + 1) begin
            valid_array[i] <= 1'b0;
            dirty_array[i] <= 1'b0;
        end
    end
    else 
    begin
        
        cpu_ready <= 1'b0;
        

        case (state)
            IDLE:
             begin
                if (cpu_valid)
                 begin
                    if (hit) 
                    begin
                        if (!cpu_wr)  //readhit
                        begin
                            cpu_rdata <= data_array[index];
                            cpu_ready <= 1'b1;
                        end
                         else 
                         begin //writehit
                            data_array[index]  <= cpu_wdata;
                            dirty_array[index] <= 1'b1;
                            cpu_ready <= 1'b1;
                        end
                    end 
                    else 
                    begin
                       
                        org_wr<=cpu_wr;
                        org_wdata<=cpu_wdata;
                        org_addr<=cpu_addr;
                        if(valid_array[index] && dirty_array[index])
                        state<= WRITE_BACK_START;
                        else
                        state<=MEM_START;
                    end
                end
            end
          MEM_START:
          begin
          start<=1'b1;
          state<=MEM_READ;
         
          end
            MEM_READ:
             begin
             start<=0;
               miss_wr<=org_wr;
                miss_wdata<=org_wdata;
                miss_addr<=org_addr;
                if(done)
                 state <= REFILL;
                end
           
            WRITE_BACK_START:
            begin
            start<=1'b1;
            state<=WRITE_BACK;
            end
            WRITE_BACK:
             begin
             start<=0;
               miss_wr<=1'b1;
               miss_wdata<=data_array[org_index];
               miss_addr<={tag_array[org_index], org_index[INDEX_W-1:0]};
               if(done)
               state<=MEM_START;//memread
               
           end
                REFILL:
                 begin
                    tag_array[org_index]   <= org_tag;
                    valid_array[org_index] <= 1'b1;
                    if(org_wr)
                    begin
                    dirty_array[org_index] <= 1'b1;
                    data_array[org_index]  <= org_wdata;
                    end
                    else
                    begin
                    dirty_array[org_index] <= 1'b0;
                    data_array[org_index]  <= rdata_out;
                    end
                    state <= RESPOND;
                end

            RESPOND:
             begin
                cpu_rdata <= data_array[org_index];
                cpu_ready <= 1'b1;
                state     <= IDLE;
            end
        endcase
    end
end
endmodule
