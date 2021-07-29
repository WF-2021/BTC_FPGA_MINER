//	********************************************************************************
//	ģ������clk_gen
//	��  �ܣ�����ʱ��
//	��	Դ��
//	********************************************************************************
module clk_gen (
	
	//	�����ź�                                     	
	input	i_clk			,	//	����ʱ��

	//	����ź�
	output	o_clk			,	//	���ʱ��
	output	o_mmcm_locked		//	���MMCM����
	);
	
	
	//  ===============================================================================================
	//	�������źš�����˵��
	//  ===============================================================================================
	//  -------------------------------------------------------------------------------------
	//	����˵��
	//  -------------------------------------------------------------------------------------
//	//	175MHz
//	localparam	CLKIN_PERIOD	= 	20.000	;	//	����ʱ�����ڣ�50MHz��20ns
//	localparam	CLK_MULT		= 	21		;	//	ʱ�ӱ�Ƶϵ��
//	localparam	CLK_DIVIDE		= 	1		;	//	ʱ�ӷ�Ƶϵ��
//	localparam	CLKOUT0_DIVIDE	= 	6		;	//	ʱ�����0��Ƶϵ��
	
	//	100MHz
	localparam	CLKIN_PERIOD	= 	20.000	;	//	����ʱ�����ڣ�50MHz��20ns
	localparam	CLK_MULT		= 	20		;	//	ʱ�ӱ�Ƶϵ��
	localparam	CLK_DIVIDE		= 	1		;	//	ʱ�ӷ�Ƶϵ��
	localparam	CLKOUT0_DIVIDE	= 	10		;	//	ʱ�����0��Ƶϵ��
	
	//  -------------------------------------------------------------------------------------
	//	�ź�˵��
	//  -------------------------------------------------------------------------------------
	wire	clk_io	;	//	IBUF���ʱ��
	wire	clk_fb	;	//	MMCM����ʱ��
	wire	clk0	;	//	MMCM���ʱ��0
		
		
	//  ===============================================================================================
	//	ʱ����Դԭ������
	//  ===============================================================================================	
	//  -------------------------------------------------------------------------------------
	//	�������뻺��������
	//  -------------------------------------------------------------------------------------
	IBUF ibuf_clk (
		.I		(i_clk	),
		.O		(clk_io	)
	);
	
	//  -------------------------------------------------------------------------------------
	//	MMCM����
	//	Fvco = CLKIN1 * CLKFBOUT_MULT_F / DIVCLK_DIVIDE  (600MHz - 1440MHz)
	//	Fout = Fvco / CLKOUTx_DIVIDE  (4.69MHz - 800MHz)
	//	Ffb = CLKIN1 / DIVCLK_DIVIDE
	//  -------------------------------------------------------------------------------------
	//	Fvco = 50MHz * 21 / 1 = 1050MHz
	//	Fout = 1050MHz / 6 = 175MHz
	//  -------------------------------------------------------------------------------------
	MMCME2_BASE #(
		
		//	���Ʋ���
		.BANDWIDTH			("OPTIMIZED"	),	// Jitter programming (OPTIMIZED, HIGH, LOW).
		.CLKOUT4_CASCADE	("FALSE"		),	// Cascade CLKOUT4 counter with CLKOUT6 (FALSE, TRUE).
		.REF_JITTER1		(0.0			),	// Reference input jitter in UI (0.000-0.999).
		.STARTUP_WAIT		("FALSE"		),	// Delays DONE until MMCM is locked (FALSE, TRUE).
		
		//	ʱ�Ӳ���
		.CLKIN1_PERIOD		(CLKIN_PERIOD	),	// Input clock period in ns to ps resolution (i.e. 33.333 is 30 MHz).
		.DIVCLK_DIVIDE		(CLK_DIVIDE		),	// Master division value (1-106)
		                        			
		.CLKFBOUT_MULT_F	(CLK_MULT		),	// Multiply value for all CLKOUT (2.000-64.000).
		.CLKFBOUT_PHASE		(0.0			),	// Phase offset in degrees of CLKFB (-360.000-360.000).
		                        			
		.CLKOUT0_DIVIDE_F	(CLKOUT0_DIVIDE	),	// Divide amount for CLKOUT0 (1.000-128.000).
		.CLKOUT0_DUTY_CYCLE	(0.5			),	// CLKOUT0_DUTY_CYCLE: Duty cycle for each CLKOUT (0.01-0.99).
		.CLKOUT0_PHASE		(0.0			)	// CLKOUT0_PHASE: Phase offset for each CLKOUT (-360.000-360.000).
	)
	MMCME2_BASE_inst (
	
		//	�����ź�
		.PWRDWN				(1'b0			),	// 1-bit input: Power-down
		.RST				(1'b0			),	// 1-bit input: Reset
	                                    	
		//	ʱ���ź�                    	
		.CLKIN1				(clk_io			),	// 1-bit input: Clock
		.CLKFBOUT			(clk_fb			),	// 1-bit output: Feedback clock
		.CLKFBIN			(clk_fb			),	// 1-bit input: Feedback clock
		.CLKOUT0			(clk0			),	// 1-bit output: CLKOUT0
                                        	
		//	ָʾ�ź�                    	
		.LOCKED				(o_mmcm_locked	) 	// 1-bit output: LOCK
	);
	
	//  -------------------------------------------------------------------------------------
	//	BUFG����
	//  -------------------------------------------------------------------------------------
	BUFG bufg_clk0 ( .I (clk0 ), .O (o_clk ) );
	
endmodule