`timescale 1ns / 1ps
module cache2#(
    parameter ADDR_W = 8,
    parameter DATA_W = 8,
    parameter NL  = 4,
    parameter WL = 1
)( // CPU interface
    input logic clk,
    input  logic rst,                                                  
    input logic cpu_valid,
    input  logic cpu_wr,
    input  logic [ADDR_W-1:0] cpu_addr,
    input  logic [DATA_W-1:0] cpu_wdata,
    output logic [DATA_W-1:0] cpu_rdata,
    output logic cpu_ready,
    // Memory interface
    output logic mem_valid,
    output logic  mem_wr,
    output logic [ADDR_W-1:0] mem_addr,
    output logic [DATA_W-1:0] mem_wdata,
    input  logic [DATA_W-1:0] mem_rdata,
    input  logic  mem_ready
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
    WRITE_BACK=3'b100
} state_t;
state_t state;

logic[ADDR_W-1:0] miss_addr;
logic [INDEX_W-1:0] miss_index;
logic [TAG_W-1:0]   miss_tag;
logic [DATA_W-1:0] miss_wdata;
logic miss_wr;
assign miss_index = miss_addr[INDEX_W-1:0];
assign miss_tag = miss_addr[ADDR_W-1 : INDEX_W + OFFSET_W];

always_ff @(posedge clk) begin
    if (rst)
     begin
        state     <= IDLE;
        miss_addr <= '0;
        cpu_ready <= 1'b0;
        mem_valid <= 1'b0;
        for (i = 0; i < NL; i = i + 1) begin
            valid_array[i] <= 1'b0;
            dirty_array[i] <= 1'b0;
        end
    end
    else 
    begin
        
        cpu_ready <= 1'b0;
        mem_valid <= 1'b0;
        mem_wr<=1'b0;

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
                       
                        miss_wr<=cpu_wr;
                        miss_wdata<=cpu_wdata;
                        miss_addr<=cpu_addr;
                        if(valid_array[index] && dirty_array[index])
                        state<= WRITE_BACK;
                        else
                        state<=MEM_READ;
                    end
                end
            end

            MEM_READ:
             begin
                mem_valid <= 1'b1;
                mem_addr  <= miss_addr;
                if (mem_ready)
                    state <= REFILL;
            end

            REFILL:
             begin
                tag_array[miss_index]   <= miss_tag;
                valid_array[miss_index] <= 1'b1;
                if(miss_wr)
                begin
                dirty_array[miss_index] <= 1'b1;
                data_array[miss_index]  <= miss_wdata;
                end
                else
                begin
                dirty_array[miss_index] <= 1'b0;
                data_array[miss_index]  <= mem_rdata;
                end
                state <= RESPOND;
            end

            RESPOND:
             begin
                cpu_rdata <= data_array[miss_index];
                cpu_ready <= 1'b1;
                state     <= IDLE;
            end
            
            WRITE_BACK:
             begin
           mem_valid <= 1'b1;
           mem_wr <= 1'b1;
           mem_addr  <= {tag_array[miss_index], miss_index[INDEX_W-1:0]}; // old address being evicted
           mem_wdata <= data_array[miss_index];
          if (mem_ready)
          state <= MEM_READ;
           end
        endcase
    end
end
endmodule
