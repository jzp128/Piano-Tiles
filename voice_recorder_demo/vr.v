module vr(
inout	[15:0]	DRAM_DQ,				//	SDRAM Data bus 16 Bits
output	[11:0]	DRAM_ADDR,				//	SDRAM Address bus 12 Bits
output			DRAM_LDQM,				//	SDRAM Low-byte Data Mask 
output			DRAM_UDQM,				//	SDRAM High-byte Data Mask
output			DRAM_WE_N,				//	SDRAM Write Enable
output			DRAM_CAS_N,				//	SDRAM Column Address Strobe
output			DRAM_RAS_N,				//	SDRAM Row Address Strobe
output			DRAM_CS_N,				//	SDRAM Chip Select
output			DRAM_BA_0,				//	SDRAM Bank Address 0
output			DRAM_BA_1,				//	SDRAM Bank Address 0
output			DRAM_CLK,				//	SDRAM Clock
output			DRAM_CKE,				//	SDRAM Clock Enable

input			CLOCK_50,				//	On Board 50 MHz

input	[3:0]	KEY,					//	Pushbutton[3:0]
input	[17:0]	SW,						//	Toggle Switch[17:0]
output	[6:0]	HEX0,					//	Seven Segment Digit 0
output	[6:0]	HEX1,					//	Seven Segment Digit 1
output	[6:0]	HEX2,					//	Seven Segment Digit 2
output	[6:0]	HEX3,					//	Seven Segment Digit 3
output	[8:0]	LEDG,					//	LED Green[8:0]
output	reg [17:0]	LEDR,					//	LED Red[17:0]

inout			AUD_ADCLRCK,			//	Audio CODEC ADC LR Clock
input			AUD_ADCDAT,				//	Audio CODEC ADC Data
inout			AUD_DACLRCK,			//	Audio CODEC DAC LR Clock
output			AUD_DACDAT,				//	Audio CODEC DAC Data
inout			AUD_BCLK,				//	Audio CODEC Bit-Stream Clock
output			AUD_XCK,				//	Audio CODEC Chip Clock

inout			I2C_SDAT,				//	I2C Data
output			I2C_SCLK,				//	I2C Clock

output			VGA_CLK,   				//	VGA Clock
output			VGA_HS,					//	VGA H_SYNC
output			VGA_VS,					//	VGA V_SYNC
output			VGA_BLANK,				//	VGA BLANK
output			VGA_SYNC,				//	VGA SYNC
output	[9:0]	VGA_R,   				//	VGA Red[9:0]
output	[9:0]	VGA_G,	 				//	VGA Green[9:0]
output	[9:0]	VGA_B   				//	VGA Blue[9:0]
);

wire reset = !KEY[0];

wire [21:0] ram_addr;
wire [15:0] ram_data_in, ram_data_out;
wire ram_valid, ram_waitrq, ram_read, ram_write;

wire [15:0] audio_out, audio_in;
wire audio_out_allowed, audio_in_available, write_audio_out, read_audio_in;

wire vga_color;
wire [8:0] vga_x;
wire [7:0] vga_y;
wire vga_plot;

wire play = SW[0];
wire pause = SW[1];
wire record = SW[2];
wire [1:0] speed = SW[4:3];
wire [3:0] scale = SW[8:5];

wire [15:0] display_data = play ? audio_out : audio_in;
reg [15:0] display_data_scaled;

// And all we needed was a sign-extended shift...
always @(*)
	case(scale)
		0: display_data_scaled = display_data;
		1: display_data_scaled = {{2{display_data[15]}}, display_data[14:1]};
		2: display_data_scaled = {{3{display_data[15]}}, display_data[14:2]};
		3: display_data_scaled = {{4{display_data[15]}}, display_data[14:3]};
		4: display_data_scaled = {{5{display_data[15]}}, display_data[14:4]};
		5: display_data_scaled = {{6{display_data[15]}}, display_data[14:5]};
		6: display_data_scaled = {{7{display_data[15]}}, display_data[14:6]};
		7: display_data_scaled = {{8{display_data[15]}}, display_data[14:7]};
		8: display_data_scaled = {{9{display_data[15]}}, display_data[14:8]};
		9: display_data_scaled = {{10{display_data[15]}}, display_data[14:9]};
		10: display_data_scaled = {{11{display_data[15]}}, display_data[14:10]};
		11: display_data_scaled = {{12{display_data[15]}}, display_data[14:11]};
		12: display_data_scaled = {{13{display_data[15]}}, display_data[14:12]};
		13: display_data_scaled = {{14{display_data[15]}}, display_data[14:13]};
		14: display_data_scaled = {{15{display_data[15]}}, display_data[14:14]};
		15: display_data_scaled = {16{display_data[15]}};
	endcase



// Blinkenlights

assign LEDR[15:0] = display_data_scaled[15] ? 0 : display_data_scaled;
assign LEDG[8] = pause ? blink_cnt[25] : 0;

reg [25:0] blink_cnt;
always @(posedge CLOCK_50) blink_cnt++;


// Hook up the modules

SDRAM_PLL pll(.inclk0(CLOCK_50), .c0(DRAM_CLK), .c1(VGA_CLK), .c2(AUD_XCK));

sdram ram(	.zs_addr(DRAM_ADDR), .zs_ba({DRAM_BA_1,DRAM_BA_0}), .zs_cas_n(DRAM_CAS_N), .zs_cke(DRAM_CKE), .zs_cs_n(DRAM_CS_N), .zs_dq(DRAM_DQ),
			.zs_dqm({DRAM_UDQM,DRAM_LDQM}), .zs_ras_n(DRAM_RAS_N), .zs_we_n(DRAM_WE_N),
			.clk(CLOCK_50), .az_addr(ram_addr), .az_be_n(2'b00), .az_cs(1), .az_data(ram_data_in), .az_rd_n(!ram_read), .az_wr_n(!ram_write),
			.reset_n(!reset), .za_data(ram_data_out), .za_valid(ram_valid), .za_waitrequest(ram_waitrq));

Audio_Controller Audio_Controller (	.clk(CLOCK_50), .reset(reset), .clear_audio_in_memory(), .read_audio_in(read_audio_in), .clear_audio_out_memory(),
									.left_channel_audio_out({audio_out, 16'b0}), .right_channel_audio_out({audio_out, 16'b0}), .write_audio_out(write_audio_out),
									.AUD_ADCDAT(AUD_ADCDAT), .AUD_BCLK(AUD_BCLK), .AUD_ADCLRCK(AUD_ADCLRCK), .AUD_DACLRCK(AUD_DACLRCK), .I2C_SDAT(I2C_SDAT),
									.audio_in_available(audio_in_available), .left_channel_audio_in({audio_in, 16'bx}), .right_channel_audio_in(),
									.audio_out_allowed(audio_out_allowed), .AUD_XCK(), .AUD_DACDAT(AUD_DACDAT), .I2C_SCLK(I2C_SCLK));
defparam
	Audio_Controller.USE_MIC_INPUT = 1; // 0 - for line in or 1 - for microphone in


playrec rc(	CLOCK_50, reset, ram_addr, ram_data_in, ram_read, ram_write, ram_data_out, ram_valid, ram_waitrq,
			audio_out, audio_in, audio_out_allowed, audio_in_available, write_audio_out, read_audio_in, play, record, pause, speed);

vga_adapter VGA(
			.resetn(!reset),
			.clock(CLOCK_50),
			.colour(vga_color),
			.x(vga_x),
			.y(vga_y),
			.plot(vga_plot),
			.VGA_R(VGA_R),
			.VGA_G(VGA_G),
			.VGA_B(VGA_B),
			.VGA_HS(VGA_HS),
			.VGA_VS(VGA_VS),
			.VGA_BLANK(VGA_BLANK),
			.VGA_SYNC(VGA_SYNC),
			.clock_25(VGA_CLK));
		defparam VGA.RESOLUTION = "320x240";
		defparam VGA.MONOCHROME = "TRUE";

display disp(CLOCK_50, reset, pause, display_data_scaled, vga_x, vga_y, vga_color, vga_plot);


hex2seg h0(ram_addr[17:14], HEX2);
hex2seg h1(ram_addr[21:18], HEX3);
hex2seg h3({2'b00, speed}, HEX1);
hex2seg h4(scale, HEX0);

endmodule
