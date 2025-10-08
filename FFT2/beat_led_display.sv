module beat_led_display (
    input  logic       clk,        // 50 MHz system clock
    input  logic       reset,
    input  logic       beat_pulse,     // Bass beat indicator
    input  logic       snare_pulse,    // Snare indicator  
    input  logic       hihat_pulse,    // Hi-hat indicator
    input  logic [7:0] bpm_value,      // 60-180 BPM
    output logic [9:0] LEDR            // Red LEDs (DE1-SoC has 10 LEDs: LEDR[9:0])
);

    // Parameters for timing calculations
    parameter CLOCK_FREQ = 50_000_000;  // 50 MHz
    parameter PULSE_DURATION_MS = 100;  // 100ms LED pulse duration
    parameter PULSE_CYCLES = CLOCK_FREQ * PULSE_DURATION_MS / 1000; // ~5M cycles
    
    // Counter width to hold 5M cycles (23 bits needed)
    localparam COUNTER_WIDTH = $clog2(PULSE_CYCLES) + 1;

    //==========================================================================
    // Beat Pulse Indicators (100ms duration)
    //==========================================================================
    logic [COUNTER_WIDTH-1:0] bass_counter, snare_counter, hihat_counter;
    logic bass_led, snare_led, hihat_led;
    
    // Bass beat indicator (LEDR[0])
    always_ff @(posedge clk) begin
        if (reset) begin
            bass_counter <= 0;
            bass_led <= 0;
        end else if (beat_pulse) begin
            bass_counter <= PULSE_CYCLES;
            bass_led <= 1;
        end else if (bass_counter > 0) begin
            bass_counter <= bass_counter - 1;
            bass_led <= 1;
        end else begin
            bass_led <= 0;
        end
    end
    
    // Snare beat indicator (LEDR[1])
    always_ff @(posedge clk) begin
        if (reset) begin
            snare_counter <= 0;
            snare_led <= 0;
        end else if (snare_pulse) begin
            snare_counter <= PULSE_CYCLES;
            snare_led <= 1;
        end else if (snare_counter > 0) begin
            snare_counter <= snare_counter - 1;
            snare_led <= 1;
        end else begin
            snare_led <= 0;
        end
    end
    
    // Hi-hat beat indicator (LEDR[2])
    always_ff @(posedge clk) begin
        if (reset) begin
            hihat_counter <= 0;
            hihat_led <= 0;
        end else if (hihat_pulse) begin
            hihat_counter <= PULSE_CYCLES;
            hihat_led <= 1;
        end else if (hihat_counter > 0) begin
            hihat_counter <= hihat_counter - 1;
            hihat_led <= 1;
        end else begin
            hihat_led <= 0;
        end
    end

    //==========================================================================
    // BPM Bar Graph Display (LEDR[9:4] - 6 LEDs)
    //==========================================================================
    logic [5:0] bpm_leds;
    logic [2:0] led_count;
    
    always_comb begin
        // Map BPM 60-180 to LED count 0-6
        // led_count = (bpm_value - 60) / 20 (gives 0-6 range)
        if (bpm_value < 60) begin
            led_count = 0;
        end else if (bpm_value >= 180) begin
            led_count = 6;
        end else begin
            led_count = (bpm_value - 60) / 20; // Divide by 20 for 6-step range
        end
        
        // Generate thermometer code
        case (led_count)
            3'd0: bpm_leds = 6'b000000;
            3'd1: bpm_leds = 6'b000001;
            3'd2: bpm_leds = 6'b000011;
            3'd3: bpm_leds = 6'b000111;
            3'd4: bpm_leds = 6'b001111;
            3'd5: bpm_leds = 6'b011111;
            3'd6: bpm_leds = 6'b111111;
            default: bpm_leds = 6'b000000;
        endcase
    end

    //==========================================================================
    // Heartbeat/Metronome (LEDR[3])
    //==========================================================================
    logic [31:0] metronome_counter;
    logic [31:0] metronome_period;
    logic metronome_led;
    
    // Calculate metronome period: 60 seconds / BPM = period in seconds
    // Period in clock cycles = (60 * CLOCK_FREQ) / BPM
    always_comb begin
        if (bpm_value > 0) begin
            metronome_period = (32'd60 * CLOCK_FREQ) / bpm_value;
        end else begin
            metronome_period = CLOCK_FREQ; // Default 1 Hz if BPM is 0
        end
    end
    
    always_ff @(posedge clk) begin
        if (reset) begin
            metronome_counter <= 0;
            metronome_led <= 0;
        end else if (metronome_counter >= metronome_period) begin
            metronome_counter <= 0;
            metronome_led <= ~metronome_led; // Toggle
        end else begin
            metronome_counter <= metronome_counter + 1;
        end
    end

    //==========================================================================
    // LED Output Assignment
    //==========================================================================
    always_comb begin
        LEDR[0] = bass_led;           // Bass beat
        LEDR[1] = snare_led;          // Snare beat
        LEDR[2] = hihat_led;          // Hi-hat beat
        LEDR[3] = metronome_led;      // Heartbeat/metronome
        LEDR[9:4] = bpm_leds;         // BPM bar graph (6 LEDs)
    end

endmodule