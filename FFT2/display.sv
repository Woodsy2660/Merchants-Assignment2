module display (
    input         clk,
		input  [6:0]  snr_value,   // 0–99
		input  [7:0]  bpm_value,    // 0–180
    output [6:0]  display0,
    output [6:0]  display1,
    output [6:0]  display2,
    output [6:0]  display3,
    output [6:0]  display4,
    output [6:0]  display5
);
    /*** FSM Controller Code: ***/
    enum { Initialise, Add3, Shift, Result } next_state, current_state = Initialise; // FSM states.
    
    logic init, add, done; // FSM outputs.

    logic [3:0] count = 0; // Use this to count the 11 loop iterations.

    /*** DO NOT MODIFY THE CODE ABOVE ***/

    always_comb begin : double_dabble_fsm_next_state_logic
        case (current_state)
            Initialise: next_state = Add3;
            Add3:       next_state = Shift;
            Shift:      next_state = count == 10 ? Result : Add3;
            Result:     next_state = Initialise;
            default:    next_state = Initialise;
        endcase
    end

    always_ff @(posedge clk) begin : double_dabble_fsm_ff
        current_state <= next_state;
        if (current_state == Shift) begin
            count <= count == 10 ? 0 : count + 1;
        end
    end

    always_comb begin : double_dabble_fsm_output
        init = 1'b0;
        add = 1'b0;
        done = 1'b0;
        case (current_state) // Moore FSM
            Initialise: init = 1'b1;
            Add3:       add = 1'b1;
            Result:     done = 1'b1;
        endcase
    end
    

    /*** DO NOT MODIFY THE CODE BELOW ***/
    logic [3:0] digit0, digit1, digit2, digit3, digit4, digit5;

    //// Seven-Segment Displays
    seven_seg u_digit0 (.bcd(digit0), .segments(display0));
    seven_seg u_digit1 (.bcd(digit1), .segments(display1));
    seven_seg u_digit2 (.bcd(digit2), .segments(display2));
    seven_seg u_digit3 (.bcd(digit3), .segments(display3));
    seven_seg u_digit4 (.bcd(digit4), .segments(display4));
    seven_seg u_digit5 (.bcd(digit5), .segments(display5));

    // Algorithm RTL:  (completed no changes required - see dd_rtl.png for a representation of the code below but for 2 BCD digits. )
    // essentially a 27-bit long, 1-bit wide shift-register, starting from the 11 input bits through to the 4 bits of each BCD digit (4*4=16, 16+11=27).
    // We shift in the Shift state, add 3 to BCD digits greater than 4 in the Add3 state, and initialise the shift-register values in the Initialise state.
    logic [3:0]  bcd0, bcd1, bcd2, bcd3, bcd4, bcd5; // Added bcd4, bcd5 for SNR digits
    logic [10:0] temp_value; // Do NOT change.

    always_ff @(posedge clk) begin : double_dabble_shiftreg
        if (init) begin // Initialise: set bcd values to 0 and temp_value to value.
			{bcd5, bcd4, bcd3, bcd2, bcd1, bcd0, temp_value} <= {snr_value, 4'b0, bpm_value};

           /*
			bcd0–bcd3 → BPM (lower 4 digits)

			bcd4–bcd5 → SNR (upper 2 digits)

			temp_value → shift register for double-dabble processing

			The 4'b0 is padding to keep the concatenation aligned
			*/
			
        end
        else begin
            if (add) begin // Add3: 3 is added to each bcd value greater than 4.
                bcd0 <= bcd0 > 4 ? bcd0 + 3 : bcd0;  // Conditional operator.
                bcd1 <= bcd1 > 4 ? bcd1 + 3 : bcd1;
                bcd2 <= bcd2 > 4 ? bcd2 + 3 : bcd2;
                bcd3 <= bcd3 > 4 ? bcd3 + 3 : bcd3;
                bcd4 <= bcd4 > 4 ? bcd4 + 3 : bcd4;  // New
                bcd5 <= bcd5 > 4 ? bcd5 + 3 : bcd5;  // New
            end
            else begin // Shift: essentially everything becomes a shift-register
                {bcd5, bcd4, bcd3, bcd2, bcd1, bcd0, temp_value} <= 
                    {bcd5, bcd4, bcd3, bcd2, bcd1, bcd0, temp_value} << 1; 
                // Concatenated shift now includes bcd4 and bcd5
            end
        end
    end

    always_ff @(posedge clk) begin : double_dabble_ff_output
        // Need to 'flop' bcd values at the output so that intermediate calculations are not seen at the output.
        if (done) begin  // Only take bcd values when the algorithm is done!
            digit0 <= bcd0;
            digit1 <= bcd1;
            digit2 <= bcd2;
            digit3 <= bcd3;
            digit4 <= bcd4; // New SNR digit
            digit5 <= bcd5; // New SNR digit
        end
    end

endmodule
