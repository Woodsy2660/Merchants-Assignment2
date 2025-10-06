

`timescale 1ps/1ps
module mic_load #(parameter N=16) (
    input  logic bclk,
    input  logic adclrc,
    input  logic adcdat,
    output logic valid,
    output logic [N-1:0] sample_data
);

    logic [N-1:0] temp_rx_data;
    logic [4:0] bit_index_counter;  
    logic adclrc_q;

    logic [N-1:0] temp_rx_next; // temporary combinational copy of the RX register to save bit immediately

    always_ff @(posedge bclk) begin
        adclrc_q <= adclrc;

        if (adclrc & ~adclrc_q) begin   // means it's rising edge of adclrc

            // MSB capture starts immediately when adclrc is detected to go high (rising edge)
            temp_rx_next = temp_rx_data; // // make a copy of current bits
            temp_rx_next[N-1] = adcdat; // write current bit immediately
            temp_rx_data <= temp_rx_next; // store at end of cycle 
            bit_index_counter <= 1;
            valid <= 0;

        end

        else if (bit_index_counter > 0 && bit_index_counter < N) begin
            temp_rx_next = temp_rx_data;
            temp_rx_next[N-1 - bit_index_counter] = adcdat; // first bit received from adcdat goes to MSB, last bit received to LSB.
            temp_rx_data <= temp_rx_next;

            if (bit_index_counter == N-1) begin // we are now at the LSB
                sample_data <= temp_rx_next; // full sample including LSB (because temp_rx_next still has it)
                                            // original problem was the temp_rx_data's LSB got off too early
                valid <= 1;

            end else begin
                valid <= 0;
            end

            bit_index_counter <= bit_index_counter + 1;

        end
        else begin
            valid <= 0;
        end
    end


endmodule






//
//`timescale 1ps/1ps
//module mic_load #(parameter N=16) (
//	input bclk, // Assume a 18.432 MHz clock
//    input adclrc,
//	input adcdat,
//
//    output logic valid,
//    output logic [N-1:0] sample_data
//);
//    // Assume that i2c has already configured the CODEC.
//
//    logic redge_adclrc, adclrc_q; // Rising edge detect on ADCLRC to sense left channel
//    always_ff @(posedge  bclk) begin : adclrc_rising_edge_ff
//        adclrc_q <= adclrc;
//    end
//    assign redge_adclrc = ~adclrc_q & adclrc; // rising edge detected!
//
//
//    integer bit_index = 0;
//    always_ff @(posedge bclk) begin : bit_index_logic
//        if (redge_adclrc) begin
//            bit_index <= 1; // reset as ADCLRC has just risen
//        end
//        else if (bit_index == 0) begin
//            bit_index <= 0;
//        end
//        else if (bit_index < N+1) begin  // Extra index N used for FIFO write enable.
//            bit_index <= bit_index + 1;
//        end
//    end
//
//    logic [N-1:0] temp_rx_data;
//    always_ff @(posedge bclk) begin : rx_logic
//        if (redge_adclrc) begin
//            temp_rx_data[N-1] <= adcdat;
//        end
//        else if (bit_index < N) begin
//            temp_rx_data[N-1-bit_index] <= adcdat;
//        end
//    end
//	
//    always_ff @(posedge bclk) begin
//        valid <= 0;
//        if(bit_index == N-1) begin
//            sample_data <= {temp_rx_data[N-1:1], adcdat};
//            valid <= 1;
//        end
//    end
//endmodule



// version without relying on any blocking statements (like the one during lesson 3)
// This version sees the LEDs stuck at the first one lighting up and flicking all the time 
// (never goes up despite increasing voice volume)

//`timescale 1ps/1ps
//module mic_load #(parameter N=16) (
//    input  logic bclk,       // bit clock from ADC
//    input  logic adclrc,     // word select (left/right channel)
//    input  logic adcdat,     // serial data from ADC
//    output logic valid,      // pulses high when full word captured
//    output logic [N-1:0] sample_data // parallel word output
//);
//
//    logic [N-1:0] temp_rx_data;
//    logic [4:0] bit_index_counter;  
//    logic adclrc_q;
//    logic redge_adclrc;
//
//    // detect rising edge of adclrc
//    always_ff @(posedge bclk) begin
//            adclrc_q <= adclrc;
//            redge_adclrc <= adclrc & ~adclrc_q;     // redge pulse will be 1
//        end
//
//        // shift in bits
//    always_ff @(posedge bclk) begin
//        valid <= 0;
//
//        if (redge_adclrc) begin
//            temp_rx_data[N-1] <= adcdat;
//            bit_index_counter <= 1;
//        end
//        else if (bit_index_counter > 0 && bit_index_counter < N) begin
//            temp_rx_data[N-1-bit_index_counter] <= adcdat;
//            bit_index_counter <= bit_index_counter + 1;
//
//            if (bit_index_counter == N-1) begin
//                valid <= 1; // full word ready on next cycle
//            end
//        end
//
//        if (valid)
//            sample_data <= temp_rx_data; // update one cycle later
//    end
//endmodule








