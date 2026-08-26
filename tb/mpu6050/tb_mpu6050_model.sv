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

    localparam logic [1:0] START      = 2'b00;
    localparam logic [1:0] STOP       = 2'b01;
    localparam logic [1:0] WRITE_BYTE = 2'b10;
    localparam logic [1:0] READ_BYTE  = 2'b11;

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
        .mpu_scl_drive_low(mpu_scl_drive_low)
    );

    assign sda_bus = ~(sda_drive_low | mpu_sda_drive_low);
    assign scl_bus = ~(scl_drive_low | mpu_scl_drive_low);

    always #5 clk = ~clk;

    initial begin
        clk = 1'b0;
        reset = 1'b1;
        cmd_valid = 1'b0;
        cmd_kind = START;
        tx_data = 8'h00;
        read_ack = 1'b0;
        repeat(4)@(negedge clk); begin
            reset=1;
        end
        @(negedge clk)begin
            reset=0;
            cmd_kind=START;
            cmd_valid=1;
        end

    end

endmodule