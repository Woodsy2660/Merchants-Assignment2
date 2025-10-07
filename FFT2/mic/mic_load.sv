`timescale 1ps/1ps

module mic_load #(parameter N=16) (
    input bclk, // Assume a 18.432 MHz clock
    input adclrc,
    input adcdat,
    
    // No ready signal nor handshake: as this module streams live audio data, it cannot be stalled, therefore we only have the valid signal.
    output logic valid,
    output logic [N-1:0] sample_data
);
    
    // Assume that i2c has already configured the CODEC for LJ data, MSB-first and N-bit samples.
    
    // Rising edge detect on ADCLRC to sense left channel
    logic redge_adclrc, adclrc_q; 
    always_ff @(posedge bclk) begin : adclrc_rising_edge_ff
        adclrc_q <= adclrc;
    end
    assign redge_adclrc = ~adclrc_q & adclrc; // rising edge detected!
    
    /*
     * Implement the Timing diagram.
     * -----------------------------
     * You should use a temporary N-bit RX register to store the ADCDAT bitstream from MSB to LSB.
     * Remember that MSB is first, LSB is last.
     * Use `temp_rx_data[(N-1)-bit_index] <= adcdat;`
     * BCLK rising is your trigger to sample the value of ADCDAT into the register at the appropriate bit index.
     * ADCLRC rising (see `redge_adclrc`) signals that the MSB should be sampled on the next rising edge of BCLK.
     * With the above, think about when and how you would reset your bit_index counter.
     */
    
    // State machine states
    typedef enum logic [1:0] {
        IDLE = 2'b00,
        SAMPLING = 2'b01,
        DONE = 2'b10
    } state_t;
    
    state_t state, next_state;
    
    // Bit counter and temporary receive register
    logic [N:0] bit_index;
    logic [N-1:0] temp_rx_data;
    
    // State machine sequential logic
    always_ff @(posedge bclk) begin
        state <= next_state;
    end
    
    // State machine combinational logic
    always_comb begin
        next_state = state;
        
        case (state)
            IDLE: begin
                // Wait for rising edge of ADCLRC to start sampling left channel
                if (redge_adclrc) begin
                    next_state = SAMPLING;
                end
            end
            
            SAMPLING: begin
                // Continue sampling until we've collected all N bits
                if (bit_index == N) begin
                    next_state = DONE;
                end
            end
            
            DONE: begin
                // Return to IDLE to wait for next left channel
                next_state = IDLE;
            end
        endcase
    end
    
    // Data sampling and bit counter logic
    always_ff @(posedge bclk) begin
        valid <= 1'b0; // Default: valid is low
        
        case (state)
            IDLE: begin
                if (redge_adclrc) begin
                    // Start of left channel detected
                    // Sample MSB on the next clock edge (which is now)
                    bit_index <= 1;
                    temp_rx_data[N-1] <= adcdat; // Sample MSB
                end else begin
                    bit_index <= 0;
                end
            end
            
            SAMPLING: begin
                if (bit_index < N) begin
                    // Sample data bit (MSB first)
                    temp_rx_data[(N-1)-bit_index] <= adcdat;
                    bit_index <= bit_index + 1;
                end else if (bit_index == N) begin
                    // All bits sampled, transfer to output
                    sample_data <= temp_rx_data;
                    valid <= 1'b1; // Pulse valid for one cycle
                    bit_index <= 0;
                end
            end
            
            DONE: begin
                bit_index <= 0;
            end
        endcase
    end

endmodule
