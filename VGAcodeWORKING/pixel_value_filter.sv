module pixel_value_filter (
    input  logic        clk,
    input  logic        reset,
    input  logic [7:0]  intensity,       // Brightness control input
    input  logic [2:0]  filter_select,   // Filter selection (3 bits for 8 filters)
    // Avalon-ST Input
    input  logic [29:0] data_in,         // Pixel input from VGA Face source
    input  logic        startofpacket_in,// Start of packet signal
    input  logic        endofpacket_in,  // End of packet signal
    input  logic        valid_in,        // Input data is valid
    output logic        ready_in,        // We are ready for signal
    // Avalon-ST Output
    output logic [29:0] data_out,        // Pixel input to VGA
    output logic        startofpacket_out,// Start of packet signal
    output logic        endofpacket_out,  // End of packet signal
    output logic        valid_out,        // Data valid signal
    input  logic        ready_out        // Data ready signal from VGA
);
    // Extract RGB components from 30-bit input
    logic [7:0] r_in, g_in, b_in;
    logic [7:0] r_filtered, g_filtered, b_filtered;
    logic [7:0] r_color, g_color, b_color;
    
    // Extract RGB components from input
    assign r_in = data_in[29:22];
    assign g_in = data_in[19:12];
    assign b_in = data_in[9:2];
    
    // Ready signal
    assign ready_in = ready_out;
    
    // Apply color filters based on filter_select
    always_comb begin
        case (filter_select)
            3'b000: begin // Normal (no filter)
                r_color = r_in;
                g_color = g_in;
                b_color = b_in;
            end
            3'b001: begin // Grayscale (average method)
                logic [8:0] avg;
                avg = (r_in + g_in + b_in) / 3;
                r_color = avg[7:0];
                g_color = avg[7:0];
                b_color = avg[7:0];
            end
            3'b010: begin // Sepia tone
                logic [9:0] sepia_r, sepia_g, sepia_b;
                sepia_r = (r_in * 393 + g_in * 769 + b_in * 189) >> 10;
                sepia_g = (r_in * 349 + g_in * 686 + b_in * 168) >> 10;
                sepia_b = (r_in * 272 + g_in * 534 + b_in * 131) >> 10;
                r_color = (sepia_r > 255) ? 8'd255 : sepia_r[7:0];
                g_color = (sepia_g > 255) ? 8'd255 : sepia_g[7:0];
                b_color = (sepia_b > 255) ? 8'd255 : sepia_b[7:0];
            end
            3'b011: begin // Red channel only
                r_color = r_in;
                g_color = 8'd0;
                b_color = 8'd0;
            end
            3'b100: begin // Green channel only
                r_color = 8'd0;
                g_color = g_in;
                b_color = 8'd0;
            end
            3'b101: begin // Blue channel only
                r_color = 8'd0;
                g_color = 8'd0;
                b_color = b_in;
            end
            3'b110: begin // Inverted colors
                r_color = ~r_in;
                g_color = ~g_in;
                b_color = ~b_in;
            end
            3'b111: begin // Cyan-Magenta swap (artistic)
                r_color = b_in;
                g_color = g_in;
                b_color = r_in;
            end
        endcase
    end
    
    // Apply brightness/intensity adjustment
    logic [15:0] r_mult, g_mult, b_mult;
    
    assign r_mult = r_color * intensity;
    assign g_mult = g_color * intensity;
    assign b_mult = b_color * intensity;
    
    assign r_filtered = r_mult[15:8];
    assign g_filtered = g_mult[15:8];
    assign b_filtered = b_mult[15:8];
    
    // Output assignment
    assign data_out = {r_filtered, 2'b00, g_filtered, 2'b00, b_filtered, 2'b00};
    assign startofpacket_out = startofpacket_in;
    assign endofpacket_out   = endofpacket_in;
    assign valid_out         = valid_in;
endmodule