// SNR estimate displayed (integer
// dB) and increases on beats (i.e. claps) and decreases on covering
// the mic

module snr_calculator #(
    parameter DATA_WIDTH,
    parameter SNR_WIDTH,
    parameter ALPHA_SHORT, // 0.4 in Q1.15
    parameter ALPHA_LONG    // 0.025 in Q1.15
)(
    input  logic        clk,
    input  logic        reset,

    input  logic        quiet_period,  // Indicates quiet period for calibration

    // Audio Input
    input  logic [DATA_WIDTH-1:0] audio_input,
    input  logic                  audio_input_valid,
    output logic                  audio_input_ready,

    // SNR Results
    output logic [SNR_WIDTH-1:0]  snr_db,
    output logic [DATA_WIDTH-1:0] signal_rms,
    output logic [DATA_WIDTH-1:0] noise_rms,
    output logic                  output_valid,
    input logic                   output_ready
);

    // ------------------------------
    // Internal signals
    // ------------------------------
    logic signed [DATA_WIDTH-1:0]  abs_audio_input;
    logic signed [DATA_WIDTH:0]    x_diff_signal;
    logic signed [DATA_WIDTH-1:0]  y_signal_reg;
    logic signed [2*DATA_WIDTH-1:0] mult_coefficient_short;

    logic signed [DATA_WIDTH:0]    x_diff_noise;
    logic signed [DATA_WIDTH-1:0]  y_noise_reg;
    logic signed [2*DATA_WIDTH-1:0] mult_coefficient_long;

    logic [3:0] lut_idx_signal, lut_idx_noise;
    logic [15:0] log10_sig, log10_noise;
    logic signed [31:0] snr_temp;

    // ------------------------------
    // Small 16-entry log10 LUT (Q1.15)
    // ------------------------------
    function [15:0] log10_lut(input [3:0] index);
        case(index)
            4'd0: log10_lut = 16'd0;
            4'd1: log10_lut = 16'd147;
            4'd2: log10_lut = 16'd295;
            4'd3: log10_lut = 16'd442;
            4'd4: log10_lut = 16'd590;
            4'd5: log10_lut = 16'd738;
            4'd6: log10_lut = 16'd885;
            4'd7: log10_lut = 16'd1033;
            4'd8: log10_lut = 16'd1181;
            4'd9: log10_lut = 16'd1328;
            4'd10: log10_lut = 16'd1476;
            4'd11: log10_lut = 16'd1624;
            4'd12: log10_lut = 16'd1771;
            4'd13: log10_lut = 16'd1919;
            4'd14: log10_lut = 16'd2067;
            4'd15: log10_lut = 16'd2214;
            default: log10_lut = 16'd0;
        endcase
    endfunction

    // ------------------------------
    // Main EMA and SNR calculation
    // ------------------------------
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            snr_db       <= 0;
            signal_rms   <= 0;
            noise_rms    <= 0;
            output_valid <= 0;
            y_signal_reg <= 0;
            y_noise_reg  <= 0;
            audio_input_ready <= 1; // always ready (no back pressure)
        end
        else begin
            if (audio_input_valid) begin
                // Step 1: magnitude
                abs_audio_input <= audio_input[DATA_WIDTH-1] ? (~audio_input + 1) : audio_input;

                // Step 2: difference
                x_diff_signal <= abs_audio_input - y_signal_reg;
                x_diff_noise  <= abs_audio_input - y_noise_reg;
					 
					 
					 // long EMA updates only during quiet period (noise)   --> so that noise_rms tracks only the background noise during calibration, giving a reliable baseline for SNR
					 if (quiet_period) begin
						  x_diff_noise <= abs_audio_input - y_noise_reg;
						  mult_coefficient_long <= ALPHA_LONG * x_diff_noise;
						  y_noise_reg <= y_noise_reg + (mult_coefficient_long >>> 16);
					 end
					 
					 // noise_rms only adapts when quiet_period = 1.
					 
					 
					 

                // Step 3: multiply by alpha
                mult_coefficient_short <= ALPHA_SHORT * x_diff_signal;
                mult_coefficient_long  <= ALPHA_LONG  * x_diff_noise;

                // Step 4: moving average update
                y_signal_reg <= y_signal_reg + (mult_coefficient_short >>> 16); // Q1.15 alpha
                y_noise_reg  <= y_noise_reg  + (mult_coefficient_long  >>> 16);

                // Step 5: assign RMS approximation
                signal_rms <= y_signal_reg;
                noise_rms  <= y_noise_reg;

                // ------------------------------
                // Step 6: compute SNR using LUT
                // ------------------------------
                lut_idx_signal = y_signal_reg[15:12]; // top 4 bits for LUT index
                lut_idx_noise  = y_noise_reg[15:12];

                log10_sig   = log10_lut(lut_idx_signal);
                log10_noise = log10_lut(lut_idx_noise);

                snr_temp = 20 * ($signed(log10_sig) - $signed(log10_noise));
                snr_db   <= snr_temp >>> 15; // convert to integer dB
					 
            end
        end
    end

endmodule



//                                                                   //*** Fixed point formats: (e.g. W=16, W_FRAC=8)
//		 logic signed [DATA_WIDTH-1:0] 		abs_audio_input;
////		 logic [DATA_WIDTH-1:0] 				alpha_short;    	// large alpha for quick response in a short moving avg         
//		 
////		logic [DATA_WIDTH-1:0] 				alpha_long;
//		
//		
//		logic signed [DATA_WIDTH:0]		x_diff_signal;	// 1 extra bit for subtraction
//
//		logic signed [DATA_WIDTH-1:0]		y_signal_reg;
//		
//		logic signed [DATA_WIDTH-1:0] 	signal_rms;
//		
//		
//		logic signed [DATA_WIDTH+15:0]   mult_coefficient_short;
//
//
//
//		
//		 
//
////	 logic signed [2*DATA_WIDTH-1:0]     a1_mult; // Output of -a_1 multiplier //** multiply: 16.16 (= 8.8 * 8.8)
////    logic signed [2*(DATA_WIDTH+1)-1:0] b0_mult; // Output of b_0 multiplier  //** multiply: 18.16 (= 9.8 * 9.8)
////    logic signed [DATA_WIDTH:0]         add_input; // Output of left adder    //** add: 9.8 (= 8.8 + 8.8) (truncate a1_mult to 8.8)
////						
//
//
//always_ff @(posedge clk) begin
//
//	if (reset) begin
//					snr_db     <= 0;
//					signal_rms     <= 0;
//					noise_rms     <= 0;
//					output_valid<= 0;
//					
//					signal_reg <= 0;
//					
//					audio_input_ready <= 0;
//					
//					// etc...
//					
//					
//					// the student sampel also had: (dont include these yet)
////					xy_diff_signal <= 0;
////					mult_signal <= 0;
//					
//	end
//	
//	else begin
//		
//		if (audio_input_valid) begin
//		
//
//			abs__audio_input <= audio_input[DATA_WIDTH-1] ? (~audio_input + 1) : audio_input; //	If the sample is negative (data[15] = sign bit),
//	
//																														//take its two’s complement to get the absolute value,
//			// Difference (x[n] - y[n-1])
//        x_diff_signal <= abs_audio_input - y_signal_reg;
//
//		  
//		  
//        // Update filter output: y[n] = y[n-1] + α * (x - y[n-1])
//		  mult_coefficient_short <= (ALPHA_SHORT * (abs_input - y_reg));  // α * (x - y)
//		   y_signal_reg <= y_signal_reg + (mult_coefficient_short >>> DATA_WIDTH);        // shift back after fixed-point mult
//			
//			
//			signal_rms <= y_signal_reg;
//			
//		end
//		
//		
//		
////		localparam ONE = 1 << W_FRAC; // 1.0 in fixed point
//  
//		
//		
//		
//	
//	
//	end
//	
//	
//	
//
//end




