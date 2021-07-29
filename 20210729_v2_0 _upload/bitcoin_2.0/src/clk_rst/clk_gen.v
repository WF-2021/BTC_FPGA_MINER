//	********************************************************************************
//	模块名：clk_gen
//	功  能：产生时钟
//	资	源：
//	********************************************************************************
module clk_gen (
	
	//	输入信号                                     	
	input	i_clk			,	//	输入时钟

	//	输出信号
	output	o_clk			,	//	输出时钟
	output	o_mmcm_locked		//	输出MMCM锁定
	);
	
	
	//  ===============================================================================================
	//	参数、信号、函数说明
	//  ===============================================================================================
	//  -------------------------------------------------------------------------------------
	//	参数说明
	//  -------------------------------------------------------------------------------------
//	//	175MHz
//	localparam	CLKIN_PERIOD	= 	20.000	;	//	输入时钟周期，50MHz，20ns
//	localparam	CLK_MULT		= 	21		;	//	时钟倍频系数
//	localparam	CLK_DIVIDE		= 	1		;	//	时钟分频系数
//	localparam	CLKOUT0_DIVIDE	= 	6		;	//	时钟输出0分频系数
	
	//	100MHz
	localparam	CLKIN_PERIOD	= 	20.000	;	//	输入时钟周期，50MHz，20ns
	localparam	CLK_MULT		= 	20		;	//	时钟倍频系数
	localparam	CLK_DIVIDE		= 	1		;	//	时钟分频系数
	localparam	CLKOUT0_DIVIDE	= 	10		;	//	时钟输出0分频系数
	
	//  -------------------------------------------------------------------------------------
	//	信号说明
	//  -------------------------------------------------------------------------------------
	wire	clk_io	;	//	IBUF输出时钟
	wire	clk_fb	;	//	MMCM反馈时钟
	wire	clk0	;	//	MMCM输出时钟0
		
		
	//  ===============================================================================================
	//	时钟资源原语例化
	//  ===============================================================================================	
	//  -------------------------------------------------------------------------------------
	//	引脚输入缓冲器例化
	//  -------------------------------------------------------------------------------------
	IBUF ibuf_clk (
		.I		(i_clk	),
		.O		(clk_io	)
	);
	
	//  -------------------------------------------------------------------------------------
	//	MMCM例化
	//	Fvco = CLKIN1 * CLKFBOUT_MULT_F / DIVCLK_DIVIDE  (600MHz - 1440MHz)
	//	Fout = Fvco / CLKOUTx_DIVIDE  (4.69MHz - 800MHz)
	//	Ffb = CLKIN1 / DIVCLK_DIVIDE
	//  -------------------------------------------------------------------------------------
	//	Fvco = 50MHz * 21 / 1 = 1050MHz
	//	Fout = 1050MHz / 6 = 175MHz
	//  -------------------------------------------------------------------------------------
	MMCME2_BASE #(
		
		//	控制参数
		.BANDWIDTH			("OPTIMIZED"	),	// Jitter programming (OPTIMIZED, HIGH, LOW).
		.CLKOUT4_CASCADE	("FALSE"		),	// Cascade CLKOUT4 counter with CLKOUT6 (FALSE, TRUE).
		.REF_JITTER1		(0.0			),	// Reference input jitter in UI (0.000-0.999).
		.STARTUP_WAIT		("FALSE"		),	// Delays DONE until MMCM is locked (FALSE, TRUE).
		
		//	时钟参数
		.CLKIN1_PERIOD		(CLKIN_PERIOD	),	// Input clock period in ns to ps resolution (i.e. 33.333 is 30 MHz).
		.DIVCLK_DIVIDE		(CLK_DIVIDE		),	// Master division value (1-106)
		                        			
		.CLKFBOUT_MULT_F	(CLK_MULT		),	// Multiply value for all CLKOUT (2.000-64.000).
		.CLKFBOUT_PHASE		(0.0			),	// Phase offset in degrees of CLKFB (-360.000-360.000).
		                        			
		.CLKOUT0_DIVIDE_F	(CLKOUT0_DIVIDE	),	// Divide amount for CLKOUT0 (1.000-128.000).
		.CLKOUT0_DUTY_CYCLE	(0.5			),	// CLKOUT0_DUTY_CYCLE: Duty cycle for each CLKOUT (0.01-0.99).
		.CLKOUT0_PHASE		(0.0			)	// CLKOUT0_PHASE: Phase offset for each CLKOUT (-360.000-360.000).
	)
	MMCME2_BASE_inst (
	
		//	控制信号
		.PWRDWN				(1'b0			),	// 1-bit input: Power-down
		.RST				(1'b0			),	// 1-bit input: Reset
	                                    	
		//	时钟信号                    	
		.CLKIN1				(clk_io			),	// 1-bit input: Clock
		.CLKFBOUT			(clk_fb			),	// 1-bit output: Feedback clock
		.CLKFBIN			(clk_fb			),	// 1-bit input: Feedback clock
		.CLKOUT0			(clk0			),	// 1-bit output: CLKOUT0
                                        	
		//	指示信号                    	
		.LOCKED				(o_mmcm_locked	) 	// 1-bit output: LOCK
	);
	
	//  -------------------------------------------------------------------------------------
	//	BUFG例化
	//  -------------------------------------------------------------------------------------
	BUFG bufg_clk0 ( .I (clk0 ), .O (o_clk ) );
	
endmodule