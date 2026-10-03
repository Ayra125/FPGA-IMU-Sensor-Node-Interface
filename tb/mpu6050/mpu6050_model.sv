`timescale 1ns/1ps
module mpu6050_model (
    input logic sda_in,
    input logic scl_in,
    input logic reset,
    input logic inject_nack,
    output logic mpu_sda_drive_low,
    output logic mpu_scl_drive_low
);
    // local peramiters
localparam [7:0] PWR_MGMT_1 = 8'h6B;
localparam [7:0] SMPLRT_DIV = 8'h19;
localparam [7:0] MPU_CONFIG = 8'h1A;
localparam [7:0] GYRO_CONFIG = 8'h1B;
localparam [7:0] ACCEL_CONFIG = 8'h1C;
localparam [7:0] WHO_AM_I = 8'h75;
localparam logic [7:0] I2C_WRITE_ADDR = 8'hD2;
localparam logic [7:0] I2C_READ_ADDR  = 8'hD3;

logic [7:0] rx_shift_reg;
logic [7:0] tx_shift_reg;
logic [7:0] register_pointer;
logic [3:0] bit_count;
logic transaction_active;
logic read_mode;
logic [7:0] register_map [0:255];
logic address_recived;
logic ack_pending;
logic ack_active;
logic pointer_recived;
logic read_ack;
logic read_ack_val;
logic last_data_bit;
logic nack_pending;
time scl_last_change;
logic scl_was_high;
initial begin
register_map[8'h3B] = 8'h12; // Accel X high
register_map[8'h3C] = 8'h34; // Accel X low

register_map[8'h3D] = 8'h56; // Accel Y high
register_map[8'h3E] = 8'h78; // Accel Y low

register_map[8'h3F] = 8'h9A; // Accel Z high
register_map[8'h40] = 8'hBC; // Accel Z low

register_map[8'h41] = 8'hDE; // Temperature high
register_map[8'h42] = 8'hF0; // Temperature low

register_map[8'h43] = 8'h13; // Gyro X high
register_map[8'h44] = 8'h57; // Gyro X low

register_map[8'h45] = 8'h24; // Gyro Y high
register_map[8'h46] = 8'h68; // Gyro Y low

register_map[8'h47] = 8'h80; // Gyro Z high
register_map[8'h48] = 8'hFF; // Gyro Z low

register_map[8'h75] = 8'h68; // WHO_AM_I
transaction_active=0;
read_mode=0;
address_recived=0;
register_pointer=0;
bit_count=0;
rx_shift_reg=0;
tx_shift_reg=0;
ack_pending=0;
ack_active=0;
pointer_recived=0;
read_ack=0;
read_ack_val=0;
last_data_bit=0;
mpu_sda_drive_low=0;
mpu_scl_drive_low=0;
nack_pending=0;
end

always @(posedge reset) begin
    transaction_active=0;
    read_mode=0;
    address_recived=0;
    register_pointer=0;
    bit_count=0;
    rx_shift_reg=0;
    tx_shift_reg=0;
    ack_pending=0;
    ack_active=0;
    pointer_recived=0;
    read_ack=0;
    read_ack_val=0;
    last_data_bit=0;
    mpu_sda_drive_low=0;
    mpu_scl_drive_low=0;
    nack_pending=0;
end
always @(scl_in) begin
    scl_last_change = $time;
    scl_was_high <= scl_in;
end
always @(negedge sda_in) begin
    #1;
    if(!reset && scl_was_high && $time != scl_last_change)begin
        transaction_active=1;
        bit_count=0;
        rx_shift_reg = 8'h00;
        address_recived=0;
    end
end
always @(posedge sda_in) begin
    #1;
    if (!reset && scl_was_high && $time != scl_last_change) begin
        transaction_active = 0;
        read_mode  = 0;
        bit_count = 0;
        rx_shift_reg = 0;
        tx_shift_reg = 0;
        mpu_sda_drive_low = 0;
        mpu_scl_drive_low = 0;
        address_recived=0;
    end
end
always @(posedge scl_in)begin
    
    if(transaction_active && !read_mode && !ack_active && !reset)begin
        rx_shift_reg = {rx_shift_reg[6:0], sda_in};
        if(bit_count == 7)begin
            bit_count=0;
            if(inject_nack)begin
                nack_pending = 1;
                ack_pending = 0;
            end 
            else begin
        if(!address_recived) begin
        if(rx_shift_reg==I2C_READ_ADDR)begin
                read_mode=1;
                address_recived=1;
                rx_shift_reg=0;
                tx_shift_reg=register_map[register_pointer];
                bit_count=7;
                ack_pending=1;
        end
        else if(rx_shift_reg==I2C_WRITE_ADDR)begin
                read_mode=0;
                address_recived=1;
                rx_shift_reg =0;
                pointer_recived=0;
                ack_pending=1;
        end 
        else begin
                read_mode=0;
                address_recived=0;
                rx_shift_reg =0;
                pointer_recived=0;
                nack_pending=1;
                ack_pending=0;
        end
        end
        else if(!read_mode && !pointer_recived) begin
            read_mode=0;
            register_pointer = rx_shift_reg;
            rx_shift_reg=0;
            pointer_recived=1;
            address_recived=1;
            ack_pending=1;
        end
        else if(!read_mode && pointer_recived)begin
            read_mode=0;
            register_map[register_pointer]=rx_shift_reg; 
            rx_shift_reg=0;
            pointer_recived=1;
            address_recived=1;
            ack_pending=1;
        end
        end
        end
        else begin
         bit_count=bit_count+1;
        end

    end
end
always @(negedge scl_in) begin
    if(ack_pending && !reset )begin
        mpu_sda_drive_low<=1;
        ack_pending=0;
        ack_active=1;
    end
    else if(nack_pending && !reset)begin
        mpu_sda_drive_low<=0;
       nack_pending=0;
    end
     else if(ack_active && !reset)begin
        ack_active=0;
        if(read_mode)begin
            mpu_sda_drive_low = ~tx_shift_reg[bit_count];
            bit_count<=bit_count-1;
        end
        else begin
             mpu_sda_drive_low<=0;
        end
    end
    else if(read_mode && !ack_active && !read_ack && !reset)begin
        mpu_sda_drive_low = ~tx_shift_reg[bit_count];
        if(bit_count==0 && !last_data_bit)begin
            last_data_bit<=1;
        end
        else if(last_data_bit)begin
            read_ack=1;
            last_data_bit=0;
             mpu_sda_drive_low=0;
        end
        else begin
            bit_count=bit_count-1;
        end
    end

end
always @(posedge scl_in)begin
    if(read_ack && !reset)begin
        read_ack_val=sda_in;
        last_data_bit=0;
        if(!read_ack_val)begin
        read_ack_val=0;
        register_pointer++;
        tx_shift_reg=register_map[register_pointer];
        bit_count=7;
        read_ack=0;
        end
        else if(read_ack_val) begin
       read_mode=0;
       read_ack=0;
       end
    end
end
endmodule
