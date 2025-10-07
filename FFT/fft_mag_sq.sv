module fft_mag_sq #(
    parameter W = 16
) (
    input                clk,
	 input                reset,
	 input                fft_valid,
    input        [W-1:0] fft_imag,
    input        [W-1:0] fft_real,
    output logic [W*2:0] mag_sq,
	 output logic         mag_valid
);

	 logic signed [W*2-1:0] multiply_stage_real, multiply_stage_imag;
    logic signed [W*2:0]   add_stage;

    logic [1:0] valid_pipe;
    
    always_ff @(posedge clk) begin  : mulitplier     //TODO Your code here!
       if (reset) begin
            multiply_stage_real <= 0;
            multiply_stage_imag <= 0;
       end else begin
            multiply_stage_imag <= signed'(fft_imag) * signed'(fft_imag);
            multiply_stage_real <= signed'(fft_real) * signed'(fft_real);
        end
    end

    always_ff @(posedge clk) begin
        if (reset) begin
            add_stage <= 0;
        end else begin
            add_stage <= multiply_stage_real + multiply_stage_imag;
        end
    end

     always_ff @(posedge clk) begin
        if (reset)
            valid_pipe <= 2'b00;
        else
            valid_pipe <= {valid_pipe[0], fft_valid};
    end            

    assign mag_sq    = add_stage;
    assign mag_valid = valid_pipe[1];//TODO set to `1` when mag_sq valid **this should be 2 cycles after valid input!**
    // Hint: you can use a shift register to implement valid.

endmodule
