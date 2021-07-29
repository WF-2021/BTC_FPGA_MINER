//	********************************************************************************
//	ģ������sha256_calc
//	��  �ܣ����ݳ�ʼhashֵ���Լ�����Ϣ��M����sha256����
//	��	Դ��
//	********************************************************************************
module sha256_calc # (
	
	//	�������
	parameter		HASH_WORD_NUM				= 8					,	//	��ϣֵ��WORD������8
	parameter		MESSAGE_WORD_NUM			= 16				,	//	��Ϣ���WORD������16
	parameter		DATA_WID					= 32					//	WORDλ��32
	)
	(
	
	//	�����ź�
	input										clk					,	//	ģ�鹤��ʱ���ź�
	input										rst					,	//	clkʱ���򣬸�λ
	input	[HASH_WORD_NUM*DATA_WID		-1:0]	iv_h_data			,	//	clkʱ���������ʼhash
	input										i_h_data_vld		,	//	clkʱ���������ʼhash��Ч
	input	[MESSAGE_WORD_NUM*DATA_WID	-1:0]	iv_m_data			,	//	clkʱ����������Ϣ��M
	input										i_m_data_vld		,	//	clkʱ����������Ϣ��M��Ч
	
	//	����ź�
	output	[HASH_WORD_NUM*DATA_WID		-1:0]	ov_sha256_data		,	//	clkʱ�������sha256
	output										o_sha256_data_vld		//	clkʱ�������sha256��Ч
	);
	
	
	//  ===============================================================================================
	//	�������źš�����˵��
	//  ===============================================================================================
	//  -------------------------------------------------------------------------------------
	//	����˵��
	//  -------------------------------------------------------------------------------------
	localparam	MODULE_NUM	= 64	;	//	��ģ������������sha256���㲽����
	
	//  -------------------------------------------------------------------------------------
	//	�ź�˵��
	//  -------------------------------------------------------------------------------------
	wire	[MESSAGE_WORD_NUM*DATA_WID			-1:0]	m_data_endian									;	//	clkʱ����������Ϣ��M��С��ת��
	wire	[MODULE_NUM*HASH_WORD_NUM*DATA_WID	-1:0]	k_data											;	//	clkʱ������ԿK
	wire	[DATA_WID							-1:0]	wv_k_data				[MODULE_NUM		-1:0]	;	//	clkʱ�����м���ԿK
	wire	[HASH_WORD_NUM*DATA_WID				-1:0]	wv_h_data				[MODULE_NUM		-1:0]	;	//	clkʱ�����м�hash
	wire	[MODULE_NUM							-1:0]	w_h_data_vld									;	//	clkʱ�����м�hash��Ч
	wire	[MESSAGE_WORD_NUM*DATA_WID			-1:0]	wv_m_data				[MODULE_NUM		-1:0]	;	//	clkʱ�����м���Ϣ��M
	wire	[MODULE_NUM							-1:0]	w_m_data_vld									;	//	clkʱ�����м���Ϣ��M��Ч
	wire	[DATA_WID							-1:0]	wv_w_data				[MODULE_NUM		-1:0]	;	//	clkʱ�����м���չ��Ϣ��W
	wire	[MODULE_NUM							-1:0]	w_w_data_vld									;	//	clkʱ�����м���չ��Ϣ��W��Ч
	reg		[DATA_WID							-1:0]	sha256_data_reg			[HASH_WORD_NUM	-1:0]	;	//	clkʱ�������sha256������
	reg													sha256_data_vld_reg		= 1'b0					;	//	clkʱ�������sha256��Ч������
	
	
	//  ===============================================================================================
	//	����Ԥ����
	//  ===============================================================================================	
	//  -------------------------------------------------------------------------------------
	//	������Ϣ��M��С��ת��
	//	��������Ϣ��M����32bitΪ��λ�����д�С��ת��
	//  -------------------------------------------------------------------------------------
	genvar i;	
	generate
		for(i=0; i<MESSAGE_WORD_NUM; i=i+1) begin : m_data_endian_loop
			assign m_data_endian[(DATA_WID*i) +: DATA_WID] = iv_m_data[(DATA_WID*(MESSAGE_WORD_NUM-1-i)) +: DATA_WID];
		end
	endgenerate
	
	//  -------------------------------------------------------------------------------------
	//	��ԿK��ֵ
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
	//	��ԿK����
	//	��һ����ϣֵλ��8*32bit��Ϊ��λ����
	//  -------------------------------------------------------------------------------------	
	genvar j;
	generate
		for(j=0; j<MODULE_NUM; j=j+1) begin : wv_k_data_loop
			assign wv_k_data[j] = k_data[(DATA_WID*j) +: DATA_WID];
		end
	endgenerate
	
	
	//  ===============================================================================================
	//	��ģ������
	//  ===============================================================================================	
	//  -------------------------------------------------------------------------------------
	//	��ϣֵ����ģ��
	//  -------------------------------------------------------------------------------------	
	generate
		for(j=0; j<MODULE_NUM; j=j+1) begin : hash_value_calc_loop
			
			//	��0��ģ��
			if(j == 0) begin
				hash_value_calc # (
					.WORD_NUM				(HASH_WORD_NUM				),	//	WORD������8
					.DATA_WID				(DATA_WID					)	//	WORDλ��32
				)                       	                			
				hash_value_calc_inst (  	                			
					.clk					(clk						),	//	ģ�鹤��ʱ���ź�
					.rst					(rst						),	//	clkʱ���򣬸�λ
					.iv_h_data				(iv_h_data					),	//	clkʱ��������ɵ�hash
					.i_h_data_vld			(i_h_data_vld				),	//	clkʱ��������ɵ�hash��Ч
					.iv_w_data				(wv_w_data[j]				),	//	clkʱ����������չ��Ϣ��W
					.i_w_data_vld			(w_w_data_vld[j]			),	//	clkʱ����������չ��Ϣ��W��Ч
					.iv_k_data				(wv_k_data[j]				),	//	clkʱ����������ԿK
					.ov_h_data				(wv_h_data[j]				),	//	clkʱ��������µ�hash
					.o_h_data_vld			(w_h_data_vld[j]			)	//	clkʱ��������µ�hash��Ч
				);
			end
			
			//	��1~63��ģ��
			else begin
				hash_value_calc # (
					.WORD_NUM				(HASH_WORD_NUM				),	//	WORD������8
					.DATA_WID				(DATA_WID					)	//	WORDλ��32
				)                       	                			
				hash_value_calc_inst (  	                			
					.clk					(clk						),	//	ģ�鹤��ʱ���ź�
					.rst					(rst						),	//	clkʱ���򣬸�λ
					.iv_h_data				(wv_h_data[j-1]				),	//	clkʱ��������ɵ�hash
					.i_h_data_vld			(w_h_data_vld[j-1]			),	//	clkʱ��������ɵ�hash��Ч
					.iv_w_data				(wv_w_data[j]				),	//	clkʱ����������չ��Ϣ��W
					.i_w_data_vld			(w_w_data_vld[j]			),	//	clkʱ����������չ��Ϣ��W��Ч
					.iv_k_data				(wv_k_data[j]				),	//	clkʱ����������ԿK
					.ov_h_data				(wv_h_data[j]				),	//	clkʱ��������µ�hash
					.o_h_data_vld			(w_h_data_vld[j]			)	//	clkʱ��������µ�hash��Ч
				);
			end
		end
	endgenerate
	
	//  -------------------------------------------------------------------------------------
	//	��չ��Ϣ����ģ��
	//  -------------------------------------------------------------------------------------	
	generate
		for(j=0; j<MODULE_NUM; j=j+1) begin : extend_message_calc_loop
			
			//	��0��ģ��
			if(j == 0) begin
				extend_message_calc # (
					.MODULE_INDEX		(j					),	//	ģ���ţ�0~63
					.WORD_NUM			(MESSAGE_WORD_NUM	),	//	WORD������16
					.DATA_WID			(DATA_WID			)	//	WORDλ��32
				)
				extend_message_calc_inst (
					.clk				(clk				),	//	ģ�鹤��ʱ���ź�
					.rst				(rst				),	//	clkʱ���򣬸�λ
					.iv_m_data			(m_data_endian		),	//	clkʱ����������Ϣ������M
					.i_m_data_vld		(i_m_data_vld		),	//	clkʱ����������Ϣ������M��Ч
					.ov_m_data			(wv_m_data[j]		),	//	clkʱ���������Ϣ������M
					.o_m_data_vld		(w_m_data_vld[j]	),	//	clkʱ���������Ϣ������M��Ч
					.ov_w_data			(wv_w_data[j]		),	//	clkʱ���������չ��Ϣ������W
					.o_w_data_vld		(w_w_data_vld[j]	)	//	clkʱ���������չ��Ϣ������W��Ч
				);
			end
			
			//	��1~63��ģ��
			else begin
				extend_message_calc # (
					.MODULE_INDEX		(j					),	//	ģ���ţ�0~63
					.WORD_NUM			(MESSAGE_WORD_NUM	),	//	WORD������16
					.DATA_WID			(DATA_WID			)	//	WORDλ��32
				)
				extend_message_calc_inst (
					.clk				(clk				),	//	ģ�鹤��ʱ���ź�
					.rst				(rst				),	//	clkʱ���򣬸�λ
					.iv_m_data			(wv_m_data[j-1]		),	//	clkʱ����������Ϣ������M
					.i_m_data_vld		(w_m_data_vld[j-1]	),	//	clkʱ����������Ϣ������M��Ч
					.ov_m_data			(wv_m_data[j]		),	//	clkʱ���������Ϣ������M
					.o_m_data_vld		(w_m_data_vld[j]	),	//	clkʱ���������Ϣ������M��Ч
					.ov_w_data			(wv_w_data[j]		),	//	clkʱ���������չ��Ϣ������W
					.o_w_data_vld		(w_w_data_vld[j]	)	//	clkʱ���������չ��Ϣ������W��Ч
				);
			end
		end
	endgenerate
	
	
	//  ===============================================================================================
	//	�������
	//  ===============================================================================================
	//  -------------------------------------------------------------------------------------
	//	SHA256���
	//	�����һ��hash��Чʱ��������64���������hash���ʼhash����32bitΪ��λ���
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
	//	����µ�hashƴ��
	//	��������µ�hash����32bit��wordΪ��λ������ƴ��
	//  -------------------------------------------------------------------------------------	
	generate
		for(k=0; k<HASH_WORD_NUM; k=k+1) begin : ov_h_data_loop
			assign	ov_sha256_data[(DATA_WID*k) +: DATA_WID] = sha256_data_reg[k];
		end
	endgenerate
	
	//  -------------------------------------------------------------------------------------
	//	SHA256��Ч���
	//  -------------------------------------------------------------------------------------	
	always @ (posedge clk) begin
		
		//	��λ
		if(rst) begin
			sha256_data_vld_reg <= 1'b0;
		end
		
		//	�����һ����hash��Ч�źŴ�1��
		else begin
			sha256_data_vld_reg <= w_h_data_vld[MODULE_NUM-1];
		end
	end
	
	assign o_sha256_data_vld = sha256_data_vld_reg;
	
endmodule