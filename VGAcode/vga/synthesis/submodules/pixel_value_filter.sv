module pixel_value_filter (
    input  logic        clk,
    input  logic        reset,
    input  logic [7:0]  intensity,       // Brightness control input

    // Avalon-ST Input
    input  logic [29:0] data_in,         // Pixel input from VGA Face source
    input  logic        startofpacket_in,// Start of packet signal
    input  logic        endofpacket_in,  // End of packet signal
    input  logic        valid_in,        // Input data is valid
    output logic        ready_in,        // We are ready for signal

    // Avalon-ST Output
    output logic [29:0] data_out,         // Pixel input to VGA
    output logic        startofpacket_out,// Start of packet signal
    output logic        endofpacket_out,  // End of packet signal
    output logic        valid_out,        // Data valid signal
    input  logic        ready_out         // Data ready signal from VGA
);

    // Extract RGB components from 30-bit input
    // Input format from VGA Face: {R[7:0], 2'b00, G[7:0], 2'b00, B[7:0], 2'b00}
    logic [7:0] r_in, g_in, b_in;
    logic [7:0] r_filtered, g_filtered, b_filtered;

    // Pipeline registers for Avalon-ST signals
    logic startofpacket_reg;
    logic endofpacket_reg;
    logic valid_reg;

    // Extract RGB components from input
    // Bit layout: [29:22]=R, [21:20]=pad, [19:12]=G, [11:10]=pad, [9:2]=B, [1:0]=pad
    assign r_in = data_in[29:22];
    assign g_in = data_in[19:12];
    assign b_in = data_in[9:2];

    // Ready signal - we're ready for data (input) when downstream is ready (for our output)
    assign ready_in = ready_out;

    // Brightness adjustment logic
    // Multiply each channel by intensity, then divide by 256 (right shift by 8)
    // This scales the pixel value: pixel_out = pixel_in × (intensity / 256)
    logic [15:0] r_mult, g_mult, b_mult;  // 8-bit × 8-bit = 16-bit result
    
    assign r_mult = r_in * intensity;
    assign g_mult = g_in * intensity;
    assign b_mult = b_in * intensity;
    
    // Divide by 256 (right shift by 8) to get final 8-bit values
    assign r_filtered = r_mult[15:8];
    assign g_filtered = g_mult[15:8];
    assign b_filtered = b_mult[15:8];

    // Assign outputs directly (no pipeline for simple combinational logic)
    // Output format: {R[7:0], 2'b00, G[7:0], 2'b00, B[7:0], 2'b00}
    assign data_out = {r_filtered, 2'b00, g_filtered, 2'b00, b_filtered, 2'b00};
    assign startofpacket_out = startofpacket_in;
    assign endofpacket_out   = endofpacket_in;
    assign valid_out         = valid_in;

endmodule