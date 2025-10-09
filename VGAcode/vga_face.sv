module vga_face (
    input  logic        clk,            
    input  logic        reset,          
    input  logic [1:0]  face_select,     // 0: Happy, 1: Neutral, 2: Angry

    // Avalon-ST Interface:
    output logic [29:0] data,            // Data output to VGA (8 data bits + 2 padding bits for each colour Red, Green and Blue = 30 bits)
    output logic        startofpacket,   // Start of packet signal
    output logic        endofpacket,     // End of packet signal
    output logic        valid,           // Data valid signal
    input  logic        ready            // Data ready signal from VGA Module
);
    typedef enum logic [1:0] {Happy=2'd0, Neutral=2'd1, Angry=2'd2} face_t;

    // Store images at 320x240 resolution
    localparam StoredWidth   = 320;
    localparam StoredHeight  = 240;
    localparam StoredPixels  = StoredWidth * StoredHeight;  // 76,800 pixels
    localparam DisplayWidth  = 640;
    localparam DisplayHeight = 480;
    localparam NumPixels     = DisplayWidth * DisplayHeight;  // 307,200 pixels
    localparam NumColourBits = 12;  // 12-bit colour: 4 bits per RGB channel

    // Image ROMs at reduced resolution:
    (* ram_init_file = "happy.mif" *)   logic [NumColourBits-1:0] happy_face   [StoredPixels];
    (* ram_init_file = "neutral.mif" *) logic [NumColourBits-1:0] neutral_face [StoredPixels];
    (* ram_init_file = "angry.mif" *)   logic [NumColourBits-1:0] angry_face   [StoredPixels];

    `ifdef VERILATOR
    initial begin : memset
        $readmemh("happy.hex", happy_face);
        $readmemh("neutral.hex", neutral_face);
        $readmemh("angry.hex", angry_face);
    end
    `endif
     
    logic [18:0] pixel_index = 0, pixel_index_next;  // Display pixel counter (640x480)
    
    // Current display coordinates
    logic [9:0] display_x;  // 0-639
    logic [8:0] display_y;  // 0-479
    
    // Source coordinates in stored image (divide by 2 for 2x upscaling)
    logic [8:0] src_x;  // 0-319
    logic [7:0] src_y;  // 0-239
    logic [16:0] src_index;  // Index into 320x240 image
    
    // Calculate coordinates from pixel index
    assign display_x = pixel_index % DisplayWidth;
    assign display_y = pixel_index / DisplayWidth;
    
    // Simple 2x upscaling: divide display coordinates by 2
    assign src_x = display_x[9:1];
    assign src_y = display_y[8:1];
    assign src_index = src_y * StoredWidth + src_x;

    logic [NumColourBits-1:0] happy_face_q, neutral_face_q, angry_face_q; // Registers for reading from each ROM.
     
    logic read_enable;
    assign read_enable = reset | (valid & ready);

    always_ff @(posedge clk) begin : bram_read
        if (read_enable) begin
            happy_face_q   <= happy_face[src_index];
            neutral_face_q <= neutral_face[src_index];
            angry_face_q   <= angry_face[src_index];
        end
    end
   
    // Select which image's pixel to stream
    logic [NumColourBits-1:0] current_pixel;
    always_comb begin
        unique case (face_select)
            Happy:   current_pixel = happy_face_q;
            Neutral: current_pixel = neutral_face_q;
            Angry:   current_pixel = angry_face_q;
            default: current_pixel = '0;
        endcase
    end

    // Source is continuously producing pixels (except during reset)
    assign valid = ~reset;

    // SOP/EOP markers
    assign startofpacket = (pixel_index == 0);
    assign endofpacket   = (pixel_index == NumPixels-1);

    // Extract 4-bit RGB channels and expand to 8-bit
    // 12-bit format: {R[3:0], G[3:0], B[3:0]}
    wire [3:0] r4 = current_pixel[11:8];
    wire [3:0] g4 = current_pixel[7:4];
    wire [3:0] b4 = current_pixel[3:0];
    
    // Expand 4-bit to 8-bit by duplicating the 4 bits
    wire [7:0] r8 = {r4, r4};
    wire [7:0] g8 = {g4, g4};
    wire [7:0] b8 = {b4, b4};

    // Pack 30-bit RGB: {R8, 2'b00, G8, 2'b00, B8, 2'b00}
    assign data = {r8, 2'b00, g8, 2'b00, b8, 2'b00};

    // Next index logic (combinational)
    always_comb begin
        if (reset) begin
            pixel_index_next = 0;
        end else if (valid && ready) begin
            pixel_index_next = (pixel_index == NumPixels-1) ? 19'd0
                                                            : (pixel_index + 19'd1);
        end else begin
            pixel_index_next = pixel_index; // hold when no handshake
        end
    end

    // Update the index on the clock
    always_ff @(posedge clk) begin
        pixel_index <= pixel_index_next;
    end

endmodule