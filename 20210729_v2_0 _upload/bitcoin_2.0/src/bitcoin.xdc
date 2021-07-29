##  ==================================================
##  引脚约束
##  ==================================================
##  --------------------------------------------------
##	spi flash 定义
##  --------------------------------------------------
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CONFIG_MODE SPIx4 [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 50 [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]
set_property BITSTREAM.CONFIG.UNUSEDPIN PULLUP [current_design]
set_property BITSTREAM.CONFIG.SPI_FALL_EDGE YES [current_design]
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]

##  --------------------------------------------------
##	时钟 定义
##  --------------------------------------------------
set_property -dict {PACKAGE_PIN R4 IOSTANDARD LVCMOS15} [get_ports i_clk]
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets i_clk]

##  --------------------------------------------------
##	串口 定义
##	RX: E14 Y16
##	TX: D17 AA16
##  --------------------------------------------------
set_property -dict {PACKAGE_PIN Y16 IOSTANDARD LVCMOS33} [get_ports i_uart_rx]
set_property -dict {PACKAGE_PIN AA16 IOSTANDARD LVCMOS33} [get_ports o_uart_tx]


##  ==================================================
##  时钟约束
##  ==================================================
##  --------------------------------------------------
##	创建时钟
##  --------------------------------------------------
create_clock -period 20.000 -name i_clk [get_ports i_clk]
create_clock -period 5.001 -name uart_clk
set_clock_groups -name async_clk_group -asynchronous -group [get_clocks -include_generated_clocks i_clk] -group {uart_clk}

##  --------------------------------------------------
##	输入延时
##  --------------------------------------------------
set_input_delay -clock uart_clk 20 [get_ports i_uart_rx]

##  --------------------------------------------------
##	输出延时
##  --------------------------------------------------
set_output_delay -clock uart_clk 20 [get_ports o_uart_tx]

