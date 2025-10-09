`timescale 1ps/1ps
module snr_calculator_tb;

    localparam DATA_WIDTH = 16;
    localparam SNR_WIDTH  = 8;
    localparam ALPHA_SHORT = 16'd3277; // Q1.15
    localparam ALPHA_LONG  = 16'd655;  // Q1.15
    localparam NSamples    = 1024;

    // Clock parameters
    localparam TCLK      = 20_000; // 50 MHz clock period (20 ns)
    localparam AUDIO_CLK = 54_253 * 6; // ~3.072 MHz for audio input
	 
	 // Note:
	 // For actual audio chip, 3.072 MHz audio clock period ≈ 325.52 ns
	//always #162.76 clk = ~clk;  // toggle every half period
		
	// but we can use fast clock here to save simulation time
		

    // Clocks and reset
    logic clk = 0;
    logic reset = 1;
    always #(TCLK/2) clk = ~clk;

    // DUT signals
    logic [DATA_WIDTH-1:0] audio_input;
    logic audio_input_valid;
    logic audio_input_ready;
    logic quiet_period;

    logic [SNR_WIDTH-1:0] snr_db;
    logic [DATA_WIDTH-1:0] signal_rms;
    logic [DATA_WIDTH-1:0] noise_rms;
    logic output_valid;
    logic output_ready = 1'b1;

    // DUT instantiation
    snr_calculator #(
        .DATA_WIDTH(DATA_WIDTH),
        .SNR_WIDTH(SNR_WIDTH),
        .ALPHA_SHORT(ALPHA_SHORT),
        .ALPHA_LONG(ALPHA_LONG)
    ) DUT (
        .clk(clk),
        .reset(reset),
        .quiet_period(quiet_period),
        .audio_input(audio_input),
        .audio_input_valid(audio_input_valid),
        .audio_input_ready(audio_input_ready),
        .snr_db(snr_db),
        .signal_rms(signal_rms),
        .noise_rms(noise_rms),
        .output_valid(output_valid),
        .output_ready(output_ready)
    );

    // Test waveform
    logic [DATA_WIDTH-1:0] input_signal [0:NSamples-1];
    initial $readmemh("audio_waveform.hex", input_signal);

    // Simulation control
    integer i = 0;
    initial begin
        $dumpfile("snr_waveform.vcd");
        $dumpvars();
        reset = 1;
        #(TCLK*5);
        reset = 0;
        #(TCLK*5);
        quiet_period = 1'b0;
    end

    // Input driver
    always_ff @(posedge clk) begin
        if (!reset) begin
            audio_input <= input_signal[i];
            audio_input_valid <= 1'b1;
            quiet_period <= (i < 10); // example: first 10 samples are quiet
            i <= (i < NSamples-1) ? i + 1 : 0;
        end else begin
            audio_input_valid <= 0;
        end
    end

    // Timeout watchdog
    initial begin
        #(TCLK*1_000_000); // arbitrary long timeout
        $error("Simulation timed out!");
        $finish();
    end

endmodule





// testbench must be self-contained module with no ports, and it instantiates the DUT internally




		
		
		
		