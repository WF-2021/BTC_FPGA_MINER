//	********************************************************************************
//	模块名：sha256_calc
//	功  能：根据初始hash值，对计算消息块M进行sha256运算
//	资	源：
//	********************************************************************************
module sha256_calc # (
	
	//	输入参数
	parameter		HASH_WORD_NUM				= 8					,	//	哈希值的WORD个数，8
	parameter		MESSAGE_WORD_NUM			= 16				,	//	消息块的WORD个数，16
	parameter		DATA_WID					= 32					//	WORD位宽，32
	)
	(
	
	//	输入信号
	input										clk					,	//	模块工作时钟信号
	input										rst					,	//	clk时钟域，复位
	input	[HASH_WORD_NUM*DATA_WID		-1:0]	iv_h_data			,	//	clk时钟域，输入初始hash
	input										i_h_data_vld		,	//	clk时钟域，输入初始hash有效
	input	[MESSAGE_WORD_NUM*DATA_WID	-1:0]	iv_m_data			,	//	clk时钟域，输入消息块M
	input										i_m_data_vld		,	//	clk时钟域，输入消息块M有效
	
	//	输出信号
	output	[HASH_WORD_NUM*DATA_WID		-1:0]	ov_sha256_data		,	//	clk时钟域，输出sha256
	output										o_sha256_data_vld		//	clk时钟域，输出sha256有效
	);
	
	
	//  ===============================================================================================
	//	参数、信号、函数说明
	//  ===============================================================================================
	//  -------------------------------------------------------------------------------------
	//	参数说明
	//  -------------------------------------------------------------------------------------
	localparam	MODULE_NUM	= 64	;	//	子模块例化个数，sha256计算步骤数
	
	//  -------------------------------------------------------------------------------------
	//	信号说明
	//  -------------------------------------------------------------------------------------
	wire	[MESSAGE_WORD_NUM*DATA_WID			-1:0]	m_data_endian									;	//	clk时钟域，输入消息块M大小端转换
	wire	[MODULE_NUM*HASH_WORD_NUM*DATA_WID	-1:0]	k_data											;	//	clk时钟域，密钥K
	wire	[DATA_WID							-1:0]	wv_k_data				[MODULE_NUM		-1:0]	;	//	clk时钟域，中间密钥K
	wire	[HASH_WORD_NUM*DATA_WID				-1:0]	wv_h_data				[MODULE_NUM		-1:0]	;	//	clk时钟域，中间hash
	wire	[MODULE_NUM							-1:0]	w_h_data_vld									;	//	clk时钟域，中间hash有效
	wire	[MESSAGE_WORD_NUM*DATA_WID			-1:0]	wv_m_data				[MODULE_NUM		-1:0]	;	//	clk时钟域，中间消息块M
	wire	[MODULE_NUM							-1:0]	w_m_data_vld									;	//	clk时钟域，中间消息块M有效
	wire	[DATA_WID							-1:0]	wv_w_data				[MODULE_NUM		-1:0]	;	//	clk时钟域，中间扩展消息块W
	wire	[MODULE_NUM							-1:0]	w_w_data_vld									;	//	clk时钟域，中间扩展消息块W有效
	reg		[DATA_WID							-1:0]	sha256_data_reg			[HASH_WORD_NUM	-1:0]	;	//	clk时钟域，输出sha256，锁存
	reg													sha256_data_vld_reg		= 1'b0					;	//	clk时钟域，输出sha256有效，锁存
	
	
	//  ===============================================================================================
	//	数据预处理
	//  ===============================================================================================	
	//  -------------------------------------------------------------------------------------
	//	输入消息块M大小端转换
	//	将输入消息块M，以32bit为单位，进行大小端转换
	//  -------------------------------------------------------------------------------------
	genvar i;	
	generate
		for(i=0; i<MESSAGE_WORD_NUM; i=i+1) begin : m_data_endian_loop
			assign m_data_endian[(DATA_WID*i) +: DATA_WID] = iv_m_data[(DATA_WID*(MESSAGE_WORD_NUM-1-i)) +: DATA_WID];
		end
	endgenerate
	
	//  -------------------------------------------------------------------------------------
	//	密钥K赋值
	//  -------------------------------------------------------------------------------------
	assign k_data =	{32'hc67178f2,32'hbef9a3f7,32'ha4506ceb,32'h90befffa,32'h8cc70208,32'h84c87814,32'h78a5636f,32'h748f82ee,
					 32'h682e6ff3,32'h5b9cca4f,32'h4ed8aa4a,32'h391c0cb3,32'h34b0bcb5,32'h2748774c,32'h1e376c08,32'h19a4c116,
					 32'h106aa070,32'hf40e3585,32'hd6990624,32'hd192e819,32'hc76c51a3,32'hc24b8b70,32'ha81a664b,32'ha2bfe8a1,
					 32'h92722c85,32'h81c2c92e,32'h766a0abb,32'h650a7354,32'h53380d13,32'h4d2c6dfc,32'h2e1b2138,32'h27b70a85,
					 32'h14292967,32'h06ca6351,32'hd5a79147,32'hc6e00bf3,32'hbf597fc7,32'hb00327c8,32'ha831c66d,32'h983e5152,
					 32'h76f988da,32'h5cb0a9dc,32'h4a7484aa,32'h2de92c6f,32'h240ca1cc,32'h0fc19dc6,32'hefbe4786,32'he49b69c1,
					 32'hc19bf174,32'h9bdc06a7,32'h80deb1fe,32'h72be5d74,32'h550c7dc3,32'h243185be,32'h12835b01,32'hd807aa98,
					 32'hab1c5ed5,32'h923f82a4,32'h59f111f1,32'h3956c25b,32'he9b5dba5,32'hb5c0fbcf,32'h71374491,32'h428a2f98};
		
	//  -------------------------------------------------------------------------------------
	//	密钥K分离
	//	以一个哈希值位宽（8*32bit）为单位分离
	//  -------------------------------------------------------------------------------------	
	genvar j;
	generate
		for(j=0; j<MODULE_NUM; j=j+1) begin : wv_k_data_loop
			assign wv_k_data[j] = k_data[(DATA_WID*j) +: DATA_WID];
		end
	endgenerate
	
	
	//  ===============================================================================================
	//	子模块例化
	//  ===============================================================================================	
	//  -------------------------------------------------------------------------------------
	//	哈希值计算模块
	//  -------------------------------------------------------------------------------------	
	generate
		for(j=0; j<MODULE_NUM; j=j+1) begin : hash_value_calc_loop
			
			//	第0个模块
			if(j == 0) begin
				hash_value_calc # (
					.WORD_NUM				(HASH_WORD_NUM				),	//	WORD个数，8
					.DATA_WID				(DATA_WID					)	//	WORD位宽，32
				)                       	                			
				hash_value_calc_inst (  	                			
					.clk					(clk						),	//	模块工作时钟信号
					.rst					(rst						),	//	clk时钟域，复位
					.iv_h_data				(iv_h_data					),	//	clk时钟域，输入旧的hash
					.i_h_data_vld			(i_h_data_vld				),	//	clk时钟域，输入旧的hash有效
					.iv_w_data				(wv_w_data[j]				),	//	clk时钟域，输入扩展消息块W
					.i_w_data_vld			(w_w_data_vld[j]			),	//	clk时钟域，输入扩展消息块W有效
					.iv_k_data				(wv_k_data[j]				),	//	clk时钟域，输入密钥K
					.ov_h_data				(wv_h_data[j]				),	//	clk时钟域，输出新的hash
					.o_h_data_vld			(w_h_data_vld[j]			)	//	clk时钟域，输出新的hash有效
				);
			end
			
			//	第1~63个模块
			else begin
				hash_value_calc # (
					.WORD_NUM				(HASH_WORD_NUM				),	//	WORD个数，8
					.DATA_WID				(DATA_WID					)	//	WORD位宽，32
				)                       	                			
				hash_value_calc_inst (  	                			
					.clk					(clk						),	//	模块工作时钟信号
					.rst					(rst						),	//	clk时钟域，复位
					.iv_h_data				(wv_h_data[j-1]				),	//	clk时钟域，输入旧的hash
					.i_h_data_vld			(w_h_data_vld[j-1]			),	//	clk时钟域，输入旧的hash有效
					.iv_w_data				(wv_w_data[j]				),	//	clk时钟域，输入扩展消息块W
					.i_w_data_vld			(w_w_data_vld[j]			),	//	clk时钟域，输入扩展消息块W有效
					.iv_k_data				(wv_k_data[j]				),	//	clk时钟域，输入密钥K
					.ov_h_data				(wv_h_data[j]				),	//	clk时钟域，输出新的hash
					.o_h_data_vld			(w_h_data_vld[j]			)	//	clk时钟域，输出新的hash有效
				);
			end
		end
	endgenerate
	
	//  -------------------------------------------------------------------------------------
	//	扩展消息计算模块
	//  -------------------------------------------------------------------------------------	
	generate
		for(j=0; j<MODULE_NUM; j=j+1) begin : extend_message_calc_loop
			
			//	第0个模块
			if(j == 0) begin
				extend_message_calc # (
					.MODULE_INDEX		(j					),	//	模块编号，0~63
					.WORD_NUM			(MESSAGE_WORD_NUM	),	//	WORD个数，16
					.DATA_WID			(DATA_WID			)	//	WORD位宽，32
				)
				extend_message_calc_inst (
					.clk				(clk				),	//	模块工作时钟信号
					.rst				(rst				),	//	clk时钟域，复位
					.iv_m_data			(m_data_endian		),	//	clk时钟域，输入消息块数据M
					.i_m_data_vld		(i_m_data_vld		),	//	clk时钟域，输入消息块数据M有效
					.ov_m_data			(wv_m_data[j]		),	//	clk时钟域，输出消息块数据M
					.o_m_data_vld		(w_m_data_vld[j]	),	//	clk时钟域，输出消息块数据M有效
					.ov_w_data			(wv_w_data[j]		),	//	clk时钟域，输出扩展消息块数据W
					.o_w_data_vld		(w_w_data_vld[j]	)	//	clk时钟域，输出扩展消息块数据W有效
				);
			end
			
			//	第1~63个模块
			else begin
				extend_message_calc # (
					.MODULE_INDEX		(j					),	//	模块编号，0~63
					.WORD_NUM			(MESSAGE_WORD_NUM	),	//	WORD个数，16
					.DATA_WID			(DATA_WID			)	//	WORD位宽，32
				)
				extend_message_calc_inst (
					.clk				(clk				),	//	模块工作时钟信号
					.rst				(rst				),	//	clk时钟域，复位
					.iv_m_data			(wv_m_data[j-1]		),	//	clk时钟域，输入消息块数据M
					.i_m_data_vld		(w_m_data_vld[j-1]	),	//	clk时钟域，输入消息块数据M有效
					.ov_m_data			(wv_m_data[j]		),	//	clk时钟域，输出消息块数据M
					.o_m_data_vld		(w_m_data_vld[j]	),	//	clk时钟域，输出消息块数据M有效
					.ov_w_data			(wv_w_data[j]		),	//	clk时钟域，输出扩展消息块数据W
					.o_w_data_vld		(w_w_data_vld[j]	)	//	clk时钟域，输出扩展消息块数据W有效
				);
			end
		end
	endgenerate
	
	
	//  ===============================================================================================
	//	数据输出
	//  ===============================================================================================
	//  -------------------------------------------------------------------------------------
	//	SHA256输出
	//	在最后一步hash有效时，将经过64步计算出的hash与初始hash，以32bit为单位相加
	//  -------------------------------------------------------------------------------------	
	genvar k;
	generate
		for(k=0; k<HASH_WORD_NUM; k=k+1) begin : sha256_data_reg_loop
			always @ (posedge clk) begin
				if(w_h_data_vld[MODULE_NUM-1]) begin
					sha256_data_reg[k] <= iv_h_data[(DATA_WID*k) +: DATA_WID] + wv_h_data[MODULE_NUM-1][(DATA_WID*k) +: DATA_WID];
				end
			end
		end
	endgenerate
	
	//  -------------------------------------------------------------------------------------
	//	输出新的hash拼接
	//	将计算后新的hash，以32bit的word为单位，进行拼接
	//  -------------------------------------------------------------------------------------	
	generate
		for(k=0; k<HASH_WORD_NUM; k=k+1) begin : ov_h_data_loop
			assign	ov_sha256_data[(DATA_WID*k) +: DATA_WID] = sha256_data_reg[k];
		end
	endgenerate
	
	//  -------------------------------------------------------------------------------------
	//	SHA256有效输出
	//  -------------------------------------------------------------------------------------	
	always @ (posedge clk) begin
		
		//	复位
		if(rst) begin
			sha256_data_vld_reg <= 1'b0;
		end
		
		//	将最后一步出hash有效信号打1拍
		else begin
			sha256_data_vld_reg <= w_h_data_vld[MODULE_NUM-1];
		end
	end
	
	assign o_sha256_data_vld = sha256_data_vld_reg;
	
endmodule