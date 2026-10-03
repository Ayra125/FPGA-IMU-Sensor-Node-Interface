`timescale 1ns/1ps

module tb_mpu6050_model;

    logic clk;
    logic reset;
    logic i2c_step;
    logic sample_tick;

    logic cmd_valid;
    logic cmd_ready;
    logic [1:0] cmd_kind;
    logic [7:0] tx_data;
    logic read_ack;

    logic busy;
    logic done;
    logic error;
    logic error_nack;
    logic error_timeout;
    logic [7:0] rx_data;

    logic sda_drive_low;
    logic scl_drive_low;
    logic mpu_sda_drive_low;
    logic mpu_scl_drive_low;
    logic sda_bus;
    logic scl_bus;
    logic tb_scl_stretch_low;
    logic stretch_enable;
    logic stretch_used;
    int message;
    int unsigned seed;
    logic inject_nack;
    logic tb_scl_timeout_low;
    logic timeout_seen;
    logic watchdog_expired;
    logic [7:0] logger_shift_reg;
    logic [3:0] logger_byte_count;
    logic [2:0] logger_bit_count;
    logic       logger_read_direction;
    time scl_last_change;
    logic scl_was_high;
    logic [7:0] transaction_log [0:31];
    integer logger_count;
    logic transaction_ack_log [0:31];
    logic [7:0] expected_log [0:16];
    logic       expected_ack [0:16];        
    logic [7:0] expected_value1,expected_value2,expected_value3,
    expected_value4,expected_value5,expected_value6,expected_value7,
    expected_value8,expected_value9,expected_value10,expected_value11,
    expected_value12,expected_value13,expected_value14;
    localparam logic [1:0] START      = 2'b00;
    localparam logic [1:0] STOP       = 2'b01;
    localparam logic [1:0] WRITE_BYTE = 2'b10;
    localparam logic [1:0] READ_BYTE  = 2'b11;
    
    typedef enum logic [1:0] {
    NACK_NONE          = 2'b00,
    NACK_POINTER      = 2'b01,
    NACK_DATA         = 2'b10,
    NACK_READ_ADDRESS = 2'b11
} nack_phase_t;

nack_phase_t nack_phase;
    typedef enum logic [2:0] {
    LOG_WAIT_START      = 3'd0,
    LOG_DEVICE_ADDRESS  = 3'd1,
    LOG_REGISTER_POINTER= 3'd2,
    LOG_WRITE_DATA      = 3'd3,
    LOG_READ_ADDRESS    = 3'd4,
    LOG_READ_DATA       = 3'd5,
    LOG_ACK_PHASE       = 3'd6,
    LOG_WAIT_STOP       = 3'd7
} logger_phase_t;

logger_phase_t logger_phase;
logger_phase_t ack_return_phase;

    timing_enable_gen #(
        .STEP_CYCLES(4),
        .SAMPLE_CYCLES(10)
    ) timing_gen (
        .clk(clk),
        .reset(reset),
        .i2c_step(i2c_step),
        .sample_tick(sample_tick)
    );

    i2c_engine i2c_master (
        .clk(clk),
        .reset(reset),
        .i2c_step(i2c_step),
        .cmd_valid(cmd_valid),
        .cmd_ready(cmd_ready),
        .cmd_kind(cmd_kind),
        .tx_data(tx_data),
        .read_ack(read_ack),
        .busy(busy),
        .done(done),
        .error(error),
        .error_nack(error_nack),
        .error_timeout(error_timeout),
        .rx_data(rx_data),
        .sda_drive_low(sda_drive_low),
        .scl_drive_low(scl_drive_low),
        .sda_in(sda_bus),
        .scl_in(scl_bus)
    );

    mpu6050_model sensor_model (
        .sda_in(sda_bus),
        .scl_in(scl_bus),
        .mpu_sda_drive_low(mpu_sda_drive_low),
        .mpu_scl_drive_low(mpu_scl_drive_low),
        .reset(reset),
        .inject_nack(inject_nack)
    );

    assign sda_bus = ~(sda_drive_low | mpu_sda_drive_low);

    assign scl_bus = ~(
        scl_drive_low |
        mpu_scl_drive_low |
        tb_scl_stretch_low |
        tb_scl_timeout_low
    );

    always #5 clk = ~clk;


    // Testbench-injected slave clock stretching. The stretch is applied once
    // on the first SCL falling edge after stretch_enable is asserted.
    always @(negedge scl_bus) begin
        if (stretch_enable && !stretch_used) begin
            stretch_used = 1'b1;
            tb_scl_stretch_low = 1'b1;
            #20_000;
            tb_scl_stretch_low = 1'b0;
        end
    end
    

    initial begin
        inject_nack = 1'b0;
        tb_scl_stretch_low = 1'b0;
        stretch_enable = 1'b0;
        stretch_used = 1'b0;
        seed = 32'h1A2B_3C4D;
        clk = 1'b0;
        reset = 1'b1;
        cmd_valid = 1'b0;
        tx_data = 8'h00;
        read_ack = 1'b0;
        message=0;
        logger_phase = LOG_WAIT_START;
        logger_shift_reg = 8'h00;
        logger_byte_count = 4'd0;
        logger_read_direction = 1'b0;
        logger_count = 0;
        nack_phase = NACK_NONE;
        tb_scl_timeout_low = 1'b0;
        logger_phase = LOG_WAIT_START;
        ack_return_phase = LOG_WAIT_START;
        logger_bit_count = 3'd0;
        logger_byte_count = 4'd0;
        expected_log[0]  = 8'hD2;
        expected_log[1]  = 8'h3B;
        expected_log[2]  = 8'hD3;
        expected_log[3]  = 8'h12;
        expected_log[4]  = 8'h34;
        expected_log[5]  = 8'h56;
        expected_log[6]  = 8'h78;
        expected_log[7]  = 8'h9A;
        expected_log[8]  = 8'hBC;
        expected_log[9]  = 8'hDE;
        expected_log[10] = 8'hF0;
        expected_log[11] = 8'h13;
        expected_log[12] = 8'h57;
        expected_log[13] = 8'h24;
        expected_log[14] = 8'h68;
        expected_log[15] = 8'h80;
        expected_log[16] = 8'hFF;
 
    for (int i = 0; i < 16; i = i + 1)begin
        expected_ack[i] = 1'b0; // ACK
    end

    expected_ack[16] = 1'b1; // Final read NACK
        $display("Random seed = 0x%08h", seed);
        repeat(4) @(negedge clk)begin
            reset = 1'b1;
        end
        @(negedge clk)begin
            reset=0;
            cmd_kind=START;
            cmd_valid=1;
        wait(cmd_valid && cmd_ready)begin
        end
        wait(busy)begin
            cmd_valid=0;
        end
        wait(done || error)begin
            @(negedge clk);
        if(error)begin
            $error("Mismatch: expected %0d, received %0d",
            0,
            error
        );
        message=message+1;
        end
       if (sensor_model.transaction_active !== 1'b1) begin
            $error("Expected transaction_active = 1, got %b",
           sensor_model.transaction_active);
            message = message + 1;
         end
        end
        end
        @(negedge clk)begin
            cmd_kind = WRITE_BYTE;
            tx_data   = 8'hD2;
            cmd_valid = 1'b1;
        end
        wait(cmd_valid && cmd_ready)begin
        end
        wait(busy)begin
            cmd_valid=0;
        end
        wait(done || error)begin
            @(negedge clk);
            if(error)begin
            $error("Mismatch: expected %0d, received %0d",
            0,
            error
            );
            message=message+1;
            end
            if(error_nack)begin
                $error("Mismatch: expected %0d, received %0d",
                0,
                error_nack
            );
            message=message+1;
            end
            if(sensor_model.address_recived!==1)begin
            $error("Mismatch: expected %0d, received %0d",
            1,
            sensor_model.address_recived
            );
            message=message+1;
            end
        end
        @(negedge clk)begin
            cmd_kind = WRITE_BYTE;
            tx_data   = 8'h3B;
            cmd_valid = 1'b1;
        end
        wait(cmd_valid && cmd_ready);
        wait(busy)begin
            cmd_valid=0;
        end
        wait(done || error)begin
            @(negedge clk);
            if(error)begin
            $error("Mismatch: expected %0d, received %0d",
            0,
            error
            );
            message=message+1;
            end
            if(error_nack)begin
                $error("Mismatch: expected %0d, received %0d",
                0,
                error_nack
            );
            message=message+1;
            end
            if(sensor_model.pointer_recived !== 1)begin
            $error("Mismatch: expected %0d, received %0d",
            1,
            sensor_model.pointer_recived
            );
            message=message+1;
            end
            if(sensor_model.register_pointer !== 8'h3B)begin
            $error("Mismatch: expected %0d, received %0d",
            8'h3B,
            sensor_model.register_pointer
            );
            message=message+1;
            end
        end
        @(negedge clk)begin
            reset=0;
            cmd_kind=START;
            cmd_valid=1;
    end
        wait(cmd_valid && cmd_ready)begin
        end
        wait(busy)begin
            cmd_valid=0;
        end
        wait(done || error)begin
            @(negedge clk);
        if(error)begin
            $error("Mismatch: expected %0d, received %0d",
            0,
            error
        );
        message=message+1;
        end
       if (sensor_model.transaction_active !== 1'b1) begin
            $error("Expected transaction_active = 1, got %b",
           sensor_model.transaction_active);
            message = message + 1;
         end
        end
    @(negedge clk)begin
            cmd_kind = WRITE_BYTE;
            tx_data   = 8'hD4;
            cmd_valid = 1'b1;
        end
        wait(cmd_valid && cmd_ready)begin
        end
        wait(busy)begin
            cmd_valid=0;
        end
        wait(done || error)begin
            @(negedge clk);
            if(!error)begin
            $error("Mismatch: expected %0d, received %0d",
            1,
            error
            );
            message=message+1;
            end
            if(!error_nack)begin
                $error("Mismatch: expected %0d, received %0d",
                1,
                error_nack
            );
            message=message+1;
            end
            if(sensor_model.address_recived!==1'b0)begin
            $error("Mismatch: expected %0d, received %0d",
            0,
            sensor_model.address_recived
            );
            message=message+1;
            end
            if(sensor_model.ack_pending!==1'b0)begin
                $error("Mismatch: expected %0d, received %0d",
                0,
                sensor_model.ack_pending
            );
            message=message+1;
            end
        end
        @(negedge clk);
        cmd_kind = STOP;
        cmd_valid = 1'b1;
        wait(cmd_valid && cmd_ready);
        wait(busy);
        cmd_valid = 1'b0;
        wait(done || error);
        @(negedge clk);
        if (error !== 1'b0) begin
            $error("read_burst STOP failed: error=%b", error);
            message = message + 1;
        end
        if (sensor_model.transaction_active !== 1'b0) begin
            $error("read_burst STOP did not end the transaction");
            message = message + 1;
        end
         @(negedge clk)begin
            reset=0;
            cmd_kind=START;
            cmd_valid=1;
        wait(cmd_valid && cmd_ready)begin
        end
        wait(busy)begin
            cmd_valid=0;
        end
        wait(done || error)begin
            @(negedge clk);
        if(error)begin
            $error("Mismatch: expected %0d, received %0d",
            0,
            error
        );
        message=message+1;
        end
       if (sensor_model.transaction_active !== 1'b1) begin
            $error("Expected transaction_active = 1, got %b",
           sensor_model.transaction_active);
            message = message + 1;
         end
        end
        end
        @(negedge clk)begin
            cmd_kind = WRITE_BYTE;
            tx_data   = 8'hD2;
            cmd_valid = 1'b1;
        end
        wait(cmd_valid && cmd_ready)begin
        end
        wait(busy)begin
            cmd_valid=0;
            #5;
            reset=1;
        end
            #10;
            if(sensor_model.transaction_active!== 1'b0)begin
            $error("Mismatch: expected %0d, received %0d",
            0,
            sensor_model.transaction_active
            );
            message=message+1;
            end
            if(sensor_model.read_mode!== 1'b0)begin
                $error("Mismatch: expected %0d, received %0d",
                0,
                sensor_model.read_mode
            );
            message=message+1;
            end
            if(sensor_model.address_recived!== 1'b0)begin
            $error("Mismatch: expected %0d, received %0d",
            0,
            sensor_model.address_recived
            );
            message=message+1;
            end
            if(sensor_model.ack_pending!== 1'b0)begin
                $error("Mismatch: expected %0d, received %0d",
                0,
                sensor_model.ack_pending
            );
            message=message+1;
            end
            if(sensor_model.ack_active!== 1'b0)begin
                $error("Mismatch: expected %0d, received %0d",
                0,
                sensor_model.ack_active
            );
            message=message+1;
            end
            if(sensor_model.nack_pending!== 1'b0)begin
                $error("Mismatch: expected %0d, received %0d",
                0,
                sensor_model.nack_pending
            );
            message=message+1;
            end
            if(sensor_model.read_ack!== 1'b0)begin
                $error("Mismatch: expected %0d, received %0d",
                0,
                sensor_model.read_ack
            );
            message=message+1;
            end
            if(sensor_model.mpu_sda_drive_low!== 1'b0)begin
                $error("Mismatch: expected %0d, received %0d",
                0,
                sensor_model.mpu_sda_drive_low
            );
            message=message+1;
            end
            if(sensor_model.mpu_scl_drive_low!== 1'b0)begin
                $error("Mismatch: expected %0d, received %0d",
                0,
                sensor_model.mpu_scl_drive_low
            );
            message=message+1;
            end
        reset=0;
        @(negedge clk)begin
            reset=0;
            cmd_kind=START;
            cmd_valid=1;
    end
        wait(cmd_valid && cmd_ready)begin
        end
        wait(busy)begin
            cmd_valid=0;
        end
        wait(done || error)begin
            @(negedge clk);
        if(error)begin
            $error("Mismatch: expected %0d, received %0d",
            0,
            error
        );
        message=message+1;
        end
       if (sensor_model.transaction_active !== 1'b1) begin
            $error("Expected transaction_active = 1, got %b",
           sensor_model.transaction_active);
            message = message + 1;
         end
        end
    @(negedge clk)begin
            cmd_kind = WRITE_BYTE;
            tx_data   = 8'hD2;
            cmd_valid = 1'b1;
        end
        wait(cmd_valid && cmd_ready)begin
        end
        wait(busy)begin
            cmd_valid=0;
        end
        wait(done || error)begin
            @(negedge clk);
            if(error)begin
            $error("Mismatch: expected %0d, received %0d",
            0,
            error
            );
            message=message+1;
            end
            if(error_nack)begin
                $error("Mismatch: expected %0d, received %0d",
                0,
                error_nack
            );
            message=message+1;
            end
            if(sensor_model.address_recived!==1)begin
            $error("Mismatch: expected %0d, received %0d",
            1,
            sensor_model.address_recived
            );
            message=message+1;
            end
        end
        @(negedge clk)begin
            cmd_kind = WRITE_BYTE;
            tx_data   = 8'h3B;
            cmd_valid = 1'b1;
            inject_nack=1;
        end
        wait(cmd_valid && cmd_ready);
        wait(busy)begin
            cmd_valid=0;
        end
        wait(done || error)begin
            @(negedge clk);
            if(!error)begin
            $error("Mismatch: expected %0d, received %0d",
            1,
            error
            );
            message=message+1;
            end
            if(!error_nack)begin
                $error("Mismatch: expected %0d, received %0d",
                1,
                error_nack
            );
            message=message+1;
            end
            if(sensor_model.pointer_recived == 1)begin
            $error("Mismatch: expected %0d, received %0d",
            0,
            sensor_model.pointer_recived
            );
            message=message+1;
            end
            if(sensor_model.register_pointer == 8'h3B)begin
            $error("Mismatch: expected %0d, received %0d",
            0,
            sensor_model.register_pointer
            );
            message=message+1;
            end
        end
        @(negedge clk)begin
            cmd_kind = STOP;
            cmd_valid = 1'b1;
            inject_nack=0;
        end
        wait(cmd_valid && cmd_ready);
        wait(busy)begin
            cmd_valid=0;
        end
        wait(done || error)begin
            @(negedge clk)begin
            if(error)begin
            $error("Mismatch: expected %0d, received %0d",
            0,
            error
            );
            message=message+1;
            end
            if(sensor_model.transaction_active!==0)begin
            $error("Mismatch: expected %0d, received %0d",
            0,
            sensor_model.transaction_active
            );
            message=message+1;
            end
            end
        end
        // Fault injection applies only to the pointer byte above.
        inject_nack = 1'b0;
        @(negedge clk)begin
        stretch_enable = 1'b1;
        stretch_used = 1'b0;
      write_register(8'h6B, 8'h01,NACK_NONE);
      if (!stretch_used) begin
        $error("Expected the register write to experience clock stretching");
        message = message + 1;
      end
      stretch_enable = 1'b0;
      timeout_phase(8'h19, 8'h09);
      write_register(8'h19, 8'h09,NACK_NONE);
      write_register(8'h1A, 8'h03,NACK_NONE);
      write_register(8'h1B, 8'h08,NACK_NONE);
      write_register(8'h1C, 8'h08,NACK_NONE);
      sensor_model.register_map[8'h1C] = 8'h00;
      write_register(8'h1C, 8'h08,NACK_DATA);
      WHO_AM_I(8'h75, 8'h68);
      read(8'h3B, 8'h12, 8'h34); // Accel X
      read(8'h3D, 8'h56, 8'h78); // Accel Y
      read(8'h3F, 8'h9A, 8'hBC); // Accel Z
      read(8'h41, 8'hDE, 8'hF0); // Temperature
      read(8'h43, 8'h13, 8'h57); // Gyro X
      read(8'h45, 8'h24, 8'h68); // Gyro Y
      read(8'h47, 8'h80, 8'hFF); // Gyro Z

      logger_count = 0;
      logger_bit_count = 3'd0;
      logger_byte_count = 4'd0;
      logger_read_direction = 1'b0;
      logger_phase = LOG_WAIT_START;
      ack_return_phase = LOG_WAIT_START;
      read_burst(8'h3B,
                 8'h12, 8'h34, 8'h56, 8'h78,
                 8'h9A, 8'hBC, 8'hDE, 8'hF0,
                 8'h13, 8'h57, 8'h24, 8'h68,
                 8'h80, 8'hFF, NACK_NONE);

      if (logger_count !== 17) begin
        $error("Expected 17 logged bytes, got %0d", logger_count);
        message = message + 1;
      end
      for (int log_index = 0; log_index < 17; log_index = log_index + 1) begin
        if (transaction_log[log_index] !== expected_log[log_index]) begin
          $error("Log byte %0d mismatch: expected %h, got %h",
                 log_index, expected_log[log_index],
                 transaction_log[log_index]);
          message = message + 1;
        end
        if (transaction_ack_log[log_index] !== expected_ack[log_index]) begin
          $error("Log ACK %0d mismatch: expected %b, got %b",
                 log_index, expected_ack[log_index],
                 transaction_ack_log[log_index]);
          message = message + 1;
        end
      end
      read_burst(8'h3B,
                 8'h12, 8'h34, 8'h56, 8'h78,
                 8'h9A, 8'hBC, 8'hDE, 8'hF0,
                 8'h13, 8'h57, 8'h24, 8'h68,
                 8'h80, 8'hFF, NACK_POINTER);
     read_burst(8'h3B,
                 8'h12, 8'h34, 8'h56, 8'h78,
                 8'h9A, 8'hBC, 8'hDE, 8'hF0,
                 8'h13, 8'h57, 8'h24, 8'h68,
                 8'h80, 8'hFF, NACK_READ_ADDRESS);
       

    sensor_model.register_map[8'h3B] = 8'h00;
    sensor_model.register_map[8'h3C] = 8'h00;
    sensor_model.register_map[8'h3D] = 8'h00;
    sensor_model.register_map[8'h3E] = 8'h00;
    sensor_model.register_map[8'h3F] = 8'h00;
    sensor_model.register_map[8'h40] = 8'h00;
    sensor_model.register_map[8'h41] = 8'h00;
    sensor_model.register_map[8'h42] = 8'h00;
    sensor_model.register_map[8'h43] = 8'h00;
    sensor_model.register_map[8'h44] = 8'h00;
    sensor_model.register_map[8'h45] = 8'h00;
    sensor_model.register_map[8'h46] = 8'h00;
    sensor_model.register_map[8'h47] = 8'h00;
    sensor_model.register_map[8'h48] = 8'h00;
    read_burst(
    8'h3B,
    8'h00, 8'h00, 8'h00, 8'h00,
    8'h00, 8'h00, 8'h00, 8'h00,
    8'h00, 8'h00, 8'h00, 8'h00,
    8'h00, 8'h00,  NACK_NONE
);
    sensor_model.register_map[8'h3B] = 8'hFF;
    sensor_model.register_map[8'h3C] = 8'hFF;
    sensor_model.register_map[8'h3D] = 8'hFF;
    sensor_model.register_map[8'h3E] = 8'hFF;
    sensor_model.register_map[8'h3F] = 8'hFF;
    sensor_model.register_map[8'h40] = 8'hFF;
    sensor_model.register_map[8'h41] = 8'hFF;
    sensor_model.register_map[8'h42] = 8'hFF;
    sensor_model.register_map[8'h43] = 8'hFF;
    sensor_model.register_map[8'h44] = 8'hFF;
    sensor_model.register_map[8'h45] = 8'hFF;
    sensor_model.register_map[8'h46] = 8'hFF;
    sensor_model.register_map[8'h47] = 8'hFF;
    sensor_model.register_map[8'h48] = 8'hFF;
    read_burst(
    8'h3B,
    8'hFF, 8'hFF, 8'hFF, 8'hFF,
    8'hFF, 8'hFF, 8'hFF, 8'hFF,
    8'hFF, 8'hFF, 8'hFF, 8'hFF,
    8'hFF, 8'hFF,  NACK_NONE
);
    sensor_model.register_map[8'h3B] = 8'h80;
    sensor_model.register_map[8'h3C] = 8'h00; // 16'h8000 = -32768

    sensor_model.register_map[8'h3D] = 8'h7F;
    sensor_model.register_map[8'h3E] = 8'hFF; // 16'h7FFF = +32767

    sensor_model.register_map[8'h3F] = 8'h80;
    sensor_model.register_map[8'h40] = 8'h00;

    sensor_model.register_map[8'h41] = 8'h7F;
    sensor_model.register_map[8'h42] = 8'hFF;

    sensor_model.register_map[8'h43] = 8'h80;
    sensor_model.register_map[8'h44] = 8'h00;

    sensor_model.register_map[8'h45] = 8'h7F;
    sensor_model.register_map[8'h46] = 8'hFF;

    sensor_model.register_map[8'h47] = 8'h80;
    sensor_model.register_map[8'h48] = 8'h00;
    read_burst(
    8'h3B,
    8'h80, 8'h00, 8'h7F, 8'hFF,
    8'h80, 8'h00, 8'h7F, 8'hFF,
    8'h80, 8'h00, 8'h7F, 8'hFF,
    8'h80, 8'h00,  NACK_NONE
); 
        expected_value1=$urandom(seed);
        expected_value2=$urandom(seed);
        expected_value3=$urandom(seed);
        expected_value4=$urandom(seed);
        expected_value5=$urandom(seed);
        expected_value6=$urandom(seed);
        expected_value7=$urandom(seed);
        expected_value8=$urandom(seed);
        expected_value9=$urandom(seed);
        expected_value10=$urandom(seed);
        expected_value11=$urandom(seed);
        expected_value12=$urandom(seed);
        expected_value13=$urandom(seed);
        expected_value14=$urandom(seed);
    sensor_model.register_map[8'h3B] = expected_value1;
    sensor_model.register_map[8'h3C] = expected_value2; 

    sensor_model.register_map[8'h3D] = expected_value3;
    sensor_model.register_map[8'h3E] = expected_value4; 

    sensor_model.register_map[8'h3F] = expected_value5;
    sensor_model.register_map[8'h40] = expected_value6;

    sensor_model.register_map[8'h41] = expected_value7;
    sensor_model.register_map[8'h42] = expected_value8;

    sensor_model.register_map[8'h43] = expected_value9;
    sensor_model.register_map[8'h44] = expected_value10;

    sensor_model.register_map[8'h45] = expected_value11;
    sensor_model.register_map[8'h46] = expected_value12;

    sensor_model.register_map[8'h47] = expected_value13;
    sensor_model.register_map[8'h48] = expected_value14;
    read_burst(
    8'h3B,
    expected_value1,expected_value2,expected_value3,
    expected_value4,expected_value5,expected_value6,expected_value7,
    expected_value8,expected_value9,expected_value10,expected_value11,
    expected_value12,expected_value13,expected_value14,  NACK_NONE
); 
    if (message == 0)
        $display("PASS: no errors found");
    else
        $fatal(1, "%0d errors found", message);

        $finish;
    end
    end
    task write_register(
    input logic [7:0] register_address,
    input logic [7:0] data_value,
    input nack_phase_t nack_phase
);
    logic [7:0] data_before;
    begin
         data_before = sensor_model.register_map[register_address];
        @(negedge clk)begin
            reset=0;
            cmd_kind=START;
            cmd_valid=1;
        wait(cmd_valid && cmd_ready)begin
        end
        wait(busy)begin
            cmd_valid=0;
        end
        wait(done || error)begin
            @(negedge clk);
        if(error)begin
            $error("Mismatch: expected %0d, received %0d",
            0,
            error
        );
        message=message+1;
        end
       if (sensor_model.transaction_active !== 1'b1) begin
            $error("Expected transaction_active = 1, got %b",
           sensor_model.transaction_active);
            message = message + 1;
         end
        end
        end
        @(negedge clk)begin
            cmd_kind = WRITE_BYTE;
            tx_data   = 8'hD2;
            cmd_valid = 1'b1;
        end
        wait(cmd_valid && cmd_ready)begin
        end
        wait(busy)begin
            cmd_valid=0;
        end
        wait(done || error)begin
            @(negedge clk);
            if(error)begin
            $error("Mismatch: expected %0d, received %0d",
            0,
            error
            );
            message=message+1;
            end
            if(error_nack)begin
                $error("Mismatch: expected %0d, received %0d",
                0,
                error_nack
            );
            message=message+1;
            end
            if(sensor_model.address_recived!==1)begin
            $error("Mismatch: expected %0d, received %0d",
            1,
            sensor_model.address_recived
            );
            message=message+1;
            end
        end
        @(negedge clk)begin
            cmd_kind = WRITE_BYTE;
            tx_data   = register_address;
            cmd_valid = 1'b1;
        end
        wait(cmd_valid && cmd_ready);
        wait(busy)begin
            cmd_valid=0;
        end
        wait(done || error)begin
            @(negedge clk);
                if(error)begin
            $error("Mismatch: expected %0d, received %0d",
            0,
            error
            );
            message=message+1;
            end
            if(error_nack)begin
                $error("Mismatch: expected %0d, received %0d",
                0,
                error_nack
            );
            message=message+1;
            end
            if(sensor_model.pointer_recived !== 1)begin
            $error("Mismatch: expected %0d, received %0d",
            1,
            sensor_model.pointer_recived
            );
            message=message+1;
            end
            if(sensor_model.register_pointer !== register_address)begin
            $error("Mismatch: expected %0d, received %0d",
            register_address,
            sensor_model.register_pointer
            );
            message=message+1;
            end
        end
        @(negedge clk)begin
            cmd_kind = WRITE_BYTE;
            tx_data   = data_value;
            cmd_valid = 1'b1;
            if(nack_phase==NACK_DATA) inject_nack=1;
        end
        wait(cmd_valid && cmd_ready);
        wait(busy)begin
            cmd_valid=0;
        end
        wait(done || error)begin
            @(negedge clk);
            if(nack_phase==NACK_DATA)begin
               if(!error)begin
            $error("Mismatch: expected %0d, received %0d",
            1,
            error
            );
            message=message+1;
            end
            if(!error_nack)begin
                $error("Mismatch: expected %0d, received %0d",
                1,
                error_nack
            );
            message=message+1;
            end
            if(sensor_model.pointer_recived !== 1)begin
            $error("Mismatch: expected %0d, received %0d",
            1,
            sensor_model.pointer_recived
            );
            message=message+1;
            end
            if(sensor_model.register_map[register_address] !== data_before)begin
            $error("Mismatch: expected %0d, received %0d",
            data_before,
            sensor_model.register_map[register_address]
            );
            message=message+1;
            end 
            inject_nack=0;
            return;
            end
            else begin
               if(error)begin
            $error("Mismatch: expected %0d, received %0d",
            0,
            error
            );
            message=message+1;
            end
            if(error_nack)begin
                $error("Mismatch: expected %0d, received %0d",
                0,
                error_nack
            );
            message=message+1;
            end
            if(sensor_model.pointer_recived !== 1)begin
            $error("Mismatch: expected %0d, received %0d",
            1,
            sensor_model.pointer_recived
            );
            message=message+1;
            end
            if(sensor_model.register_map[register_address] !== data_value)begin
            $error("Mismatch: expected %0d, received %0d",
            data_value,
            sensor_model.register_map[register_address]
            );
            message=message+1;
            end 
            end
        end
         @(negedge clk)begin
            cmd_kind = STOP;
            cmd_valid = 1'b1;
        end
        wait(cmd_valid && cmd_ready);
        wait(busy)begin
            cmd_valid=0;
        end
        wait(done || error)begin
            @(negedge clk)begin
            if(error)begin
            $error("Mismatch: expected %0d, received %0d",
            0,
            error
            );
            message=message+1;
            end
            if(sensor_model.transaction_active!==0)begin
            $error("Mismatch: expected %0d, received %0d",
            0,
            sensor_model.transaction_active
            );
            message=message+1;
            end
            end
        end
    end
endtask
    task WHO_AM_I(
        input logic [7:0] register_address,
        input logic [7:0] expected_value
);
    begin
        @(negedge clk)begin
            reset=0;
            cmd_kind=START;
            cmd_valid=1;
    end
        wait(cmd_valid && cmd_ready)begin
        end
        wait(busy)begin
            cmd_valid=0;
        end
        wait(done || error)begin
            @(negedge clk);
        if(error)begin
            $error("Mismatch: expected %0d, received %0d",
            0,
            error
        );
        message=message+1;
        end
       if (sensor_model.transaction_active !== 1'b1) begin
            $error("Expected transaction_active = 1, got %b",
           sensor_model.transaction_active);
            message = message + 1;
         end
        end
    @(negedge clk)begin
            cmd_kind = WRITE_BYTE;
            tx_data   = 8'hD2;
            cmd_valid = 1'b1;
        end
        wait(cmd_valid && cmd_ready)begin
        end
        wait(busy)begin
            cmd_valid=0;
        end
        wait(done || error)begin
            @(negedge clk);
            if(error)begin
            $error("Mismatch: expected %0d, received %0d",
            0,
            error
            );
            message=message+1;
            end
            if(error_nack)begin
                $error("Mismatch: expected %0d, received %0d",
                0,
                error_nack
            );
            message=message+1;
            end
            if(sensor_model.address_recived!==1)begin
            $error("Mismatch: expected %0d, received %0d",
            1,
            sensor_model.address_recived
            );
            message=message+1;
            end
        end
        @(negedge clk)begin
            cmd_kind = WRITE_BYTE;
            tx_data   = register_address;
            cmd_valid = 1'b1;
        end
        wait(cmd_valid && cmd_ready);
        wait(busy)begin
            cmd_valid=0;
        end
        wait(done || error)begin
            @(negedge clk);
            if(error)begin
            $error("Mismatch: expected %0d, received %0d",
            0,
            error
            );
            message=message+1;
            end
            if(error_nack)begin
                $error("Mismatch: expected %0d, received %0d",
                0,
                error_nack
            );
            message=message+1;
            end
            if(sensor_model.pointer_recived !== 1)begin
            $error("Mismatch: expected %0d, received %0d",
            1,
            sensor_model.pointer_recived
            );
            message=message+1;
            end
            if(sensor_model.register_pointer !== register_address)begin
            $error("Mismatch: expected %0d, received %0d",
            register_address,
            sensor_model.register_pointer
            );
            message=message+1;
            end
        end
        @(negedge clk)begin
            cmd_kind=START;
            cmd_valid=1;
        wait(cmd_valid && cmd_ready);
        wait(busy)begin
            cmd_valid=0;
        end
        wait(done || error)begin
            @(negedge clk);
        if(error)begin
            $error("Mismatch: expected %0d, received %0d",
            0,
            error
        );
        message=message+1;
        end
        if(sensor_model.register_pointer !== register_address)begin
            $error("Mismatch: expected %0d, received %0d",
            register_address,
            sensor_model.register_pointer
        );
        message=message+1;
        end
       if (sensor_model.transaction_active !== 1'b1) begin
            $error("Expected transaction_active = 1, got %b",
           sensor_model.transaction_active);
            message = message + 1;
         end
        end
        end
        @(negedge clk)begin
            cmd_kind = WRITE_BYTE;
            tx_data   = 8'hD3;
            cmd_valid = 1'b1;
        end
        wait(cmd_valid && cmd_ready)begin
        end
        wait(busy)begin
            cmd_valid=0;
        end
        wait(done || error)begin
            @(negedge clk);
            if(error)begin
            $error("Mismatch: expected %0d, received %0d",
            0,
            error
            );
            message=message+1;
            end
            if(error_nack)begin
                $error("Mismatch: expected %0d, received %0d",
                0,
                error_nack
            );
            message=message+1;
            end
            if(sensor_model.address_recived!==1)begin
            $error("Mismatch: expected %0d, received %0d",
            1,
            sensor_model.address_recived
            );
            message=message+1;
            end
        end
        @(negedge clk)begin
            cmd_kind = READ_BYTE;
            cmd_valid = 1'b1;
            read_ack=0;
        end
        wait(cmd_valid && cmd_ready)begin
        end
        wait(busy)begin
            cmd_valid=0;
        end
         wait(done || error)begin
            @(negedge clk);
            if(error)begin
            $error("Mismatch: expected %0d, received %0d",
            0,
            error
            );
            message=message+1;
            end
            if(error_nack)begin
                $error("Mismatch: expected %0d, received %0d",
                0,
                error_nack
            );
            message=message+1;
            end
            if(sensor_model.read_mode !== 0)begin
            $error("Mismatch: expected %0d, received %0d",
            0,
            sensor_model.read_mode
            );
            message=message+1;
            end
            if(rx_data !== expected_value)begin
            $error("Mismatch: expected %0d, received %0d",
            expected_value,
            rx_data
            );
            message=message+1;
            end
            if(sensor_model.register_pointer !==register_address)begin
                $error("Mismatch: expected %0d, received %0d",
                register_address,
                sensor_model.register_pointer
            );
            message=message+1;
            end
         end
         @(negedge clk)begin
            cmd_kind = STOP;
            cmd_valid = 1'b1;
        end
        wait(cmd_valid && cmd_ready);
        wait(busy)begin
            cmd_valid=0;
        end
        wait(done || error)begin
            @(negedge clk)begin
            if(error)begin
            $error("Mismatch: expected %0d, received %0d",
            0,
            error
            );
            message=message+1;
            end
            if(sensor_model.transaction_active!==0)begin
            $error("Mismatch: expected %0d, received %0d",
            0,
            sensor_model.transaction_active
            );
            message=message+1;
            end
            end
        end
    end
    endtask 

    
task  read(
        input logic [7:0] register_address,
        input logic [7:0] expected_value1,
        input logic [7:0] expected_value2
);
    @(negedge clk)begin
            reset=0;
            cmd_kind=START;
            cmd_valid=1;
    end
        wait(cmd_valid && cmd_ready)begin
        end
        wait(busy)begin
            cmd_valid=0;
        end
        wait(done || error)begin
            @(negedge clk);
        if(error)begin
            $error("Mismatch: expected %0d, received %0d",
            0,
            error
        );
        message=message+1;
        end
       if (sensor_model.transaction_active !== 1'b1) begin
            $error("Expected transaction_active = 1, got %b",
           sensor_model.transaction_active);
            message = message + 1;
         end
        end
    @(negedge clk)begin
            cmd_kind = WRITE_BYTE;
            tx_data   = 8'hD2;
            cmd_valid = 1'b1;
        end
        wait(cmd_valid && cmd_ready)begin
        end
        wait(busy)begin
            cmd_valid=0;
        end
        wait(done || error)begin
            @(negedge clk);
            if(error)begin
            $error("Mismatch: expected %0d, received %0d",
            0,
            error
            );
            message=message+1;
            end
            if(error_nack)begin
                $error("Mismatch: expected %0d, received %0d",
                0,
                error_nack
            );
            message=message+1;
            end
            if(sensor_model.address_recived!==1)begin
            $error("Mismatch: expected %0d, received %0d",
            1,
            sensor_model.address_recived
            );
            message=message+1;
            end
        end
        @(negedge clk)begin
            cmd_kind = WRITE_BYTE;
            tx_data   = register_address;
            cmd_valid = 1'b1;
        end
        wait(cmd_valid && cmd_ready);
        wait(busy)begin
            cmd_valid=0;
        end
        wait(done || error)begin
            @(negedge clk);
            if(error)begin
            $error("Mismatch: expected %0d, received %0d",
            0,
            error
            );
            message=message+1;
            end
            if(error_nack)begin
                $error("Mismatch: expected %0d, received %0d",
                0,
                error_nack
            );
            message=message+1;
            end
            if(sensor_model.pointer_recived !== 1)begin
            $error("Mismatch: expected %0d, received %0d",
            1,
            sensor_model.pointer_recived
            );
            message=message+1;
            end
            if(sensor_model.register_pointer !== register_address)begin
            $error("Mismatch: expected %0d, received %0d",
            register_address,
            sensor_model.register_pointer
            );
            message=message+1;
            end
        end
        @(negedge clk)begin
            cmd_kind=START;
            cmd_valid=1;
        wait(cmd_valid && cmd_ready);
        wait(busy)begin
            cmd_valid=0;
        end
        wait(done || error)begin
            @(negedge clk);
        if(error)begin
            $error("Mismatch: expected %0d, received %0d",
            0,
            error
        );
        message=message+1;
        end
        if(sensor_model.register_pointer !== register_address)begin
            $error("Mismatch: expected %0d, received %0d",
            register_address,
            sensor_model.register_pointer
        );
        message=message+1;
        end
       if (sensor_model.transaction_active !== 1'b1) begin
            $error("Expected transaction_active = 1, got %b",
           sensor_model.transaction_active);
            message = message + 1;
         end
        end
        end
        @(negedge clk)begin
            cmd_kind = WRITE_BYTE;
            tx_data   = 8'hD3;
            cmd_valid = 1'b1;
        end
        wait(cmd_valid && cmd_ready)begin
        end
        wait(busy)begin
            cmd_valid=0;
        end
        wait(done || error)begin
            @(negedge clk);
            if(error)begin
            $error("Mismatch: expected %0d, received %0d",
            0,
            error
            );
            message=message+1;
            end
            if(error_nack)begin
                $error("Mismatch: expected %0d, received %0d",
                0,
                error_nack
            );
            message=message+1;
            end
            if(sensor_model.address_recived!==1)begin
            $error("Mismatch: expected %0d, received %0d",
            1,
            sensor_model.address_recived
            );
            message=message+1;
            end
        end
        @(negedge clk)begin
            cmd_kind = READ_BYTE;
            cmd_valid = 1'b1;
            read_ack=1;
        end
        wait(cmd_valid && cmd_ready)begin
        end
        wait(busy)begin
            cmd_valid=0;
        end
         wait(done || error)begin
            @(negedge clk);
            if(error)begin
            $error("Mismatch: expected %0d, received %0d",
            0,
            error
            );
            message=message+1;
            end
            if(error_nack)begin
                $error("Mismatch: expected %0d, received %0d",
                0,
                error_nack
            );
            message=message+1;
            end
            if(sensor_model.read_mode !== 1)begin
            $error("Mismatch: expected %0d, received %0d",
            1,
            sensor_model.read_mode
            );
            message=message+1;
            end
            if(rx_data !== expected_value1)begin
            $error("Mismatch: expected %0d, received %0d",
            expected_value1,
            rx_data
            );
            message=message+1;
            end
            if(sensor_model.register_pointer !==(register_address+1))begin
                $error("Mismatch: expected %0d, received %0d",
                (register_address+1),
                sensor_model.register_pointer
            );
            message=message+1;
            end
         end
         @(negedge clk)begin
            cmd_kind = READ_BYTE;
            cmd_valid = 1'b1;
            read_ack=0;
        end
        wait(cmd_valid && cmd_ready)begin
        end
        wait(busy)begin
            cmd_valid=0;
        end
         wait(done || error)begin
            @(negedge clk);
            if(error)begin
            $error("Mismatch: expected %0d, received %0d",
            0,
            error
            );
            message=message+1;
            end
            if(error_nack)begin
                $error("Mismatch: expected %0d, received %0d",
                0,
                error_nack
            );
            message=message+1;
            end
            if(sensor_model.read_mode !== 0)begin
            $error("Mismatch: expected %0d, received %0d",
            0,
            sensor_model.read_mode
            );
            message=message+1;
            end
            if(rx_data !== expected_value2)begin
            $error("Mismatch: expected %0d, received %0d",
            expected_value2,
            rx_data
            );
            message=message+1;
            end
            if(sensor_model.register_pointer !==(register_address+1))begin
                $error("Mismatch: expected %0d, received %0d",
                (register_address+1),
                sensor_model.register_pointer
            );
            message=message+1;
            end
         end
         @(negedge clk)begin
            cmd_kind = STOP;
            cmd_valid = 1'b1;
        end
        wait(cmd_valid && cmd_ready);
        wait(busy)begin
            cmd_valid=0;
        end
        wait(done || error)begin
            @(negedge clk)begin
            if(error)begin
            $error("Mismatch: expected %0d, received %0d",
            0,
            error
            );
            message=message+1;
            end
            if(sensor_model.transaction_active!==0)begin
            $error("Mismatch: expected %0d, received %0d",
            0,
            sensor_model.transaction_active
            );
            message=message+1;
            end
            end
        end
endtask 
task read_burst(
        input logic [7:0] start_register,
        input logic [7:0] expected_value1,
        input logic [7:0] expected_value2,
        input logic [7:0] expected_value3,
        input logic [7:0] expected_value4,
        input logic [7:0] expected_value5,
        input logic [7:0] expected_value6,
        input logic [7:0] expected_value7,
        input logic [7:0] expected_value8,
        input logic [7:0] expected_value9,
        input logic [7:0] expected_value10,
        input logic [7:0] expected_value11,
        input logic [7:0] expected_value12,
        input logic [7:0] expected_value13,
        input logic [7:0] expected_value14,
        input nack_phase_t nack_phase
       
);
    integer index;
    logic [7:0] expected_byte;
    logic [7:0] pointer_before;
    begin
        pointer_before = sensor_model.register_pointer;
        @(negedge clk);
        cmd_kind = START;
        cmd_valid = 1'b1;
        wait(cmd_valid && cmd_ready);
        wait(busy);
        cmd_valid = 1'b0;
        wait(done || error);
        @(negedge clk);
        if (error !== 1'b0) begin
            $error("read_burst START failed: error=%b", error);
            message = message + 1;
        end
        if (sensor_model.transaction_active !== 1'b1) begin
            $error("read_burst START did not activate the transaction");
            message = message + 1;
        end

        @(negedge clk);
        cmd_kind = WRITE_BYTE;
        tx_data = 8'hD2;
        cmd_valid = 1'b1;
        wait(cmd_valid && cmd_ready);
        wait(busy);
        cmd_valid = 1'b0;
        wait(done || error);
        @(negedge clk);
        if (error !== 1'b0 || error_nack !== 1'b0) begin
            $error("read_burst write address failed: error=%b nack=%b",
                   error, error_nack);
            message = message + 1;
        end

        @(negedge clk);
        cmd_kind = WRITE_BYTE;
        tx_data = start_register;
        cmd_valid = 1'b1;
        if(nack_phase== NACK_POINTER) inject_nack=1;
        wait(cmd_valid && cmd_ready);
        wait(busy);
        cmd_valid = 1'b0;
        wait(done || error);
        @(negedge clk);
        if(nack_phase== NACK_POINTER)begin
            if ((error !== 1'b1 || error_nack !== 1'b1)) begin
            $error("read_burst register pointer failed: error=%b nack=%b",
                   error, error_nack);
            message = message + 1;
        end
        if (sensor_model.register_pointer !== pointer_before) begin
            $error("read_burst pointer mismatch: expected %h, got %h",
                   start_register, sensor_model.register_pointer);
            message = message + 1;
        end
            inject_nack = 1'b0;
            return;
        end
        else begin
            if ((error !== 1'b0 || error_nack !== 1'b0)) begin
            $error("read_burst register pointer failed: error=%b nack=%b",
                   error, error_nack);
            message = message + 1;
        end
        if (sensor_model.register_pointer !== start_register) begin
            $error("read_burst pointer mismatch: expected %h, got %h",
                   start_register, sensor_model.register_pointer);
            message = message + 1;
        end
        end
        @(negedge clk);
        cmd_kind = START;
        cmd_valid = 1'b1;
        wait(cmd_valid && cmd_ready);
        wait(busy);
        cmd_valid = 1'b0;
        wait(done || error);
        @(negedge clk);
        if (error !== 1'b0) begin
            $error("read_burst repeated START failed: error=%b", error);
            message = message + 1;
        end
        if (sensor_model.register_pointer !== start_register) begin
            $error("read_burst pointer changed across repeated START");
            message = message + 1;
        end

        @(negedge clk);
        cmd_kind = WRITE_BYTE;
        tx_data = 8'hD3;
        cmd_valid = 1'b1;
        if(nack_phase== NACK_READ_ADDRESS) inject_nack=1;
        wait(cmd_valid && cmd_ready);
        wait(busy);
        cmd_valid = 1'b0;
        wait(done || error);
        @(negedge clk);
        if(nack_phase== NACK_READ_ADDRESS)begin
           if (error !== 1'b1 || error_nack !== 1'b1) begin
            $error("read_burst read address failed: error=%b nack=%b",
                   error, error_nack);
            message = message + 1;
        end 
        inject_nack = 1'b0;
        return;
        end
        else begin
            if (error !== 1'b0 || error_nack !== 1'b0) begin
            $error("read_burst read address failed: error=%b nack=%b",
                   error, error_nack);
            message = message + 1;
        end 
        end

        for (index = 0; index < 14; index = index + 1) begin
            case (index)
                0:  expected_byte = expected_value1;
                1:  expected_byte = expected_value2;
                2:  expected_byte = expected_value3;
                3:  expected_byte = expected_value4;
                4:  expected_byte = expected_value5;
                5:  expected_byte = expected_value6;
                6:  expected_byte = expected_value7;
                7:  expected_byte = expected_value8;
                8:  expected_byte = expected_value9;
                9:  expected_byte = expected_value10;
                10: expected_byte = expected_value11;
                11: expected_byte = expected_value12;
                12: expected_byte = expected_value13;
                13: expected_byte = expected_value14;
                default: expected_byte = 8'hxx;
            endcase

            @(negedge clk);
            cmd_kind = READ_BYTE;
            read_ack = (index < 13);
            cmd_valid = 1'b1;
            wait(cmd_valid && cmd_ready);
            wait(busy);
            cmd_valid = 1'b0;
            wait(done || error);
            @(negedge clk);

            if (error !== 1'b0 || error_nack !== 1'b0) begin
                $error("read_burst byte %0d failed: error=%b nack=%b",
                       index, error, error_nack);
                message = message + 1;
            end
            if (rx_data !== expected_byte) begin
                $error("read_burst byte %0d mismatch: expected %h, got %h",
                       index, expected_byte, rx_data);
                message = message + 1;
            end

            if (index < 13) begin
                if (sensor_model.read_mode !== 1'b1) begin
                    $error("read_burst stopped reading after byte %0d", index);
                    message = message + 1;
                end
                if (sensor_model.register_pointer !==
                    (start_register + index + 1)) begin
                    $error("read_burst pointer mismatch after byte %0d: expected %h, got %h",
                           index, start_register + index + 1,
                           sensor_model.register_pointer);
                    message = message + 1;
                end
            end
            else begin
                if (sensor_model.read_mode !== 1'b0) begin
                    $error("read_burst final NACK did not end read mode");
                    message = message + 1;
                end
                if (sensor_model.register_pointer !==
                    (start_register + 13)) begin
                    $error("read_burst final pointer mismatch: expected %h, got %h",
                           start_register + 13, sensor_model.register_pointer);
                    message = message + 1;
                end
            end
        end

        @(negedge clk);
        cmd_kind = STOP;
        cmd_valid = 1'b1;
        wait(cmd_valid && cmd_ready);
        wait(busy);
        cmd_valid = 1'b0;
        wait(done || error);
        @(negedge clk);
        if (error !== 1'b0) begin
            $error("read_burst STOP failed: error=%b", error);
            message = message + 1;
        end
        if (sensor_model.transaction_active !== 1'b0) begin
            $error("read_burst STOP did not end the transaction");
            message = message + 1;
        end
    end
endtask
task timeout_phase(
    input logic [7:0] register_address,
    input logic [7:0] data_value
);
    begin
        @(negedge clk)begin
            reset=0;
            cmd_kind=START;
            cmd_valid=1;
        wait(cmd_valid && cmd_ready)begin
        end
        wait(busy)begin
            cmd_valid=0;
        end
        wait(done || error)begin
            @(negedge clk);
        if(error)begin
            $error("Mismatch: expected %0d, received %0d",
            0,
            error
        );
        message=message+1;
        end
       if (sensor_model.transaction_active !== 1'b1) begin
            $error("Expected transaction_active = 1, got %b",
           sensor_model.transaction_active);
            message = message + 1;
         end
        end
        end

        @(negedge clk)begin
            cmd_kind = WRITE_BYTE;
            tx_data   = 8'hD2;
            cmd_valid = 1'b1;
        end
        wait(cmd_valid && cmd_ready)begin
        end
        wait(busy)begin
            cmd_valid=0;
        end

        timeout_seen = 1'b0;
        watchdog_expired = 1'b0;
        tb_scl_timeout_low = 1'b1;

        fork : wait_for_timeout
            begin
                @(posedge error);
                timeout_seen = 1'b1;
            end
            begin
                repeat (520_000) @(posedge clk);
                watchdog_expired = 1'b1;
            end
        join_any
        disable wait_for_timeout;

        @(negedge clk);
        tb_scl_timeout_low = 1'b0;

        if (watchdog_expired) begin
            $error("DUT failed to produce a timeout error");
            message = message + 1;
        end
        else begin
            if (!timeout_seen || error_timeout !== 1'b1) begin
            $error("Expected error_timeout=1, got error=%b timeout=%b",
                   error, error_timeout);
            message = message + 1;
        end
        end
        end
            

        // Timeout aborts this transaction; do not continue with pointer/data.
        return;

endtask

    always @(posedge scl_bus) begin
    case (logger_phase)

        LOG_DEVICE_ADDRESS,
        LOG_REGISTER_POINTER,
        LOG_WRITE_DATA,
        LOG_READ_ADDRESS,
        LOG_READ_DATA: begin
            logger_shift_reg[7 - logger_bit_count] = sda_bus;

            if (logger_bit_count == 3'd7) begin
                logger_bit_count = 3'd0;
                ack_return_phase = logger_phase;
                logger_phase = LOG_ACK_PHASE;
            end
            else begin
                logger_bit_count = logger_bit_count + 1'b1;
            end
        end

        LOG_ACK_PHASE: begin
              if (logger_count < 32) begin
        transaction_log[logger_count] = logger_shift_reg;
        transaction_ack_log[logger_count] = sda_bus;
        logger_count = logger_count + 1;
    end
    if (ack_return_phase == LOG_READ_DATA) begin
        // MPU sent data; master responds.
        if (sda_bus == 1'b0) begin
            // Master ACK: another read byte follows.
            logger_byte_count = logger_byte_count + 1'b1;
            logger_phase = LOG_READ_DATA;
        end
        else begin
            // Master NACK: read is finished.
            logger_phase = LOG_WAIT_STOP;
        end
    end
    else begin
        // Master sent a byte; MPU responds.
        if (sda_bus == 1'b1) begin
            // Slave NACK.
            logger_phase = LOG_WAIT_STOP;
             
        end
        else if (ack_return_phase == LOG_DEVICE_ADDRESS) begin
            if (logger_shift_reg == 8'hD2)
                logger_phase = LOG_REGISTER_POINTER;
            else if (logger_shift_reg == 8'hD3) begin
                logger_read_direction = 1'b1;
                logger_phase = LOG_READ_DATA;
            end
        end
        else if (ack_return_phase == LOG_REGISTER_POINTER)begin
            logger_phase = LOG_WAIT_START;
        end
        else if (ack_return_phase == LOG_WRITE_DATA) begin
            logger_phase = LOG_WAIT_STOP;
        end
       
    end
end
    endcase
end
always @(scl_bus) begin
    scl_last_change = $time;
    scl_was_high <= scl_bus;
end
always @(negedge sda_bus) begin
    #0;
    if(!reset && scl_was_high && $time != scl_last_change)begin
        logger_bit_count = 3'd0;
        logger_shift_reg = 8'h00;
        ack_return_phase = LOG_WAIT_START;
        logger_phase = LOG_DEVICE_ADDRESS;
    end
end
always @(posedge sda_bus) begin
    #0;
    if (!reset && scl_was_high && $time != scl_last_change) begin
       logger_phase=LOG_WAIT_STOP;
        logger_bit_count = 3'd0;
        logger_shift_reg = 8'h00;
    end
end
endmodule
