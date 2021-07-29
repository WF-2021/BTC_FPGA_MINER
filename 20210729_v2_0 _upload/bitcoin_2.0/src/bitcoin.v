//	********************************************************************************
//	模块名：bitcoin
//	功  能：比特币挖矿
//	资	源：
//	********************************************************************************
module bitcoin (                                                       	
	                                                        	
	//	输入信号                                     	
	input	i_clk		,	//	输入时钟
	                                                        	
	//	串口信号                                            	
	input	i_uart_rx	,	//	串口接收线
	output	o_uart_tx		//	串口发送线
	);
	
	
	//  ===============================================================================================
	//	参数、信号、函数说明
	//  ===============================================================================================
	//  -------------------------------------------------------------------------------------
	//	参数说明
	//  -------------------------------------------------------------------------------------
	parameter	IS_SIM				= "FALSE"	;	//	是否为仿真测试，"TRUE" "FALSE"
	parameter	BAUD_RATE			= "115200"	;	//	波特率，"9600" "115200"
	parameter	MINING_DATA_WID		= 608		;	//	挖矿数据位宽，608
	parameter	DATA_WID			= 32		;	//	WORD位宽，32
	parameter	TARGET_WID			= 256		;	//	挖矿目标位宽，256
	parameter	UART_DATA_WID		= 8			;	//	串口数据位宽，8
	parameter	IS_BRAM_FIFO		= "TRUE"	;	//	是否使用BRAM资源例化挖矿参数FIFO，"TRUE" "FALSE"
	parameter	HASH_WORD_NUM		= 8			;	//	哈希值的WORD个数，8
	parameter	MESSAGE_WORD_NUM	= 16		;	//	消息块的WORD个数，16
	
	//  -------------------------------------------------------------------------------------
	//	信号说明
	//  -------------------------------------------------------------------------------------
	//	clk_rst模块信号
	wire								clk							;	//	clk时钟
	wire								rst							;	//	clk时钟域，复位
	
	//	uart_ctrl模块信号
	wire								w_mining_en_uart			;	//	clk时钟域，输入挖矿使能                    
	wire	[MINING_DATA_WID	-1:0]	wv_mining_data_uart			;	//	clk时钟域，输入挖矿数据                    
	wire	[TARGET_WID			-1:0]	wv_mining_target_uart		;	//	clk时钟域，输入挖矿目标，表示hash高几位为0 
	wire	[DATA_WID			-1:0]	wv_mining_extranounce2_uart	;	//	clk时钟域，输入挖矿空间extranounce2        

	//	double_sha256_calc模块信号
	wire	[DATA_WID			-1:0]	wv_mining_extranounce2_sha	;	//	clk时钟域，输出挖矿空间extranounce2
	wire	[DATA_WID			-1:0]	wv_mining_nounce_sha		;	//	clk时钟域，输出挖矿nounce
	wire								w_mining_nounce_vld_sha		;	//	clk时钟域，输出挖矿nounce有效
	wire								w_mining_nounce_full_sha	;	//	clk时钟域，输出挖矿空间nounce已满
	
		
	//  ===============================================================================================
	//	子模块例化
	//  ===============================================================================================	
	//  -------------------------------------------------------------------------------------
	//	clk_rst模块例化
	//  -------------------------------------------------------------------------------------
	clk_rst clk_rst_inst(
		.i_clk			(i_clk	),	//	输入时钟
		.o_clk			(clk	),	//	输出时钟
		.o_rst_sync		(rst	)	//	o_clk时钟域，复位同步
	);
	
	//  -------------------------------------------------------------------------------------
	//	uart_ctrl模块例化
	//  -------------------------------------------------------------------------------------
	uart_ctrl # (
		.IS_SIM						(IS_SIM							),	//	是否为仿真测试，"TRUE" "FALSE"
		.BAUD_RATE					(BAUD_RATE						),	//	波特率，"9600" "115200"
		.MINING_DATA_WID			(MINING_DATA_WID				),	//	挖矿数据位宽，608
		.DATA_WID					(DATA_WID						),	//	WORD位宽，32
		.TARGET_WID					(TARGET_WID						),	//	挖矿目标位宽，8
		.UART_DATA_WID				(UART_DATA_WID					),	//	串口数据位宽，8
		.IS_BRAM_FIFO				(IS_BRAM_FIFO					)	//	是否使用BRAM资源例化挖矿参数FIFO，"TRUE" "FALSE"
	)                                                       		
	uart_ctrl_inst (                                            	           	
		.clk						(clk							),	//	模块工作时钟信号
		.rst						(rst							),	//	clk时钟域，复位
		.i_uart_rx					(i_uart_rx						),	//	clk时钟域，串口接收线
		.o_uart_tx					(o_uart_tx						),	//	clk时钟域，串口发送线
		.iv_mining_extranounce2		(wv_mining_extranounce2_sha	    ),	//	clk时钟域，输出挖矿空间extranounce2
		.iv_mining_nounce			(wv_mining_nounce_sha		    ),	//	clk时钟域，输出挖矿nounce
		.i_mining_nounce_vld		(w_mining_nounce_vld_sha		),	//	clk时钟域，输出挖矿nounce有效
		.i_mining_nounce_full		(w_mining_nounce_full_sha	    ),	//	clk时钟域，输出挖矿空间nounce已满
		.o_mining_en				(w_mining_en_uart			    ),	//	clk时钟域，输入挖矿使能
		.ov_mining_data				(wv_mining_data_uart			),	//	clk时钟域，输入挖矿数据
		.ov_mining_target			(wv_mining_target_uart		    ),	//	clk时钟域，输入挖矿目标，表示hash高几位为0
		.ov_mining_extranounce2		(wv_mining_extranounce2_uart	)	//	clk时钟域，输入挖矿空间extranounce2
	);
	
	
	//  -------------------------------------------------------------------------------------
	//	double_sha256_calc模块例化
	//  -------------------------------------------------------------------------------------
	double_sha256_calc # (
		.IS_SIM						(IS_SIM							),	//	是否为仿真测试，'TRUE' "FALSE"
		.MINING_DATA_WID			(MINING_DATA_WID				),	//	挖矿数据位宽，608
		.HASH_WORD_NUM				(HASH_WORD_NUM					),	//	哈希值的WORD个数，8
		.MESSAGE_WORD_NUM			(MESSAGE_WORD_NUM				),	//	消息块的WORD个数，16
		.DATA_WID					(DATA_WID						),	//	WORD位宽，32
		.TARGET_WID					(TARGET_WID						)	//	挖矿目标位宽，8
	)                                                           		
	double_sha256_calc_inst (                                                           		
		.clk						(clk							),	//	模块工作时钟信号
		.rst						(rst							),	//	clk时钟域，复位
		.i_mining_en				(w_mining_en_uart			    ),	//	clk时钟域，输入挖矿使能
		.iv_mining_data				(wv_mining_data_uart			),	//	clk时钟域，输入挖矿数据
		.iv_mining_target			(wv_mining_target_uart		    ),	//	clk时钟域，输入挖矿目标，表示hash高几位为0
		.iv_mining_extranounce2		(wv_mining_extranounce2_uart	),	//	clk时钟域，输入挖矿空间extranounce2
		.ov_mining_extranounce2		(wv_mining_extranounce2_sha	    ),	//	clk时钟域，输出挖矿空间extranounce2
		.ov_mining_nounce			(wv_mining_nounce_sha		    ),	//	clk时钟域，输出挖矿nounce
		.o_mining_nounce_vld		(w_mining_nounce_vld_sha		),	//	clk时钟域，输出挖矿nounce有效
		.o_mining_nounce_full		(w_mining_nounce_full_sha	    )	//	clk时钟域，输出挖矿空间nounce已满
	);

endmodule