// Phase 2 generic I2C bit/byte engine.
`timescale 1ns/1ps
module i2c_engine (
input  logic clk,
input  logic reset,
input  logic i2c_step,

input  logic cmd_valid,
output logic cmd_ready,
input  logic [1:0] cmd_kind,
input  logic [7:0] tx_data,
input  logic read_ack,

output logic busy,
output logic done,
output logic error,
output logic error_nack,
output logic error_timeout,
output logic [7:0] rx_data,

output logic sda_drive_low = 1'b0,
output logic scl_drive_low = 1'b0,
input  logic sda_in,
input  logic scl_in
);
// Command encodings: received from the controller on cmd_kind.
localparam logic [1:0] START      = 2'b00;
localparam logic [1:0] STOP       = 2'b01;
localparam logic [1:0] WRITE_BYTE = 2'b10;
localparam logic [1:0] READ_BYTE  = 2'b11;

localparam logic [3:0] STATE_START_PULL_SCL_LOW = 4'd12;
localparam logic [3:0] STATE_START_DRIVE_HIGH = 4'd13;
// FSM states: internal progress of this engine.
localparam logic [2:0] STATE_IDLE              = 3'd0;
localparam logic [2:0] STATE_STOP_DRIVE_LOW    = 3'd1;
localparam logic [2:0] STATE_STOP_RELEASE_SCL= 3'd2;
localparam logic [2:0] STATE_STOP_RELEASE = 3'd3;
localparam logic [3:0] STATE_WRITE_SET_SDA      = 4'd4;
localparam logic [3:0] STATE_WRITE_RELEASE_SCL  = 4'd5;
localparam logic [3:0] STATE_WRITE_PULL_SCL_LOW = 4'd6;
localparam logic [3:0] STATE_WRITE_ACK_RELEASE  = 4'd7;
localparam logic [3:0] STATE_WRITE_ACK_SCL_HIGH = 4'd8;
localparam logic [3:0] STATE_WRITE_ACK_SCL_LOW  = 4'd9;

localparam logic [4:0] STATE_READ_RELEASE_SCL = 5'd14;
localparam logic [4:0] STATE_READ_SAMPLE_SDA = 5'd15;
localparam logic [4:0] STATE_READ_PULL_SCL_LOW = 5'd16;
localparam logic [4:0] STATE_READ_SET_ACK_NACK = 5'd17;
localparam logic [4:0] STATE_READ_ACK_SCL_HIGH = 5'd18;
localparam logic [4:0] STATE_READ_ACK_SCL_LOW = 5'd19;


logic [7:0] byte_to_send;
logic [1:0] step_stop=0;
logic [2:0] bit_index;
logic [4:0] state;
logic [7:0] tx_shift_reg;
logic [7:0] rx_shift_reg;
logic read_ack_latched;
logic [18:0] timeout_counter;
logic sda_stage_1;
logic sda_stage_2;
logic scl_stage_1;
logic scl_stage_2;
always_ff @(posedge clk) begin
     if(reset)begin
        state<= STATE_IDLE;
        sda_drive_low<=0;
        scl_drive_low<=0;
        busy<=0;
        done<=0;
        cmd_ready <= 1;
        rx_data <= 0;
        bit_index <= 0;
        tx_shift_reg <= 0;
        error<=0;
        error_nack<=0;
        error_timeout<=0;
        read_ack_latched<=0;
        timeout_counter<=0;
        sda_stage_1<=0;
        sda_stage_2<=0;
        scl_stage_1<=0;
        scl_stage_2<=0;
    end
    else if(timeout_counter>=19'd499999)begin
        state<= STATE_IDLE;
        sda_drive_low<=0;
        scl_drive_low<=0;
        busy<=0;
        done<=0;
        cmd_ready <= 1;
        rx_data <= 0;
        bit_index <= 0;
        tx_shift_reg <= 0;
        error<=1;
        error_nack<=0;
        error_timeout<=1;
        read_ack_latched<=0;
        timeout_counter<=0;
        sda_stage_1<=0;
        sda_stage_2<=0;
        scl_stage_1<=0;
        scl_stage_2<=0;
    end
    else begin
        done <= 0;
        error <= 0;
        error_nack <= 0;
        error_timeout <= 0;
        sda_stage_1<=sda_in;
        scl_stage_1<=scl_in;
        sda_stage_2<=sda_stage_1;
        scl_stage_2<=scl_stage_1;
    if(busy)begin
        timeout_counter<=timeout_counter+1;
    end

         if(state == STATE_IDLE && cmd_valid && cmd_ready) begin
            case (cmd_kind)
            START: begin
                state<=STATE_START_DRIVE_HIGH;
                sda_drive_low <= 0;
                scl_drive_low <= 0;
                busy<=1;
                cmd_ready<=0;
            end
            STOP: begin
                state<=STATE_STOP_DRIVE_LOW;
                busy<=1;
                scl_drive_low<=1;
                cmd_ready <= 0;
            end 
            WRITE_BYTE: begin
                busy<=1;
                sda_drive_low<=0;
                bit_index<=3'd7;
                cmd_ready<=0;
                tx_shift_reg <= tx_data;
                if (scl_stage_2 === 1'b0) begin
                    state <= STATE_WRITE_RELEASE_SCL;
                    sda_drive_low <= ~tx_data[3'd7];
                end
                else begin
                    state <= STATE_WRITE_SET_SDA;
                    scl_drive_low <= 1;
                end
            end
            READ_BYTE: begin
                state<=STATE_READ_SAMPLE_SDA;
                scl_drive_low<=0;
                busy<=1;
                cmd_ready<=0;
                bit_index<=3'd7;
                sda_drive_low<=0;
                rx_data<=0;
                read_ack_latched<=read_ack;
            end
            endcase
        end

    if(i2c_step) begin
    case(state) 
        STATE_START_DRIVE_HIGH: begin
            scl_drive_low<=0;
            sda_drive_low<=0;
            if(scl_stage_2 && sda_stage_2)begin
                sda_drive_low<=1;
                state<= STATE_START_PULL_SCL_LOW;
            end
            else begin
                state<=STATE_START_DRIVE_HIGH;
            end
        end
        STATE_START_PULL_SCL_LOW: begin
           state <= STATE_IDLE;
            scl_drive_low <= 1;
            busy <= 0;
            done <= 1;
            cmd_ready <= 1; 
            timeout_counter<=0;
        end
        STATE_STOP_DRIVE_LOW:begin    
            if(scl_stage_2 == 0 && sda_stage_2 == 0)begin
                state<=STATE_STOP_RELEASE_SCL;
            end
            else if(scl_stage_2==0 && sda_stage_2==1) begin
                sda_drive_low<=1;
                state<=STATE_STOP_DRIVE_LOW;
            end
            else begin
                scl_drive_low<=1;
                state<=STATE_STOP_DRIVE_LOW;
            end
        end
        STATE_STOP_RELEASE_SCL: begin 
            state<=STATE_STOP_RELEASE;
            sda_drive_low<=1;
            scl_drive_low<=0;
    
        end
        STATE_STOP_RELEASE: begin
            if(scl_stage_2 == 1)begin
                state<=STATE_IDLE;
                sda_drive_low<=0;
                scl_drive_low<=0;
                busy<=0;
                done<=1;
                cmd_ready<=1;
                timeout_counter<=0;
            end
            else begin
                state<=STATE_STOP_RELEASE;
                sda_drive_low<=1;
                scl_drive_low<=0;
            end
        end 
        STATE_WRITE_SET_SDA: begin
            if(!scl_stage_2)begin
                state <= STATE_WRITE_RELEASE_SCL;
                sda_drive_low <= ~tx_shift_reg[bit_index];
            end
            else begin
                scl_drive_low=0;
            end
        end
       STATE_WRITE_RELEASE_SCL: begin
        if(scl_stage_2==1)begin
            scl_drive_low<=1'b1;
              if(bit_index==0) begin
                 state<=STATE_WRITE_ACK_SCL_HIGH;
                    sda_drive_low<=0;
            end
            else begin
               state<=STATE_WRITE_RELEASE_SCL;; 
              bit_index<=bit_index-1'b1;
              sda_drive_low <= ~tx_shift_reg[bit_index - 1'b1];
            end
        end
        else begin
            state<=STATE_WRITE_RELEASE_SCL;
            scl_drive_low<=0;
        end
       end
       STATE_WRITE_ACK_SCL_HIGH: begin
        scl_drive_low<=0;
        if(scl_stage_2)begin
            state<=STATE_IDLE;
        sda_drive_low<=0;
        timeout_counter<=0;
        if(sda_stage_2)begin
            error_nack<=1;
            error<=1;
            busy<=0;
            cmd_ready<=1;
            scl_drive_low<=1'b0;
        end
        else begin
            done<=1;
            busy<=0;
            cmd_ready<=1;
            scl_drive_low<=1;
        end
        end
        else begin
            state<= STATE_WRITE_ACK_SCL_HIGH;
        end
       end
       STATE_READ_RELEASE_SCL: begin
            state <= STATE_READ_SAMPLE_SDA;
            scl_drive_low <= 1'b0;
        end
        STATE_READ_SAMPLE_SDA: begin
        if (scl_stage_2 == 1) begin
            rx_data[bit_index] <= sda_stage_2;
            scl_drive_low <= 1'b1;

            if (bit_index == 0) begin
            state <= STATE_READ_ACK_SCL_HIGH;
            if (read_ack_latched) begin
                sda_drive_low <= 1'b1;
            end
            else begin
                sda_drive_low <= 1'b0;
            end
            end
            else begin
            bit_index <= bit_index - 1'b1;
            state <= STATE_READ_RELEASE_SCL;
            end
        end
        else begin
            state <= STATE_READ_SAMPLE_SDA;
            scl_drive_low <= 1'b0;
        end
        end
    STATE_READ_SET_ACK_NACK: begin
        scl_drive_low<=1;
        state<=STATE_READ_ACK_SCL_HIGH;
        if(read_ack_latched)begin
            sda_drive_low<=1;
        end
        else begin
            sda_drive_low<=0;
        end
    end
    STATE_READ_ACK_SCL_HIGH: begin
        scl_drive_low<=0;
        if(scl_stage_2)begin
           scl_drive_low<=1'b1;
           state<=STATE_READ_ACK_SCL_LOW;
        end
        else begin
            state<=STATE_READ_ACK_SCL_HIGH;
        end
    end
    STATE_READ_ACK_SCL_LOW: begin
        state<=STATE_IDLE;
        scl_drive_low<=1;
        sda_drive_low<=0;
        cmd_ready<=1;
        busy<=0;
        done<=1;
        timeout_counter<=0;
        error<=0;
        error_nack<=0;
    end
    endcase
end
end
end
endmodule
// Learner-authored synthesizable RTL goes here.
