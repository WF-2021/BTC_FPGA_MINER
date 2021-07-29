//	********************************************************************************
//	模块名：uart_ctrl
//	功  能：控制串口接收、发送数据
//			1. 接收数据，并处理强制开始挖矿和装填默克尔根任务
//			2. 发送数据，将挖矿结果和新默克尔根请求发送
//	资	源：
//	********************************************************************************
module uart_ctrl # (
	
	//	输入参数
	parameter		IS_SIM				= "TRUE"				,	//	是否为仿真测试，"TRUE" "FALSE"
	parameter		BAUD_RATE			= "115200"				,	//	波特率，"9600" "115200"
	parameter		MINING_DATA_WID		= 608					,	//	挖矿数据位宽，608
	parameter		DATA_WID			= 32					,	//	WORD位宽，32
	parameter		TARGET_WID			= 256					,	//	挖矿目标位宽，256
	parameter		UART_DATA_WID		= 8						,	//	串口数据位宽，8
	parameter		IS_BRAM_FIFO		= "TRUE"					//	是否使用BRAM资源例化挖矿参数FIFO，"TRUE" "FALSE"
	)                                                       	
	(                                                       	
	                                                        	
	//	时钟复位信号                                        	
	input								clk						,	//	模块工作时钟信号
	input								rst						,	//	clk时钟域，复位
	                                                        	
	//	串口信号                                            	
	input								i_uart_rx				,	//	异步时钟域，串口接收线
	output								o_uart_tx				,	//	clk时钟域，串口发送线

//	input	[UART_DATA_WID		-1:0]	iv_rx_data				,	//	clk时钟域，串口接收数据
//	input								i_rx_data_vld			,	//	clk时钟域，串口接收数据有效	
//	input								i_rx_busy				,	//	clk时钟域，串口接收忙碌
//	output	[UART_DATA_WID		-1:0]	ov_tx_data				,	//	clk时钟域，串口发送数据
//	output								o_tx_data_vld			,	//	clk时钟域，串口发送数据有效
//	input								i_tx_done				,	//	clk时钟域，串口发送完成
	
	//	挖矿信号
	input	[DATA_WID			-1:0]	iv_mining_extranounce2	,	//	clk时钟域，输出挖矿空间extranounce2
	input	[DATA_WID			-1:0]	iv_mining_nounce		,	//	clk时钟域，输出挖矿nounce
	input								i_mining_nounce_vld		,	//	clk时钟域，输出挖矿nounce有效
	input								i_mining_nounce_full	,	//	clk时钟域，输出挖矿空间nounce已满
	output								o_mining_en				,	//	clk时钟域，输入挖矿使能
	output	[MINING_DATA_WID	-1:0]	ov_mining_data			,	//	clk时钟域，输入挖矿数据
	output	[TARGET_WID			-1:0]	ov_mining_target		,	//	clk时钟域，输入挖矿目标
	output	[DATA_WID			-1:0]	ov_mining_extranounce2		//	clk时钟域，输入挖矿空间extranounce2
	);
	
	
	//  ===============================================================================================
	//	参数、信号、函数说明
	//  ===============================================================================================
	//  -------------------------------------------------------------------------------------
	//	函数说明
	//  -------------------------------------------------------------------------------------
	//	-----------------------------------------------------------------
	//	求数据位宽
	//	例如16的位宽是4，log2(16)=4
	//	-----------------------------------------------------------------
	function integer log2;
		
		//	输入信号
		input	integer	data;
		
		//	参数声明 
		integer data_tmp;
		
		//	运算过程  
		begin
			data_tmp = data - 1;
			for (log2=0; data_tmp>0; log2=log2+1) begin
				data_tmp = data_tmp >> 1;
			end
		end
	endfunction
	
	//  -------------------------------------------------------------------------------------
	//	参数说明
	//  -------------------------------------------------------------------------------------
	localparam	RX_DATA_CNT_NUM 	= (UART_DATA_WID + MINING_DATA_WID + DATA_WID + TARGET_WID) / UART_DATA_WID	;	//	串口接收数据计数器计数个数，8bit命令 + 608bit挖矿数据 + 32bitExtraNounce2 + 8bit挖矿目标
	localparam	RX_DATA_CNT_WID 	= log2(RX_DATA_CNT_NUM)														;	//	串口接收数据计数器位宽
	localparam	MINING_PARAM_WID	= MINING_DATA_WID + DATA_WID + TARGET_WID									;	//	挖矿参数位宽	
	localparam	MINING_CTRL_RESTART	= 8'h01																		;	//	挖矿控制命令，重新开始
	localparam	MINING_CTRL_MERKLE	= 8'h02																		;	//	挖矿控制命令，默克尔根
	localparam	TX_DATA_CNT_NUM		= (2 * DATA_WID + UART_DATA_WID) / UART_DATA_WID + 1						;	//	串口发送数据计数器计数个数，8bit命令 + 32bitNounce + 32bitExtraNounce2
	localparam	TX_DATA_CNT_WID		= log2(TX_DATA_CNT_NUM)														;	//	串口发送数据计数器位宽
	localparam	RESTART_DLY_NUM		= 5																			;	//	挖矿强制重新开始扩展5拍
	
	//  -------------------------------------------------------------------------------------
	//	信号说明
	//  -------------------------------------------------------------------------------------
	//	辅助信号	
	reg									tx_busy_dly				= 1'b0	;	//	clk时钟域，串口发送忙碌，打1拍	
	reg		[RESTART_DLY_NUM	-1:0]	mining_restart_dly		= 'b0	;	//	clk时钟域，挖矿强制重新开始，打5拍
	reg									nounce_fifo_rd_en_dly	= 1'b0	;	//	clk时钟域，挖矿参数FIFO读使能，打1拍
	wire								tx_busy_rise					;	//	clk时钟域，串口发送忙碌，上升沿
	
	//	串口信号
	wire	[UART_DATA_WID		-1:0]	rx_data							;	//	clk时钟域，串口接收数据
	wire								rx_data_vld						;	//	clk时钟域，串口接收数据有效
	wire								rx_busy							;	//	clk时钟域，串口接收忙碌
	reg		[UART_DATA_WID		-1:0]	tx_data							;	//	clk时钟域，串口发送数据
	wire								tx_data_vld						;	//	clk时钟域，串口发送数据有效
	wire								tx_done							;	//	clk时钟域，串口发送完成
	
	//	串口接收数据处理信号
	reg		[RX_DATA_CNT_WID	-1:0]	rx_data_cnt				= 'b0	;	//	clk时钟域，串口接收数据计数
	reg		[UART_DATA_WID		-1:0]	mining_ctrl				= 'b0	;	//	clk时钟域，挖矿控制
	reg		[MINING_PARAM_WID	-1:0]	mining_param			= 'b0	;	//	clk时钟域，挖矿参数
	reg									mining_restart			= 1'b0	;	//	clk时钟域，挖矿强制重新开始
	
	wire								mining_restart_extend			;	//	clk时钟域，挖矿强制重新开始扩展
	reg									param_fifo_wr_en		= 1'b0	;	//	clk时钟域，挖矿参数FIFO写使能
	wire	[MINING_PARAM_WID	-1:0]	param_fifo_wr_data				;	//	clk时钟域，挖矿参数FIFO写数据
	wire								param_fifo_rd_en				;	//	clk时钟域，挖矿参数FIFO读使能
	wire	[MINING_PARAM_WID	-1:0]	param_fifo_rd_data				;	//	clk时钟域，挖矿参数FIFO读数据
	wire								param_fifo_rst					;	//	clk时钟域，挖矿参数FIFO复位
	wire								param_fifo_empty				;	//	clk时钟域，挖矿参数FIFO空
	
	//	串口发送数据处理信号
	wire										nounce_fifo_wr_en			;	//	clk时钟域，挖矿结果FIFO写使能
	wire	[(2*DATA_WID+UART_DATA_WID)	-1:0]	nounce_fifo_wr_data			;	//	clk时钟域，挖矿结果FIFO写数据
	wire										nounce_fifo_rd_en			;	//	clk时钟域，挖矿结果FIFO读使能
	wire	[(2*DATA_WID+UART_DATA_WID)	-1:0]	nounce_fifo_rd_data			;	//	clk时钟域，挖矿结果FIFO读数据
	wire										nounce_fifo_empty			;	//	clk时钟域，挖矿结果FIFO空
	wire										nounce_fifo_rst				;	//	clk时钟域，挖矿结果FIFO复位
	reg											tx_busy				= 1'b0	;	//	clk时钟域，串口发送忙碌
	reg		[TX_DATA_CNT_WID			-1:0]	tx_data_cnt			= 'b0	;	//	clk时钟域，串口发送数据计数
		
		
	//  ===============================================================================================
	//	辅助信号
	//  ===============================================================================================	
	//  -------------------------------------------------------------------------------------
	//	信号打拍
	//  -------------------------------------------------------------------------------------
	always @ (posedge clk) begin
		tx_busy_dly <= tx_busy;
		mining_restart_dly <= {mining_restart_dly, mining_restart};
		nounce_fifo_rd_en_dly <= nounce_fifo_rd_en;
	end
	
	//  -------------------------------------------------------------------------------------
	//	信号上升、下降沿
	//  -------------------------------------------------------------------------------------
	assign tx_busy_rise = ((tx_busy == 1'b1) && (tx_busy_dly == 1'b0)) ? 1'b1 : 1'b0;
	
	
	//  ===============================================================================================
	//	串口模块例化
	//  ===============================================================================================	
	//  -------------------------------------------------------------------------------------
	//	串口接收模块例化
	//  -------------------------------------------------------------------------------------
	uart_rx # (
		.IS_SIM				(IS_SIM				),	//	是否为仿真测试，"TRUE" "FALSE"
		.BAUD_RATE			(BAUD_RATE			),	//	波特率，"9600" "115200"
		.UART_DATA_WID		(UART_DATA_WID		),	//	串口数据位宽，8
		.UART_RX_DATA_NUM	(RX_DATA_CNT_NUM	)	//	串口接收数据总个数，82
	)                                                       	
	uart_rx_inst (                                                       	
		.clk				(clk				),	//	模块工作时钟信号
		.rst				(rst				),	//	clk时钟域，复位
		.i_rx				(i_uart_rx			),	//	clk时钟域，串口接收线
		.ov_rx_data			(rx_data			),	//	clk时钟域，串口接收数据
		.o_rx_data_vld		(rx_data_vld		),	//	clk时钟域，串口接收数据有效	
		.o_rx_busy			(rx_busy			)	//	clk时钟域，串口接收忙碌
	);
	
	//  -------------------------------------------------------------------------------------
	//	串口发送模块例化
	//  -------------------------------------------------------------------------------------
	uart_tx # (
		.IS_SIM				(IS_SIM			),	//	是否为仿真测试，"TRUE" "FALSE"
		.BAUD_RATE			(BAUD_RATE		),	//	波特率，"9600" "115200"
		.UART_DATA_WID		(UART_DATA_WID	)	//	串口数据位宽，8
	)                                                       	
	uart_tx_inst (                                                       	
		.clk				(clk			),	//	模块工作时钟信号
		.rst				(rst			),	//	clk时钟域，复位
		.iv_tx_data			(tx_data		),	//	clk时钟域，串口发送数据
		.i_tx_data_vld		(tx_data_vld	),	//	clk时钟域，串口发送数据有效
		.o_tx				(o_uart_tx		),	//	clk时钟域，串口发送线
		.o_tx_done			(tx_done		)	//	clk时钟域，串口发送完成
	);
	
	
	//  ===============================================================================================
	//	串口接收数据处理
	//  ===============================================================================================	
	//  -------------------------------------------------------------------------------------
	//	串口接收数据计数
	//  -------------------------------------------------------------------------------------
	always @ (posedge clk) begin
		
		//	复位
		if(rst) begin
			rx_data_cnt	<= 'b0;
		end
		
		//	接收到有效的串口数据，则计算
		else if(rx_data_vld) begin
			
			//	计数到最大值，则清理
			if(rx_data_cnt >= (RX_DATA_CNT_NUM - 1'b1)) begin
				rx_data_cnt	<= 'b0;
			end
			
			//	否则，累加一
			else begin
				rx_data_cnt	<= rx_data_cnt + 1'b1;
			end
		end
	end
	
	//  -------------------------------------------------------------------------------------
	//	挖矿控制
	//  -------------------------------------------------------------------------------------
	always @ (posedge clk) begin
		
		//	复位
		if(rst) begin
			mining_ctrl	<= 'b0;
		end
		
		//	一次完整传输中，串口接收的第1个数据为挖矿控制数据
		else if((rx_data_vld == 1'b1) && (rx_data_cnt == 'b0)) begin
			mining_ctrl	<= rx_data;
		end
	end
	
	//  -------------------------------------------------------------------------------------
	//	挖矿参数
	//	目前设置为大端传输，即先传入的时高位的数据
	//  -------------------------------------------------------------------------------------
	always @ (posedge clk) begin
		
		//	复位
		if(rst) begin
			mining_param <= 'b0;
		end
		
		//	一次完整传输中，除了串口接收的第1个数据，其余的为挖矿参数
		else if((rx_data_vld == 1'b1) && (rx_data_cnt != 'b0)) begin
			mining_param <= {mining_param, rx_data};
		end
	end
	
	//  -------------------------------------------------------------------------------------
	//	挖矿重新开始
	//  -------------------------------------------------------------------------------------
	always @ (posedge clk) begin
		
		//	复位
		if(rst) begin
			mining_restart <= 1'b0;
		end
		
		//	根据挖矿控制，如果传入的挖矿参数为强制重新开始挖矿，且完成一次完整传输，则存入FIFO
		else if((mining_ctrl == MINING_CTRL_RESTART) && ((rx_data_vld == 1'b1) && (rx_data_cnt >= (RX_DATA_CNT_NUM - 1'b1)))) begin
			mining_restart <= 1'b1;
		end
		
		//	仅置高一个时钟周期
		else begin
			mining_restart <= 1'b0;
		end
	end
	
	//  -------------------------------------------------------------------------------------
	//	挖矿参数FIFO写使能
	//  -------------------------------------------------------------------------------------
	always @ (posedge clk) begin
		
		//	复位
		if(rst) begin
			param_fifo_wr_en <= 1'b0;
		end
		
		//	根据挖矿控制，如果传入的挖矿参数为新的默克尔根，且完成一次完整传输，则存入FIFO
		else if((mining_ctrl == MINING_CTRL_MERKLE) && ((rx_data_vld == 1'b1) && (rx_data_cnt >= (RX_DATA_CNT_NUM - 1'b1)))) begin
			param_fifo_wr_en <= 1'b1;
		end
		
		//	仅置高一个时钟周期
		else begin
			param_fifo_wr_en <= 1'b0;
		end
	end
	
	//  -------------------------------------------------------------------------------------
	//	挖矿参数FIFO写数据
	//	与挖矿参数一致
	//  -------------------------------------------------------------------------------------
	assign param_fifo_wr_data = mining_param;
	
	//  -------------------------------------------------------------------------------------
	//	挖矿参数FIFO读使能
	//	在挖矿参数FIFO非空，且挖矿空间已满时，读取新的挖矿参数
	//  -------------------------------------------------------------------------------------
	assign param_fifo_rd_en = ((param_fifo_empty == 1'b0) && (i_mining_nounce_full == 1'b1)) ? 1'b1 : 1'b0;
	
	//  -------------------------------------------------------------------------------------
	//	挖矿参数FIFO复位
	//	模块复位，或者在强制重新开始挖矿时，此时FIFO中存有的默克尔根已经没用了，所以复位FIFO
	//  -------------------------------------------------------------------------------------
	assign param_fifo_rst = ((rst == 1'b1) || (mining_restart == 1'b1)) ? 1'b1 : 1'b0;
	
	//  -------------------------------------------------------------------------------------
	//	输出挖矿使能信号
	//	在强制重新开始挖矿有效，或挖矿空间已满需要新的默克尔根从FIFO中读取数据时，输出挖矿使能信号
	//  -------------------------------------------------------------------------------------
	assign o_mining_en = ((mining_restart == 1'b1) || (param_fifo_rd_en == 1'b1)) ? 1'b1 : 1'b0;
	
	//  -------------------------------------------------------------------------------------
	//	输出挖矿参数
	//	在强制重新开始挖矿有效时，则直接输出挖矿参数
	//	在挖矿空间已满需要新的默克尔根从FIFO中读取数据时，则输出挖矿参数FIFO中读出的数据
	//	否则输出无效数据0
	//  -------------------------------------------------------------------------------------
	assign {ov_mining_data, ov_mining_extranounce2, ov_mining_target} = (mining_restart 	== 1'b1) ? mining_param : 
																		(param_fifo_rd_en	== 1'b1) ? param_fifo_rd_data : 'b0;
	
	//  -------------------------------------------------------------------------------------
	//	例化挖矿参数FIFO
	//	同步FIFO，896bit宽，16深，FWFT模式
	//  -------------------------------------------------------------------------------------	
	generate
	
		//	使用DRAM资源的FIFO
		if(IS_BRAM_FIFO == "FALSE") begin
			fifo_dram_896x16 param_fifo_inst (
				.clk	(clk				),	// input wire clk
				.srst	(param_fifo_rst		),	// input wire srst
				.wr_en	(param_fifo_wr_en	),	// input wire wr_en
				.din	(param_fifo_wr_data	),	// input wire [895 : 0] din
				.full	(					),	// output wire full
				.rd_en	(param_fifo_rd_en	),	// input wire rd_en
				.dout	(param_fifo_rd_data	),	// output wire [895 : 0] dout
				.empty	(param_fifo_empty	) 	// output wire empty
			);
		end
		
		//	使用BRAM资源的FIFO
		else begin
			fifo_bram_896x16 param_fifo_inst (
				.clk	(clk				),	// input wire clk
				.srst	(param_fifo_rst		),	// input wire srst
				.wr_en	(param_fifo_wr_en	),	// input wire wr_en
				.din	(param_fifo_wr_data	),	// input wire [895 : 0] din
				.full	(					),	// output wire full
				.rd_en	(param_fifo_rd_en	),	// input wire rd_en
				.dout	(param_fifo_rd_data	),	// output wire [895 : 0] dout
				.empty	(param_fifo_empty	) 	// output wire empty
			);
		end
	endgenerate
	
	
	//  ===============================================================================================
	//	串口发送数据处理
	//  ===============================================================================================	
	//  -------------------------------------------------------------------------------------
	//	挖矿强制重新开始扩展
	//	挖矿强制重新开始会复位FIFO，此时需要等待挖矿结果FIFO复位完成，才可以响应FIFO写入命令
	//  -------------------------------------------------------------------------------------
	assign mining_restart_extend = ((mining_restart == 1'b1) || (|mining_restart_dly == 1'b1)) ? 1'b1 : 1'b0;
	
	//  -------------------------------------------------------------------------------------
	//	挖矿结果FIFO写使能
	//	在挖矿结果FIFO复位完成后，且有新的nounce结果，或者挖矿空间已满，则存入FIFO
	//  -------------------------------------------------------------------------------------
	assign nounce_fifo_wr_en = ((mining_restart_extend == 1'b0) && ((i_mining_nounce_vld == 1'b1) || (i_mining_nounce_full == 1'b1))) ? 1'b1 : 1'b0; 
	
	//  -------------------------------------------------------------------------------------
	//	挖矿结果FIFO写数据
	//	将挖矿数据拼接后存入FIFO
	//  -------------------------------------------------------------------------------------
	assign nounce_fifo_wr_data = {{6'b0, i_mining_nounce_full, i_mining_nounce_vld}, iv_mining_nounce, iv_mining_extranounce2};
	
	//  -------------------------------------------------------------------------------------
	//	挖矿结果FIFO读使能
	//	在串口发送忙碌上升沿，从FIFO中读出新的数据
	//  -------------------------------------------------------------------------------------
	assign nounce_fifo_rd_en = tx_busy_rise;
	
	//  -------------------------------------------------------------------------------------
	//	挖矿结果FIFO复位
	//	模块复位，或者挖矿强制重新开始时，复位FIFO
	//  -------------------------------------------------------------------------------------
	assign nounce_fifo_rst = ((rst == 1'b1) || (mining_restart == 1'b1)) ? 1'b1 : 1'b0;
	
	//  -------------------------------------------------------------------------------------
	//	串口发送忙碌
	//	逻辑上有一定冗余
	//  -------------------------------------------------------------------------------------
	always @ (posedge clk) begin
		
		//	复位
		if(rst) begin
			tx_busy <= 1'b0;
		end
		
		//	在完成一次完整发送后，置低
		else if((tx_done == 1'b1) && (tx_data_cnt == (TX_DATA_CNT_NUM - 1'b1))) begin
			tx_busy <= 1'b0;
		end
		
		//	在串口发送不忙碌，且挖矿结果FIFO复位完成，且挖矿结果FIFO中有数据时，置高
		else if((rx_busy == 1'b0) && (mining_restart_extend == 1'b0) && (nounce_fifo_empty == 1'b0)) begin
			tx_busy <= 1'b1;
		end
	end
	
	//  -------------------------------------------------------------------------------------
	//	串口发送数据计数器
	//  -------------------------------------------------------------------------------------
	always @ (posedge clk) begin
		
		//	复位
		if(rst) begin
			tx_data_cnt <= 'b0;
		end
		
		//	从FIFO中读出数据的后一拍，或者串口每发送完成一个数据，则计数
		else if((nounce_fifo_rd_en_dly == 1'b1) || (tx_done == 1'b1)) begin
			
			//	计数到最大值，则清理
			if(tx_data_cnt >= (TX_DATA_CNT_NUM - 1'b1)) begin
				tx_data_cnt	<= 'b0;
			end
			
			//	否则，累加一
			else begin
				tx_data_cnt	<= tx_data_cnt + 1'b1;
			end
		end
	end
	
	//  -------------------------------------------------------------------------------------
	//	串口发送数据
	//	根据tx_data_cnt截取FIFO读数据中的部分数据，先发送高字节
	//	为了避免vivado综合成乘法器，使用case语句展开
	//  -------------------------------------------------------------------------------------
	always @ ( * ) begin
		case(tx_data_cnt)
				
			//	tx_data_cnt为0
			'd0	: begin
				tx_data = nounce_fifo_rd_data[(UART_DATA_WID*8) +: UART_DATA_WID];
			end
			
			//	tx_data_cnt为1
			'd1	: begin
				tx_data = nounce_fifo_rd_data[(UART_DATA_WID*7) +: UART_DATA_WID];
			end
			
			//	tx_data_cnt为2
			'd2	: begin
				tx_data = nounce_fifo_rd_data[(UART_DATA_WID*6) +: UART_DATA_WID];
			end
			
			//	tx_data_cnt为3
			'd3	: begin
				tx_data = nounce_fifo_rd_data[(UART_DATA_WID*5) +: UART_DATA_WID];
			end
			
			//	tx_data_cnt为4
			'd4	: begin
				tx_data = nounce_fifo_rd_data[(UART_DATA_WID*4) +: UART_DATA_WID];
			end
			
			//	tx_data_cnt为5
			'd5	: begin
				tx_data = nounce_fifo_rd_data[(UART_DATA_WID*3) +: UART_DATA_WID];
			end
			
			//	tx_data_cnt为6
			'd6	: begin
				tx_data = nounce_fifo_rd_data[(UART_DATA_WID*2) +: UART_DATA_WID];
			end
			
			//	tx_data_cnt为7
			'd7	: begin
				tx_data = nounce_fifo_rd_data[(UART_DATA_WID*1) +: UART_DATA_WID];
			end
			
			//	tx_data_cnt为8
			'd8	: begin
				tx_data = nounce_fifo_rd_data[(UART_DATA_WID*0) +: UART_DATA_WID];
			end
			
			//	其他值
			default	: begin
				tx_data = 'b0;
			end
		endcase
	end
	
	//  -------------------------------------------------------------------------------------
	//	串口发送数据有效
	//	在挖矿结果FIFO读使能打拍有效，或者串口发送完一个数据且tx_data_cnt不等于最大值时，有效
	//  -------------------------------------------------------------------------------------
	assign tx_data_vld = ((nounce_fifo_rd_en_dly == 1'b1) || ((tx_done == 1'b1) && (tx_data_cnt != (TX_DATA_CNT_NUM - 1'b1)))) ? 1'b1 : 1'b0;
	
	//  -------------------------------------------------------------------------------------
	//	例化挖矿结果FIFO
	//	同步FIFO，72bit宽，512深，STANDARD模式
	//  -------------------------------------------------------------------------------------	
	fifo_bram_72x512 nounce_fifo_inst (
		.clk	(clk					),	// input wire clk
		.srst	(nounce_fifo_rst		),	// input wire srst
		.wr_en	(nounce_fifo_wr_en		),	// input wire wr_en
		.din	(nounce_fifo_wr_data	),	// input wire [71 : 0] din
		.full	(						),	// output wire full
		.rd_en	(nounce_fifo_rd_en		),	// input wire rd_en
		.dout	(nounce_fifo_rd_data	),	// output wire [71 : 0] dout
		.empty	(nounce_fifo_empty		) 	// output wire empty
	);
	
	
	//  ===============================================================================================
	//	模块单独测试信号连接
	//  ===============================================================================================	
	//  -------------------------------------------------------------------------------------
	//	模块单独测试信号连接
	//	实际程序中没有此部分
	//  -------------------------------------------------------------------------------------
//	assign rx_data 			= iv_rx_data	;
//	assign rx_data_vld 		= i_rx_data_vld	;
//	assign rx_busy 			= i_rx_busy		;
//	assign ov_tx_data 		= tx_data		;
//	assign o_tx_data_vld 	= tx_data_vld	;
//	assign tx_done 			= i_tx_done		;

endmodule