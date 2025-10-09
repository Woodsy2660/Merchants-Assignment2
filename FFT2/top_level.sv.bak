module top_level #(
	parameter int DE1_SOC = 1 // !!!IMPORTANT: Set this to 1 for DE1-SoC or 0 for DE2-115
) (
	input       CLOCK_50,     // 50 MHz only used as input to the PLLs.

	// DE1-SoC I2C to WM8731:
	output	    FPGA_I2C_SCLK,
	inout       FPGA_I2C_SDAT,
	// DE2-115 I2C to WM8731:
	output      I2C_SCLK,
	inout       I2C_SDAT,

	output [6:0] HEX0,
	output [6:0] HEX1,
	output [6:0] HEX2,
	output [6:0] HEX3,
	output [9:0] LEDR,      // Red LEDs for beat display
	input  [3:0] KEY,
	input		AUD_ADCDAT,
	input       AUD_BCLK,     // 3.072 MHz clock from the WM8731
	output      AUD_XCK,      // 18.432 MHz sampling clock to the WM8731
	input       AUD_ADCLRCK
);
// ┌──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
// │     ┌─────────┐                                           ┌───────────────────────────────────────┐                                      │
// │     │ i2c_pll ├──► i2c_clk (20 kHz)                       │   WM8731 Audio Codec (External chip)  │                                      │
// │     └─────────┘         │                                 │                                       │                                      │
// │                         ▼                                 │  ┌──────────────────────────────┐     │                                      │
// │                    ┌─────────────────────┐                │  │   AUD_ADCDAT  (mic data)     ──────│─────┐                                │
// │                    │  set_audio_encoder  │                │  │   AUD_ADCLRCK (L/R clock)    ──────│──┐  │                                │
// │                    │  (I2C Config Setup) ├────────────────│──►   I2C_SCLK/I2C_SDAT (config) │     │  │  │                                │
// │                    │   - DE1: FPGA_I2C_* │                │  │   AUD_BCLK (3.072 MHz)       ──────│──┼──┼──► audio_clk (3.072 MHz)       │
// │                    │   - DE2: I2C_*      │             ┌──│──►   AUD_XCK  (18.432 MHz)      │     │  │  │      │                         │
// │                    └─────────────────────┘             │  │  └──────────────────────────────┘     │  │  │      │                         │
// │                                                        │  └───────────────────────────────────────┘  │  │      │                         │
// │     ┌─────────┐                                        │                                             │  │      │                         │
// │     │ adc_pll ├──► adc_clk (18.432 MHz) ───────────────┘                                             │  │      │                         │
// │     └─────────┘         │                                                                            │  │      │                         │
// │                         │                                                                            ▼  ▼      ▼                         │
// │                         │                                                                    ┌───────────────────┐                       │
// │                         │                                                                    │     mic_load      │                       │
// │                         │                                                                    │  (Deserializer)   │                       │
// │                         │                                                                    └──────┬────────────┘                       │
// │                         │                                                                           │audio_input_data[15:0]              │
// │                         │                                                                           │audio_input_valid                   │
// │                         │                                                                           ▼                                    │
// │                         │                                                            ┌─────────────────────────────┐                     │
// │                         └────────────────────────────────────────────────────────────┤    fft_pitch_detect         │                     │
// │                                                        fft_clk (18.432 MHz) ────────►│  (DSP Pipeline Module)      │                     │
// │                                                       audio_clk (3.072 MHz) ────────►│  See detailed diagram above │                     │
// │                                                                                      └──────────────┬──────────────┘                     │
// │                                                                                                     │pitch_output_data[9:0]              │
// │                                                                                                     ▼                                    │
// │                                                                                            ┌──────────────────┐      ┌─────────────────┐ │
// │                                                                                            │     display      │      │ HEX0,HEX1,HEX2, │ │
// │                                                                                            │  (7-seg decode)  ├─────►│     HEX3        │ │
// │  KEY[0] ───► ~reset                                                                        └──────────────────┘      └─────────────────┘ │
// └──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
//  Clock Domains:  audio_clk (3.072 MHz from WM8731), adc_clk & fft_clk (18.432 MHz), i2c_clk (20 kHz)

	localparam W        = 16;   //NOTE: To change this, you must also change the Twiddle factor initialisations in r22sdf/Twiddle.v. You can use r22sdf/twiddle_gen.pl.
	localparam NSamples = 1024; //NOTE: To change this, you must also change the SdfUnit instantiations in r22sdf/FFT.v accordingly.

	logic i2c_clk; i2c_pll i2c_pll_u (.areset(1'b0),.inclk0(CLOCK_50),.c0(i2c_clk)); // generate 20 kHz clock
	logic adc_clk; adc_pll adc_pll_u (.areset(1'b0),.inclk0(CLOCK_50),.c0(adc_clk)); // generate 18.432 MHz clock
	logic audio_clk; assign audio_clk = AUD_BCLK; // 3.072 MHz clock from the WM8731

	assign AUD_XCK = adc_clk; // The WM8731 needs a 18.432 MHz sampling clock from the FPGA. AUD_BCLK is then 1/6th of this.

	// Board-specific I2C connections:
	generate
		if (DE1_SOC) begin : DE1_SOC_BOARD
			set_audio_encoder set_codec_de1_soc (.i2c_clk(i2c_clk), .I2C_SCLK(FPGA_I2C_SCLK), .I2C_SDAT(FPGA_I2C_SDAT)); // Connected to the DE1-SoC I2C pins
			assign I2C_SCLK = 1'b1;  // Tie-off unused DE2-115 I2C pins
			assign I2C_SDAT = 1'bZ;
		end else begin : DE2_115_BOARD
			set_audio_encoder set_codec_de2_115 (.i2c_clk(i2c_clk), .I2C_SCLK(I2C_SCLK), .I2C_SDAT(I2C_SDAT)); // Connected to the DE2-115 I2C pins
			assign FPGA_I2C_SCLK = 1'b1; // Tie-off unused DE1-SoC I2C pins
			assign FPGA_I2C_SDAT = 1'bZ;
		end
	endgenerate
	// The above modules configure the WM8731 audio codec for microphone input. They are in set_audio_encoder.v and use the i2c_master module in i2c_master.sv.

	logic reset; assign reset = ~KEY[0];

	// Audio Input
	logic [W-1:0]              audio_input_data;
	logic                      audio_input_valid;
	mic_load #(.N(W)) u_mic_load (
		.adclrc(AUD_ADCLRCK),
		.bclk(AUD_BCLK),
		.adcdat(AUD_ADCDAT),
		.sample_data(audio_input_data),
		.valid(audio_input_valid)
	);
	
	logic [$clog2(NSamples)-1:0] pitch_output_data;
	logic [W*2:0] fft_mag_sq;
	logic [$clog2(NSamples)-1:0] fft_bin_index;
	logic fft_mag_valid;
	
	fft_pitch_detect #(.W(W), .NSamples(NSamples)) u_fft_pitch_detect (
	    .audio_clk(audio_clk),
	    .fft_clk(adc_clk), // Reuse ADC sampling clock for the FFT pipeline.
	    .reset(reset),
	    .audio_input_data(audio_input_data),
	    .audio_input_valid(audio_input_valid),
	    .pitch_output_data(pitch_output_data),
	    .pitch_output_valid(),
	    // Beat detection outputs
	    .fft_mag_sq_out(fft_mag_sq),
	    .fft_bin_index_out(fft_bin_index),
	    .fft_mag_valid_out(fft_mag_valid)
	);
	

	// Beat Detection System
	logic beat_pulse, snare_pulse, hihat_pulse;
	logic [7:0] bpm_value;
	
	beat_detector u_beat_detector (
		.clk(adc_clk),
		.reset(reset),
		.fft_mag_sq(fft_mag_sq),
		.fft_bin_index(fft_bin_index[9:0]), // Only need lower 10 bits for 1024 samples
		.fft_valid(fft_mag_valid),
		.beat_pulse(beat_pulse),
		.snare_pulse(snare_pulse),
		.hihat_pulse(hihat_pulse),
		.bpm_value(bpm_value)
	);
	
	// LED Display for Beat Visualization
	beat_led_display u_beat_led_display (
		.clk(CLOCK_50),  // Use 50MHz clock for LED timing
		.reset(reset),
		.beat_pulse(beat_pulse),
		.snare_pulse(snare_pulse),
		.hihat_pulse(hihat_pulse),
		.bpm_value(bpm_value),
		.LEDR(LEDR)
	);

	// Display BPM on 7-segment instead of pitch
	display u_display (
		.clk(adc_clk),
		.value({2'b0, bpm_value}), // Display BPM instead of pitch
		.display0(HEX0),
		.display1(HEX1),
		.display2(HEX2),
		.display3(HEX3)
	);

endmodule


