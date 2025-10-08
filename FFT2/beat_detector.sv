module beat_detector (
    input  logic        clk,              // 18.432 MHz
    input  logic        reset,
    input  logic [31:0] fft_mag_sq,       // |X[k]|² from FFT
    input  logic [9:0]  fft_bin_index,    // 0-511
    input  logic        fft_valid,        // New frame ready
    output logic        beat_pulse,       // Bass/kick
    output logic        snare_pulse,      // Snare
    output logic        hihat_pulse,      // Hi-hat
    output logic [7:0]  bpm_value         // 60-180 BPM
);

    // Parameters for thresholds and timing
    parameter BPM_CONSTANT      = 20'd180008;   // (703 * 256) for BPM calculation
    parameter DEBOUNCE_FRAMES   = 4;
    parameter BUFFER_SIZE       = 16;

    //==========================================================================
    // STAGE 1: Band Summation - Fixed accumulator reset timing
    //==========================================================================
    logic [31:0] energy_bass_accum, energy_snare_accum, energy_hihat_accum;
    logic [31:0] energy_bass_stage1, energy_snare_stage1, energy_hihat_stage1;
    logic stage1_valid;
    logic [9:0] bin_counter;
    
    always_ff @(posedge clk) begin
        if (reset) begin
            energy_bass_accum <= 0;
            energy_snare_accum <= 0;
            energy_hihat_accum <= 0;
            energy_bass_stage1 <= 0;
            energy_snare_stage1 <= 0;
            energy_hihat_stage1 <= 0;
            stage1_valid <= 0;
            bin_counter <= 0;
        end else if (fft_valid) begin
            // Bass: bins 3-17
            if (fft_bin_index >= 10'd3 && fft_bin_index <= 10'd17) begin
                energy_bass_accum <= energy_bass_accum + fft_mag_sq;
            end
            
            // Snare: bins 13-43  
            if (fft_bin_index >= 10'd13 && fft_bin_index <= 10'd43) begin
                energy_snare_accum <= energy_snare_accum + fft_mag_sq;
            end
            
            // Hi-hat: bins 256-512
            if (fft_bin_index >= 10'd256 && fft_bin_index <= 10'd511) begin
                energy_hihat_accum <= energy_hihat_accum + fft_mag_sq;
            end
            
            bin_counter <= bin_counter + 1;
            
            // Frame complete when all 512 bins processed
            if (bin_counter == 10'd511) begin
                // Copy accumulators to output registers
                energy_bass_stage1 <= energy_bass_accum;
                energy_snare_stage1 <= energy_snare_accum;
                energy_hihat_stage1 <= energy_hihat_accum;
                stage1_valid <= 1;
                bin_counter <= 0;
                // Reset accumulators for next frame
                energy_bass_accum <= 0;
                energy_snare_accum <= 0;
                energy_hihat_accum <= 0;
            end else begin
                stage1_valid <= 0;
            end
        end else begin
            stage1_valid <= 0;
        end
    end

    //==========================================================================
    // STAGE 2: Exponential Smoothing - Bit-shift approximations (no DSP blocks)
    //==========================================================================
    logic [31:0] alpha_new_bass, alpha_new_snare, alpha_new_hihat;
    logic [31:0] one_minus_alpha_prev_bass, one_minus_alpha_prev_snare, one_minus_alpha_prev_hihat;
    logic [31:0] energy_bass_smooth, energy_snare_smooth, energy_hihat_smooth;
    logic stage2_valid;
    
    always_ff @(posedge clk) begin
        if (reset) begin
            energy_bass_smooth <= 0;
            energy_snare_smooth <= 0;
            energy_hihat_smooth <= 0;
            stage2_valid <= 0;
        end else if (stage1_valid) begin
            // E_smooth = α×E + (1-α)×E_prev using bit-shift approximations
            // α ≈ 0.4375 = (E>>2) + (E>>3) + (E>>4)
            // (1-α) ≈ 0.625 = (E>>1) + (E>>3)
            
            alpha_new_bass = (energy_bass_stage1 >> 2) + (energy_bass_stage1 >> 3) + (energy_bass_stage1 >> 4);
            one_minus_alpha_prev_bass = (energy_bass_smooth >> 1) + (energy_bass_smooth >> 3);
            energy_bass_smooth <= alpha_new_bass + one_minus_alpha_prev_bass;
            
            alpha_new_snare = (energy_snare_stage1 >> 2) + (energy_snare_stage1 >> 3) + (energy_snare_stage1 >> 4);
            one_minus_alpha_prev_snare = (energy_snare_smooth >> 1) + (energy_snare_smooth >> 3);
            energy_snare_smooth <= alpha_new_snare + one_minus_alpha_prev_snare;
            
            alpha_new_hihat = (energy_hihat_stage1 >> 2) + (energy_hihat_stage1 >> 3) + (energy_hihat_stage1 >> 4);
            one_minus_alpha_prev_hihat = (energy_hihat_smooth >> 1) + (energy_hihat_smooth >> 3);
            energy_hihat_smooth <= alpha_new_hihat + one_minus_alpha_prev_hihat;
            
            stage2_valid <= 1;
        end else begin
            stage2_valid <= 0;
        end
    end

    //==========================================================================
    // STAGE 3: Flux (Onset Detection)
    //==========================================================================
    logic [31:0] energy_bass_prev, energy_snare_prev, energy_hihat_prev;
    logic [31:0] flux_bass, flux_snare, flux_hihat;
    logic stage3_valid;
    
    always_ff @(posedge clk) begin
        if (reset) begin
            energy_bass_prev <= 0;
            energy_snare_prev <= 0;
            energy_hihat_prev <= 0;
            flux_bass <= 0;
            flux_snare <= 0;
            flux_hihat <= 0;
            stage3_valid <= 0;
        end else if (stage2_valid) begin
            // flux = max(0, E_smooth - E_smooth_prev)
            flux_bass <= (energy_bass_smooth > energy_bass_prev) ? 
                        (energy_bass_smooth - energy_bass_prev) : 32'd0;
            flux_snare <= (energy_snare_smooth > energy_snare_prev) ? 
                         (energy_snare_smooth - energy_snare_prev) : 32'd0;
            flux_hihat <= (energy_hihat_smooth > energy_hihat_prev) ? 
                         (energy_hihat_smooth - energy_hihat_prev) : 32'd0;
            
            // Store previous values
            energy_bass_prev <= energy_bass_smooth;
            energy_snare_prev <= energy_snare_smooth;
            energy_hihat_prev <= energy_hihat_smooth;
            
            stage3_valid <= 1;
        end else begin
            stage3_valid <= 0;
        end
    end

    //==========================================================================
    // STAGE 4A: Adaptive Threshold - Buffer Update (Fixed timing)
    //==========================================================================
    logic [31:0] bass_buffer [BUFFER_SIZE-1:0];
    logic [31:0] snare_buffer [BUFFER_SIZE-1:0];
    logic [31:0] hihat_buffer [BUFFER_SIZE-1:0];
    logic [3:0] buffer_index;
    logic stage4a_valid;
    
    always_ff @(posedge clk) begin
        if (reset) begin
            for (int i = 0; i < BUFFER_SIZE; i++) begin
                bass_buffer[i] <= 0;
                snare_buffer[i] <= 0; 
                hihat_buffer[i] <= 0;
            end
            buffer_index <= 0;
            stage4a_valid <= 0;
        end else if (stage3_valid) begin
            // Store smoothed energy in circular buffer
            bass_buffer[buffer_index] <= energy_bass_smooth;
            snare_buffer[buffer_index] <= energy_snare_smooth;
            hihat_buffer[buffer_index] <= energy_hihat_smooth;
            buffer_index <= (buffer_index == BUFFER_SIZE-1) ? 0 : buffer_index + 1;
            stage4a_valid <= 1;
        end else begin
            stage4a_valid <= 0;
        end
    end
    
    //==========================================================================
    // STAGE 4B: Adaptive Threshold - Sum Calculation (Pipelined)
    //==========================================================================
    logic [35:0] bass_sum, snare_sum, hihat_sum;
    logic [31:0] energy_bass_local, energy_snare_local, energy_hihat_local;
    logic stage4_valid;
    
    always_ff @(posedge clk) begin
        if (reset) begin
            energy_bass_local <= 0;
            energy_snare_local <= 0;
            energy_hihat_local <= 0;
            stage4_valid <= 0;
        end else if (stage4a_valid) begin
            // Calculate local average using summation (16 elements acceptable for timing)
            bass_sum = 0;
            snare_sum = 0;
            hihat_sum = 0;
            
            // Sum all buffer elements
            for (int i = 0; i < BUFFER_SIZE; i++) begin
                bass_sum = bass_sum + bass_buffer[i];
                snare_sum = snare_sum + snare_buffer[i];
                hihat_sum = hihat_sum + hihat_buffer[i];
            end
            
            energy_bass_local <= bass_sum >> 4;  // Divide by 16
            energy_snare_local <= snare_sum >> 4;
            energy_hihat_local <= hihat_sum >> 4;
            stage4_valid <= 1;
        end else begin
            stage4_valid <= 0;
        end
    end

    //==========================================================================
    // STAGE 5: Beat Detection - Bit-shift threshold approximations (no DSP blocks)
    //==========================================================================
    logic [31:0] bass_threshold, snare_threshold, hihat_threshold;
    logic [3:0] bass_debounce, snare_debounce, hihat_debounce;
    logic bass_detect, snare_detect, hihat_detect;
    logic stage5_valid;
    
    always_ff @(posedge clk) begin
        if (reset) begin
            bass_debounce <= 0;
            snare_debounce <= 0;
            hihat_debounce <= 0;
            bass_detect <= 0;
            snare_detect <= 0;
            hihat_detect <= 0;
            stage5_valid <= 0;
        end else if (stage4_valid) begin
            // Decrement debounce counters
            if (bass_debounce > 0) bass_debounce <= bass_debounce - 1;
            if (snare_debounce > 0) snare_debounce <= snare_debounce - 1;
            if (hihat_debounce > 0) hihat_debounce <= hihat_debounce - 1;
            
            // Beat detection: E_smooth > C×E_local AND flux > 0 AND debounce expired
            // Using bit-shift threshold approximations:
            // Bass (C≈1.375): threshold = E_local + (E_local>>2) + (E_local>>3)
            // Snare (C≈1.75): threshold = E_local + (E_local>>1) + (E_local>>2)
            // Hihat (C≈2.25): threshold = (E_local<<1) + (E_local>>2)
            
            bass_threshold = energy_bass_local + (energy_bass_local >> 2) + (energy_bass_local >> 3);
            snare_threshold = energy_snare_local + (energy_snare_local >> 1) + (energy_snare_local >> 2);
            hihat_threshold = (energy_hihat_local << 1) + (energy_hihat_local >> 2);
            
            bass_detect <= (energy_bass_smooth > bass_threshold) && 
                          (flux_bass > 0) && (bass_debounce == 0);
                          
            snare_detect <= (energy_snare_smooth > snare_threshold) && 
                           (flux_snare > 0) && (snare_debounce == 0);
                           
            hihat_detect <= (energy_hihat_smooth > hihat_threshold) && 
                           (flux_hihat > 0) && (hihat_debounce == 0);
            
            // Set debounce when beat detected
            if (bass_detect) bass_debounce <= DEBOUNCE_FRAMES;
            if (snare_detect) snare_debounce <= DEBOUNCE_FRAMES;  
            if (hihat_detect) hihat_debounce <= DEBOUNCE_FRAMES;
            
            stage5_valid <= 1;
        end else begin
            bass_detect <= 0;
            snare_detect <= 0;
            hihat_detect <= 0;
            stage5_valid <= 0;
        end
    end

    //==========================================================================
    // STAGE 6: Pulse & BPM - Fixed BPM calculation
    //==========================================================================
    logic [15:0] bass_interval_buffer [3:0];
    logic [1:0] interval_index;
    logic [15:0] frame_counter;
    logic [15:0] last_bass_frame;
    logic [19:0] bpm_calc;
    logic [15:0] interval;
    logic [17:0] avg_interval;
    logic [7:0] bpm_result;
    
    always_ff @(posedge clk) begin
        if (reset) begin
            beat_pulse <= 0;
            snare_pulse <= 0;
            hihat_pulse <= 0;
            frame_counter <= 0;
            last_bass_frame <= 0;
            interval_index <= 0;
            bpm_value <= 8'd120; // Default 120 BPM
            for (int i = 0; i < 4; i++) begin
                bass_interval_buffer[i] <= 16'd704; // Default ~120 BPM interval
            end
        end else if (stage5_valid) begin
            frame_counter <= frame_counter + 1;
            
            // Generate single-cycle pulses
            beat_pulse <= bass_detect;
            snare_pulse <= snare_detect;
            hihat_pulse <= hihat_detect;
            
            // BPM calculation from bass intervals
            if (bass_detect) begin
                interval = frame_counter - last_bass_frame;
                last_bass_frame <= frame_counter;
                
                // Store interval in circular buffer
                bass_interval_buffer[interval_index] <= interval;
                interval_index <= interval_index + 1;
                
                // Calculate average interval
                avg_interval = (bass_interval_buffer[0] + bass_interval_buffer[1] + 
                               bass_interval_buffer[2] + bass_interval_buffer[3]) >> 2;
                
                // BPM = 60000 / (frames × 85.33ms)
                // Use BPM_CONSTANT / avg_interval then >> 8 for integer BPM
                if (avg_interval > 0) begin
                    bpm_calc = BPM_CONSTANT / avg_interval; // 180,008 / avg_interval
                    bpm_result = bpm_calc >> 8; // Extract integer BPM
                    if (bpm_result < 60) bpm_value <= 8'd60;
                    else if (bpm_result > 180) bpm_value <= 8'd180;
                    else bpm_value <= bpm_result;
                end
            end
        end else begin
            beat_pulse <= 0;
            snare_pulse <= 0;
            hihat_pulse <= 0;
        end
    end

endmodule