//	********************************************************************************
//	ģ������bitcoin
//	��  �ܣ����ر��ڿ�
//	��	Դ��
//	********************************************************************************
module bitcoin (                                                       	
	                                                        	
	//	�����ź�                                     	
	input	i_clk		,	//	����ʱ��
	                                                        	
	//	�����ź�                                            	
	input	i_uart_rx	,	//	���ڽ�����
	output	o_uart_tx		//	���ڷ�����
	);
	
	
	//  ===============================================================================================
	//	�������źš�����˵��
	//  ===============================================================================================
	//  -------------------------------------------------------------------------------------
	//	����˵��
	//  -------------------------------------------------------------------------------------
	parameter	IS_SIM				= "FALSE"	;	//	�Ƿ�Ϊ������ԣ�"TRUE" "FALSE"
	parameter	BAUD_RATE			= "115200"	;	//	�����ʣ�"9600" "115200"
	parameter	MINING_DATA_WID		= 608		;	//	�ڿ�����λ��608
	parameter	DATA_WID			= 32		;	//	WORDλ��32
	parameter	TARGET_WID			= 256		;	//	�ڿ�Ŀ��λ��256
	parameter	UART_DATA_WID		= 8			;	//	��������λ��8
	parameter	IS_BRAM_FIFO		= "TRUE"	;	//	�Ƿ�ʹ��BRAM��Դ�����ڿ����FIFO��"TRUE" "FALSE"
	parameter	HASH_WORD_NUM		= 8			;	//	��ϣֵ��WORD������8
	parameter	MESSAGE_WORD_NUM	= 16		;	//	��Ϣ���WORD������16
	
	//  -------------------------------------------------------------------------------------
	//	�ź�˵��
	//  -------------------------------------------------------------------------------------
	//	clk_rstģ���ź�
	wire								clk							;	//	clkʱ��
	wire								rst							;	//	clkʱ���򣬸�λ
	
	//	uart_ctrlģ���ź�
	wire								w_mining_en_uart			;	//	clkʱ���������ڿ�ʹ��                    
	wire	[MINING_DATA_WID	-1:0]	wv_mining_data_uart			;	//	clkʱ���������ڿ�����                    
	wire	[TARGET_WID			-1:0]	wv_mining_target_uart		;	//	clkʱ���������ڿ�Ŀ�꣬��ʾhash�߼�λΪ0 
	wire	[DATA_WID			-1:0]	wv_mining_extranounce2_uart	;	//	clkʱ���������ڿ�ռ�extranounce2        

	//	double_sha256_calcģ���ź�
	wire	[DATA_WID			-1:0]	wv_mining_extranounce2_sha	;	//	clkʱ��������ڿ�ռ�extranounce2
	wire	[DATA_WID			-1:0]	wv_mining_nounce_sha		;	//	clkʱ��������ڿ�nounce
	wire								w_mining_nounce_vld_sha		;	//	clkʱ��������ڿ�nounce��Ч
	wire								w_mining_nounce_full_sha	;	//	clkʱ��������ڿ�ռ�nounce����
	
		
	//  ===============================================================================================
	//	��ģ������
	//  ===============================================================================================	
	//  -------------------------------------------------------------------------------------
	//	clk_rstģ������
	//  -------------------------------------------------------------------------------------
	clk_rst clk_rst_inst(
		.i_clk			(i_clk	),	//	����ʱ��
		.o_clk			(clk	),	//	���ʱ��
		.o_rst_sync		(rst	)	//	o_clkʱ���򣬸�λͬ��
	);
	
	//  -------------------------------------------------------------------------------------
	//	uart_ctrlģ������
	//  -------------------------------------------------------------------------------------
	uart_ctrl # (
		.IS_SIM						(IS_SIM							),	//	�Ƿ�Ϊ������ԣ�"TRUE" "FALSE"
		.BAUD_RATE					(BAUD_RATE						),	//	�����ʣ�"9600" "115200"
		.MINING_DATA_WID			(MINING_DATA_WID				),	//	�ڿ�����λ��608
		.DATA_WID					(DATA_WID						),	//	WORDλ��32
		.TARGET_WID					(TARGET_WID						),	//	�ڿ�Ŀ��λ��8
		.UART_DATA_WID				(UART_DATA_WID					),	//	��������λ��8
		.IS_BRAM_FIFO				(IS_BRAM_FIFO					)	//	�Ƿ�ʹ��BRAM��Դ�����ڿ����FIFO��"TRUE" "FALSE"
	)                                                       		
	uart_ctrl_inst (                                            	           	
		.clk						(clk							),	//	ģ�鹤��ʱ���ź�
		.rst						(rst							),	//	clkʱ���򣬸�λ
		.i_uart_rx					(i_uart_rx						),	//	clkʱ���򣬴��ڽ�����
		.o_uart_tx					(o_uart_tx						),	//	clkʱ���򣬴��ڷ�����
		.iv_mining_extranounce2		(wv_mining_extranounce2_sha	    ),	//	clkʱ��������ڿ�ռ�extranounce2
		.iv_mining_nounce			(wv_mining_nounce_sha		    ),	//	clkʱ��������ڿ�nounce
		.i_mining_nounce_vld		(w_mining_nounce_vld_sha		),	//	clkʱ��������ڿ�nounce��Ч
		.i_mining_nounce_full		(w_mining_nounce_full_sha	    ),	//	clkʱ��������ڿ�ռ�nounce����
		.o_mining_en				(w_mining_en_uart			    ),	//	clkʱ���������ڿ�ʹ��
		.ov_mining_data				(wv_mining_data_uart			),	//	clkʱ���������ڿ�����
		.ov_mining_target			(wv_mining_target_uart		    ),	//	clkʱ���������ڿ�Ŀ�꣬��ʾhash�߼�λΪ0
		.ov_mining_extranounce2		(wv_mining_extranounce2_uart	)	//	clkʱ���������ڿ�ռ�extranounce2
	);
	
	
	//  -------------------------------------------------------------------------------------
	//	double_sha256_calcģ������
	//  -------------------------------------------------------------------------------------
	double_sha256_calc # (
		.IS_SIM						(IS_SIM							),	//	�Ƿ�Ϊ������ԣ�'TRUE' "FALSE"
		.MINING_DATA_WID			(MINING_DATA_WID				),	//	�ڿ�����λ��608
		.HASH_WORD_NUM				(HASH_WORD_NUM					),	//	��ϣֵ��WORD������8
		.MESSAGE_WORD_NUM			(MESSAGE_WORD_NUM				),	//	��Ϣ���WORD������16
		.DATA_WID					(DATA_WID						),	//	WORDλ��32
		.TARGET_WID					(TARGET_WID						)	//	�ڿ�Ŀ��λ��8
	)                                                           		
	double_sha256_calc_inst (                                                           		
		.clk						(clk							),	//	ģ�鹤��ʱ���ź�
		.rst						(rst							),	//	clkʱ���򣬸�λ
		.i_mining_en				(w_mining_en_uart			    ),	//	clkʱ���������ڿ�ʹ��
		.iv_mining_data				(wv_mining_data_uart			),	//	clkʱ���������ڿ�����
		.iv_mining_target			(wv_mining_target_uart		    ),	//	clkʱ���������ڿ�Ŀ�꣬��ʾhash�߼�λΪ0
		.iv_mining_extranounce2		(wv_mining_extranounce2_uart	),	//	clkʱ���������ڿ�ռ�extranounce2
		.ov_mining_extranounce2		(wv_mining_extranounce2_sha	    ),	//	clkʱ��������ڿ�ռ�extranounce2
		.ov_mining_nounce			(wv_mining_nounce_sha		    ),	//	clkʱ��������ڿ�nounce
		.o_mining_nounce_vld		(w_mining_nounce_vld_sha		),	//	clkʱ��������ڿ�nounce��Ч
		.o_mining_nounce_full		(w_mining_nounce_full_sha	    )	//	clkʱ��������ڿ�ռ�nounce����
	);

endmodule