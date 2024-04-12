//************************************************
// Author       : Jack
// Create Date  : 2024-04-10 16:14:38
// File Name    : axi_wr_master.v
// Revision     : v1.0  2024-04-10 16:14:38
// Target Device: Xilinx
// Description  : 
//************************************************

module axi_wr_master #(
    parameter AXI_DATA_WIDTH    = 'd128 ,
    parameter AXI_ADDR_WIDTH    = 'd32   
)(
    input                                   axi_clk         ,
    input                                   reset           ,

    output  reg     [3:0]                   m_axi_awid      ,
    output  reg     [AXI_ADDR_WIDTH-1:0]    m_axi_awaddr    ,
    output  reg     [7:0]                   m_axi_awlen     ,
    output  reg     [2:0]                   m_axi_awsize    ,
    output  reg     [1:0]                   m_axi_awburst   ,
    output  reg                             m_axi_awlock    ,
    output  reg     [3:0]                   m_axi_awcache   ,
    output  reg     [2:0]                   m_axi_awprot    ,
    output  reg     [3:0]                   m_axi_awqos     ,
    output  reg                             m_axi_awvalid   ,
    input   wire                            m_axi_awready   ,

    output  reg     [AXI_DATA_WIDTH-1:0]    m_axi_wdata     ,
    output  reg     [AXI_DATA_WIDTH/8-1:0]  m_axi_wstrb     ,
    output  reg                             m_axi_wvalid    ,
    output  reg                             m_axi_wlast     ,
    input   wire                            m_axi_wready    ,

    input   wire    [3:0]                   m_axi_bid       ,
    input   wire    [1:0]                   m_axi_bresp     ,
    input   wire                            m_axi_bvalid    ,
    output  wire                            m_axi_bready    ,

    output  reg                             axi_aw_ready    ,
    input   wire                            axi_aw_req_en   ,
    input   wire    [7:0]                   axi_aw_burst_len,
    input   wire    [AXI_ADDR_WIDTH-1:0]    axi_aw_addr     ,

    output  reg                             axi_w_ready     ,
    input   wire    [AXI_DATA_WIDTH-1:0]    axi_w_data      ,
    input   wire                            axi_w_valid     ,
    input   wire                            axi_w_last       
);
/*************************parameter**************************/
localparam AXI_IDLE     = 4'b0000;
localparam AXI_WR_PRE   = 4'b0001;
localparam AXI_WR_DATA  = 4'b0010;
localparam AXI_WR_END   = 4'b0100;

/****************************reg*****************************/
reg             a_reset_sync_d0 ;
reg             a_reset_sync_d1 ;
reg             a_reset_sync    ;

reg     [3:0]   axi_cur_status  ;
reg     [3:0]   axi_nxt_status  ;

/****************************wire****************************/


/********************combinational logic*********************/


/***********************instantiation************************/


/****************************FSM*****************************/


/**************************process***************************/
always@(posedge clk) begin
    a_reset_sync_d0 <= reset            ;
    a_reset_sync_d1 <= a_reset_sync_d0  ;
    a_reset_sync    <= a_reset_sync_d1  ;
end

always@(posedge axi_clk) begin
    m_axi_awid      <= 4'h0;
    m_axi_awburst   <= 2'b01; // incrementing burst
    m_axi_awlock    <= 1'b0;
    m_axi_awcache   <= 4'h0;
    m_axi_awprot    <= 3'h0;
    m_axi_awqos     <= 4'h0;
    m_axi_wstrb     <= {AXI_DATA_WIDTH/8{1'b1}};

    m_axi_awsize    <= AXI_DATA_WIDTH == 'd512 ? 3'd6 :
                       AXI_DATA_WIDTH == 'd256 ? 3'd5 :
                       AXI_DATA_WIDTH == 'd128 ? 3'd4 :
                       AXI_DATA_WIDTH == 'd64  ? 3'd3 :
                       AXI_DATA_WIDTH == 'd32  ? 3'd2 : 3'd0;
end


/*----------------------------------------------------------*\
                        AXI state machine
\*----------------------------------------------------------*/
always@(posedge axi_clk) begin
    if(a_reset_sync)
        axi_cur_status <= AXI_IDLE;
    else
        axi_cur_status <= axi_nxt_status;
end

always@(*) begin
    if(a_reset_sync)
        axi_nxt_status <= AXI_IDLE;
    else case(axi_cur_status)
        AXI_IDLE:
            if(axi_aw_req_en)
                axi_nxt_status <= AXI_WR_PRE;
            else
                axi_nxt_status <= AXI_IDLE;
        AXI_WR_PRE:
            axi_nxt_status <= AXI_WR_DATA;
        AXI_WR_DATA:
            if(m_axi_wvalid && m_axi_wready && m_axi_wlast)
                axi_nxt_status <= AXI_WR_END;
            else
                axi_nxt_status <= AXI_WR_DATA;
        AXI_WR_END:
            axi_nxt_status <= AXI_IDLE;
        default:
            axi_nxt_status <= AXI_IDLE;
    endcase
end

/*----------------------------------------------------------*\
                          ready signals
\*----------------------------------------------------------*/
always@(*) begin
    axi_aw_ready    <= axi_cur_status == AXI_WR_PRE;
    axi_w_ready     <= m_axi_wready;
end

/*----------------------------------------------------------*\
      axi write data channel and write address channel
\*----------------------------------------------------------*/
always@(posedge axi_clk) begin
    if(a_reset_sync)
        m_axi_awvalid <= 1'b0;
    else if(m_axi_awvalid && m_axi_awready)
        m_axi_awvalid <= 1'b0;
    else if(axi_aw_ready && axi_aw_req_en)
        m_axi_awvalid <= 1'b1;
end

always@(posedge axi_clk) begin
    if(axi_aw_ready && axi_aw_req_en) begin
        m_axi_awaddr    <= axi_aw_addr;
        m_axi_awlen     <= axi_aw_burst_len;
    end
end

always@(posedge axi_clk) begin
    if(a_reset_sync)
        m_axi_wvalid <= 1'b0;
    else if(m_axi_wvalid && m_axi_wready && m_axi_wlast)
        m_axi_wvalid <= 1'b0;
    else if(axi_w_valid && axi_w_ready)
        m_axi_wvalid <= 1'b1;
end

always@(posedge axi_clk) begin
    if(a_reset_sync)
        m_axi_wlast <= 1'b0;
    else if(m_axi_wvalid && m_axi_wready && m_axi_wlast)
        m_axi_wlast <= 1'b0;
    else if(axi_w_valid && axi_w_ready && axi_w_last)
        m_axi_wlast <= 1'b1;
end

always@(posedge axi_clk) begin
    if(axi_w_valid && axi_w_ready)
        m_axi_wdata <= axi_w_data;
    else
        m_axi_wdata <= m_axi_wdata;
end

endmodule