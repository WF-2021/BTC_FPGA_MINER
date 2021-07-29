//	********************************************************************************
//	ģ������double_sha256_calc
//	��  �ܣ�ʹ��״̬�������ڿ���㣬����˫SHA256������ڿ����ж�
//	��	Դ��
//	********************************************************************************
module double_sha256_calc # (
	
	//	�������
	parameter		IS_SIM						= "TRUE"				,	//	�Ƿ�Ϊ������ԣ�'TRUE' "FALSE"
	parameter		MINING_DATA_WID				= 608					,	//	�ڿ�����λ��608
	parameter		HASH_WORD_NUM				= 8						,	//	��ϣֵ��WORD������8
	parameter		MESSAGE_WORD_NUM			= 16					,	//	��Ϣ���WORD������16
	parameter		DATA_WID					= 32					,	//	WORDλ��32
	parameter		TARGET_WID					= 256						//	�ڿ�Ŀ��λ��256
	)                                                           		
	(                                                           		
	                                                          		
	//	�����ź�                                                		
	input										clk						,	//	ģ�鹤��ʱ���ź�
	input										rst						,	//	clkʱ���򣬸�λ
	input										i_mining_en				,	//	clkʱ���������ڿ�ʹ��
	input	[MINING_DATA_WID			-1:0]	iv_mining_data			,	//	clkʱ���������ڿ�����
	input	[TARGET_WID					-1:0]	iv_mining_target		,	//	clkʱ���������ڿ�Ŀ��
	input	[DATA_WID					-1:0]	iv_mining_extranounce2	,	//	clkʱ���������ڿ�ռ�extranounce2
	                                                            	
	//	����ź�                                                	
	output	[DATA_WID					-1:0]	ov_mining_extranounce2	,	//	clkʱ��������ڿ�ռ�extranounce2
	output	[DATA_WID					-1:0]	ov_mining_nounce		,	//	clkʱ��������ڿ�nounce
	output										o_mining_nounce_vld		,	//	clkʱ��������ڿ�nounce��Ч
	output										o_mining_nounce_full		//	clkʱ��������ڿ�ռ�nounce����
	);
	
	
	//  ===============================================================================================
	//	�������źš�����˵��
	//  ===============================================================================================
	//  -------------------------------------------------------------------------------------
	//	����˵��
	//  -------------------------------------------------------------------------------------
	localparam	S_IDLE			= 3'b001													;	//	��ʼ״̬
	localparam	S_CALC_0		= 3'b010													;	//	��һ��SHA256���㣬��һ�׶�״̬
	localparam	S_CALC_1		= 3'b100													;	//	��һ��SHA256���㣬�ڶ��׶�״̬
	localparam	EXTEND_BIT_1	= {1'b1, 319'b0, 64'd640}									;	//	��һ��SHA256��λ
	localparam	EXTEND_BIT_2	= {1'b1, 191'b0, 64'd256}									;	//	�ڶ���SHA256��λ
	localparam	NOUNCE_INIT		= (IS_SIM == "TRUE") ? {{(25){1'b1}}, 7'b0} : 'b0			;	//	�ڿ�ռ�nounce��ʼֵ
//	localparam	NOUNCE_INIT		= (IS_SIM == "TRUE") ? 32'h008b6000 : 'b0					;	//	�ڿ�ռ�nounce��ʼֵ
	localparam	HASH_INITIAL	= {32'h6a09e667, 32'hbb67ae85, 32'h3c6ef372, 32'ha54ff53a, 
								   32'h510e527f, 32'h9b05688c, 32'h1f83d9ab, 32'h5be0cd19}	;	//	��ʼhashֵ
	localparam	HASH_BYTE_NUM	= HASH_WORD_NUM * DATA_WID / 8								;	//	��ϣֵ��BYTE������32
	localparam	BYTE_WID		= 8															;	//	BYTE��λ��8
		
	//  -------------------------------------------------------------------------------------
	//	�ź�˵��
	//  -------------------------------------------------------------------------------------
	//	״̬������ź�
	reg		[128						-1:0]	state_ascii								;	//	״̬��ASCII���ʾ
	reg		[3							-1:0]	current_state			= S_IDLE		;	//	��ǰ״̬
	reg		[3							-1:0]	next_state				= S_IDLE		;	//	��һ״̬
	wire										rst_mining								;	//	clkʱ�����ڿ�λ
	reg											mining_en				= 1'b0			;	//	clkʱ�����ڿ�ʹ��	
	reg		[MINING_DATA_WID			-1:0]	mining_data_reg			= 'b0			;	//	clkʱ�����ڿ���������
	reg		[DATA_WID					-1:0]	nounce					= 'b0			;	//	clkʱ�����ڿ�ռ�nounce
	                                                                	            	
	//	SHA256����ģ������ź�                                                      	
	reg		[MESSAGE_WORD_NUM*DATA_WID	-1:0]	message_0								;	//	clkʱ������Ϣ��M
	reg											message_vld_0			= 1'b0			;	//	clkʱ������Ϣ��M��Ч
	reg		[HASH_WORD_NUM*DATA_WID		-1:0]	hash_init_0				= HASH_INITIAL	;	//	clkʱ���򣬳�ʼhash
	reg											hash_init_vld_0			= 1'b0			;	//	clkʱ���򣬳�ʼhash��Ч
	wire	[HASH_WORD_NUM*DATA_WID		-1:0]	sha256_result_0							;	//	clkʱ����SHA256������
	wire										sha256_result_vld_0						;	//	clkʱ����SHA256��������Ч
	wire	[MESSAGE_WORD_NUM*DATA_WID	-1:0]	message_1								;	//	clkʱ������Ϣ��M
	wire										message_vld_1							;	//	clkʱ������Ϣ��M��Ч
	wire	[HASH_WORD_NUM*DATA_WID		-1:0]	hash_init_1								;	//	clkʱ���򣬳�ʼhash
	reg											hash_init_vld_1			= 1'b0			;	//	clkʱ���򣬳�ʼhash��Ч
	wire	[HASH_WORD_NUM*DATA_WID		-1:0]	double_sha256							;	//	clkʱ����SHA256������
	wire										double_sha256_vld						;	//	clkʱ����SHA256��������Ч
	reg											double_sha256_vld_dly	= 1'b0			;	//	clkʱ����SHA256��������Ч����1��
	wire										double_sha256_vld_fall					;	//	clkʱ����SHA256��������Ч���½���
	                                                                            		
	//	�ڿ����ж�����ź�                                                    		
	reg		[TARGET_WID					-1:0]	mining_target_reg		= 'b0			;	//	clkʱ�����ڿ�Ŀ������
	reg		[DATA_WID					-1:0]	mining_extranounce2		= 'b0			;	//	clkʱ�����ڿ�ռ�extranounce2����
	reg		[DATA_WID					-1:0]	mining_nounce			= 'b0			;	//	clkʱ�����ڿ�ռ�nounce
	reg											mining_nounce_vld						;	//	clkʱ�����ڿ�ռ�nounce��Ч
	wire	[HASH_WORD_NUM*DATA_WID		-1:0]	work_proof								;	//	clkʱ�����ڿ���֤��
	
	
	//  ===============================================================================================
	//	˫SHA256״̬��
	//  ===============================================================================================	
	//  -------------------------------------------------------------------------------------
	//	״̬��ASCII��ʾ��ʵ�ʹ����лᱻ�ۺϵ�
	//  -------------------------------------------------------------------------------------
	always @ ( * ) begin
		case(current_state)
			3'b001	: state_ascii	= "S_IDLE"	;
			3'b010	: state_ascii	= "S_CALC_0";
			3'b100	: state_ascii	= "S_CALC_1";
			default	: state_ascii	= "ERROR"	;
		endcase
	end

	//  -------------------------------------------------------------------------------------
	//	����ʽ״̬������һ��
	//  -------------------------------------------------------------------------------------
	always @ (posedge clk) begin
		if(rst) begin
			current_state <= S_IDLE;
		end
		else begin
			current_state <= next_state;
		end
	end

	//  -------------------------------------------------------------------------------------
	//	����ʽ״̬�����ڶ���
	//  -------------------------------------------------------------------------------------
	always @ ( * ) begin
		case(current_state)
			
			//	S_IDLE״̬
			S_IDLE	: begin
				
				//	S_IDLE -> S_IDLE
				//	�ڿ�λ
				if(rst_mining) begin
					next_state	= S_IDLE;
				end
				
				//	S_IDLE -> S_CALC_0
				//	�ڿ�ʹ����Ч����ʼ�ڿ�
				else if(mining_en) begin
					next_state	= S_CALC_0;
				end
				
				//	S_IDLE -> S_IDLE
				else begin
					next_state	= S_IDLE;
				end
			end
	
			//	S_CALC_0״̬
			S_CALC_0	: begin
				
				//	S_CALC_0 -> S_IDLE
				//	�ڿ�λ
				if(rst_mining) begin
					next_state	= S_IDLE;
				end
				
				//	S_CALC_0 -> S_CALC_1
				//	�õ���һ��SHA256������
				else if(sha256_result_vld_0) begin
					next_state	= S_CALC_1;
				end
				
				//	S_CALC_0 -> S_CALC_0
				else begin
					next_state	= S_CALC_0;
				end
			end		
	
			//	S_CALC_1״̬
			S_CALC_1	: begin
	    	
				//	S_CALC_1 -> S_IDLE
				//	�ڿ�λ�����ߵõ��ڶ���SHA256��������
				if((rst_mining == 1'b1) || (double_sha256_vld_fall == 1'b1)) begin
					next_state	= S_IDLE;
				end
				
				//	S_SHA_12 -> S_SHA_12
				else begin
					next_state	= S_CALC_1;
				end
			end
			
			//	����״̬
			default	: begin
				next_state	= S_IDLE;
			end
		endcase
	end

	//  -------------------------------------------------------------------------------------
	//	����ʽ״̬���������Σ�������߼�
	//  -------------------------------------------------------------------------------------
	//  -------------------------------------------------------------------------------------
	//	�ڿ�λ
	//	�������ڿ�ʹ��ʱ����λ��������
	//  -------------------------------------------------------------------------------------
	assign rst_mining = i_mining_en;
	
	//  -------------------------------------------------------------------------------------
	//	�ڿ�ʹ��
	//	���ڿ�λ�󣬿�ʼ�µ��ڿ����
	//  -------------------------------------------------------------------------------------
	always @ (posedge clk) begin
		mining_en <= rst_mining;
	end
	
	//  -------------------------------------------------------------------------------------
	//	�ڿ���������
	//  -------------------------------------------------------------------------------------
	always @ (posedge clk) begin
		
		//	�µ��ڿ�ʼ���������ڿ�����
		if(i_mining_en) begin
			mining_data_reg <= iv_mining_data;
		end
	end
	
	//  -------------------------------------------------------------------------------------
	//	�ڿ�ռ�nounce
	//  -------------------------------------------------------------------------------------
	always @ (posedge clk) begin
		
		//	ģ�鸴λ�����ڿ�λ
		if((rst == 1'b1) || (rst_mining == 1'b1)) begin
			nounce <= NOUNCE_INIT;
		end
		
		//	��S_CALC_1״̬������Ϣ��M_0��Ч��ѭ����һ����
		else if((current_state == S_CALC_1) && (message_vld_0 == 1'b1)) begin
			nounce <= nounce + 1'b1;
		end
	end
	
	
	//  ===============================================================================================
	//	sha256����ģ��0�����ܵ�һ��SHA256����
	//  ===============================================================================================
	//  -------------------------------------------------------------------------------------
	//	�ڿ���Ϣ��M_0
	//  -------------------------------------------------------------------------------------
	always @ ( * ) begin
		case(current_state)
							
			//	S_CALC_0״̬��׼����һ��SHA256���㣬�ڿ����ݸ�512bit��Ϊ��Ϣ��M
			S_CALC_0: begin
				message_0 = mining_data_reg[(MINING_DATA_WID-1) -: 512];
			end
			
			//	S_CALC_1״̬��׼���ڶ���SHA256���㣬�ڿ����ݵ�96bit��λ��Ϊ��Ϣ��M
			S_CALC_1: begin
				message_0 = {mining_data_reg[95 : 0], nounce, EXTEND_BIT_1};
			end
			
			//	����״̬��
			default	: begin
				message_0 = 'b0;
			end
		endcase
	end
	
	//  -------------------------------------------------------------------------------------
	//	�ڿ���Ϣ��M_0��Ч
	//  -------------------------------------------------------------------------------------
	always @ (posedge clk) begin
		
		//	ģ�鸴λ�����ڿ�λ
		if((rst == 1'b1) || (rst_mining == 1'b1)) begin
			message_vld_0 <= 1'b0;
		end
		
		//	���ڿ�ʹ����Ч������S_CALC_0->S_CALC_1�����ø�
		else if((mining_en == 1'b1) || ((current_state == S_CALC_0) && (sha256_result_vld_0 == 1'b1))) begin
			message_vld_0 <= 1'b1;
		end
		
		//	��S_SHA_11��message_vldΪ�ߣ�����nounce���㵽���ֵ�����õ�
		else if(((current_state == S_CALC_0) && (message_vld_0 == 1'b1)) || (nounce == {(DATA_WID){1'b1}})) begin
			message_vld_0 <= 1'b0;
		end
	end
	
	//  -------------------------------------------------------------------------------------
	//	��ʼhash_0
	//  -------------------------------------------------------------------------------------
	always @ (posedge clk) begin
		
		//	S_CALC_0->S_CALC_1״̬ʱ�������һ��SHA256������
		if((current_state == S_CALC_0) && (sha256_result_vld_0 == 1'b1)) begin
			hash_init_0 <= sha256_result_0;
		end
		
		//	S_CALC_0->S_CALC_1״̬ʱ������س�ʼhash
		else if((current_state == S_CALC_1) && (double_sha256_vld_fall == 1'b1)) begin
			hash_init_0 = HASH_INITIAL;
		end
	end
	
	//  -------------------------------------------------------------------------------------
	//	��ʼhash_0��Ч
	//  -------------------------------------------------------------------------------------
	always @ (posedge clk) begin
		
		//	ģ�鸴λ�����ڿ�λ
		if((rst == 1'b1) || (rst_mining == 1'b1)) begin
			hash_init_vld_0 <= 1'b0;
		end
		
		//	�ڿ���Ϣ��M��Ч����1��
		else begin
			hash_init_vld_0 <= message_vld_0;
		end
	end
	
	//  -------------------------------------------------------------------------------------
	//	˫SHA256�����Ч�ź��½���
	//  -------------------------------------------------------------------------------------
	always @ (posedge clk) begin
		double_sha256_vld_dly <= double_sha256_vld;
	end
	
	assign double_sha256_vld_fall = ((double_sha256_vld == 1'b0) && (double_sha256_vld_dly == 1'b1)) ? 1'b1 : 1'b0;	
	
	
	//  ===============================================================================================
	//	sha256����ģ��1�����ܵڶ���SHA256����
	//  ===============================================================================================
	//  -------------------------------------------------------------------------------------
	//	�ڿ���Ϣ��M_1
	//	��sha256����ģ��0������һ��
	//  -------------------------------------------------------------------------------------
	assign message_1 = {sha256_result_0, EXTEND_BIT_2};
	
	//  -------------------------------------------------------------------------------------
	//	�ڿ���Ϣ��M_1��Ч
	//	��CALC_1״̬����sha256����ģ��0��������Ч�ź�һ��
	//  -------------------------------------------------------------------------------------
	assign message_vld_1 = (current_state == S_CALC_1) ? sha256_result_vld_0 : 1'b0;
	
	//  -------------------------------------------------------------------------------------
	//	��ʼhash_1
	//	��Ϊ�ڶ���SHA256����ֻ��һ����Ϣ�飬����֮��Ϊ��ʼHASH
	//  -------------------------------------------------------------------------------------
	assign hash_init_1 = HASH_INITIAL;
	
	//  -------------------------------------------------------------------------------------
	//	��ʼhash_1��Ч
	//  -------------------------------------------------------------------------------------
	always @ (posedge clk) begin
		
		//	ģ�鸴λ�����ڿ�λ
		if((rst == 1'b1) || (rst_mining == 1'b1)) begin
			hash_init_vld_1 <= 1'b0;
		end
		
		//	�ڿ���Ϣ��M��Ч����1��
		else begin
			hash_init_vld_1 <= message_vld_1;
		end
	end
	

	//  ===============================================================================================
	//	����sha256����ģ��
	//  ===============================================================================================
	//  -------------------------------------------------------------------------------------
	//	SHA256����ģ��0����һ��SHA256����
	//  -------------------------------------------------------------------------------------
	sha256_calc # (
		.HASH_WORD_NUM			(HASH_WORD_NUM			),	//	��ϣֵ��WORD������8
		.MESSAGE_WORD_NUM		(MESSAGE_WORD_NUM		),	//	��Ϣ���WORD������16
		.DATA_WID				(DATA_WID				)	//	WORDλ��32
	)                       	                    	
	sha256_calc_inst0 (       	                    	
		.clk					(clk					),	//	ģ�鹤��ʱ���ź�
		.rst					(rst | rst_mining		),	//	clkʱ���򣬸�λ
		.iv_h_data				(hash_init_0			),	//	clkʱ���������ʼhash
		.i_h_data_vld			(hash_init_vld_0		),	//	clkʱ���������ʼhash��Ч
		.iv_m_data				(message_0				),	//	clkʱ����������Ϣ��M
		.i_m_data_vld			(message_vld_0			),	//	clkʱ����������Ϣ��M��Ч
		.ov_sha256_data			(sha256_result_0		),	//	clkʱ�������sha256
		.o_sha256_data_vld		(sha256_result_vld_0	)	//	clkʱ�������sha256��Ч
	);
	
	//  -------------------------------------------------------------------------------------
	//	SHA256����ģ��1���ڶ���SHA256����
	//  -------------------------------------------------------------------------------------
	sha256_calc # (
		.HASH_WORD_NUM			(HASH_WORD_NUM			),	//	��ϣֵ��WORD������8
		.MESSAGE_WORD_NUM		(MESSAGE_WORD_NUM		),	//	��Ϣ���WORD������16
		.DATA_WID				(DATA_WID				)	//	WORDλ��32
	)                       	                    	
	sha256_calc_inst1 (       	                    	
		.clk					(clk					),	//	ģ�鹤��ʱ���ź�
		.rst					(rst | rst_mining		),	//	clkʱ���򣬸�λ
		.iv_h_data				(hash_init_1			),	//	clkʱ���������ʼhash
		.i_h_data_vld			(hash_init_vld_1		),	//	clkʱ���������ʼhash��Ч
		.iv_m_data				(message_1				),	//	clkʱ����������Ϣ��M
		.i_m_data_vld			(message_vld_1			),	//	clkʱ����������Ϣ��M��Ч
		.ov_sha256_data			(double_sha256			),	//	clkʱ�������sha256
		.o_sha256_data_vld		(double_sha256_vld		)	//	clkʱ�������sha256��Ч
	);
	
	
	//  ===============================================================================================
	//	�ڿ����ж�
	//  ===============================================================================================	
	//  -------------------------------------------------------------------------------------
	//	�ڿ�ռ�nounce���
	//	������ڿ�ռ���Ҫ��С��ת��
	//  -------------------------------------------------------------------------------------
	always @ (posedge clk) begin
		
		//	ģ�鸴λ�����ڿ�λ
		if((rst == 1'b1) || (rst_mining == 1'b1)) begin
			mining_nounce <= NOUNCE_INIT;
		end
		
		//	��˫SHA256��Чʱ��ѭ����һ����
		else if(double_sha256_vld) begin
			mining_nounce <= mining_nounce + 1'b1;
		end
	end
	
	assign ov_mining_nounce = {mining_nounce[7:0], mining_nounce[15:8], mining_nounce[23:16], mining_nounce[31:24]};
	
	//  -------------------------------------------------------------------------------------
	//	�ڿ�ռ�extranounce2���桢���
	//  -------------------------------------------------------------------------------------
	always @ (posedge clk) begin
		
		//	�µ��ڿ�ʼ���������ڿ�ռ�extranounce2
		if(i_mining_en) begin
			mining_extranounce2 <= iv_mining_extranounce2;
		end
	end
	
	assign ov_mining_extranounce2 = mining_extranounce2;
	
	//  -------------------------------------------------------------------------------------
	//	�ڿ�Ŀ��ֵ����
	//  -------------------------------------------------------------------------------------
	always @ (posedge clk) begin
		
		//	�µ��ڿ�ʼ���������ڿ�Ŀ��ֵ
		if(i_mining_en) begin
			mining_target_reg <= iv_mining_target;
		end
	end
	
	//  -------------------------------------------------------------------------------------
	//	�ڿ���֤��
	//	��˫SHA256�����8bitΪ��λ�����д�С��ת��
	//  -------------------------------------------------------------------------------------
	genvar i;	
	generate
		for(i=0; i<HASH_BYTE_NUM; i=i+1) begin : work_proof_loop
			assign work_proof[(BYTE_WID*i) +: BYTE_WID] = double_sha256[(BYTE_WID*(HASH_BYTE_NUM-1-i)) +: BYTE_WID];
		end
	endgenerate
	
	//  -------------------------------------------------------------------------------------
	//	�ڿ�����Ч
	//  -------------------------------------------------------------------------------------
	always @ ( * ) begin
		
		//	˫SHA256�����Ч����С�ڵ���Ŀ�꣬����֤����Ч
		if((double_sha256_vld == 1'b1) && (mining_target_reg >= work_proof)) begin
			mining_nounce_vld = 1'b1;
		end
		
		//	������֤����Ч
		else begin
			mining_nounce_vld = 1'b0;
		end
	end
	
	assign o_mining_nounce_vld = mining_nounce_vld;
	
	//  -------------------------------------------------------------------------------------
	//	�ڿ�ռ�nounce����
	//	��˫SHA256�����Ч�½���һ��
	//  -------------------------------------------------------------------------------------
	assign o_mining_nounce_full = double_sha256_vld_fall;
	
endmodule