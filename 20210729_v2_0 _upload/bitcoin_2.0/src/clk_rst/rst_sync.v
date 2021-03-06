//	********************************************************************************
//	模块名：rst_sync
//	功  能：异步复位同步释放
//	资	源：
//	********************************************************************************
module rst_sync (
	
	//	输入信号                                     	
	input	clk				,	//	模块工作时钟信号
	input	i_rst_async		,	//	复位异步
	input	i_rst_sync_en	,	//	复位同步使能

	//	输出信号
	output	o_rst_sync			//	clk时钟域，复位同步
	);
	
	
	//  ===============================================================================================
	//	参数、信号、函数说明
	//  ===============================================================================================
	//  -------------------------------------------------------------------------------------
	//	参数说明
	//  -------------------------------------------------------------------------------------
	localparam	INITIALIZATION = 2'b11	;	//	复位同步寄存器初始值
	
	//  -------------------------------------------------------------------------------------
	//	信号说明
	//  -------------------------------------------------------------------------------------
	wire	rst_sync_0	;	//	clk时钟域，复位同步0
	wire	rst_sync_1	;	//	clk时钟域，复位同步1
		
		
	//  ===============================================================================================
	//	异步复位同步释放
	//  ===============================================================================================	
	//  -------------------------------------------------------------------------------------
	//	FDPE异步置位寄存器0
	//  -------------------------------------------------------------------------------------
	FDPE # (
		.INIT	(INITIALIZATION[0]	)	//	FDPE输出初始值
	)
	fdpe_inst0 (
		.CE		(i_rst_sync_en		),	//	时钟使能
		.C		(clk				),  //	时钟
		.PRE	(i_rst_async		),	//	异步置位控制
		.D		(1'b0				),  //	输入信号
		.Q		(rst_sync_0			)   //	输出信号
	);
	
	//  -------------------------------------------------------------------------------------
	//	FDPE异步置位寄存器0
	//  -------------------------------------------------------------------------------------
	FDPE # (
		.INIT	(INITIALIZATION[1]	)	//	FDPE输出初始值
	)
	fdpe_inst1 (
		.CE		(i_rst_sync_en		),	//	时钟使能     
		.C		(clk				),	//	时钟         
		.PRE	(i_rst_async		),	//	异步置位控制 
		.D		(rst_sync_0			),	//	输入信号     
		.Q		(rst_sync_1			) 	//	输出信号     
	);
	
	//  -------------------------------------------------------------------------------------
	//	复位同步输出
	//  -------------------------------------------------------------------------------------
	assign o_rst_sync = rst_sync_1;
	
endmodule