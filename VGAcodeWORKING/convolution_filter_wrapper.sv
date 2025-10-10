module convolution_filter_wrapper #(
    parameter WIDTH = 640,
    parameter HEIGHT = 480
)(
    input  logic       clk,
    input  logic       reset,
    input  logic [2:0] kernel_select,  // Select which kernel to use
    
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
    // Kernel coefficients
    logic signed [7:0] k11, k12, k13;
    logic signed [7:0] k21, k22, k23;
    logic signed [7:0] k31, k32, k33;
    
    // Normalization parameters
    logic [3:0] divisor_shift;  // Divide by 2^shift
    logic       add_offset;      // Add 128 for edge detection
    
    // Kernel selection
    always_comb begin
        case (kernel_select)
            // 0: Identity (no change)
            3'd0: begin
                k11 = 0;  k12 = 0;  k13 = 0;
                k21 = 0;  k22 = 1;  k23 = 0;
                k31 = 0;  k32 = 0;  k33 = 0;
            end
            
            // 1: Edge Detection (Laplacian)
            3'd1: begin
                k11 = -1; k12 = -1; k13 = -1;
                k21 = -1; k22 =  8; k23 = -1;
                k31 = -1; k32 = -1; k33 = -1;
            end
            
            // 2: Box Blur (average) - NOTE: sum=9, will be bright!
            3'd2: begin
                k11 = 1;  k12 = 1;  k13 = 1;
                k21 = 1;  k22 = 1;  k23 = 1;
                k31 = 1;  k32 = 1;  k33 = 1;
            end
            
            // 3: Sharpen
            3'd3: begin
                k11 =  0; k12 = -1; k13 =  0;
                k21 = -1; k22 =  5; k23 = -1;
                k31 =  0; k32 = -1; k33 =  0;
            end
            
            // 4: Horizontal Edge Detection (Sobel X)
            3'd4: begin
                k11 = -1; k12 = 0; k13 = 1;
                k21 = -2; k22 = 0; k23 = 2;
                k31 = -1; k32 = 0; k33 = 1;
            end
            
            // 5: Vertical Edge Detection (Sobel Y)
            3'd5: begin
                k11 = -1; k12 = -2; k13 = -1;
                k21 =  0; k22 =  0; k23 =  0;
                k31 =  1; k32 =  2; k33 =  1;
            end
            
            // 6: Emboss
            3'd6: begin
                k11 = -2; k12 = -1; k13 = 0;
                k21 = -1; k22 =  1; k23 = 1;
                k31 =  0; k32 =  1; k33 = 2;
            end
            
            // 7: Gaussian Blur (approximation) - NOTE: sum=16, will be bright!
            3'd7: begin
                k11 = 1;  k12 = 2;  k13 = 1;
                k21 = 2;  k22 = 4;  k23 = 2;
                k31 = 1;  k32 = 2;  k33 = 1;
            end
            
            default: begin
                k11 = 0;  k12 = 0;  k13 = 0;
                k21 = 0;  k22 = 1;  k23 = 0;
                k31 = 0;  k32 = 0;  k33 = 0;
            end
        endcase
    end
    
    // Instantiate the convolution filter - FIXED: use the k11-k33 signals!
    convolution_2d_filter #(
        .WIDTH(WIDTH),
        .HEIGHT(HEIGHT)
    ) conv_filter (
        .clk(clk),
        .reset(reset),
        .k11(k11), .k12(k12), .k13(k13),
        .k21(k21), .k22(k22), .k23(k23),
        .k31(k31), .k32(k32), .k33(k33),
        .data_in(data_in),
        .startofpacket_in(startofpacket_in),
        .endofpacket_in(endofpacket_in),
        .valid_in(valid_in),
        .ready_out(ready_out),
        .data_out(data_out),
        .startofpacket_out(startofpacket_out),
        .endofpacket_out(endofpacket_out),
        .valid_out(valid_out),
        .ready_in(ready_in)
    );
endmodule