module convolution_2d_filter #(
    parameter WIDTH = 640,
    parameter HEIGHT = 480
)(
    input  logic        clk,
    input  logic        reset,
    
    // Kernel coefficients (3x3) - unused for now
    input  logic signed [7:0] k11, k12, k13,
    input  logic signed [7:0] k21, k22, k23,
    input  logic signed [7:0] k31, k32, k33,
    
    // Avalon-ST Input
    input  logic [29:0] data_in,
    input  logic        startofpacket_in,
    input  logic        endofpacket_in,
    input  logic        valid_in,
    output logic        ready_out,
    
    // Avalon-ST Output
    output logic [29:0] data_out,
    output logic        startofpacket_out,
    output logic        endofpacket_out,
    output logic        valid_out,
    input  logic        ready_in
);

    // Test mode select: Change this to test different stages
    localparam TEST_MODE = 4;
    // 0 = Pass-through (should work like original)
    // 1 = Test position counter
    // 2 = Test line buffer write/read
    // 3 = Test 3x3 window shift
    // 4 = Full convolution

    // Ready signal
    assign ready_out = ready_in;
    
    // Extract RGB from 30-bit input
    logic [23:0] rgb_in;
    assign rgb_in = {data_in[29:22], data_in[19:12], data_in[9:2]};
    
    // Position tracking
    logic [9:0] x_pos;
    logic [9:0] y_pos;
    
    always_ff @(posedge clk) begin
        if (reset) begin
            x_pos <= 10'd0;
            y_pos <= 10'd0;
        end else if (valid_in && ready_in) begin
            if (x_pos == WIDTH - 1) begin
                x_pos <= 10'd0;
                if (y_pos == HEIGHT - 1)
                    y_pos <= 10'd0;
                else
                    y_pos <= y_pos + 10'd1;
            end else begin
                x_pos <= x_pos + 10'd1;
            end
        end
    end
    
    // Line buffers
    logic [23:0] line0 [WIDTH-1:0];
    logic [23:0] line1 [WIDTH-1:0];
    logic [23:0] line2 [WIDTH-1:0];
    
    // 3x3 pixel window
    logic [23:0] p11, p12, p13;
    logic [23:0] p21, p22, p23;
    logic [23:0] p31, p32, p33;
    
    // Update line buffers and window
    always_ff @(posedge clk) begin
        if (reset) begin
            p11 <= 24'd0; p12 <= 24'd0; p13 <= 24'd0;
            p21 <= 24'd0; p22 <= 24'd0; p23 <= 24'd0;
            p31 <= 24'd0; p32 <= 24'd0; p33 <= 24'd0;
        end else if (valid_in && ready_in) begin
            // Shift window
            p11 <= p12; p12 <= p13; p13 <= line0[x_pos];
            p21 <= p22; p22 <= p23; p23 <= line1[x_pos];
            p31 <= p32; p32 <= p33; p33 <= line2[x_pos];
            
            // Update line buffers
            line0[x_pos] <= line1[x_pos];
            line1[x_pos] <= line2[x_pos];
            line2[x_pos] <= rgb_in;
        end
    end
    
    // Output logic based on test mode
    logic [23:0] rgb_out;
    logic [7:0] r_test, g_test, b_test;

    // Use wider accumulators to avoid overflow
    logic signed [31:0] r_sum, g_sum, b_sum;
    logic signed [31:0] r_div, g_div, b_div;
    logic signed [15:0] kernel_sum;

    always_comb begin
        // default
        rgb_out = rgb_in;
        r_test = 8'd0; g_test = 8'd0; b_test = 8'd0;
        r_sum = 32'sd0; g_sum = 32'sd0; b_sum = 32'sd0;
        r_div = 32'sd0; g_div = 32'sd0; b_div = 32'sd0;
        kernel_sum = k11 + k12 + k13 + k21 + k22 + k23 + k31 + k32 + k33;

        case (TEST_MODE)
            0: begin
                // Pass-through
                rgb_out = rgb_in;
            end
            1: begin
                // Show position as color (x in red, y in green)
                r_test = x_pos[7:0];
                g_test = y_pos[7:0];
                b_test = 8'd0;
                rgb_out = {r_test, g_test, b_test};
            end
            2: begin
                // Output from line2 (should show delayed image)
                rgb_out = line2[x_pos];
            end
            3: begin
                // Output center pixel p22 (should show 1-frame delayed)
                rgb_out = p22;
            end
            4: begin
                // Full convolution
                // Compute sums (unsigned pixels converted to signed for multiplication)
                r_sum = k11 * $signed({1'b0, p11[23:16]}) +
                        k12 * $signed({1'b0, p12[23:16]}) +
                        k13 * $signed({1'b0, p13[23:16]}) +
                        k21 * $signed({1'b0, p21[23:16]}) +
                        k22 * $signed({1'b0, p22[23:16]}) +
                        k23 * $signed({1'b0, p23[23:16]}) +
                        k31 * $signed({1'b0, p31[23:16]}) +
                        k32 * $signed({1'b0, p32[23:16]}) +
                        k33 * $signed({1'b0, p33[23:16]});
                
                g_sum = k11 * $signed({1'b0, p11[15:8]}) +
                        k12 * $signed({1'b0, p12[15:8]}) +
                        k13 * $signed({1'b0, p13[15:8]}) +
                        k21 * $signed({1'b0, p21[15:8]}) +
                        k22 * $signed({1'b0, p22[15:8]}) +
                        k23 * $signed({1'b0, p23[15:8]}) +
                        k31 * $signed({1'b0, p31[15:8]}) +
                        k32 * $signed({1'b0, p32[15:8]}) +
                        k33 * $signed({1'b0, p33[15:8]});
                
                b_sum = k11 * $signed({1'b0, p11[7:0]}) +
                        k12 * $signed({1'b0, p12[7:0]}) +
                        k13 * $signed({1'b0, p13[7:0]}) +
                        k21 * $signed({1'b0, p21[7:0]}) +
                        k22 * $signed({1'b0, p22[7:0]}) +
                        k23 * $signed({1'b0, p23[7:0]}) +
                        k31 * $signed({1'b0, p31[7:0]}) +
                        k32 * $signed({1'b0, p32[7:0]}) +
                        k33 * $signed({1'b0, p33[7:0]});
                
                // If kernel sum > 1, divide by kernel_sum to normalize (box blur will divide by 9)
                if (kernel_sum > 16'sd1) begin
                    // integer division - synthesizable (but some FPGAs may implement divider logic -> resource/latency)
                    r_div = r_sum / kernel_sum;
                    g_div = g_sum / kernel_sum;
                    b_div = b_sum / kernel_sum;
                end else begin
                    // Otherwise do no normalization (keep original behavior)
                    r_div = r_sum;
                    g_div = g_sum;
                    b_div = b_sum;
                end

                // Clamp to 0-255 range (handles negative or >255 results)
                if (r_div < 32'sd0) r_test = 8'd0;
                else if (r_div > 32'sd255) r_test = 8'd255;
                else r_test = r_div[7:0];

                if (g_div < 32'sd0) g_test = 8'd0;
                else if (g_div > 32'sd255) g_test = 8'd255;
                else g_test = g_div[7:0];

                if (b_div < 32'sd0) b_test = 8'd0;
                else if (b_div > 32'sd255) b_test = 8'd255;
                else b_test = b_div[7:0];

                rgb_out = {r_test, g_test, b_test};
            end
            default: rgb_out = rgb_in;
        endcase
    end
    
    // Direct output (no pipeline delay for now)
    assign data_out = {rgb_out[23:16], 2'b00, rgb_out[15:8], 2'b00, rgb_out[7:0], 2'b00};
    assign startofpacket_out = startofpacket_in;
    assign endofpacket_out = endofpacket_in;
    assign valid_out = valid_in;

endmodule
