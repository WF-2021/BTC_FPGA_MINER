//	********************************************************************************
//	模块名：extend_message_calc
//	功  能：通过消息块M，计算扩展消息块W
//	资	源：LUT-136，REG-513
//	********************************************************************************
module extend_message_calc # (
	
	//	输入参数
	parameter		MODULE_INDEX		= 0				,	//	模块编号，0~63
	parameter		WORD_NUM			= 16			,	//	WORD个数，16
	parameter		DATA_WID			= 32				//	WORD位宽，32
	)
	(
	
	//	输入信号
	input								clk				,	//	模块工作时钟信号
	input								rst				,	//	clk时钟域，复位
	input	[WORD_NUM*DATA_WID	-1:0]	iv_m_data		,	//	clk时钟域，输入消息块数据M
	input								i_m_data_vld	,	//	clk时钟域，输入消息块数据M有效
	
	//	输出信号
	output	[WORD_NUM*DATA_WID	-1:0]	ov_m_data		,	//	clk时钟域，输出消息块数据M
	output								o_m_data_vld	,	//	clk时钟域，输出消息块数据M有效
	output	[DATA_WID			-1:0]	ov_w_data		,	//	clk时钟域，输出扩展消息块数据W
	output								o_w_data_vld		//	clk时钟域，输出扩展消息块数据W有效
	);
	
	
	//  ===============================================================================================
	//	参数、信号、函数说明
	//  ===============================================================================================
	//  -------------------------------------------------------------------------------------
	//	函数说明
	//  -------------------------------------------------------------------------------------
	//  -----------------------------------------------------------------
	//	rou0函数
	//	rou0(x) = s7(x) ^ s18(x) ^ r3(x)
	//  -----------------------------------------------------------------
	function [DATA_WID-1:0] rou0;
		
		//	输入信号
		input	[DATA_WID	-1:0]	data;
		
		//	参数声明 
		reg		[DATA_WID	-1:0]	s7	;
		reg		[DATA_WID	-1:0]	s18	;
		reg		[DATA_WID	-1:0]	r3	;
		
		//	运算过程  
		begin
			s7		= {data[6:0],	data[DATA_WID-1:7]};
			s18		= {data[17:0],	data[DATA_WID-1:18]};
			r3		= {{(3){1'b0}},	data[DATA_WID-1:3]};
			rou0	= s7 ^ s18 ^ r3;
		end
	endfunction
	
	//  -----------------------------------------------------------------
	//	rou1函数
	//	rou1(x) = s17(x) ^ s19(x) ^ r10(x)
	//  -----------------------------------------------------------------
	function [DATA_WID-1:0] rou1;
		
		//	输入信号
		input	[DATA_WID	-1:0]	data;
		
		//	参数声明 
		reg		[DATA_WID	-1:0]	s17;
		reg		[DATA_WID	-1:0]	s19;
		reg		[DATA_WID	-1:0]	r10;
		
		//	运算过程  
		begin
			s17		= {data[16:0],		data[DATA_WID-1:17]};
			s19		= {data[18:0],		data[DATA_WID-1:19]};
			r10		= {{(10){1'b0}},	data[DATA_WID-1:10]};
			rou1	= s17 ^ s19 ^ r10;
		end
	endfunction
	
	//  -------------------------------------------------------------------------------------
	//	信号说明
	//  -------------------------------------------------------------------------------------
	wire	[DATA_WID	-1:0]	m_data_word		[WORD_NUM	-1:0]	;	//	clk时钟域，输入消息块数据M分离
	reg		[DATA_WID	-1:0]	m_data_word_reg	[WORD_NUM	-1:0]	;	//	clk时钟域，消息块数据M计算结果
	reg							data_vld_reg	= 1'b0				;	//	clk时钟域，输入消息块数据M有效，打1拍

	
	//  ===============================================================================================
	//	扩展消息块W计算
	//  ===============================================================================================
	//  -------------------------------------------------------------------------------------
	//	输入消息块数据M分离
	//	将输入消息块M，以32bit的word为单位，进行分离
	//  -------------------------------------------------------------------------------------	
	genvar i;	
	generate
		for(i=0; i<WORD_NUM; i=i+1) begin : m_data_word_loop
			assign m_data_word[i] = iv_m_data[(DATA_WID*i) +: DATA_WID];
		end
	endgenerate
	
	//  -------------------------------------------------------------------------------------
	//	消息块数据M计算
	//  -------------------------------------------------------------------------------------
	generate
		for(i=0; i<WORD_NUM; i=i+1) begin : m_data_word_reg_loop
			
			//	模块索引为0~15时
			if(MODULE_INDEX < 16) begin
				
				//	消息块M计算公式为 M'(i) = M(i)，i取值0~15
				always @ (posedge clk) begin
					
					//	在输入消息块数据M有效时，计算
					if(i_m_data_vld) begin
						m_data_word_reg[i] <= m_data_word[i];
					end
				end
			end
			
			//	模块索引为16~63时
			else begin
				
				//	消息块计算公式为 M'(i) = M(i+1)，i取值0~14
				if(i < 15) begin
					always @ (posedge clk) begin
					
						//	在输入消息块数据M有效时，计算
						if(i_m_data_vld) begin
							m_data_word_reg[i] <= m_data_word[i+1];
						end
					end
				end
				
				//	消息块计算公式为 M'(i) = rou1(M(i-1)) + M(i-6) + rou0(M(i-14)) + M(i-15)，i取值15
				else begin
					always @ (posedge clk) begin
						
						//	在输入消息块数据M有效时，计算
						if(i_m_data_vld) begin
							m_data_word_reg[i] <= rou1(m_data_word[i-1]) + m_data_word[i-6] + rou0(m_data_word[i-14]) + m_data_word[i-15];
						end
					end
				end
			end
		end
	endgenerate
	
	//  -------------------------------------------------------------------------------------
	//	输出消息块数据M拼接
	//	将计算后的消息块M，以32bit的word为单位，进行拼接
	//  -------------------------------------------------------------------------------------	
	generate
		for(i=0; i<WORD_NUM; i=i+1) begin : ov_m_data_loop
			assign	ov_m_data[(DATA_WID*i) +: DATA_WID] = m_data_word_reg[i];
		end
	endgenerate
	
	//  -------------------------------------------------------------------------------------
	//	输出扩展消息块数据W
	//  -------------------------------------------------------------------------------------	
	generate
		//	模块索引为0~15时
		if(MODULE_INDEX < 16) begin
			
			//	扩展消息块W为 W = M(MODULE_INDEX)
			assign	ov_w_data = m_data_word_reg[MODULE_INDEX];
		end
		
		//	模块索引为16~63时
		else begin
			
			//	扩展消息块W为 W = M(15)
			assign	ov_w_data = m_data_word_reg[15];
		end
	endgenerate
	
	//  -------------------------------------------------------------------------------------
	//	输出消息块数据M有效，输出扩展消息块数据W有效
	//  -------------------------------------------------------------------------------------	
	always @ (posedge clk) begin
		
		//	复位
		if(rst) begin
			data_vld_reg <= 1'b0;
		end
		
		//	将输入消息块数据M有效，打1拍
		else begin
			data_vld_reg <= i_m_data_vld;
		end
	end
	
	assign o_m_data_vld = data_vld_reg;
	assign o_w_data_vld = data_vld_reg;
	
endmodule