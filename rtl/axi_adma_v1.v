//-----------------------------------------------------------
// Author : XiaoBai FPGA
// File   : axi_adma_v1.v的端口信号
// 说明  ：  通过AXI4总线读写DDR
//
//一套代码、一套架构搞定任意平台、任意总线的DDR读写系列
//大厂DDR设计代码、比开发板培训班教程好太多
// -----------------------------------------------------------------------------

module axi_adma_v1 #(
    parameter USER_RD_DATA_WIDTH    = 16,  //support 8bit / 16bit / 32bit / 64bit .....	
	parameter USER_WR_DATA_WIDTH    = 16,  //support 8bit / 16bit / 32bit / 64bit .....
	parameter AXI_DATA_WIDTH 		= 128, //support 64bit /128bit / 126bit
	parameter AXI_ADDR_WIDTH        = 32	
)(
	input  wire								user_wr_clk, 
	input  wire								user_rd_clk, 	 		
	input  wire								axi_clk,    
	input  wire								reset,

	input  wire								ddr_init_done,	

	input  wire								user_wr_en,
	input  wire	[USER_WR_DATA_WIDTH-1:0]	user_wr_data,
	input  wire	[AXI_ADDR_WIDTH-1 :0]		user_wr_base_addr, 
	input  wire	[AXI_ADDR_WIDTH-1 :0]		user_wr_end_addr,	
	
	input  wire								user_rd_req,      //posedge trigger
	input  wire	[AXI_ADDR_WIDTH- 1:0]		user_rd_base_addr,
	input  wire	[AXI_ADDR_WIDTH- 1:0]		user_rd_end_addr,
	output wire								user_rd_valid,
	output wire								user_rd_last,
	output wire	[USER_RD_DATA_WIDTH-1:0]	user_rd_data,
	output wire                             user_rd_req_busy,	

	output wire	[ 3:0]						m_axi_awid,   	//axi wirte address channel
	output wire	[AXI_ADDR_WIDTH -1:0]		m_axi_awaddr,
	output wire	[ 7:0]						m_axi_awlen,
	output wire	[ 2:0]						m_axi_awsize, 
	output wire	[ 1:0]						m_axi_awburst, 
	output wire								m_axi_awlock, 
	output wire	[ 3:0]						m_axi_awcache, 
	output wire	[ 2:0]						m_axi_awprot, 
	output wire	[ 3:0]						m_axi_awqos, 
	output wire								m_axi_awvalid, 
	input  wire								m_axi_awready,

	output wire	[AXI_DATA_WIDTH-1:0]		m_axi_wdata,   //axi write data channel
	output wire	[AXI_DATA_WIDTH/8-1:0]		m_axi_wstrb,
	output wire								m_axi_wvalid,
	output wire								m_axi_wlast,
	input  wire								m_axi_wready,

	input  wire	[ 3:0]						m_axi_bid,		//axi wirte response channel
	input  wire	[ 1:0]						m_axi_bresp,
	input  wire								m_axi_bvalid,
	output wire								m_axi_bready,	

	output wire   		 					m_axi_arvalid, // axi read address channel
	input  wire   		 					m_axi_arready, 
	output wire  [AXI_ADDR_WIDTH-1:0] 		m_axi_araddr,
	output wire  [ 7:0] 					m_axi_arlen,
	output wire  [ 2:0] 					m_axi_arsize,
	output wire  [ 1:0] 					m_axi_arburst, 	
	output wire  [ 3:0] 					m_axi_arid,	 
	output wire  	  	 					m_axi_arlock, 
	output wire  [ 3:0] 					m_axi_arcache, 
	output wire  [ 2:0] 					m_axi_arprot, 
	output wire  [ 3:0] 					m_axi_arqos, 

	input  wire  [ 3:0] 				    m_axi_rid,   // axi read data channel
	input  wire  [AXI_DATA_WIDTH-1:0]	    m_axi_rdata,
	input  wire  [ 1:0] 				    m_axi_resp,
	input  wire     					    m_axi_rvalid,
	input  wire  						    m_axi_rlast,
	output wire   						    m_axi_rready				
);

endmodule