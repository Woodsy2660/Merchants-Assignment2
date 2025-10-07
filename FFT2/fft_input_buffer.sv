module fft_input_buffer #(
    parameter W = 16,
    parameter NSamples = 1024
) (
     input                clk,
     input                reset,
     input                audio_clk,
     
     input  logic         audio_input_valid,
     output logic         audio_input_ready,
     input  logic [W-1:0]   audio_input_data,

     output logic [W-1:0] fft_input,
     output logic         fft_input_valid
);

logic [$clog2(NSamples):0] count;
    logic fft_read;
    logic full, wr_full;
    async_fifo u_fifo (.aclr(reset),
                        .data(audio_input_data),.wrclk(audio_clk),.wrreq(audio_input_valid),.wrfull(wr_full),
                        .q(fft_input),          .rdclk(clk),      .rdreq(fft_read),         .rdfull(full)    );

    
    
    assign audio_input_ready = !wr_full;
    assign fft_input_valid   = fft_read;
    assign fft_read          = (count != 0);  // read while counting down

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            count <= 0;
        end else begin
            if (count != 0) begin
                // Decrement until done
                count <= count - 1;
            end else if (full) begin
                // Load counter when FIFO full
                count <= NSamples;
            end
        end
    end

endmodule
