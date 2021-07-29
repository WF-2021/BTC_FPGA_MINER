//	********************************************************************************
//	模块名：double_sha256_calc
//	功  能：使用状态机进行挖矿计算，包括双SHA256计算和挖矿结果判断
//	资	源：
//	********************************************************************************
module double_sha256_calc # (
	
	//	输入参数
	parameter		IS_SIM						= "TRUE"				,	//	是否为仿真测试，'TRUE' "FALSE"
	parameter		MINING_DATA_WID				= 608					,	//	挖矿数据位宽，608
	parameter		HASH_WORD_NUM				= 8						,	//	哈希值的WORD个数，8
	parameter		MESSAGE_WORD_NUM			= 16					,	//	消息块的WORD个数，16
	parameter		DATA_WID					= 32					,	//	WORD位宽，32
	parameter		TARGET_WID					= 256						//	挖矿目标位宽，256
	)                                                           		
	(                                                           		
	                                                          		
	//	输入信号                                                		
	input										clk						,	//	模块工作时钟信号
	input										rst						,	//	clk时钟域，复位
	input										i_mining_en				,	//	clk时钟域，输入挖矿使能
	input	[MINING_DATA_WID			-1:0]	iv_mining_data			,	//	clk时钟域，输入挖矿数据
	input	[TARGET_WID					-1:0]	iv_mining_target		,	//	clk时钟域，输入挖矿目标
	input	[DATA_WID					-1:0]	iv_mining_extranounce2	,	//	clk时钟域，输入挖矿空间extranounce2
	                                                            	
	//	输出信号                                                	
	output	[DATA_WID					-1:0]	ov_mining_extranounce2	,	//	clk时钟域，输出挖矿空间extranounce2
	output	[DATA_WID					-1:0]	ov_mining_nounce		,	//	clk时钟域，输出挖矿nounce
	output										o_mining_nounce_vld		,	//	clk时钟域，输出挖矿nounce有效
	output										o_mining_nounce_full		//	clk时钟域，输出挖矿空间nounce已满
	);
	
	
	//  ===============================================================================================
	//	参数、信号、函数说明
	//  ===============================================================================================
	//  -------------------------------------------------------------------------------------
	//	参数说明
	//  -------------------------------------------------------------------------------------
	localparam	S_IDLE			= 3'b001													;	//	初始状态
	localparam	S_CALC_0		= 3'b010													;	//	第一轮SHA256计算，第一阶段状态
	localparam	S_CALC_1		= 3'b100													;	//	第一轮SHA256计算，第二阶段状态
	localparam	EXTEND_BIT_1	= {1'b1, 319'b0, 64'd640}									;	//	第一轮SHA256补位
	localparam	EXTEND_BIT_2	= {1'b1, 191'b0, 64'd256}									;	//	第二轮SHA256补位
	localparam	NOUNCE_INIT		= (IS_SIM == "TRUE") ? {{(25){1'b1}}, 7'b0} : 'b0			;	//	挖矿空间nounce初始值
//	localparam	NOUNCE_INIT		= (IS_SIM == "TRUE") ? 32'h008b6000 : 'b0					;	//	挖矿空间nounce初始值
	localparam	HASH_INITIAL	= {32'h6a09e667, 32'hbb67ae85, 32'h3c6ef372, 32'ha54ff53a, 
								   32'h510e527f, 32'h9b05688c, 32'h1f83d9ab, 32'h5be0cd19}	;	//	初始hash值
	localparam	HASH_BYTE_NUM	= HASH_WORD_NUM * DATA_WID / 8								;	//	哈希值的BYTE个数，32
	localparam	BYTE_WID		= 8															;	//	BYTE的位宽，8
		
	//  -------------------------------------------------------------------------------------
	//	信号说明
	//  -------------------------------------------------------------------------------------
	//	状态机相关信号
	reg		[128						-1:0]	state_ascii								;	//	状态机ASCII码表示
	reg		[3							-1:0]	current_state			= S_IDLE		;	//	当前状态
	reg		[3							-1:0]	next_state				= S_IDLE		;	//	下一状态
	wire										rst_mining								;	//	clk时钟域，挖矿复位
	reg											mining_en				= 1'b0			;	//	clk时钟域，挖矿使能	
	reg		[MINING_DATA_WID			-1:0]	mining_data_reg			= 'b0			;	//	clk时钟域，挖矿数据锁存
	reg		[DATA_WID					-1:0]	nounce					= 'b0			;	//	clk时钟域，挖矿空间nounce
	                                                                	            	
	//	SHA256计算模块相关信号                                                      	
	reg		[MESSAGE_WORD_NUM*DATA_WID	-1:0]	message_0								;	//	clk时钟域，消息块M
	reg											message_vld_0			= 1'b0			;	//	clk时钟域，消息块M有效
	reg		[HASH_WORD_NUM*DATA_WID		-1:0]	hash_init_0				= HASH_INITIAL	;	//	clk时钟域，初始hash
	reg											hash_init_vld_0			= 1'b0			;	//	clk时钟域，初始hash有效
	wire	[HASH_WORD_NUM*DATA_WID		-1:0]	sha256_result_0							;	//	clk时钟域，SHA256运算结果
	wire										sha256_result_vld_0						;	//	clk时钟域，SHA256运算结果有效
	wire	[MESSAGE_WORD_NUM*DATA_WID	-1:0]	message_1								;	//	clk时钟域，消息块M
	wire										message_vld_1							;	//	clk时钟域，消息块M有效
	wire	[HASH_WORD_NUM*DATA_WID		-1:0]	hash_init_1								;	//	clk时钟域，初始hash
	reg											hash_init_vld_1			= 1'b0			;	//	clk时钟域，初始hash有效
	wire	[HASH_WORD_NUM*DATA_WID		-1:0]	double_sha256							;	//	clk时钟域，SHA256运算结果
	wire										double_sha256_vld						;	//	clk时钟域，SHA256运算结果有效
	reg											double_sha256_vld_dly	= 1'b0			;	//	clk时钟域，SHA256运算结果有效，打1拍
	wire										double_sha256_vld_fall					;	//	clk时钟域，SHA256运算结果有效，下降沿
	                                                                            		
	//	挖矿结果判断相关信号                                                    		
	reg		[TARGET_WID					-1:0]	mining_target_reg		= 'b0			;	//	clk时钟域，挖矿目标锁存
	reg		[DATA_WID					-1:0]	mining_extranounce2		= 'b0			;	//	clk时钟域，挖矿空间extranounce2锁存
	reg		[DATA_WID					-1:0]	mining_nounce			= 'b0			;	//	clk时钟域，挖矿空间nounce
	reg											mining_nounce_vld						;	//	clk时钟域，挖矿空间nounce有效
	wire	[HASH_WORD_NUM*DATA_WID		-1:0]	work_proof								;	//	clk时钟域，挖矿工作证明
	
	
	//  ===============================================================================================
	//	双SHA256状态机
	//  ===============================================================================================	
	//  -------------------------------------------------------------------------------------
	//	状态机ASCII表示，实际工程中会被综合掉
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
	//	三段式状态机，第一段
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
	//	三段式状态机，第二段
	//  -------------------------------------------------------------------------------------
	always @ ( * ) begin
		case(current_state)
			
			//	S_IDLE状态
			S_IDLE	: begin
				
				//	S_IDLE -> S_IDLE
				//	挖矿复位
				if(rst_mining) begin
					next_state	= S_IDLE;
				end
				
				//	S_IDLE -> S_CALC_0
				//	挖矿使能有效，开始挖矿
				else if(mining_en) begin
					next_state	= S_CALC_0;
				end
				
				//	S_IDLE -> S_IDLE
				else begin
					next_state	= S_IDLE;
				end
			end
	
			//	S_CALC_0状态
			S_CALC_0	: begin
				
				//	S_CALC_0 -> S_IDLE
				//	挖矿复位
				if(rst_mining) begin
					next_state	= S_IDLE;
				end
				
				//	S_CALC_0 -> S_CALC_1
				//	得到第一轮SHA256计算结果
				else if(sha256_result_vld_0) begin
					next_state	= S_CALC_1;
				end
				
				//	S_CALC_0 -> S_CALC_0
				else begin
					next_state	= S_CALC_0;
				end
			end		
	
			//	S_CALC_1状态
			S_CALC_1	: begin
	    	
				//	S_CALC_1 -> S_IDLE
				//	挖矿复位，或者得到第二轮SHA256计算结果后
				if((rst_mining == 1'b1) || (double_sha256_vld_fall == 1'b1)) begin
					next_state	= S_IDLE;
				end
				
				//	S_SHA_12 -> S_SHA_12
				else begin
					next_state	= S_CALC_1;
				end
			end
			
			//	其他状态
			default	: begin
				next_state	= S_IDLE;
			end
		endcase
	end

	//  -------------------------------------------------------------------------------------
	//	三段式状态机，第三段，各相关逻辑
	//  -------------------------------------------------------------------------------------
	//  -------------------------------------------------------------------------------------
	//	挖矿复位
	//	在输入挖矿使能时，复位整个计算
	//  -------------------------------------------------------------------------------------
	assign rst_mining = i_mining_en;
	
	//  -------------------------------------------------------------------------------------
	//	挖矿使能
	//	在挖矿复位后，开始新的挖矿计算
	//  -------------------------------------------------------------------------------------
	always @ (posedge clk) begin
		mining_en <= rst_mining;
	end
	
	//  -------------------------------------------------------------------------------------
	//	挖矿数据锁存
	//  -------------------------------------------------------------------------------------
	always @ (posedge clk) begin
		
		//	新的挖矿开始，则锁存挖矿数据
		if(i_mining_en) begin
			mining_data_reg <= iv_mining_data;
		end
	end
	
	//  -------------------------------------------------------------------------------------
	//	挖矿空间nounce
	//  -------------------------------------------------------------------------------------
	always @ (posedge clk) begin
		
		//	模块复位，或挖矿复位
		if((rst == 1'b1) || (rst_mining == 1'b1)) begin
			nounce <= NOUNCE_INIT;
		end
		
		//	在S_CALC_1状态，且消息块M_0有效，循环加一计数
		else if((current_state == S_CALC_1) && (message_vld_0 == 1'b1)) begin
			nounce <= nounce + 1'b1;
		end
	end
	
	
	//  ===============================================================================================
	//	sha256计算模块0，主管第一轮SHA256计算
	//  ===============================================================================================
	//  -------------------------------------------------------------------------------------
	//	挖矿消息块M_0
	//  -------------------------------------------------------------------------------------
	always @ ( * ) begin
		case(current_state)
							
			//	S_CALC_0状态，准备第一轮SHA256计算，挖矿数据高512bit作为消息块M
			S_CALC_0: begin
				message_0 = mining_data_reg[(MINING_DATA_WID-1) -: 512];
			end
			
			//	S_CALC_1状态，准备第二轮SHA256计算，挖矿数据低96bit补位作为消息块M
			S_CALC_1: begin
				message_0 = {mining_data_reg[95 : 0], nounce, EXTEND_BIT_1};
			end
			
			//	其他状态，
			default	: begin
				message_0 = 'b0;
			end
		endcase
	end
	
	//  -------------------------------------------------------------------------------------
	//	挖矿消息块M_0有效
	//  -------------------------------------------------------------------------------------
	always @ (posedge clk) begin
		
		//	模块复位，或挖矿复位
		if((rst == 1'b1) || (rst_mining == 1'b1)) begin
			message_vld_0 <= 1'b0;
		end
		
		//	在挖矿使能有效，或者S_CALC_0->S_CALC_1，则置高
		else if((mining_en == 1'b1) || ((current_state == S_CALC_0) && (sha256_result_vld_0 == 1'b1))) begin
			message_vld_0 <= 1'b1;
		end
		
		//	在S_SHA_11且message_vld为高，或者nounce计算到最大值，则置低
		else if(((current_state == S_CALC_0) && (message_vld_0 == 1'b1)) || (nounce == {(DATA_WID){1'b1}})) begin
			message_vld_0 <= 1'b0;
		end
	end
	
	//  -------------------------------------------------------------------------------------
	//	初始hash_0
	//  -------------------------------------------------------------------------------------
	always @ (posedge clk) begin
		
		//	S_CALC_0->S_CALC_1状态时，锁存第一轮SHA256计算结果
		if((current_state == S_CALC_0) && (sha256_result_vld_0 == 1'b1)) begin
			hash_init_0 <= sha256_result_0;
		end
		
		//	S_CALC_0->S_CALC_1状态时，锁存回初始hash
		else if((current_state == S_CALC_1) && (double_sha256_vld_fall == 1'b1)) begin
			hash_init_0 = HASH_INITIAL;
		end
	end
	
	//  -------------------------------------------------------------------------------------
	//	初始hash_0有效
	//  -------------------------------------------------------------------------------------
	always @ (posedge clk) begin
		
		//	模块复位，或挖矿复位
		if((rst == 1'b1) || (rst_mining == 1'b1)) begin
			hash_init_vld_0 <= 1'b0;
		end
		
		//	挖矿消息块M有效，打1拍
		else begin
			hash_init_vld_0 <= message_vld_0;
		end
	end
	
	//  -------------------------------------------------------------------------------------
	//	双SHA256结果有效信号下降沿
	//  -------------------------------------------------------------------------------------
	always @ (posedge clk) begin
		double_sha256_vld_dly <= double_sha256_vld;
	end
	
	assign double_sha256_vld_fall = ((double_sha256_vld == 1'b0) && (double_sha256_vld_dly == 1'b1)) ? 1'b1 : 1'b0;	
	
	
	//  ===============================================================================================
	//	sha256计算模块1，主管第二轮SHA256计算
	//  ===============================================================================================
	//  -------------------------------------------------------------------------------------
	//	挖矿消息块M_1
	//	与sha256计算模块0计算结果一致
	//  -------------------------------------------------------------------------------------
	assign message_1 = {sha256_result_0, EXTEND_BIT_2};
	
	//  -------------------------------------------------------------------------------------
	//	挖矿消息块M_1有效
	//	在CALC_1状态，与sha256计算模块0计算结果有效信号一致
	//  -------------------------------------------------------------------------------------
	assign message_vld_1 = (current_state == S_CALC_1) ? sha256_result_vld_0 : 1'b0;
	
	//  -------------------------------------------------------------------------------------
	//	初始hash_1
	//	因为第二轮SHA256计算只有一个消息块，所以之中为初始HASH
	//  -------------------------------------------------------------------------------------
	assign hash_init_1 = HASH_INITIAL;
	
	//  -------------------------------------------------------------------------------------
	//	初始hash_1有效
	//  -------------------------------------------------------------------------------------
	always @ (posedge clk) begin
		
		//	模块复位，或挖矿复位
		if((rst == 1'b1) || (rst_mining == 1'b1)) begin
			hash_init_vld_1 <= 1'b0;
		end
		
		//	挖矿消息块M有效，打1拍
		else begin
			hash_init_vld_1 <= message_vld_1;
		end
	end
	

	//  ===============================================================================================
	//	例化sha256计算模块
	//  ===============================================================================================
	//  -------------------------------------------------------------------------------------
	//	SHA256运算模块0，第一轮SHA256计算
	//  -------------------------------------------------------------------------------------
	sha256_calc # (
		.HASH_WORD_NUM			(HASH_WORD_NUM			),	//	哈希值的WORD个数，8
		.MESSAGE_WORD_NUM		(MESSAGE_WORD_NUM		),	//	消息块的WORD个数，16
		.DATA_WID				(DATA_WID				)	//	WORD位宽，32
	)                       	                    	
	sha256_calc_inst0 (       	                    	
		.clk					(clk					),	//	模块工作时钟信号
		.rst					(rst | rst_mining		),	//	clk时钟域，复位
		.iv_h_data				(hash_init_0			),	//	clk时钟域，输入初始hash
		.i_h_data_vld			(hash_init_vld_0		),	//	clk时钟域，输入初始hash有效
		.iv_m_data				(message_0				),	//	clk时钟域，输入消息块M
		.i_m_data_vld			(message_vld_0			),	//	clk时钟域，输入消息块M有效
		.ov_sha256_data			(sha256_result_0		),	//	clk时钟域，输出sha256
		.o_sha256_data_vld		(sha256_result_vld_0	)	//	clk时钟域，输出sha256有效
	);
	
	//  -------------------------------------------------------------------------------------
	//	SHA256运算模块1，第二轮SHA256计算
	//  -------------------------------------------------------------------------------------
	sha256_calc # (
		.HASH_WORD_NUM			(HASH_WORD_NUM			),	//	哈希值的WORD个数，8
		.MESSAGE_WORD_NUM		(MESSAGE_WORD_NUM		),	//	消息块的WORD个数，16
		.DATA_WID				(DATA_WID				)	//	WORD位宽，32
	)                       	                    	
	sha256_calc_inst1 (       	                    	
		.clk					(clk					),	//	模块工作时钟信号
		.rst					(rst | rst_mining		),	//	clk时钟域，复位
		.iv_h_data				(hash_init_1			),	//	clk时钟域，输入初始hash
		.i_h_data_vld			(hash_init_vld_1		),	//	clk时钟域，输入初始hash有效
		.iv_m_data				(message_1				),	//	clk时钟域，输入消息块M
		.i_m_data_vld			(message_vld_1			),	//	clk时钟域，输入消息块M有效
		.ov_sha256_data			(double_sha256			),	//	clk时钟域，输出sha256
		.o_sha256_data_vld		(double_sha256_vld		)	//	clk时钟域，输出sha256有效
	);
	
	
	//  ===============================================================================================
	//	挖矿结果判断
	//  ===============================================================================================	
	//  -------------------------------------------------------------------------------------
	//	挖矿空间nounce输出
	//	输出的挖矿空间需要大小端转换
	//  -------------------------------------------------------------------------------------
	always @ (posedge clk) begin
		
		//	模块复位，或挖矿复位
		if((rst == 1'b1) || (rst_mining == 1'b1)) begin
			mining_nounce <= NOUNCE_INIT;
		end
		
		//	在双SHA256有效时，循环加一计数
		else if(double_sha256_vld) begin
			mining_nounce <= mining_nounce + 1'b1;
		end
	end
	
	assign ov_mining_nounce = {mining_nounce[7:0], mining_nounce[15:8], mining_nounce[23:16], mining_nounce[31:24]};
	
	//  -------------------------------------------------------------------------------------
	//	挖矿空间extranounce2锁存、输出
	//  -------------------------------------------------------------------------------------
	always @ (posedge clk) begin
		
		//	新的挖矿开始，则锁存挖矿空间extranounce2
		if(i_mining_en) begin
			mining_extranounce2 <= iv_mining_extranounce2;
		end
	end
	
	assign ov_mining_extranounce2 = mining_extranounce2;
	
	//  -------------------------------------------------------------------------------------
	//	挖矿目标值锁存
	//  -------------------------------------------------------------------------------------
	always @ (posedge clk) begin
		
		//	新的挖矿开始，则锁存挖矿目标值
		if(i_mining_en) begin
			mining_target_reg <= iv_mining_target;
		end
	end
	
	//  -------------------------------------------------------------------------------------
	//	挖矿工作证明
	//	将双SHA256结果以8bit为单位，进行大小端转换
	//  -------------------------------------------------------------------------------------
	genvar i;	
	generate
		for(i=0; i<HASH_BYTE_NUM; i=i+1) begin : work_proof_loop
			assign work_proof[(BYTE_WID*i) +: BYTE_WID] = double_sha256[(BYTE_WID*(HASH_BYTE_NUM-1-i)) +: BYTE_WID];
		end
	endgenerate
	
	//  -------------------------------------------------------------------------------------
	//	挖矿结果有效
	//  -------------------------------------------------------------------------------------
	always @ ( * ) begin
		
		//	双SHA256结果有效，且小于等于目标，则工作证明有效
		if((double_sha256_vld == 1'b1) && (mining_target_reg >= work_proof)) begin
			mining_nounce_vld = 1'b1;
		end
		
		//	否则工作证明无效
		else begin
			mining_nounce_vld = 1'b0;
		end
	end
	
	assign o_mining_nounce_vld = mining_nounce_vld;
	
	//  -------------------------------------------------------------------------------------
	//	挖矿空间nounce已满
	//	与双SHA256结果有效下降沿一致
	//  -------------------------------------------------------------------------------------
	assign o_mining_nounce_full = double_sha256_vld_fall;
	
endmodule