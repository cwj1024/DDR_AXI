//************************************************
// Author       : Jack
// Create Date  : 2024-04-10 10:57:54
// File Name    : wr_buffer.v
// Revision     : v1.0  2024-04-10 10:57:54
// Target Device: Xilinx
// Description  : 
//************************************************

module wr_buffer #(
    parameter AXI_DATA_WIDTH    = 'd128 ,
    parameter AXI_ADDR_WIDTH    = 'd32  
)(
    input   wire                            clk             ,
    input   wire                            axi_clk         ,
    input   wire                            reset           ,

    input   wire                            wr_req_en       ,
    input   wire    [7:0]                   wr_burst_length ,
    input   wire    [AXI_ADDR_WIDTH-1:0]    wr_data_addr    ,
    input   wire    [AXI_DATA_WIDTH-1:0]    wr_data_din     ,
    input   wire                            wr_data_valid   ,
    input   wire                            wr_data_last    ,

    input   wire                            axi_aw_ready    ,
    output  reg                             axi_aw_req_en   ,
    output  reg     [7:0]                   axi_aw_burst_len,
    output  reg     [AXI_ADDR_WIDTH-1:0]    axi_aw_addr     ,

    input   wire                            axi_w_ready     ,
    output  reg     [AXI_DATA_WIDTH-1:0]    axi_w_data      ,
    output  reg                             axi_w_valid     ,
    output  reg                             axi_w_last      ,

    output  reg                             wr_data_fifo_err,
    output  reg                             wr_cmd_fifo_err 
);
/*************************parameter**************************/


/****************************reg*****************************/
reg             reset_sync_d0   ;
reg             reset_sync_d1   ;
reg             reset_sync      ;

reg             a_reset_sync_d0 ;
reg             a_reset_sync_d1 ;
reg             a_reset_sync    ;

reg     [39:0]  cmd_din         ;
reg             cmd_wren        ;

reg             data_wren       ;
reg             data_rden       ;

reg     [2:0]   cur_status      ;
reg     [2:0]   nxt_status      ;

/****************************wire****************************/
wire    [39:0]  cmd_dout        ;
wire            cmd_rden        ;
wire            cmd_wrfull      ;
wire            cmd_rdempty     ;
wire    [4:0]   cmd_wrcount     ;
wire    [4:0]   cmd_rdcount     ;

wire            data_rdempty    ;
wire            data_wrfull     ;

/********************combinational logic*********************/
assign cmd_rden = axi_aw_req_en && axi_aw_ready;

/***********************instantiation************************/


/****************************FSM*****************************/
localparam RD_IDLE      = 3'b000;
localparam RD_REQ       = 3'b001;
localparam RD_DATA_EN   = 3'b010;
localparam RD_DATA_END  = 3'b100;

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
    a_reset_sync_d0 <= reset            ;
    a_reset_sync_d1 <= a_reset_sync_d0  ;
    a_reset_sync    <= a_reset_sync_d1  ;
end

/*----------------------------------------------------------*\
        write burst length and burst addr to cmd fifo
\*----------------------------------------------------------*/
always@(posedge clk) begin
    if(wr_req_en) begin
        cmd_wren    <= 1'b1;
        cmd_din     <= {wr_burst_length, wr_data_addr};
    end else begin
        cmd_wren    <= 1'b0;
        cmd_din     <= cmd_din;
    end
end

/*----------------------------------------------------------*\
                    read data state machine
\*----------------------------------------------------------*/
always@(posedge axi_clk) begin
    if(a_reset_sync)
        cur_status <= RD_IDLE;
    else
        cur_status <= nxt_status;
end

always@(*) begin
    if(a_reset_sync)
        nxt_status <= RD_IDLE;
    else case(cur_status)
        RD_IDLE:
            if(!cmd_rdempty)
                nxt_status <= RD_REQ;
            else
                nxt_status <= cur_status;
        RD_REQ:
            if(axi_aw_req_en && axi_aw_ready)
                nxt_status <= RD_DATA_EN;
            else
                nxt_status <= cur_status;
        RD_DATA_EN:
            if(axi_w_valid && axi_w_ready && axi_w_last)
                nxt_status <= RD_DATA_END;
            else
                nxt_status <= cur_status;
        RD_DATA_END:
            nxt_status <= RD_IDLE;
        default:
            nxt_status <= RD_IDLE;
    endcase
end

/*----------------------------------------------------------*\
                            aw_req_en
\*----------------------------------------------------------*/
always@(posedge axi_clk) begin
    if(a_reset_sync)
        axi_aw_req_en <= 1'b0;
    else if(axi_aw_req_en && axi_aw_ready)
        axi_aw_req_en <= 1'b0;
    else if(cur_status == RD_REQ)
        axi_aw_req_en <= 1'b1;
end

always@(*) begin
    if(a_reset_sync) begin
        axi_aw_burst_len    <= 8'd0;
        axi_aw_addr         <= 'd0;
    end else begin
        axi_aw_burst_len    <= cmd_dout[39:32];
        axi_aw_addr         <= cmd_dout[31:0];
    end
end

fifo_w40xd16 wr_cmd_fifo (
    .rst            (reset_sync),
    .wr_clk         (clk),
    .rd_clk         (axi_clk),
    .din            (cmd_din),
    .wr_en          (cmd_wren),
    .rd_en          (cmd_rden),
    .dout           (cmd_dout),
    .full           (cmd_wrfull),
    .empty          (cmd_rdempty),
    .rd_data_count  (cmd_rdcount),
    .wr_data_count  (cmd_wrcount)
);

generate
    if(AXI_DATA_WIDTH == 'd256) begin
        reg     [287:0] data_din    ;
        wire    [287:0] data_dout   ;
        wire    [  9:0] data_wrcount;
        wire    [  9:0] data_rdcount;

        always@(posedge clk) begin
            data_wren   <= wr_data_valid;
            data_din    <= {31'h0, wr_data_last, wr_data_din};
        end

        always@(posedge axi_clk) begin
            if(axi_aw_req_en && axi_aw_ready)
                axi_w_valid <= 1'b1;
            else if(axi_w_valid && axi_w_ready && axi_w_last)
                axi_w_valid <= 1'b0;
        end

        always@(*) begin
            if(data_rden) begin
                axi_w_data  <= data_dout[255:0];
                axi_w_last  <= data_dout[256];
            end else begin
                axi_w_data  <= 'd0;
                axi_w_last  <= 1'b0;
            end
        end

        always@(*) begin
            data_rden <= (cur_status == RD_DATA_EN) && axi_w_valid && axi_w_ready;
        end

        fifo_w288xd512 data_fifo (
            .rst            (reset_sync),
            .wr_clk         (clk),
            .rd_clk         (axi_clk),
            .din            (data_din),
            .wr_en          (data_wren),
            .rd_en          (data_rden),
            .dout           (data_dout),
            .full           (data_wrfull),
            .empty          (data_rdempty),
            .rd_data_count  (data_rdcount),
            .wr_data_count  (data_wrcount)
        );
    end else if(AXI_DATA_WIDTH == 'd128) begin
        reg     [143:0] data_din    ;
        wire    [143:0] data_dout   ;
        wire    [  9:0] data_wrcount;
        wire    [  9:0] data_rdcount;

        always@(posedge clk) begin
            data_wren   <= wr_data_valid;
            data_din    <= {15'h0, wr_data_last, wr_data_din};
        end

        always@(posedge axi_clk) begin
            if(axi_aw_req_en && axi_aw_ready)
                axi_w_valid <= 1'b1;
            else if(axi_w_valid && axi_w_ready && axi_w_last)
                axi_w_valid <= 1'b0;
        end

        always@(*) begin
            if(data_rden) begin
                axi_w_data  <= data_dout[127:0];
                axi_w_last  <= data_dout[128];
            end else begin
                axi_w_data  <= 'd0;
                axi_w_last  <= 1'b0;
            end
        end

        always@(*) begin
            data_rden <= (cur_status == RD_DATA_EN) && axi_w_valid && axi_w_ready;
        end

        fifo_w144xd512 data_fifo (
            .rst            (reset_sync),
            .wr_clk         (clk),
            .rd_clk         (axi_clk),
            .din            (data_din),
            .wr_en          (data_wren),
            .rd_en          (data_rden),
            .dout           (data_dout),
            .full           (data_wrfull),
            .empty          (data_rdempty),
            .rd_data_count  (data_rdcount),
            .wr_data_count  (data_wrcount)
        );
    end else if(AXI_DATA_WIDTH == 'd64) begin
        reg     [71:0] data_din    ;
        wire    [71:0] data_dout   ;
        wire    [  9:0] data_wrcount;
        wire    [  9:0] data_rdcount;

        always@(posedge clk) begin
            data_wren   <= wr_data_valid;
            data_din    <= {7'h0, wr_data_last, wr_data_din};
        end

        always@(posedge axi_clk) begin
            if(axi_aw_req_en && axi_aw_ready)
                axi_w_valid <= 1'b1;
            else if(axi_w_valid && axi_w_ready && axi_w_last)
                axi_w_valid <= 1'b0;
        end

        always@(*) begin
            if(data_rden) begin
                axi_w_data  <= data_dout[63:0];
                axi_w_last  <= data_dout[64];
            end else begin
                axi_w_data  <= 'd0;
                axi_w_last  <= 1'b0;
            end
        end

        always@(*) begin
            data_rden <= (cur_status == RD_DATA_EN) && axi_w_valid && axi_w_ready;
        end

        fifo_w72xd512 data_fifo (
            .rst            (reset_sync),
            .wr_clk         (clk),
            .rd_clk         (axi_clk),
            .din            (data_din),
            .wr_en          (data_wren),
            .rd_en          (data_rden),
            .dout           (data_dout),
            .full           (data_wrfull),
            .empty          (data_rdempty),
            .rd_data_count  (data_rdcount),
            .wr_data_count  (data_wrcount)
        );
    end
endgenerate

always@(posedge clk) begin
    if(reset_sync)
        wr_data_fifo_err <= 1'b0;
    else if(data_wren && data_wrfull)
        wr_data_fifo_err <= 1'b1;
end

always@(posedge clk) begin
    if(reset_sync)
        wr_cmd_fifo_err <= 1'b0;
    else if(cmd_wren && cmd_wrfull)
        wr_cmd_fifo_err <= 1'b1;
end

endmodule