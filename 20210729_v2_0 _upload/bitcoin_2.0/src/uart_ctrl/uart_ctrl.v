//	********************************************************************************
//	ģ������uart_ctrl
//	��  �ܣ����ƴ��ڽ��ա���������
//			1. �������ݣ�������ǿ�ƿ�ʼ�ڿ��װ��Ĭ�˶�������
//			2. �������ݣ����ڿ�������Ĭ�˶���������
//	��	Դ��
//	********************************************************************************
module uart_ctrl # (
	
	//	�������
	parameter		IS_SIM				= "TRUE"				,	//	�Ƿ�Ϊ������ԣ�"TRUE" "FALSE"
	parameter		BAUD_RATE			= "115200"				,	//	�����ʣ�"9600" "115200"
	parameter		MINING_DATA_WID		= 608					,	//	�ڿ�����λ��608
	parameter		DATA_WID			= 32					,	//	WORDλ��32
	parameter		TARGET_WID			= 256					,	//	�ڿ�Ŀ��λ��256
	parameter		UART_DATA_WID		= 8						,	//	��������λ��8
	parameter		IS_BRAM_FIFO		= "TRUE"					//	�Ƿ�ʹ��BRAM��Դ�����ڿ����FIFO��"TRUE" "FALSE"
	)                                                       	
	(                                                       	
	                                                        	
	//	ʱ�Ӹ�λ�ź�                                        	
	input								clk						,	//	ģ�鹤��ʱ���ź�
	input								rst						,	//	clkʱ���򣬸�λ
	                                                        	
	//	�����ź�                                            	
	input								i_uart_rx				,	//	�첽ʱ���򣬴��ڽ�����
	output								o_uart_tx				,	//	clkʱ���򣬴��ڷ�����

//	input	[UART_DATA_WID		-1:0]	iv_rx_data				,	//	clkʱ���򣬴��ڽ�������
//	input								i_rx_data_vld			,	//	clkʱ���򣬴��ڽ���������Ч	
//	input								i_rx_busy				,	//	clkʱ���򣬴��ڽ���æµ
//	output	[UART_DATA_WID		-1:0]	ov_tx_data				,	//	clkʱ���򣬴��ڷ�������
//	output								o_tx_data_vld			,	//	clkʱ���򣬴��ڷ���������Ч
//	input								i_tx_done				,	//	clkʱ���򣬴��ڷ������
	
	//	�ڿ��ź�
	input	[DATA_WID			-1:0]	iv_mining_extranounce2	,	//	clkʱ��������ڿ�ռ�extranounce2
	input	[DATA_WID			-1:0]	iv_mining_nounce		,	//	clkʱ��������ڿ�nounce
	input								i_mining_nounce_vld		,	//	clkʱ��������ڿ�nounce��Ч
	input								i_mining_nounce_full	,	//	clkʱ��������ڿ�ռ�nounce����
	output								o_mining_en				,	//	clkʱ���������ڿ�ʹ��
	output	[MINING_DATA_WID	-1:0]	ov_mining_data			,	//	clkʱ���������ڿ�����
	output	[TARGET_WID			-1:0]	ov_mining_target		,	//	clkʱ���������ڿ�Ŀ��
	output	[DATA_WID			-1:0]	ov_mining_extranounce2		//	clkʱ���������ڿ�ռ�extranounce2
	);
	
	
	//  ===============================================================================================
	//	�������źš�����˵��
	//  ===============================================================================================
	//  -------------------------------------------------------------------------------------
	//	����˵��
	//  -------------------------------------------------------------------------------------
	//	-----------------------------------------------------------------
	//	������λ��
	//	����16��λ����4��log2(16)=4
	//	-----------------------------------------------------------------
	function integer log2;
		
		//	�����ź�
		input	integer	data;
		
		//	�������� 
		integer data_tmp;
		
		//	�������  
		begin
			data_tmp = data - 1;
			for (log2=0; data_tmp>0; log2=log2+1) begin
				data_tmp = data_tmp >> 1;
			end
		end
	endfunction
	
	//  -------------------------------------------------------------------------------------
	//	����˵��
	//  -------------------------------------------------------------------------------------
	localparam	RX_DATA_CNT_NUM 	= (UART_DATA_WID + MINING_DATA_WID + DATA_WID + TARGET_WID) / UART_DATA_WID	;	//	���ڽ������ݼ���������������8bit���� + 608bit�ڿ����� + 32bitExtraNounce2 + 8bit�ڿ�Ŀ��
	localparam	RX_DATA_CNT_WID 	= log2(RX_DATA_CNT_NUM)														;	//	���ڽ������ݼ�����λ��
	localparam	MINING_PARAM_WID	= MINING_DATA_WID + DATA_WID + TARGET_WID									;	//	�ڿ����λ��	
	localparam	MINING_CTRL_RESTART	= 8'h01																		;	//	�ڿ����������¿�ʼ
	localparam	MINING_CTRL_MERKLE	= 8'h02																		;	//	�ڿ�������Ĭ�˶���
	localparam	TX_DATA_CNT_NUM		= (2 * DATA_WID + UART_DATA_WID) / UART_DATA_WID + 1						;	//	���ڷ������ݼ���������������8bit���� + 32bitNounce + 32bitExtraNounce2
	localparam	TX_DATA_CNT_WID		= log2(TX_DATA_CNT_NUM)														;	//	���ڷ������ݼ�����λ��
	localparam	RESTART_DLY_NUM		= 5																			;	//	�ڿ�ǿ�����¿�ʼ��չ5��
	
	//  -------------------------------------------------------------------------------------
	//	�ź�˵��
	//  -------------------------------------------------------------------------------------
	//	�����ź�	
	reg									tx_busy_dly				= 1'b0	;	//	clkʱ���򣬴��ڷ���æµ����1��	
	reg		[RESTART_DLY_NUM	-1:0]	mining_restart_dly		= 'b0	;	//	clkʱ�����ڿ�ǿ�����¿�ʼ����5��
	reg									nounce_fifo_rd_en_dly	= 1'b0	;	//	clkʱ�����ڿ����FIFO��ʹ�ܣ���1��
	wire								tx_busy_rise					;	//	clkʱ���򣬴��ڷ���æµ��������
	
	//	�����ź�
	wire	[UART_DATA_WID		-1:0]	rx_data							;	//	clkʱ���򣬴��ڽ�������
	wire								rx_data_vld						;	//	clkʱ���򣬴��ڽ���������Ч
	wire								rx_busy							;	//	clkʱ���򣬴��ڽ���æµ
	reg		[UART_DATA_WID		-1:0]	tx_data							;	//	clkʱ���򣬴��ڷ�������
	wire								tx_data_vld						;	//	clkʱ���򣬴��ڷ���������Ч
	wire								tx_done							;	//	clkʱ���򣬴��ڷ������
	
	//	���ڽ������ݴ����ź�
	reg		[RX_DATA_CNT_WID	-1:0]	rx_data_cnt				= 'b0	;	//	clkʱ���򣬴��ڽ������ݼ���
	reg		[UART_DATA_WID		-1:0]	mining_ctrl				= 'b0	;	//	clkʱ�����ڿ����
	reg		[MINING_PARAM_WID	-1:0]	mining_param			= 'b0	;	//	clkʱ�����ڿ����
	reg									mining_restart			= 1'b0	;	//	clkʱ�����ڿ�ǿ�����¿�ʼ
	
	wire								mining_restart_extend			;	//	clkʱ�����ڿ�ǿ�����¿�ʼ��չ
	reg									param_fifo_wr_en		= 1'b0	;	//	clkʱ�����ڿ����FIFOдʹ��
	wire	[MINING_PARAM_WID	-1:0]	param_fifo_wr_data				;	//	clkʱ�����ڿ����FIFOд����
	wire								param_fifo_rd_en				;	//	clkʱ�����ڿ����FIFO��ʹ��
	wire	[MINING_PARAM_WID	-1:0]	param_fifo_rd_data				;	//	clkʱ�����ڿ����FIFO������
	wire								param_fifo_rst					;	//	clkʱ�����ڿ����FIFO��λ
	wire								param_fifo_empty				;	//	clkʱ�����ڿ����FIFO��
	
	//	���ڷ������ݴ����ź�
	wire										nounce_fifo_wr_en			;	//	clkʱ�����ڿ���FIFOдʹ��
	wire	[(2*DATA_WID+UART_DATA_WID)	-1:0]	nounce_fifo_wr_data			;	//	clkʱ�����ڿ���FIFOд����
	wire										nounce_fifo_rd_en			;	//	clkʱ�����ڿ���FIFO��ʹ��
	wire	[(2*DATA_WID+UART_DATA_WID)	-1:0]	nounce_fifo_rd_data			;	//	clkʱ�����ڿ���FIFO������
	wire										nounce_fifo_empty			;	//	clkʱ�����ڿ���FIFO��
	wire										nounce_fifo_rst				;	//	clkʱ�����ڿ���FIFO��λ
	reg											tx_busy				= 1'b0	;	//	clkʱ���򣬴��ڷ���æµ
	reg		[TX_DATA_CNT_WID			-1:0]	tx_data_cnt			= 'b0	;	//	clkʱ���򣬴��ڷ������ݼ���
		
		
	//  ===============================================================================================
	//	�����ź�
	//  ===============================================================================================	
	//  -------------------------------------------------------------------------------------
	//	�źŴ���
	//  -------------------------------------------------------------------------------------
	always @ (posedge clk) begin
		tx_busy_dly <= tx_busy;
		mining_restart_dly <= {mining_restart_dly, mining_restart};
		nounce_fifo_rd_en_dly <= nounce_fifo_rd_en;
	end
	
	//  -------------------------------------------------------------------------------------
	//	�ź��������½���
	//  -------------------------------------------------------------------------------------
	assign tx_busy_rise = ((tx_busy == 1'b1) && (tx_busy_dly == 1'b0)) ? 1'b1 : 1'b0;
	
	
	//  ===============================================================================================
	//	����ģ������
	//  ===============================================================================================	
	//  -------------------------------------------------------------------------------------
	//	���ڽ���ģ������
	//  -------------------------------------------------------------------------------------
	uart_rx # (
		.IS_SIM				(IS_SIM				),	//	�Ƿ�Ϊ������ԣ�"TRUE" "FALSE"
		.BAUD_RATE			(BAUD_RATE			),	//	�����ʣ�"9600" "115200"
		.UART_DATA_WID		(UART_DATA_WID		),	//	��������λ��8
		.UART_RX_DATA_NUM	(RX_DATA_CNT_NUM	)	//	���ڽ��������ܸ�����82
	)                                                       	
	uart_rx_inst (                                                       	
		.clk				(clk				),	//	ģ�鹤��ʱ���ź�
		.rst				(rst				),	//	clkʱ���򣬸�λ
		.i_rx				(i_uart_rx			),	//	clkʱ���򣬴��ڽ�����
		.ov_rx_data			(rx_data			),	//	clkʱ���򣬴��ڽ�������
		.o_rx_data_vld		(rx_data_vld		),	//	clkʱ���򣬴��ڽ���������Ч	
		.o_rx_busy			(rx_busy			)	//	clkʱ���򣬴��ڽ���æµ
	);
	
	//  -------------------------------------------------------------------------------------
	//	���ڷ���ģ������
	//  -------------------------------------------------------------------------------------
	uart_tx # (
		.IS_SIM				(IS_SIM			),	//	�Ƿ�Ϊ������ԣ�"TRUE" "FALSE"
		.BAUD_RATE			(BAUD_RATE		),	//	�����ʣ�"9600" "115200"
		.UART_DATA_WID		(UART_DATA_WID	)	//	��������λ��8
	)                                                       	
	uart_tx_inst (                                                       	
		.clk				(clk			),	//	ģ�鹤��ʱ���ź�
		.rst				(rst			),	//	clkʱ���򣬸�λ
		.iv_tx_data			(tx_data		),	//	clkʱ���򣬴��ڷ�������
		.i_tx_data_vld		(tx_data_vld	),	//	clkʱ���򣬴��ڷ���������Ч
		.o_tx				(o_uart_tx		),	//	clkʱ���򣬴��ڷ�����
		.o_tx_done			(tx_done		)	//	clkʱ���򣬴��ڷ������
	);
	
	
	//  ===============================================================================================
	//	���ڽ������ݴ���
	//  ===============================================================================================	
	//  -------------------------------------------------------------------------------------
	//	���ڽ������ݼ���
	//  -------------------------------------------------------------------------------------
	always @ (posedge clk) begin
		
		//	��λ
		if(rst) begin
			rx_data_cnt	<= 'b0;
		end
		
		//	���յ���Ч�Ĵ������ݣ������
		else if(rx_data_vld) begin
			
			//	���������ֵ��������
			if(rx_data_cnt >= (RX_DATA_CNT_NUM - 1'b1)) begin
				rx_data_cnt	<= 'b0;
			end
			
			//	�����ۼ�һ
			else begin
				rx_data_cnt	<= rx_data_cnt + 1'b1;
			end
		end
	end
	
	//  -------------------------------------------------------------------------------------
	//	�ڿ����
	//  -------------------------------------------------------------------------------------
	always @ (posedge clk) begin
		
		//	��λ
		if(rst) begin
			mining_ctrl	<= 'b0;
		end
		
		//	һ�����������У����ڽ��յĵ�1������Ϊ�ڿ��������
		else if((rx_data_vld == 1'b1) && (rx_data_cnt == 'b0)) begin
			mining_ctrl	<= rx_data;
		end
	end
	
	//  -------------------------------------------------------------------------------------
	//	�ڿ����
	//	Ŀǰ����Ϊ��˴��䣬���ȴ����ʱ��λ������
	//  -------------------------------------------------------------------------------------
	always @ (posedge clk) begin
		
		//	��λ
		if(rst) begin
			mining_param <= 'b0;
		end
		
		//	һ�����������У����˴��ڽ��յĵ�1�����ݣ������Ϊ�ڿ����
		else if((rx_data_vld == 1'b1) && (rx_data_cnt != 'b0)) begin
			mining_param <= {mining_param, rx_data};
		end
	end
	
	//  -------------------------------------------------------------------------------------
	//	�ڿ����¿�ʼ
	//  -------------------------------------------------------------------------------------
	always @ (posedge clk) begin
		
		//	��λ
		if(rst) begin
			mining_restart <= 1'b0;
		end
		
		//	�����ڿ���ƣ����������ڿ����Ϊǿ�����¿�ʼ�ڿ������һ���������䣬�����FIFO
		else if((mining_ctrl == MINING_CTRL_RESTART) && ((rx_data_vld == 1'b1) && (rx_data_cnt >= (RX_DATA_CNT_NUM - 1'b1)))) begin
			mining_restart <= 1'b1;
		end
		
		//	���ø�һ��ʱ������
		else begin
			mining_restart <= 1'b0;
		end
	end
	
	//  -------------------------------------------------------------------------------------
	//	�ڿ����FIFOдʹ��
	//  -------------------------------------------------------------------------------------
	always @ (posedge clk) begin
		
		//	��λ
		if(rst) begin
			param_fifo_wr_en <= 1'b0;
		end
		
		//	�����ڿ���ƣ����������ڿ����Ϊ�µ�Ĭ�˶����������һ���������䣬�����FIFO
		else if((mining_ctrl == MINING_CTRL_MERKLE) && ((rx_data_vld == 1'b1) && (rx_data_cnt >= (RX_DATA_CNT_NUM - 1'b1)))) begin
			param_fifo_wr_en <= 1'b1;
		end
		
		//	���ø�һ��ʱ������
		else begin
			param_fifo_wr_en <= 1'b0;
		end
	end
	
	//  -------------------------------------------------------------------------------------
	//	�ڿ����FIFOд����
	//	���ڿ����һ��
	//  -------------------------------------------------------------------------------------
	assign param_fifo_wr_data = mining_param;
	
	//  -------------------------------------------------------------------------------------
	//	�ڿ����FIFO��ʹ��
	//	���ڿ����FIFO�ǿգ����ڿ�ռ�����ʱ����ȡ�µ��ڿ����
	//  -------------------------------------------------------------------------------------
	assign param_fifo_rd_en = ((param_fifo_empty == 1'b0) && (i_mining_nounce_full == 1'b1)) ? 1'b1 : 1'b0;
	
	//  -------------------------------------------------------------------------------------
	//	�ڿ����FIFO��λ
	//	ģ�鸴λ��������ǿ�����¿�ʼ�ڿ�ʱ����ʱFIFO�д��е�Ĭ�˶����Ѿ�û���ˣ����Ը�λFIFO
	//  -------------------------------------------------------------------------------------
	assign param_fifo_rst = ((rst == 1'b1) || (mining_restart == 1'b1)) ? 1'b1 : 1'b0;
	
	//  -------------------------------------------------------------------------------------
	//	����ڿ�ʹ���ź�
	//	��ǿ�����¿�ʼ�ڿ���Ч�����ڿ�ռ�������Ҫ�µ�Ĭ�˶�����FIFO�ж�ȡ����ʱ������ڿ�ʹ���ź�
	//  -------------------------------------------------------------------------------------
	assign o_mining_en = ((mining_restart == 1'b1) || (param_fifo_rd_en == 1'b1)) ? 1'b1 : 1'b0;
	
	//  -------------------------------------------------------------------------------------
	//	����ڿ����
	//	��ǿ�����¿�ʼ�ڿ���Чʱ����ֱ������ڿ����
	//	���ڿ�ռ�������Ҫ�µ�Ĭ�˶�����FIFO�ж�ȡ����ʱ��������ڿ����FIFO�ж���������
	//	���������Ч����0
	//  -------------------------------------------------------------------------------------
	assign {ov_mining_data, ov_mining_extranounce2, ov_mining_target} = (mining_restart 	== 1'b1) ? mining_param : 
																		(param_fifo_rd_en	== 1'b1) ? param_fifo_rd_data : 'b0;
	
	//  -------------------------------------------------------------------------------------
	//	�����ڿ����FIFO
	//	ͬ��FIFO��896bit��16�FWFTģʽ
	//  -------------------------------------------------------------------------------------	
	generate
	
		//	ʹ��DRAM��Դ��FIFO
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
		
		//	ʹ��BRAM��Դ��FIFO
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
	//	���ڷ������ݴ���
	//  ===============================================================================================	
	//  -------------------------------------------------------------------------------------
	//	�ڿ�ǿ�����¿�ʼ��չ
	//	�ڿ�ǿ�����¿�ʼ�ḴλFIFO����ʱ��Ҫ�ȴ��ڿ���FIFO��λ��ɣ��ſ�����ӦFIFOд������
	//  -------------------------------------------------------------------------------------
	assign mining_restart_extend = ((mining_restart == 1'b1) || (|mining_restart_dly == 1'b1)) ? 1'b1 : 1'b0;
	
	//  -------------------------------------------------------------------------------------
	//	�ڿ���FIFOдʹ��
	//	���ڿ���FIFO��λ��ɺ������µ�nounce����������ڿ�ռ������������FIFO
	//  -------------------------------------------------------------------------------------
	assign nounce_fifo_wr_en = ((mining_restart_extend == 1'b0) && ((i_mining_nounce_vld == 1'b1) || (i_mining_nounce_full == 1'b1))) ? 1'b1 : 1'b0; 
	
	//  -------------------------------------------------------------------------------------
	//	�ڿ���FIFOд����
	//	���ڿ�����ƴ�Ӻ����FIFO
	//  -------------------------------------------------------------------------------------
	assign nounce_fifo_wr_data = {{6'b0, i_mining_nounce_full, i_mining_nounce_vld}, iv_mining_nounce, iv_mining_extranounce2};
	
	//  -------------------------------------------------------------------------------------
	//	�ڿ���FIFO��ʹ��
	//	�ڴ��ڷ���æµ�����أ���FIFO�ж����µ�����
	//  -------------------------------------------------------------------------------------
	assign nounce_fifo_rd_en = tx_busy_rise;
	
	//  -------------------------------------------------------------------------------------
	//	�ڿ���FIFO��λ
	//	ģ�鸴λ�������ڿ�ǿ�����¿�ʼʱ����λFIFO
	//  -------------------------------------------------------------------------------------
	assign nounce_fifo_rst = ((rst == 1'b1) || (mining_restart == 1'b1)) ? 1'b1 : 1'b0;
	
	//  -------------------------------------------------------------------------------------
	//	���ڷ���æµ
	//	�߼�����һ������
	//  -------------------------------------------------------------------------------------
	always @ (posedge clk) begin
		
		//	��λ
		if(rst) begin
			tx_busy <= 1'b0;
		end
		
		//	�����һ���������ͺ��õ�
		else if((tx_done == 1'b1) && (tx_data_cnt == (TX_DATA_CNT_NUM - 1'b1))) begin
			tx_busy <= 1'b0;
		end
		
		//	�ڴ��ڷ��Ͳ�æµ�����ڿ���FIFO��λ��ɣ����ڿ���FIFO��������ʱ���ø�
		else if((rx_busy == 1'b0) && (mining_restart_extend == 1'b0) && (nounce_fifo_empty == 1'b0)) begin
			tx_busy <= 1'b1;
		end
	end
	
	//  -------------------------------------------------------------------------------------
	//	���ڷ������ݼ�����
	//  -------------------------------------------------------------------------------------
	always @ (posedge clk) begin
		
		//	��λ
		if(rst) begin
			tx_data_cnt <= 'b0;
		end
		
		//	��FIFO�ж������ݵĺ�һ�ģ����ߴ���ÿ�������һ�����ݣ������
		else if((nounce_fifo_rd_en_dly == 1'b1) || (tx_done == 1'b1)) begin
			
			//	���������ֵ��������
			if(tx_data_cnt >= (TX_DATA_CNT_NUM - 1'b1)) begin
				tx_data_cnt	<= 'b0;
			end
			
			//	�����ۼ�һ
			else begin
				tx_data_cnt	<= tx_data_cnt + 1'b1;
			end
		end
	end
	
	//  -------------------------------------------------------------------------------------
	//	���ڷ�������
	//	����tx_data_cnt��ȡFIFO�������еĲ������ݣ��ȷ��͸��ֽ�
	//	Ϊ�˱���vivado�ۺϳɳ˷�����ʹ��case���չ��
	//  -------------------------------------------------------------------------------------
	always @ ( * ) begin
		case(tx_data_cnt)
				
			//	tx_data_cntΪ0
			'd0	: begin
				tx_data = nounce_fifo_rd_data[(UART_DATA_WID*8) +: UART_DATA_WID];
			end
			
			//	tx_data_cntΪ1
			'd1	: begin
				tx_data = nounce_fifo_rd_data[(UART_DATA_WID*7) +: UART_DATA_WID];
			end
			
			//	tx_data_cntΪ2
			'd2	: begin
				tx_data = nounce_fifo_rd_data[(UART_DATA_WID*6) +: UART_DATA_WID];
			end
			
			//	tx_data_cntΪ3
			'd3	: begin
				tx_data = nounce_fifo_rd_data[(UART_DATA_WID*5) +: UART_DATA_WID];
			end
			
			//	tx_data_cntΪ4
			'd4	: begin
				tx_data = nounce_fifo_rd_data[(UART_DATA_WID*4) +: UART_DATA_WID];
			end
			
			//	tx_data_cntΪ5
			'd5	: begin
				tx_data = nounce_fifo_rd_data[(UART_DATA_WID*3) +: UART_DATA_WID];
			end
			
			//	tx_data_cntΪ6
			'd6	: begin
				tx_data = nounce_fifo_rd_data[(UART_DATA_WID*2) +: UART_DATA_WID];
			end
			
			//	tx_data_cntΪ7
			'd7	: begin
				tx_data = nounce_fifo_rd_data[(UART_DATA_WID*1) +: UART_DATA_WID];
			end
			
			//	tx_data_cntΪ8
			'd8	: begin
				tx_data = nounce_fifo_rd_data[(UART_DATA_WID*0) +: UART_DATA_WID];
			end
			
			//	����ֵ
			default	: begin
				tx_data = 'b0;
			end
		endcase
	end
	
	//  -------------------------------------------------------------------------------------
	//	���ڷ���������Ч
	//	���ڿ���FIFO��ʹ�ܴ�����Ч�����ߴ��ڷ�����һ��������tx_data_cnt���������ֵʱ����Ч
	//  -------------------------------------------------------------------------------------
	assign tx_data_vld = ((nounce_fifo_rd_en_dly == 1'b1) || ((tx_done == 1'b1) && (tx_data_cnt != (TX_DATA_CNT_NUM - 1'b1)))) ? 1'b1 : 1'b0;
	
	//  -------------------------------------------------------------------------------------
	//	�����ڿ���FIFO
	//	ͬ��FIFO��72bit��512�STANDARDģʽ
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
	//	ģ�鵥�������ź�����
	//  ===============================================================================================	
	//  -------------------------------------------------------------------------------------
	//	ģ�鵥�������ź�����
	//	ʵ�ʳ�����û�д˲���
	//  -------------------------------------------------------------------------------------
//	assign rx_data 			= iv_rx_data	;
//	assign rx_data_vld 		= i_rx_data_vld	;
//	assign rx_busy 			= i_rx_busy		;
//	assign ov_tx_data 		= tx_data		;
//	assign o_tx_data_vld 	= tx_data_vld	;
//	assign tx_done 			= i_tx_done		;

endmodule