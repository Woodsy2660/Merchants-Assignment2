module vga_face #(
    // Stored image resolution (choose smaller to save memory)
    parameter int STORED_WIDTH  = 160,   // e.g. 160, 80, 320 (original)
    parameter int STORED_HEIGHT = 120,   // e.g. 120, 60, 240 (original)
    // Display resolution and scale
    parameter int DISPLAY_WIDTH  = 640,
    parameter int DISPLAY_HEIGHT = 480,
    // SCALE must be an integer power of two such that
    // DISPLAY_WIDTH  == STORED_WIDTH  * SCALE
    // DISPLAY_HEIGHT == STORED_HEIGHT * SCALE
    parameter int SCALE = 4, // e.g. 2,4,8
    // Colour bits per stored pixel (12-bit: 4R 4G 4B)
    parameter int NUM_COLOUR_BITS = 12
)(
    input  logic        clk,
    input  logic        reset,

    // Avalon-ST Interface:
    output logic [29:0] data,
    output logic        startofpacket,
    output logic        endofpacket,
    output logic        valid,
    input  logic        ready
);

    // Sanity checks (elaborates will warn if mismatch)
    // (SCALE must be power of two; tools typically accept $clog2 on parameters.)
    localparam int SCALE_LOG2 = $clog2(SCALE);
    // Derived sizes
    localparam int STORED_PIXELS = STORED_WIDTH * STORED_HEIGHT;
    localparam int NUM_PIXELS    = DISPLAY_WIDTH * DISPLAY_HEIGHT;

    // --- Simple compile-time assertions (some simulators will error) ---
    initial begin
        if (DISPLAY_WIDTH  != STORED_WIDTH  * SCALE) begin
            $error("DISPLAY_WIDTH != STORED_WIDTH * SCALE");
        end
        if (DISPLAY_HEIGHT != STORED_HEIGHT * SCALE) begin
            $error("DISPLAY_HEIGHT != STORED_HEIGHT * SCALE");
        end
        // SCALE must be power-of-two so $clog2(SCALE) is integral and shift works
        if ((1 << SCALE_LOG2) != SCALE) begin
            $error("SCALE must be a power of two (1<<SCALE_LOG2 == SCALE)");
        end
    end

    // ROM for stored image (small)
    (* ram_init_file = "happy.mif" *) logic [NUM_COLOUR_BITS-1:0] happy_face [STORED_PIXELS];

    `ifdef VERILATOR
    initial begin
        $readmemh("happy.hex", happy_face);
    end
    `endif

    // Pixel indexing on the output frame
    logic [$clog2(NUM_PIXELS+1)-1:0] pixel_index;
    logic [$clog2(NUM_PIXELS+1)-1:0] pixel_index_next;

    // Display coordinates (derived from pixel_index)
    logic [$clog2(DISPLAY_WIDTH)-1:0]  display_x;
    logic [$clog2(DISPLAY_HEIGHT)-1:0] display_y;

    // Source coordinates in stored image (after shifting down by SCALE_LOG2)
    logic [$clog2(STORED_WIDTH)-1:0]  src_x;
    logic [$clog2(STORED_HEIGHT)-1:0] src_y;
    logic [$clog2(STORED_PIXELS+1)-1:0] src_index;

    // Compute display coords from pixel index
    // Use division/mod only at elaboration or let synthesis handle it — these are simple.
    assign display_x = pixel_index % DISPLAY_WIDTH;
    assign display_y = pixel_index / DISPLAY_WIDTH;

    // Nearest-neighbour upscale by shifting (cheap)
    assign src_x = display_x >> SCALE_LOG2;
    assign src_y = display_y >> SCALE_LOG2;
    assign src_index = src_y * STORED_WIDTH + src_x;

    // ROM output register (synchronous read)
    logic [NUM_COLOUR_BITS-1:0] happy_face_q;

    // read_enable: read on valid&ready (i.e., when downstream handshake occurs).
    // Do not read while reset asserted.
    logic read_enable;
    assign read_enable = (~reset) & valid & ready;

    always_ff @(posedge clk) begin
        if (read_enable) begin
            happy_face_q <= happy_face[src_index];
        end
        if (reset) begin
            happy_face_q <= '0;
        end
    end

    // Expose current pixel
    logic [NUM_COLOUR_BITS-1:0] current_pixel;
    always_comb current_pixel = happy_face_q;

    // valid is asserted when not in reset (module continuously produces pixels)
    assign valid = ~reset;

    // SOP/EOP based on frame index
    assign startofpacket = (pixel_index == 0);
    assign endofpacket   = (pixel_index == NUM_PIXELS - 1);

    // Extract 4-bit channels (12-bit storage assumed: {R[3:0], G[3:0], B[3:0]})
    wire [3:0] r4 = current_pixel[11:8];
    wire [3:0] g4 = current_pixel[7:4];
    wire [3:0] b4 = current_pixel[3:0];

    // Expand 4->8 bits by duplication (simple and cheap)
    wire [7:0] r8 = {r4, r4};
    wire [7:0] g8 = {g4, g4};
    wire [7:0] b8 = {b4, b4};

    // Pack into 30-bit output
    assign data = {r8, 2'b00, g8, 2'b00, b8, 2'b00};

    // Next pixel index combinational logic (respect handshake)
    always_comb begin
        if (reset) begin
            pixel_index_next = '0;
        end else if (valid & ready) begin
            pixel_index_next = (pixel_index == NUM_PIXELS - 1) ? '0 : (pixel_index + 1);
        end else begin
            pixel_index_next = pixel_index;
        end
    end

    // Register update
    always_ff @(posedge clk) begin
        if (reset) begin
            pixel_index <= '0;
        end else begin
            pixel_index <= pixel_index_next;
        end
    end

endmodule
