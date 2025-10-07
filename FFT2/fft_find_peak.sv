module fft_find_peak #(
    parameter NSamples = 1024, // 1024 N-points
    parameter W        = 33,   // For 16x2 + 1
    parameter NBits    = $clog2(NSamples)

) (
    input                        clk,
    input                        reset,
    input  [W-1:0]               mag,
    input                        mag_valid,
    output logic [W-1:0]         peak = 0,
    output logic [NBits-1:0]     peak_k = 0,
    output logic                 peak_valid
);

 // Counter for input stream
    logic [NBits-1:0] i = 0;

    // Bit-reversed index
    logic [NBits-1:0] k;
    always_comb for (integer j=0; j<NBits; j=j+1)
        k[j] = i[NBits-1-j];

    // Temporary registers to track peak within window
    logic [W-1:0]     peak_temp = 0;
    logic [NBits-1:0] peak_k_temp = 0;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            i           <= 0;
            peak_temp   <= 0;
            peak_k_temp <= 0;
            peak        <= 0;
            peak_k      <= 0;
            peak_valid  <= 0;
        end else if (!mag_valid) begin
            // Stream idle: reset counter and temp peak
            i         <= 0;
            peak_temp <= 0;
            peak_k_temp <= 0;
            peak_valid <= 0;
        end else begin
            peak_valid <= 0; // Default low

            // Only update peak if k is non-negative (MSB=0)
            if (!k[NBits-1]) begin
                if (mag > peak_temp) begin
                    peak_temp   <= mag;
                    peak_k_temp <= k;
                end
            end

            // Increment counter
            if (i == NSamples-1) begin
                // End of FFT window: commit peak
                peak       <= peak_temp;
                peak_k     <= peak_k_temp;
                peak_valid <= 1'b1;

                // Reset for next window
                i           <= 0;
                peak_temp   <= 0;
                peak_k_temp <= 0;
            end else begin
                i <= i + 1;
            end
        end
    end

endmodule

