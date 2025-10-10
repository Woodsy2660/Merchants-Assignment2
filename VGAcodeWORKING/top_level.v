module top_level (
    input  wire        CLOCK_50,
    input  wire [17:0] SW,
    
    output wire        VGA_CLK,    
    output wire        VGA_HS,     
    output wire        VGA_VS,     
    output wire        VGA_BLANK_N,  
    output wire        VGA_SYNC_N,   
    output wire [7:0]  VGA_R,        
    output wire [7:0]  VGA_G,        
    output wire [7:0]  VGA_B         
);
    // Intensity control signal
    reg [7:0] intensity_value;
    
    // Brightness control logic (SW[9:5])
    wire [4:0] brightness_switches;
    assign brightness_switches = SW[9:5];
    always @(*) begin
        case (brightness_switches)
            5'b00001: intensity_value = 8'd51;   // SW5: ~20% brightness (very dim)
            5'b00010: intensity_value = 8'd102;  // SW6: ~40% brightness
            5'b00100: intensity_value = 8'd153;  // SW7: ~60% brightness
            5'b01000: intensity_value = 8'd204;  // SW8: ~80% brightness
            5'b10000: intensity_value = 8'd255;  // SW9: 100% brightness (full)
            default:  intensity_value = 8'd255;  // No switches or multiple: full brightness
        endcase
    end
    
    // Filter selection (SW[17:15]) - 3 bits for 8 different filters
    wire [2:0] filter_select;
    assign filter_select = SW[17:15];
    
    // Kernel selection (SW[14:12])
    wire [2:0] kernel_select;
    assign kernel_select = SW[14:12];
    
    // VGA system instantiation
    vga u_vga (
        .clk_clk(CLOCK_50),
        .intensity_intensity(intensity_value),       // SW[9:5]: Brightness control
        .filter_select_filter_select(filter_select), // SW[17:15]: Filter selection
        .kernel_select_kernel_select(kernel_select), // SW[14:12]: Kernel selection
        .reset_reset_n(1'b1),
        .vga_CLK(VGA_CLK),
        .vga_HS(VGA_HS),
        .vga_VS(VGA_VS),
        .vga_BLANK(VGA_BLANK_N),
        .vga_SYNC(VGA_SYNC_N),
        .vga_R(VGA_R),
        .vga_G(VGA_G),
        .vga_B(VGA_B)
    );
endmodule