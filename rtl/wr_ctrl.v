//************************************************
// Author       : Jack
// Create Date  : 2024-04-09 21:57:11
// File Name    : wr_ctrl.v
// Revision     : v1.0  2024-04-09 21:57:11
// Target Device: Xilinx
// Description  : 
//************************************************

module wr_ctrl #(
    parameter USER_WR_DATA_WIDTH    = 'd16  ,
    parameter AXI_DATA_WIDTH        = 'd128 ,
    parameter AXI_ADDR_WIDTH        = 'd32  ,
    parameter WR_BURST_LENGTH       = 'd4096
)(
    input   wire                                clk                 ,
    input   wire                                reset               ,

    input   wire                                ddr_init_done       ,

    input   wire                                user_wr_en          ,
    input   wire    [USER_WR_DATA_WIDTH-1:0]    user_wr_data        ,
    input   wire    [AXI_ADDR_WIDTH-1:0]        user_wr_base_addr   ,
    input   wire    [AXI_ADDR_WIDTH-1:0]        user_wr_end_addr    ,

    output  reg                                 wr_req_en           ,
    output  wire    [7:0]                       wr_burst_length     ,
    output  reg     [AXI_ADDR_WIDTH-1:0]        wr_data_addr        ,
    output  reg     [AXI_DATA_WIDTH-1:0]        wr_data_out         , // AXI端数据，为128bit
    output  reg                                 wr_data_valid       ,
    output  reg                                 wr_data_last         
);
/*************************parameter**************************/
localparam WR_CNT_MAX       = AXI_DATA_WIDTH / USER_WR_DATA_WIDTH - 'd1;
localparam MAX_BURST_LENGTH = WR_BURST_LENGTH / (AXI_DATA_WIDTH / 8) - 'd1;

/****************************reg*****************************/
reg                                 reset_sync_d0   ;
reg                                 reset_sync_d1   ;
reg                                 reset_sync      ;

reg                                 ddr_init_done_d0;
reg                                 ddr_wr_enable   ;

reg                                 user_wr_en_d    ;
reg     [USER_WR_DATA_WIDTH-1:0]    user_wr_data_d  ;

reg     [7:0]                       wr_cnt          ;
reg     [7:0]                       wr_burst_len    ;

/****************************wire****************************/


/********************combinational logic*********************/
assign wr_burst_length = MAX_BURST_LENGTH;

/***********************instantiation************************/


/****************************FSM*****************************/


/**************************process***************************/
/*----------------------------------------------------------*\
                          CDC process
\*----------------------------------------------------------*/
always@(posedge clk) begin
    reset_sync_d0   <= reset            ;
    reset_sync_d1   <= reset_sync_d0    ;
    reset_sync      <= reset_sync_d1    ;
end

always@(posedge clk) begin
    ddr_init_done_d0    <= ddr_init_done    ;
    ddr_wr_enable       <= ddr_init_done_d0 ;
end

/*----------------------------------------------------------*\
                    user data to axi data
\*----------------------------------------------------------*/
always@(posedge clk) begin
    if(ddr_wr_enable) begin
        user_wr_en_d    <= user_wr_en   ;
        user_wr_data_d  <= user_wr_data ;
    end else begin
        user_wr_en_d    <= 1'b0;
        user_wr_data_d  <= 'd0;
    end
end

always@(posedge clk) begin
    if(reset_sync) begin
        wr_cnt          <= 'd0;
        wr_burst_len    <= 'd0;
    end else if(user_wr_en_d) begin
        if(wr_cnt == WR_CNT_MAX) begin
            wr_cnt          <= 'd0;
            wr_burst_len    <= (wr_burst_len == MAX_BURST_LENGTH) ? 'd0 : wr_burst_len + 1'b1;
        end else begin
            wr_cnt          <= wr_cnt + 1'b1;
            wr_burst_len    <= wr_burst_len;
        end
    end
end

always@(posedge clk) begin
    if(wr_cnt == WR_CNT_MAX)
        wr_data_valid <= 1'b1;
    else
        wr_data_valid <= 1'b0;
end

always@(posedge clk) begin
    if((wr_cnt == WR_CNT_MAX) && (wr_burst_len == MAX_BURST_LENGTH))
        wr_data_last <= 1'b1;
    else
        wr_data_last <= 1'b0;
end

always@(posedge clk) begin
    if(user_wr_en_d)
        wr_data_out <= {user_wr_data_d, wr_data_out[AXI_DATA_WIDTH-1:USER_WR_DATA_WIDTH]};
    else
        wr_data_out <= wr_data_out;
end

/*----------------------------------------------------------*\
                        write burst req
\*----------------------------------------------------------*/
always@(posedge clk) begin
    if((wr_cnt == WR_CNT_MAX) && (wr_burst_len == MAX_BURST_LENGTH))
        wr_req_en <= 1'b1;
    else
        wr_req_en <= 1'b0;
end

always@(posedge clk) begin
    if(reset_sync)
        wr_data_addr <= user_wr_base_addr;
    else if(wr_req_en && (wr_data_addr >= user_wr_end_addr - WR_BURST_LENGTH))
        wr_data_addr <= user_wr_base_addr;
    else if(wr_req_en)
        wr_data_addr <= wr_data_addr + WR_BURST_LENGTH;
end

endmodule