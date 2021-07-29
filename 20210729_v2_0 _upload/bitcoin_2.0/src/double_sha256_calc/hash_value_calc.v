//	********************************************************************************
//	模块名：hash_value_calc
//	功  能：通过旧的hash、扩展消息块W和密钥K，计算新的hash
//	资	源：LUT-409，REG-513
//	********************************************************************************
module hash_value_calc # (
	
	//	输入参数
	parameter		WORD_NUM			= 8					,	//	WORD个数，8
	parameter		DATA_WID			= 32					//	WORD位宽，32
	)
	(
	
	//	输入信号
	input								clk					,	//	模块工作时钟信号
	input								rst					,	//	clk时钟域，复位
	input	[WORD_NUM*DATA_WID	-1:0]	iv_h_data			,	//	clk时钟域，输入旧的hash
	input								i_h_data_vld		,	//	clk时钟域，输入旧的hash有效
	input	[DATA_WID			-1:0]	iv_w_data			,	//	clk时钟域，输入扩展消息块W
	input								i_w_data_vld		,	//	clk时钟域，输入扩展消息块W有效
	input	[DATA_WID			-1:0]	iv_k_data			,	//	clk时钟域，输入密钥K
	
	//	输出信号
	output	[WORD_NUM*DATA_WID	-1:0]	ov_h_data			,	//	clk时钟域，输出新的hash
	output								o_h_data_vld			//	clk时钟域，输出新的hash有效
	);
	
	
	//  ===============================================================================================
	//	参数、信号、函数说明
	//  ===============================================================================================
	//  -------------------------------------------------------------------------------------
	//	函数说明
	//  -------------------------------------------------------------------------------------
	//  -----------------------------------------------------------------
	//	sig0函数
	//	sig0(x) = s2(x) ^ s13(x) ^ s22(x)
	//  -----------------------------------------------------------------
	function [DATA_WID-1:0] sig0;
		
		//	输入信号
		input	[DATA_WID	-1:0]	data;
		
		//	参数声明 
		reg		[DATA_WID	-1:0]	s2	;
		reg		[DATA_WID	-1:0]	s13	;
		reg		[DATA_WID	-1:0]	s22	;
		
		//	运算过程  
		begin
			s2		= {data[ 1:0],	data[DATA_WID-1: 2]};
			s13		= {data[12:0],	data[DATA_WID-1:13]};
			s22		= {data[21:0],	data[DATA_WID-1:22]};
			sig0	= s2 ^ s13 ^ s22;
		end
	endfunction
	
	//  -----------------------------------------------------------------
	//	sig1函数
	//	sig1(x) = s6(x) ^ s11(x) ^ s25(x)
	//  -----------------------------------------------------------------
	function [DATA_WID-1:0] sig1;
		
		//	输入信号
		input	[DATA_WID	-1:0]	data;
		
		//	参数声明 
		reg		[DATA_WID	-1:0]	s6	;
		reg		[DATA_WID	-1:0]	s11	;
		reg		[DATA_WID	-1:0]	s25	;
		
		//	运算过程  
		begin
			s6		= {data[ 5:0],	data[DATA_WID-1: 6]};
			s11		= {data[10:0],	data[DATA_WID-1:11]};
			s25		= {data[24:0],	data[DATA_WID-1:25]};
			sig1	= s6 ^ s11 ^ s25;
		end
	endfunction
	
	//  -----------------------------------------------------------------
	//	ch函数
	//	ch(x, y, z) = (x & y) ^ (~x & z)
	//  -----------------------------------------------------------------
	function [DATA_WID-1:0] ch;
		
		//	输入信号
		input	[DATA_WID	-1:0]	data_x;
		input	[DATA_WID	-1:0]	data_y;
		input	[DATA_WID	-1:0]	data_z;
		
		//	运算过程  
		begin
			ch	= (data_x & data_y) ^ (~data_x & data_z);
		end
	endfunction
	
	//  -----------------------------------------------------------------
	//	maj函数
	//	maj(x, y, z) = (x & y) ^ (x & z) ^ (y & z)
	//  -----------------------------------------------------------------
	function [DATA_WID-1:0] maj;
		
		//	输入信号
		input	[DATA_WID	-1:0]	data_x;
		input	[DATA_WID	-1:0]	data_y;
		input	[DATA_WID	-1:0]	data_z;
		
		//	运算过程  
		begin
			maj	= (data_x & data_y) ^ (data_x & data_z) ^ (data_y & data_z);
		end
	endfunction
	
	//  -------------------------------------------------------------------------------------
	//	信号说明
	//  -------------------------------------------------------------------------------------
	wire	[DATA_WID	-1:0]	h_data_word				[WORD_NUM	-1:0]	;	//	clk时钟域，输入旧的hash分离
	reg		[DATA_WID	-1:0]	h_data_word_reg			[WORD_NUM	-1:0]	;	//	clk时钟域，新的hash计算结果
	reg							data_vld_reg			= 1'b0				;	//	clk时钟域，输出新的hash有效
	
	
	//  ===============================================================================================
	//	新的hash计算
	//  ===============================================================================================
	//  -------------------------------------------------------------------------------------
	//	输入旧的hash分离
	//	将旧的hash，以32bit的word为单位，进行分离
	//  -------------------------------------------------------------------------------------	
	genvar i;	
	generate
		for(i=0; i<WORD_NUM; i=i+1) begin : h_data_word_loop
			assign h_data_word[i] = iv_h_data[(DATA_WID*i) +: DATA_WID];
		end
	endgenerate
	
	//  -------------------------------------------------------------------------------------
	//	消息块数据M计算
	//  -------------------------------------------------------------------------------------
	generate
		for(i=0; i<WORD_NUM; i=i+1) begin : h_data_word_reg_loop
			case (i)
				
				//	hash计算公式为 h'[7] = h[0] + w + k + ch(h[3], h[2], h[1]) + sig1(h[3]) + maj(h[7], h[6], h[5]) + sig0(h[7])
				7		: begin
					always @ (posedge clk) begin
						
						//	在输入数据有效时，计算
						
						if((i_h_data_vld == 1'b1) && (i_w_data_vld == 1'b1)) begin
							h_data_word_reg[7] <= h_data_word[0] + iv_w_data + iv_k_data + ch(h_data_word[3], h_data_word[2], h_data_word[1])
										  		+ sig1(h_data_word[3])+ maj(h_data_word[7], h_data_word[6], h_data_word[5]) + sig0(h_data_word[7]);
						end
					end
				end
				
				//	hash计算公式为 h'[3] = h[0] + w + k + ch(h[3], h[2], h[1]) + sig1(h[3]) + h[4]
				3		: begin
					always @ (posedge clk) begin
						
						//	在输入数据有效时，计算
						if((i_h_data_vld == 1'b1) && (i_w_data_vld == 1'b1)) begin
							h_data_word_reg[3] <= h_data_word[0] + iv_w_data + iv_k_data + ch(h_data_word[3], h_data_word[2], h_data_word[1])
												+ sig1(h_data_word[3])+ h_data_word[4];
						end
					end
				end
				
				//	hash计算公式为 h'[i] = h[i+1]，i取值0~2，4~6
				default	:	begin
					always @ (posedge clk) begin
						
						//	在输入数据有效时，计算
						if((i_h_data_vld == 1'b1) && (i_w_data_vld == 1'b1)) begin
							h_data_word_reg[i] <= h_data_word[i+1];
						end
					end
				end
			endcase
		end
	endgenerate
	
	//  -------------------------------------------------------------------------------------
	//	输出新的hash拼接
	//	将计算后新的hash，以32bit的word为单位，进行拼接
	//  -------------------------------------------------------------------------------------	
	generate
		for(i=0; i<WORD_NUM; i=i+1) begin : ov_h_data_loop
			assign	ov_h_data[(DATA_WID*i) +: DATA_WID] = h_data_word_reg[i];
		end
	endgenerate
	
	//  -------------------------------------------------------------------------------------
	//	输出新的hash有效
	//  -------------------------------------------------------------------------------------	
	always @ (posedge clk) begin
		
		//	复位
		if(rst) begin
			data_vld_reg <= 1'b0;
		end
		
		//	将输入旧的hash有效和输入扩展消息块W有效相“与”，打1拍
		else begin
			data_vld_reg <= i_h_data_vld & i_w_data_vld;
		end
	end
	
	assign o_h_data_vld = data_vld_reg;
	
endmodule