//	********************************************************************************
//	ģ������hash_value_calc
//	��  �ܣ�ͨ���ɵ�hash����չ��Ϣ��W����ԿK�������µ�hash
//	��	Դ��LUT-409��REG-513
//	********************************************************************************
module hash_value_calc # (
	
	//	�������
	parameter		WORD_NUM			= 8					,	//	WORD������8
	parameter		DATA_WID			= 32					//	WORDλ��32
	)
	(
	
	//	�����ź�
	input								clk					,	//	ģ�鹤��ʱ���ź�
	input								rst					,	//	clkʱ���򣬸�λ
	input	[WORD_NUM*DATA_WID	-1:0]	iv_h_data			,	//	clkʱ��������ɵ�hash
	input								i_h_data_vld		,	//	clkʱ��������ɵ�hash��Ч
	input	[DATA_WID			-1:0]	iv_w_data			,	//	clkʱ����������չ��Ϣ��W
	input								i_w_data_vld		,	//	clkʱ����������չ��Ϣ��W��Ч
	input	[DATA_WID			-1:0]	iv_k_data			,	//	clkʱ����������ԿK
	
	//	����ź�
	output	[WORD_NUM*DATA_WID	-1:0]	ov_h_data			,	//	clkʱ��������µ�hash
	output								o_h_data_vld			//	clkʱ��������µ�hash��Ч
	);
	
	
	//  ===============================================================================================
	//	�������źš�����˵��
	//  ===============================================================================================
	//  -------------------------------------------------------------------------------------
	//	����˵��
	//  -------------------------------------------------------------------------------------
	//  -----------------------------------------------------------------
	//	sig0����
	//	sig0(x) = s2(x) ^ s13(x) ^ s22(x)
	//  -----------------------------------------------------------------
	function [DATA_WID-1:0] sig0;
		
		//	�����ź�
		input	[DATA_WID	-1:0]	data;
		
		//	�������� 
		reg		[DATA_WID	-1:0]	s2	;
		reg		[DATA_WID	-1:0]	s13	;
		reg		[DATA_WID	-1:0]	s22	;
		
		//	�������  
		begin
			s2		= {data[ 1:0],	data[DATA_WID-1: 2]};
			s13		= {data[12:0],	data[DATA_WID-1:13]};
			s22		= {data[21:0],	data[DATA_WID-1:22]};
			sig0	= s2 ^ s13 ^ s22;
		end
	endfunction
	
	//  -----------------------------------------------------------------
	//	sig1����
	//	sig1(x) = s6(x) ^ s11(x) ^ s25(x)
	//  -----------------------------------------------------------------
	function [DATA_WID-1:0] sig1;
		
		//	�����ź�
		input	[DATA_WID	-1:0]	data;
		
		//	�������� 
		reg		[DATA_WID	-1:0]	s6	;
		reg		[DATA_WID	-1:0]	s11	;
		reg		[DATA_WID	-1:0]	s25	;
		
		//	�������  
		begin
			s6		= {data[ 5:0],	data[DATA_WID-1: 6]};
			s11		= {data[10:0],	data[DATA_WID-1:11]};
			s25		= {data[24:0],	data[DATA_WID-1:25]};
			sig1	= s6 ^ s11 ^ s25;
		end
	endfunction
	
	//  -----------------------------------------------------------------
	//	ch����
	//	ch(x, y, z) = (x & y) ^ (~x & z)
	//  -----------------------------------------------------------------
	function [DATA_WID-1:0] ch;
		
		//	�����ź�
		input	[DATA_WID	-1:0]	data_x;
		input	[DATA_WID	-1:0]	data_y;
		input	[DATA_WID	-1:0]	data_z;
		
		//	�������  
		begin
			ch	= (data_x & data_y) ^ (~data_x & data_z);
		end
	endfunction
	
	//  -----------------------------------------------------------------
	//	maj����
	//	maj(x, y, z) = (x & y) ^ (x & z) ^ (y & z)
	//  -----------------------------------------------------------------
	function [DATA_WID-1:0] maj;
		
		//	�����ź�
		input	[DATA_WID	-1:0]	data_x;
		input	[DATA_WID	-1:0]	data_y;
		input	[DATA_WID	-1:0]	data_z;
		
		//	�������  
		begin
			maj	= (data_x & data_y) ^ (data_x & data_z) ^ (data_y & data_z);
		end
	endfunction
	
	//  -------------------------------------------------------------------------------------
	//	�ź�˵��
	//  -------------------------------------------------------------------------------------
	wire	[DATA_WID	-1:0]	h_data_word				[WORD_NUM	-1:0]	;	//	clkʱ��������ɵ�hash����
	reg		[DATA_WID	-1:0]	h_data_word_reg			[WORD_NUM	-1:0]	;	//	clkʱ�����µ�hash������
	reg							data_vld_reg			= 1'b0				;	//	clkʱ��������µ�hash��Ч
	
	
	//  ===============================================================================================
	//	�µ�hash����
	//  ===============================================================================================
	//  -------------------------------------------------------------------------------------
	//	����ɵ�hash����
	//	���ɵ�hash����32bit��wordΪ��λ�����з���
	//  -------------------------------------------------------------------------------------	
	genvar i;	
	generate
		for(i=0; i<WORD_NUM; i=i+1) begin : h_data_word_loop
			assign h_data_word[i] = iv_h_data[(DATA_WID*i) +: DATA_WID];
		end
	endgenerate
	
	//  -------------------------------------------------------------------------------------
	//	��Ϣ������M����
	//  -------------------------------------------------------------------------------------
	generate
		for(i=0; i<WORD_NUM; i=i+1) begin : h_data_word_reg_loop
			case (i)
				
				//	hash���㹫ʽΪ h'[7] = h[0] + w + k + ch(h[3], h[2], h[1]) + sig1(h[3]) + maj(h[7], h[6], h[5]) + sig0(h[7])
				7		: begin
					always @ (posedge clk) begin
						
						//	������������Чʱ������
						
						if((i_h_data_vld == 1'b1) && (i_w_data_vld == 1'b1)) begin
							h_data_word_reg[7] <= h_data_word[0] + iv_w_data + iv_k_data + ch(h_data_word[3], h_data_word[2], h_data_word[1])
										  		+ sig1(h_data_word[3])+ maj(h_data_word[7], h_data_word[6], h_data_word[5]) + sig0(h_data_word[7]);
						end
					end
				end
				
				//	hash���㹫ʽΪ h'[3] = h[0] + w + k + ch(h[3], h[2], h[1]) + sig1(h[3]) + h[4]
				3		: begin
					always @ (posedge clk) begin
						
						//	������������Чʱ������
						if((i_h_data_vld == 1'b1) && (i_w_data_vld == 1'b1)) begin
							h_data_word_reg[3] <= h_data_word[0] + iv_w_data + iv_k_data + ch(h_data_word[3], h_data_word[2], h_data_word[1])
												+ sig1(h_data_word[3])+ h_data_word[4];
						end
					end
				end
				
				//	hash���㹫ʽΪ h'[i] = h[i+1]��iȡֵ0~2��4~6
				default	:	begin
					always @ (posedge clk) begin
						
						//	������������Чʱ������
						if((i_h_data_vld == 1'b1) && (i_w_data_vld == 1'b1)) begin
							h_data_word_reg[i] <= h_data_word[i+1];
						end
					end
				end
			endcase
		end
	endgenerate
	
	//  -------------------------------------------------------------------------------------
	//	����µ�hashƴ��
	//	��������µ�hash����32bit��wordΪ��λ������ƴ��
	//  -------------------------------------------------------------------------------------	
	generate
		for(i=0; i<WORD_NUM; i=i+1) begin : ov_h_data_loop
			assign	ov_h_data[(DATA_WID*i) +: DATA_WID] = h_data_word_reg[i];
		end
	endgenerate
	
	//  -------------------------------------------------------------------------------------
	//	����µ�hash��Ч
	//  -------------------------------------------------------------------------------------	
	always @ (posedge clk) begin
		
		//	��λ
		if(rst) begin
			data_vld_reg <= 1'b0;
		end
		
		//	������ɵ�hash��Ч��������չ��Ϣ��W��Ч�ࡰ�롱����1��
		else begin
			data_vld_reg <= i_h_data_vld & i_w_data_vld;
		end
	end
	
	assign o_h_data_vld = data_vld_reg;
	
endmodule