
module i2c_master (
    input  clk,      // 20 kHz input clock

    output i2c_scl,  // I2C clock
    inout  i2c_sda,  // I2C DATA

    input  [6:0] slav_addr,
    input  read_not_write,
    input  [7:0] reg_addr,

    input  [7:0] write_data,
    input  write_valid,
    output logic write_ready,

    output logic [7:0] read_data,
    output logic read_valid,
    input  read_ready,

    output logic error
);

    logic sda_set;  // 1 means use high impedance on the I2C data line (undriven by the master - it is 1 by default). 0 means pull-down the I2C data line to a 0.
    logic scl_idle; // This sets the I2C clock to the idle high state.
    
    enum logic [3:0] {INIT, START, SLAVE_ADDR, READ_OR_WRITE, ACK1, REG_ADDR, ACK2, DATA, ACK3, STOP0, STOP1, STOP2} state = INIT, next_state;
        
    assign i2c_scl = scl_idle | ~clk;     // The SCLK is 1 if idle, else it is the clock inverted (this is so that the positive edge of SCLK is in the middle of a data bit).
    assign i2c_sda = sda_set ? 1'bz : 0 ; // I2C: set the data line to the high-impedance Z state when sending a `1`, else set to `0`.

    logic ack_1, ack_2, ack_3;               // Acknowledgement status bits for each separate acknowledgement - after slave address, after register address and after data.
    assign error = ack_1 | ack_2 | ack_3;    // If any of the acknowledgements from the receiver are high, then an error has occured (acknowledge is active-low).
    
    logic [2:0] counter = 0; // Use this to count bits.
    
    always_comb begin : fsm_next_state
        next_state = INIT;
        case(state)
            INIT:          next_state = write_valid ? START : INIT;     // Move to the START state once a 'write_valid' signal has been received.
            START:         next_state = SLAVE_ADDR;
            SLAVE_ADDR:    next_state = counter == 6 ? READ_OR_WRITE : SLAVE_ADDR; // Send slave address to the device
            READ_OR_WRITE: next_state = ACK1;
            ACK1:          next_state = REG_ADDR;                         
            REG_ADDR:      next_state = counter == 7 ? ACK2 : REG_ADDR;   // Send the register address to the device
            ACK2:          next_state = DATA;                             
            DATA:          next_state = counter == 7 ? ACK3 : DATA;      // Send the data to the device
            ACK3:          next_state = STOP0;
            STOP0:         next_state = STOP1;                        // Here, we use 3 STOP states to deal with the SCL and SDA stop symbol timings. 
            STOP1:         next_state = STOP2;    
            STOP2:         next_state = INIT;    
        endcase
    end    

    logic  [6:0] slav_addr_temp;
    logic  [7:0] write_data_temp;
    logic  [7:0] reg_addr_temp;
    logic        read_not_write_temp;

    always_ff @(posedge clk) begin : registers
        state <= next_state;
        case (state)
            INIT:   begin ack_1 <= 0 ; ack_2 <= 0 ; ack_3 <= 0; end
            ACK1       :  ack_1 <= i2c_sda;
            ACK2       :  ack_2 <= i2c_sda;
            ACK3       :  ack_3 <= i2c_sda;
        endcase
        if (state == SLAVE_ADDR || state == REG_ADDR || state == DATA) begin
            counter <= counter + 1; // Only count bits in these states (i.e. when we are actually sending information)
        end
        else counter <= 0;
        if (write_ready && write_valid) begin
            slav_addr_temp      <= slav_addr;
            write_data_temp     <= write_data;
            reg_addr_temp       <= reg_addr;
            read_not_write_temp <= read_not_write;
        end
    end

    always_comb begin : fsm_output
        sda_set = 1;
        scl_idle = 0;
        write_ready = 0;
        case (state)
            INIT          : begin write_ready = 1;                      scl_idle = 1; end // Reset registers.
            START         : begin sda_set = 0;                          scl_idle = 1; end // Pull SDA down for start condition
            SLAVE_ADDR    :       sda_set =  slav_addr_temp[6-counter];                   // SLAVE ADDR: The address of the slave we wish to write to.
            READ_OR_WRITE :       sda_set =        read_not_write_temp;
            REG_ADDR      :       sda_set =   reg_addr_temp[7-counter];                   // SUB ADDR: The address of the register we wish to write to. 
            DATA          :       sda_set = write_data_temp[7-counter];                   // DATA: The data we wish to write.
            STOP0         :       sda_set = 0;
            STOP1         : begin sda_set = 0;                          scl_idle = 1; end
            STOP2         :                                             scl_idle = 1;         
        endcase
    end

    always if (read_not_write) $error("I2C read transaction not implemented!");

endmodule

// My code: passed all testcases
//
//module i2c_master (
//    input  clk,      // 20 kHz input clock. Assume this is the correct frequency for the I2C transfer.
//
//    output i2c_scl,  // I2C clock
//    inout  i2c_sda,  // I2C DATA
//
//    input  [6:0] slav_addr,
//    input  read_not_write,
//    input  [7:0] reg_addr,
//
//    input  [7:0] write_data,
//    input  write_valid,
//    output logic write_ready,
//
//    output logic [7:0] read_data,
//    output logic read_valid,
//    input  read_ready,
//
//    output logic error
//);
//
//    logic sda_set;  // sda_set=1 means use high impedance on the I2C data line, so the line is undriven by the master. sda_set=0 means pull-down the I2C data line to a 0 (master drives the line).
//    logic scl_idle; // This indicates when the I2C clock should be idle (=1).
//    
//    enum logic [3:0] {INIT, START, SLAVE_ADDR, READ_OR_WRITE, ACK1, REG_ADDR, ACK2, DATA, ACK3, STOP0, STOP1, STOP2} state = INIT, next_state;
//        
//        // STOP condition happens when SDA goes from LOW → HIGH while SCL is HIGH
//        // but we can't transition directly from SDA low to (SDA high and SCL high) in one cycle
//        // can only change one signal's status at a cycle
//        // So we need STOP 0, 1, 2
//
//    assign i2c_scl = scl_idle | ~clk;     // The SCL is 1 if idle, else it is the inverted i2c clock (this is a trick so that the positive edge of SCL is always inbetween SDA transitions!).
//    assign i2c_sda = sda_set ? 1'bz : 0 ; // I2C: set the data line to the high-impedance Z state when sending a `1`, else set to `0`.
//
//    logic ack_1, ack_2, ack_3;            // Acknowledgement status bits for each separate ACK : 1.After slave address, 2.After register address and 3.After data.
//    assign error = ack_1 | ack_2 | ack_3; // If any of the acknowledgements from the receiver are high (NACK), then an error has occured (acknowledge is active-low).
//    
//    logic [2:0] counter = 0; // Use this to count bits (# of bits sent).
//    
//    //TODO Complete the FSM next-state table. Most states automatically transistion to the next (these are listed in order):
//    always_comb begin : fsm_next_state
//        next_state = INIT;
//        case(state)
//            INIT:          next_state = (write_valid && write_ready) ? START : INIT;  // Remember to check for a handshake (valid & ready). Move to the START state once a 'write_valid' signal has been received.
//            START:         next_state = SLAVE_ADDR;
//            SLAVE_ADDR:    next_state = (counter == 6) ? READ_OR_WRITE : SLAVE_ADDR;     // Send slave address to the device by incrementing the bit counter.
//            // Here we are sending the 7-bit slave address (slav_addr) bit by bit over i2c_sda
//            // If counter < 6 (0-based counting), we stay in SLAVE_ADDR and keep incrementing counter each clock cycle.
//            // If you finish counting all bits of slave address, I2C expects an ACK from slave
//
//            READ_OR_WRITE: next_state = ACK1;
//            ACK1:          next_state = REG_ADDR;
//            REG_ADDR:      next_state = (counter == 7) ? ACK2 : REG_ADDR;   // Send the register address to the device by incrementing the bit counter.
//
//
//            ACK2:          next_state = DATA;
//            DATA:          next_state = (counter == 7) ? ACK3 : DATA;   // Send the data to the device by incrementing the bit counter.
//            ACK3:          next_state = STOP0;
//
//            // Now, we use 3 STOP states to deal with the SCL and SDA stop symbol timings.
//
//            // But timing requirements of I2C are met by spending one cycle per state, not by conditional checks inside the FSM.
//            // So we set scl_idle and sda_set in the fsm_output rather than this state machine itself
//
//
//            STOP0:         next_state = STOP1;     
//            // Make sure SCL is held low while SDA is still low.
//
//            STOP1:         next_state = STOP2;
//            // Release SCL high (idle). Keep SDA low for this cycle. Now the bus is “clock idle, data low” → right before STOP
//
//            STOP2:         next_state = INIT;
//
//        endcase
//    end    
//
//    logic  [6:0] slav_addr_temp;
//    logic  [7:0] write_data_temp;
//    logic  [7:0] reg_addr_temp;
//    logic        read_not_write_temp;
//
//    always_ff @(posedge clk) begin : registers
//        state <= next_state;
//        // Register the acknowledgements (should all be zero):
//        case (state)
//            INIT:   begin ack_1 <= 0 ; ack_2 <= 0 ; ack_3 <= 0; end // Reset ACK registers.
//            ACK1:         ack_1 <= i2c_sda;
//            ACK2:         ack_2 <= i2c_sda;
//            ACK3:         ack_3 <= i2c_sda;
//        endcase
//        // Bit counter (only counts in the sending states).
//        if (state == SLAVE_ADDR || state == REG_ADDR || state == DATA) begin
//            counter <= counter + 1; // Only count bits in these states (i.e. when we are actually sending information)
//        end
//
//        else counter <= 0;  // automatically resets the counter whenever you are not in a sending state
//
//
//        // Store the data transferred on the handshake:
//        if (write_ready && write_valid) begin
//            slav_addr_temp      <= slav_addr;
//            write_data_temp     <= write_data;
//            reg_addr_temp       <= reg_addr;
//            read_not_write_temp <= read_not_write;
//        end
//    end
//
//    //TODO Complete the following FSM output table:
//    always_comb begin : fsm_output
//        sda_set = 1;      // Default : SDA line is high (undriven).
//        scl_idle = 1;     // Default : The clock is idle (high). You can change this if you think it's easier.
//        write_ready = 0;  // Default : We are not ready to send a write transaction.
//        case (state)
//            INIT:          begin 
//                sda_set = 1; // undriven
//                scl_idle = 1;
//                write_ready = 1; //ready to send a write transaction
//            end // Reset registers. Indicate that we are *ready* for a write transaction.
//            // Even though the registers themselves are reset in the flip-flop, you still need to define what the outputs do in INIT state. 
//            // The flip-flops control state and stored data, while the fsm_output block controls output signals.
//            
//
//            START:         begin sda_set = 0; end // Pull SDA down for start condition (sda_set).
//            
//            SLAVE_ADDR:    begin scl_idle = 0; 
//                            sda_set = slav_addr_temp[6 - counter]; // send bit[6] to bit[0] (MSB first)
//                             end 
//                             
//            // SLAVE ADDR: The address of the slave we wish to write to. Set sda_set accordingly.
//
//            /*
//            when counter = 0 → reg_addr_temp[7 - 0] = reg_addr_temp[7] → send MSB first
//            when counter = 1 → reg_addr_temp[7 - 1] = reg_addr_temp[6]
//            …
//            when counter = 7 → reg_addr_temp[7 - 7] = reg_addr_temp[0] → send LSB last
//            */
//            
//            
//            READ_OR_WRITE: begin
//                                scl_idle = 0;
//                                sda_set  = read_not_write_temp; // 0 = write, 1 = read
//                            end
//
//            ACK1:          begin 
//                                scl_idle = 0;
//                                sda_set  = 1; // release line (let slave pull it low for ACK)
//                           end
//
//            REG_ADDR:      begin
//                                scl_idle = 0;
//                                sda_set  = reg_addr_temp[7 - counter];
//                            end
//                            
//                            // REG ADDR: The address of the register we wish to write to. Set sda_set accordingly.
//            
//            ACK2:          begin scl_idle = 0; sda_set = 1; end
//            
//            DATA:          begin
//                                scl_idle = 0;
//                                sda_set  = write_data_temp[7 - counter];
//                            end
//            // DATA: The data we wish to write. Set sda_set accordingly.
//            
//            ACK3:          begin scl_idle = 0; sda_set = 1; end
//
//            STOP0:         begin     
//                            scl_idle = 0; // clock low
//                            sda_set  = 0;
//                           end  // Here, we use 3 STOP states to deal with the SCL and SDA stop symbol timings.
//            
//            STOP1:         begin 
//                            scl_idle = 1; // scl_idle should go high first because sda transitions only matters if clock is high
//                            sda_set = 0; 
//                            end //   For each of these 3 STOP states, set sda_set and scl_idle appropriately.
//            STOP2:         begin scl_idle = 1; sda_set = 1; end
//        endcase
//    end
//    /** Use the slav_addr_temp, write_data_temp, reg_addr_temp & read_not_write_temp signals **/
//
//
//    always if (read_not_write) $error("I2C read transaction not implemented!");
//
//endmodule
