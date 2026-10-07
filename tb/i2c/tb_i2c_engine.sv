`timescale 1ns/1ps
// Self-checking testbench for i2c_engine.
module tb_i2c_engine;
  // Testbench drives these DUT inputs
logic       clk, reset, i2c_step, sample_tick;
logic       cmd_valid;
logic [1:0] cmd_kind;
logic [7:0] tx_data;
logic       read_ack;
logic [1:0] shadow_cmd_kind;
logic [7:0] shadow_tx_data;
logic       shadow_read_ack, shadow_active;
logic       sda_in, scl_in;
logic [2:0] bit_index;
logic i2c_nack_next;
logic was_pending;
// DUT drives these outputs; testbench observes them
logic       cmd_ready,ex_cmd_ready, busy,ex_busy, done,ex_done;
logic       error,ex_error, error_nack,ex_error_nack, error_timeout,ex_error_timeout;
logic [7:0] rx_data,ex_rx_data;
logic       sda_drive_low,ex_sda_drive_low, scl_drive_low,ex_scl_drive_low;
logic [3:0] mpu_bit_count;
logic       mpu_sda_drive_low,mpu_scl_drive_low;
logic       mpu_active, mpu_ack_driven, mpu_nack_next;
logic       sda_bus, scl_bus;
logic [7:0] mpu_reconstructed_byte;
logic       mpu_read_done;
logic [3:0] mpu_strech_bit;
logic       scl_was_high;
time        scl_last_change;
time        time_begin;
time        time_end;
int message=0;
int unsigned seed;
logic [7:0] random_byte;
logic       command_outstanding;
logic       done_last;
logic       error_last;
logic reset_check_pending;
logic [18:0] command_cycle_count;
logic [1:0] accepted_cmd_kind;
logic accepted_cmd_active;
logic mpu_timeout;
time timeout_accept_time,timeout_error_time,timeout_elapsed,high_duration,low_start_time,
high_start_time,low_duration,stretched_write_duration;
logic high_start_time_done,low_start_time_done, timing_check_active;
logic [3:0] ninth_clock_check;
logic final_phase_checked, final_read_bit_pending, ack_phase_observed;
logic [3:0] low_phase_count, high_phase_count;
logic tb_scl_stretch_low;


i2c_engine dut (
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
    .sda_in(sda_in),
    .scl_in(scl_in)
);
timing_enable_gen dutt (
  .clk(clk),
  .reset(reset),
  .i2c_step(i2c_step),
  .sample_tick(sample_tick)
);
assign scl_in = scl_bus;
assign sda_in = sda_bus;
localparam logic [1:0] START      = 2'b00;
localparam logic [1:0] STOP       = 2'b01;
localparam logic [1:0] WRITE_BYTE = 2'b10;
localparam logic [1:0] READ_BYTE  = 2'b11;
localparam time EXPECTED_TIMEOUT  =5ms;
localparam time EXPECTED_SCL_HALF = 5us;
localparam time MIN_STRETCHED_WRITE = 105us;
localparam time TIMING_TOLERANCE = 10ns;

initial begin
  $dumpfile("i2c_engine.vcd");
  $dumpvars(0,tb_i2c_engine);
  $monitor("t=%0t cmd_valid=%b cmd_ready=%b busy=%b done=%b error=%b i2c_step=%b",
          $time, cmd_valid, cmd_ready, busy, done, error, i2c_step);
  clk = 0;
  reset = 1;
  cmd_valid = 0;
  cmd_kind = 0;
  tx_data = 0;
  read_ack = 0;
  ex_cmd_ready     = 0;
  ex_busy          = 0;
  ex_done          = 0;
  ex_error         = 0;
  ex_error_nack    = 0;
  ex_error_timeout = 0;
  ex_rx_data       = 0;
  ex_sda_drive_low = 0;
  ex_scl_drive_low = 0;
  mpu_active        = 0;
  shadow_active     = 0;
  was_pending       = 0;
  mpu_ack_driven    = 0;
  mpu_nack_next     = 0;  // prepare ACK response
  mpu_sda_drive_low = 0;
  mpu_scl_drive_low = 0;
  mpu_bit_count     = 0;  
  mpu_read_done=0;
  i2c_nack_next=0;
  mpu_strech_bit=10;
  seed = 32'h1A2B_3C4D;
  command_outstanding=0;
  reset_check_pending=0;
  accepted_cmd_kind=START;
  accepted_cmd_active=0;
  mpu_timeout=0;
  high_start_time_done=0;
  low_start_time_done=0;
  timing_check_active=0;
  ninth_clock_check=4'd0;
  low_phase_count=4'd0;
  high_phase_count=4'd0;
  final_phase_checked=0;
  final_read_bit_pending = 0;
  ack_phase_observed = 0;
$display("Random seed = 0x%08h", seed);
  @(negedge clk);
    reset = 0;
    cmd_valid=1;
  wait(cmd_valid && cmd_ready)begin
    cmd_kind=START;
  end
  wait(busy)begin
    cmd_valid=0;
  end
  @(posedge done or posedge error)begin
    #1;
   if(busy)begin
    $error("Mismatch: expected %0d, received %0d",
            0,
            busy
    );
    message=message+1;
   end
   if(!cmd_ready)begin
    $error("Mismatch: expected %0d, received %0d",
            1,
            cmd_ready
    );
    message=message+1;
   end
    if(error)begin
      $error("Mismatch: expected %0d, received %0d",
            0,
            error
    );
    message=message+1;
    end
    if(!mpu_active)begin
      $error("Mismatch: expected %0d, received %0d",
            1,
            mpu_active
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
    if(error_timeout)begin
      $error("Mismatch: expected %0d, received %0d",
            0,
            error_timeout
    );
    message=message+1;
    end
    cmd_valid=0;
  end
  @(negedge clk)begin
    cmd_valid=1;
    random_byte = $urandom(seed);
  end
  wait(cmd_ready && cmd_valid)begin
    cmd_kind=WRITE_BYTE;
     tx_data=random_byte;
     bit_index=7;
     mpu_nack_next=0;
     timing_check_active=1;
     final_phase_checked=0;
     low_phase_count=4'd0;
     high_phase_count=4'd0;
  end
  wait(busy)begin
    cmd_valid=0;
  end
  @(posedge done or posedge error)begin
    #1;
   if(busy)begin
    $error("Mismatch: expected %0d, received %0d",
            0,
            busy
    );
    message=message+1;
   end
   if(!cmd_ready)begin
    $error("Mismatch: expected %0d, received %0d",
            1,
            cmd_ready
    );
    message=message+1;
   end
    if(error)begin
      $error("Mismatch: expected %0d, received %0d",
            0,
            error
    );
    message=message+1;
    end
    if(!mpu_active)begin
      $error("Mismatch: expected %0d, received %0d",
            1,
            mpu_active
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
    if(error_timeout)begin
      $error("Mismatch: expected %0d, received %0d",
            0,
            error_timeout
    ); 
    message=message+1;
    end
    if(tx_data!==mpu_reconstructed_byte)begin
      $error("Mismatch: expected %0d, received %0d",
            tx_data,
            mpu_reconstructed_byte
    ); 
    message=message+1;
    end
    if (ninth_clock_check !== 4'd9) begin
    $error("Expected 9 SCL clocks, got %0d", ninth_clock_check);
    message = message + 1;
    end
    if (low_phase_count !== 4'd8) begin
      $error("Expected 8 complete low phases, got %0d", low_phase_count);
      message = message + 1;
    end
    if (high_phase_count !== 4'd9) begin
      $error("Expected 9 high phases, got %0d", high_phase_count);
      message = message + 1;
    end
    if (!final_phase_checked) begin
      $error("Final SCL high phase was not checked");
      message = message + 1;
    end

ninth_clock_check = 4'd0;
high_start_time_done = 0;
low_start_time_done = 0;
timing_check_active = 0;
final_phase_checked = 0;
    cmd_valid=0;
    bit_index=0;
    mpu_read_done=0;
    tx_data=0;
    mpu_reconstructed_byte=0;
    mpu_sda_drive_low=0;
    timing_check_active=0;
  end
  
  @(negedge clk);
    reset = 0;
    cmd_valid=1;
  wait(cmd_valid && cmd_ready)begin
    cmd_kind=START;
  end
  wait(busy)begin
    cmd_valid=0;
  end
  @(posedge done or posedge error)begin
    #1;
   if(busy)begin
    $error("Mismatch: expected %0d, received %0d",
            0,
            busy
    );
    message=message+1;
   end
   if(!cmd_ready)begin
    $error("Mismatch: expected %0d, received %0d",
            1,
            cmd_ready
    );
    message=message+1;
   end
    if(error)begin
      $error("Mismatch: expected %0d, received %0d",
            0,
            error
    );
    message=message+1;
    end
    if(!mpu_active)begin
      $error("Mismatch: expected %0d, received %0d",
            1,
            mpu_active
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
    if(error_timeout)begin
      $error("Mismatch: expected %0d, received %0d",
            0,
            error_timeout
    );
    message=message+1;
    end
    cmd_valid=0;
  end
  @(negedge clk)begin
    cmd_valid=1;
    random_byte = $urandom(seed);
  end
  wait(cmd_ready && cmd_valid)begin
    cmd_kind=WRITE_BYTE;
     tx_data=random_byte;
     bit_index=7;
     mpu_nack_next=0;
  end
  wait(busy)begin
    cmd_valid=0;
  end
  @(posedge done or posedge error)begin
    #1;
   if(busy)begin
    $error("Mismatch: expected %0d, received %0d",
            0,
            busy
    );
    message=message+1;
   end
   if(!cmd_ready)begin
    $error("Mismatch: expected %0d, received %0d",
            1,
            cmd_ready
    );
    message=message+1;
   end
    if(error)begin
      $error("Mismatch: expected %0d, received %0d",
            0,
            error
    );
    message=message+1;
    end
    if(!mpu_active)begin
      $error("Mismatch: expected %0d, received %0d",
            1,
            mpu_active
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
    if(error_timeout)begin
      $error("Mismatch: expected %0d, received %0d",
            0,
            error_timeout
    ); 
    message=message+1;
    end
    if(tx_data!==mpu_reconstructed_byte)begin
      $error("Mismatch: expected %0d, received %0d",
            tx_data,
            mpu_reconstructed_byte
    ); 
    message=message+1;
    end
    cmd_valid=0;
    bit_index=0;
    mpu_read_done=0;
    tx_data=0;
    mpu_reconstructed_byte=0;
    mpu_sda_drive_low=0;
  end@(negedge clk);
    reset = 0;
    cmd_valid=1;
  wait(cmd_valid && cmd_ready)begin
    cmd_kind=START;
  end
  wait(busy)begin
    cmd_valid=0;
  end
  @(posedge done or posedge error)begin
    #1;
   if(busy)begin
    $error("Mismatch: expected %0d, received %0d",
            0,
            busy
    );
    message=message+1;
   end
   if(!cmd_ready)begin
    $error("Mismatch: expected %0d, received %0d",
            1,
            cmd_ready
    );
    message=message+1;
   end
    if(error)begin
      $error("Mismatch: expected %0d, received %0d",
            0,
            error
    );
    message=message+1;
    end
    if(!mpu_active)begin
      $error("Mismatch: expected %0d, received %0d",
            1,
            mpu_active
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
    if(error_timeout)begin
      $error("Mismatch: expected %0d, received %0d",
            0,
            error_timeout
    );
    message=message+1;
    end
    cmd_valid=0;
  end
  @(negedge clk)begin
    cmd_valid=1;
    random_byte = $urandom(seed);
  end
  wait(cmd_ready && cmd_valid)begin
    cmd_kind=WRITE_BYTE;
     tx_data=random_byte;
     bit_index=7;
     mpu_nack_next=0;
  end
  wait(busy)begin
    cmd_valid=0;
  end
  @(posedge done or posedge error)begin
    #1;
   if(busy)begin
    $error("Mismatch: expected %0d, received %0d",
            0,
            busy
    );
    message=message+1;
   end
   if(!cmd_ready)begin
    $error("Mismatch: expected %0d, received %0d",
            1,
            cmd_ready
    );
    message=message+1;
   end
    if(error)begin
      $error("Mismatch: expected %0d, received %0d",
            0,
            error
    );
    message=message+1;
    end
    if(!mpu_active)begin
      $error("Mismatch: expected %0d, received %0d",
            1,
            mpu_active
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
    if(error_timeout)begin
      $error("Mismatch: expected %0d, received %0d",
            0,
            error_timeout
    ); 
    message=message+1;
    end
    if(tx_data!==mpu_reconstructed_byte)begin
      $error("Mismatch: expected %0d, received %0d",
            tx_data,
            mpu_reconstructed_byte
    ); 
    message=message+1;
    end
    cmd_valid=0;
    bit_index=0;
    mpu_read_done=0;
    tx_data=0;
    mpu_reconstructed_byte=0;
    mpu_sda_drive_low=0;
  end@(negedge clk);
    reset = 0;
    cmd_valid=1;
  wait(cmd_valid && cmd_ready)begin
    cmd_kind=START;
  end
  wait(busy)begin
    cmd_valid=0;
  end
  @(posedge done or posedge error)begin
    #1;
   if(busy)begin
    $error("Mismatch: expected %0d, received %0d",
            0,
            busy
    );
    message=message+1;
   end
   if(!cmd_ready)begin
    $error("Mismatch: expected %0d, received %0d",
            1,
            cmd_ready
    );
    message=message+1;
   end
    if(error)begin
      $error("Mismatch: expected %0d, received %0d",
            0,
            error
    );
    message=message+1;
    end
    if(!mpu_active)begin
      $error("Mismatch: expected %0d, received %0d",
            1,
            mpu_active
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
    if(error_timeout)begin
      $error("Mismatch: expected %0d, received %0d",
            0,
            error_timeout
    );
    message=message+1;
    end
    cmd_valid=0;
  end
  @(negedge clk)begin
    cmd_valid=1;
    random_byte = $urandom(seed);
  end
  wait(cmd_ready && cmd_valid)begin
    cmd_kind=WRITE_BYTE;
     tx_data=random_byte;
     bit_index=7;
     mpu_nack_next=0;
  end
  wait(busy)begin
    cmd_valid=0;
  end
  @(posedge done or posedge error)begin
    #1;
   if(busy)begin
    $error("Mismatch: expected %0d, received %0d",
            0,
            busy
    );
    message=message+1;
   end
   if(!cmd_ready)begin
    $error("Mismatch: expected %0d, received %0d",
            1,
            cmd_ready
    );
    message=message+1;
   end
    if(error)begin
      $error("Mismatch: expected %0d, received %0d",
            0,
            error
    );
    message=message+1;
    end
    if(!mpu_active)begin
      $error("Mismatch: expected %0d, received %0d",
            1,
            mpu_active
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
    if(error_timeout)begin
      $error("Mismatch: expected %0d, received %0d",
            0,
            error_timeout
    ); 
    message=message+1;
    end
    if(tx_data!==mpu_reconstructed_byte)begin
      $error("Mismatch: expected %0d, received %0d",
            tx_data,
            mpu_reconstructed_byte
    ); 
    message=message+1;
    end
    cmd_valid=0;
    bit_index=0;
    mpu_read_done=0;
    tx_data=0;
    mpu_reconstructed_byte=0;
    mpu_sda_drive_low=0;
  end@(negedge clk);
    reset = 0;
    cmd_valid=1;
  wait(cmd_valid && cmd_ready)begin
    cmd_kind=START;
  end
  wait(busy)begin
    cmd_valid=0;
  end
  @(posedge done or posedge error)begin
    #1;
   if(busy)begin
    $error("Mismatch: expected %0d, received %0d",
            0,
            busy
    );
    message=message+1;
   end
   if(!cmd_ready)begin
    $error("Mismatch: expected %0d, received %0d",
            1,
            cmd_ready
    );
    message=message+1;
   end
    if(error)begin
      $error("Mismatch: expected %0d, received %0d",
            0,
            error
    );
    message=message+1;
    end
    if(!mpu_active)begin
      $error("Mismatch: expected %0d, received %0d",
            1,
            mpu_active
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
    if(error_timeout)begin
      $error("Mismatch: expected %0d, received %0d",
            0,
            error_timeout
    );
    message=message+1;
    end
    cmd_valid=0;
  end
  @(negedge clk)begin
    cmd_valid=1;
    random_byte = $urandom(seed);
  end
  wait(cmd_ready && cmd_valid)begin
    cmd_kind=WRITE_BYTE;
     tx_data=random_byte;
     bit_index=7;
     mpu_nack_next=0;
  end
  wait(busy)begin
    cmd_valid=0;
  end
  @(posedge done or posedge error)begin
    #1;
   if(busy)begin
    $error("Mismatch: expected %0d, received %0d",
            0,
            busy
    );
    message=message+1;
   end
   if(!cmd_ready)begin
    $error("Mismatch: expected %0d, received %0d",
            1,
            cmd_ready
    );
    message=message+1;
   end
    if(error)begin
      $error("Mismatch: expected %0d, received %0d",
            0,
            error
    );
    message=message+1;
    end
    if(!mpu_active)begin
      $error("Mismatch: expected %0d, received %0d",
            1,
            mpu_active
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
    if(error_timeout)begin
      $error("Mismatch: expected %0d, received %0d",
            0,
            error_timeout
    ); 
    message=message+1;
    end
    if(tx_data!==mpu_reconstructed_byte)begin
      $error("Mismatch: expected %0d, received %0d",
            tx_data,
            mpu_reconstructed_byte
    ); 
    message=message+1;
    end
    cmd_valid=0;
    bit_index=0;
    mpu_read_done=0;
    tx_data=0;
    mpu_reconstructed_byte=0;
    mpu_sda_drive_low=0;
  end

@(negedge clk);
    reset = 0;
    cmd_valid=1;
  wait(cmd_valid && cmd_ready)begin
    cmd_kind=START;
  end
  wait(busy)begin
    cmd_valid=0;
  end
  @(posedge done or posedge error)begin
    #1;
   if(busy)begin
    $error("Mismatch: expected %0d, received %0d",
            0,
            busy
    );
    message=message+1;
   end
   if(!cmd_ready)begin
    $error("Mismatch: expected %0d, received %0d",
            1,
            cmd_ready
    );
    message=message+1;
   end
    if(error)begin
      $error("Mismatch: expected %0d, received %0d",
            0,
            error
    );
    message=message+1;
    end
    if(!mpu_active)begin
      $error("Mismatch: expected %0d, received %0d",
            1,
            mpu_active
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
    if(error_timeout)begin
      $error("Mismatch: expected %0d, received %0d",
            0,
            error_timeout
    );
    message=message+1;
    end
    cmd_valid=0;
    mpu_sda_drive_low=0;
  end
  @(negedge clk)begin
    cmd_valid=1;
    random_byte = $urandom(seed);
  end
  wait(cmd_ready && cmd_valid)begin
    cmd_kind=READ_BYTE;
     mpu_reconstructed_byte=random_byte;
     bit_index=6;
     mpu_nack_next=0;
     read_ack=0;
     timing_check_active=1;
     final_phase_checked=0;
     low_phase_count=4'd0;
     high_phase_count=4'd0;
  end
  wait(busy)begin
    cmd_valid=0;
     mpu_sda_drive_low=~mpu_reconstructed_byte[7];
  end
  @(posedge done or posedge error)begin
    #1;
   if(busy)begin
    $error("Mismatch: expected %0d, received %0d",
            0,
            busy
    );
    message=message+1;
   end
   if(!cmd_ready)begin
    $error("Mismatch: expected %0d, received %0d",
            1,
            cmd_ready
    );
    message=message+1;
   end
    if(error)begin
      $error("Mismatch: expected %0d, received %0d",
            0,
            error
    );
    message=message+1;
    end
    if(!mpu_active)begin
      $error("Mismatch: expected %0d, received %0d",
            0,
            mpu_active
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
    if(error_timeout)begin
      $error("Mismatch: expected %0d, received %0d",
            0,
            error_timeout
    ); 
    message=message+1;
    end
    if(rx_data !== mpu_reconstructed_byte)begin
      $error("Mismatch: expected %0d, received %0d",
            rx_data,
            mpu_reconstructed_byte
    ); 
    message=message+1;
    end
    if (ninth_clock_check !== 4'd9) begin
      $error("Expected 9 SCL clocks, got %0d", ninth_clock_check);
      message = message + 1;
    end
    if (low_phase_count !== 4'd8) begin
      $error("Expected 8 complete low phases, got %0d", low_phase_count);
      message = message + 1;
    end
    if (high_phase_count !== 4'd9) begin
      $error("Expected 9 high phases, got %0d", high_phase_count);
      message = message + 1;
    end
    if (!final_phase_checked) begin
      $error("Final SCL high phase was not checked");
      message = message + 1;
    end
    ninth_clock_check = 4'd0;
    high_start_time_done = 0;
    low_start_time_done = 0;
    timing_check_active = 0;
    final_phase_checked = 0;
    cmd_valid=0;
    bit_index=0;
    mpu_read_done=0;
    tx_data=0;
    mpu_reconstructed_byte=0;
    mpu_sda_drive_low=0;
    read_ack=0;
  end
  @(negedge clk);
    reset = 0;
    cmd_valid=1;
  wait(cmd_valid && cmd_ready)begin
    cmd_kind=START;
  end
  wait(busy)begin
    cmd_valid=0;
  end
  @(posedge done or posedge error)begin
    #1;
   if(busy)begin
    $error("Mismatch: expected %0d, received %0d",
            0,
            busy
    );
    message=message+1;
   end
   if(!cmd_ready)begin
    $error("Mismatch: expected %0d, received %0d",
            1,
            cmd_ready
    );
    message=message+1;
   end
    if(error)begin
      $error("Mismatch: expected %0d, received %0d",
            0,
            error
    );
    message=message+1;
    end
    if(!mpu_active)begin
      $error("Mismatch: expected %0d, received %0d",
            1,
            mpu_active
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
    if(error_timeout)begin
      $error("Mismatch: expected %0d, received %0d",
            0,
            error_timeout
    );
    message=message+1;
    end
    cmd_valid=0;
    mpu_sda_drive_low=0;
  end
  @(negedge clk)begin
    cmd_valid=1;
  // Even LSB proves the MPU releases SDA before the master's read NACK;
  // otherwise a data-bit-0 low could falsely satisfy the observation.
  random_byte = $urandom(seed) & 8'hFE;
  end
  wait(cmd_ready && cmd_valid)begin
    cmd_kind=READ_BYTE;
     mpu_reconstructed_byte=random_byte;
     bit_index=6;
     mpu_nack_next=0;
     read_ack=0;
     i2c_nack_next=1'b1;
     ack_phase_observed=1'b0;
  end
  wait(busy)begin
    cmd_valid=0;
     mpu_sda_drive_low=~mpu_reconstructed_byte[7];
  end
  @(posedge done or posedge error)begin
    #1;
   if(busy)begin
    $error("Mismatch: expected %0d, received %0d",
            0,
            busy
    );
    message=message+1;
   end
   if(!cmd_ready)begin
    $error("Mismatch: expected %0d, received %0d",
            1,
            cmd_ready
    );
    message=message+1;
   end
    if(error)begin
      $error("Mismatch: expected %0d, received %0d",
            0,
            error
    );
    message=message+1;
    end
    if(!mpu_active)begin
      $error("Mismatch: expected %0d, received %0d",
            0,
            mpu_active
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
    if(error_timeout)begin
      $error("Mismatch: expected %0d, received %0d",
            0,
            error_timeout
    ); 
    message=message+1;
    end
    if(rx_data !== mpu_reconstructed_byte)begin
      $error("Mismatch: expected %0d, received %0d",
            rx_data,
            mpu_reconstructed_byte
    ); 
    message=message+1;
    end
    if (i2c_nack_next !== 1'b0) begin
      $error("Expected the BFM to observe master NACK, got %b",
             i2c_nack_next);
      message = message + 1;
    end
    if (!ack_phase_observed) begin
      $error("BFM did not observe the ninth ACK/NACK clock");
      message = message + 1;
    end
    cmd_valid=0;
    bit_index=0;
    mpu_read_done=0;
    tx_data=0;
    mpu_reconstructed_byte=0;
    mpu_sda_drive_low=0;
    read_ack=0;
    ack_phase_observed=0;
  end
  @(negedge clk);
    reset = 0;
    cmd_valid=1;
  wait(cmd_valid && cmd_ready)begin
    cmd_kind=START;
  end
  wait(busy)begin
    cmd_valid=0;
  end
  @(posedge done or posedge error)begin
    #1;
   if(busy)begin
    $error("Mismatch: expected %0d, received %0d",
            0,
            busy
    );
    message=message+1;
   end
   if(!cmd_ready)begin
    $error("Mismatch: expected %0d, received %0d",
            1,
            cmd_ready
    );
    message=message+1;
   end
    if(error)begin
      $error("Mismatch: expected %0d, received %0d",
            0,
            error
    );
    message=message+1;
    end
    if(!mpu_active)begin
      $error("Mismatch: expected %0d, received %0d",
            1,
            mpu_active
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
    if(error_timeout)begin
      $error("Mismatch: expected %0d, received %0d",
            0,
            error_timeout
    );
    message=message+1;
    end
    cmd_valid=0;
    mpu_sda_drive_low=0;
  end
  @(negedge clk)begin
    cmd_valid=1;
    random_byte = $urandom(seed);
  end
  wait(cmd_ready && cmd_valid)begin
    cmd_kind=READ_BYTE;
     mpu_reconstructed_byte=random_byte;
     bit_index=6;
     mpu_nack_next=0;
     read_ack=0;
  end
  wait(busy)begin
    cmd_valid=0;
     mpu_sda_drive_low=~mpu_reconstructed_byte[7];
  end
  @(posedge done or posedge error)begin
    #1;
   if(busy)begin
    $error("Mismatch: expected %0d, received %0d",
            0,
            busy
    );
    message=message+1;
   end
   if(!cmd_ready)begin
    $error("Mismatch: expected %0d, received %0d",
            1,
            cmd_ready
    );
    message=message+1;
   end
    if(error)begin
      $error("Mismatch: expected %0d, received %0d",
            0,
            error
    );
    message=message+1;
    end
    if(!mpu_active)begin
      $error("Mismatch: expected %0d, received %0d",
            0,
            mpu_active
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
    if(error_timeout)begin
      $error("Mismatch: expected %0d, received %0d",
            0,
            error_timeout
    ); 
    message=message+1;
    end
    if(rx_data !== mpu_reconstructed_byte)begin
      $error("Mismatch: expected %0d, received %0d",
            rx_data,
            mpu_reconstructed_byte
    ); 
    message=message+1;
    end
    cmd_valid=0;
    bit_index=0;
    mpu_read_done=0;
    tx_data=0;
    mpu_reconstructed_byte=0;
    mpu_sda_drive_low=0;
    read_ack=0;
  end
  @(negedge clk);
    reset = 0;
    cmd_valid=1;
  wait(cmd_valid && cmd_ready)begin
    cmd_kind=START;
  end
  wait(busy)begin
    cmd_valid=0;
  end
  @(posedge done or posedge error)begin
    #1;
   if(busy)begin
    $error("Mismatch: expected %0d, received %0d",
            0,
            busy
    );
    message=message+1;
   end
   if(!cmd_ready)begin
    $error("Mismatch: expected %0d, received %0d",
            1,
            cmd_ready
    );
    message=message+1;
   end
    if(error)begin
      $error("Mismatch: expected %0d, received %0d",
            0,
            error
    );
    message=message+1;
    end
    if(!mpu_active)begin
      $error("Mismatch: expected %0d, received %0d",
            1,
            mpu_active
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
    if(error_timeout)begin
      $error("Mismatch: expected %0d, received %0d",
            0,
            error_timeout
    );
    message=message+1;
    end
    cmd_valid=0;
    mpu_sda_drive_low=0;
  end
  @(negedge clk)begin
    cmd_valid=1;
    random_byte = $urandom(seed);
  end
  wait(cmd_ready && cmd_valid)begin
    cmd_kind=READ_BYTE;
     mpu_reconstructed_byte=random_byte;
     bit_index=6;
     mpu_nack_next=0;
     read_ack=0;
  end
  wait(busy)begin
    cmd_valid=0;
     mpu_sda_drive_low=~mpu_reconstructed_byte[7];
  end
  @(posedge done or posedge error)begin
    #1;
   if(busy)begin
    $error("Mismatch: expected %0d, received %0d",
            0,
            busy
    );
    message=message+1;
   end
   if(!cmd_ready)begin
    $error("Mismatch: expected %0d, received %0d",
            1,
            cmd_ready
    );
    message=message+1;
   end
    if(error)begin
      $error("Mismatch: expected %0d, received %0d",
            0,
            error
    );
    message=message+1;
    end
    if(!mpu_active)begin
      $error("Mismatch: expected %0d, received %0d",
            0,
            mpu_active
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
    if(error_timeout)begin
      $error("Mismatch: expected %0d, received %0d",
            0,
            error_timeout
    ); 
    message=message+1;
    end
    if(rx_data !== mpu_reconstructed_byte)begin
      $error("Mismatch: expected %0d, received %0d",
            rx_data,
            mpu_reconstructed_byte
    ); 
    message=message+1;
    end
    cmd_valid=0;
    bit_index=0;
    mpu_read_done=0;
    tx_data=0;
    mpu_reconstructed_byte=0;
    mpu_sda_drive_low=0;
    read_ack=0;
  end
  @(negedge clk);
    reset = 0;
    cmd_valid=1;
  wait(cmd_valid && cmd_ready)begin
    cmd_kind=START;
  end
  wait(busy)begin
    cmd_valid=0;
  end
  @(posedge done or posedge error)begin
    #1;
   if(busy)begin
    $error("Mismatch: expected %0d, received %0d",
            0,
            busy
    );
    message=message+1;
   end
   if(!cmd_ready)begin
    $error("Mismatch: expected %0d, received %0d",
            1,
            cmd_ready
    );
    message=message+1;
   end
    if(error)begin
      $error("Mismatch: expected %0d, received %0d",
            0,
            error
    );
    message=message+1;
    end
    if(!mpu_active)begin
      $error("Mismatch: expected %0d, received %0d",
            1,
            mpu_active
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
    if(error_timeout)begin
      $error("Mismatch: expected %0d, received %0d",
            0,
            error_timeout
    );
    message=message+1;
    end
    cmd_valid=0;
    mpu_sda_drive_low=0;
  end
  @(negedge clk)begin
    cmd_valid=1;
    random_byte = $urandom(seed);
  end
  wait(cmd_ready && cmd_valid)begin
    cmd_kind=READ_BYTE;
     mpu_reconstructed_byte=random_byte;
     bit_index=6;
     mpu_nack_next=0;
     read_ack=0;
  end
  wait(busy)begin
    cmd_valid=0;
     mpu_sda_drive_low=~mpu_reconstructed_byte[7];
  end
  @(posedge done or posedge error)begin
    #1;
   if(busy)begin
    $error("Mismatch: expected %0d, received %0d",
            0,
            busy
    );
    message=message+1;
   end
   if(!cmd_ready)begin
    $error("Mismatch: expected %0d, received %0d",
            1,
            cmd_ready
    );
    message=message+1;
   end
    if(error)begin
      $error("Mismatch: expected %0d, received %0d",
            0,
            error
    );
    message=message+1;
    end
    if(!mpu_active)begin
      $error("Mismatch: expected %0d, received %0d",
            0,
            mpu_active
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
    if(error_timeout)begin
      $error("Mismatch: expected %0d, received %0d",
            0,
            error_timeout
    ); 
    message=message+1;
    end
    if(rx_data !== mpu_reconstructed_byte)begin
      $error("Mismatch: expected %0d, received %0d",
            rx_data,
            mpu_reconstructed_byte
    ); 
    message=message+1;
    end
    cmd_valid=0;
    bit_index=0;
    mpu_read_done=0;
    tx_data=0;
    mpu_reconstructed_byte=0;
    mpu_sda_drive_low=0;
    read_ack=0;
  end
  @(negedge clk);
    reset = 0;
    cmd_valid=1;
  wait(cmd_valid && cmd_ready)begin
    cmd_kind=START;
  end
  wait(busy)begin
    cmd_valid=0;
  end
  @(posedge done or posedge error)begin
    #1;
   if(busy)begin
    $error("Mismatch: expected %0d, received %0d",
            0,
            busy
    );
    message=message+1;
   end
   if(!cmd_ready)begin
    $error("Mismatch: expected %0d, received %0d",
            1,
            cmd_ready
    );
    message=message+1;
   end
    if(error)begin
      $error("Mismatch: expected %0d, received %0d",
            0,
            error
    );
    message=message+1;
    end
    if(!mpu_active)begin
      $error("Mismatch: expected %0d, received %0d",
            1,
            mpu_active
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
    if(error_timeout)begin
      $error("Mismatch: expected %0d, received %0d",
            0,
            error_timeout
    );
    message=message+1;
    end
    cmd_valid=0;
    mpu_sda_drive_low=0;
  end
  @(negedge clk)begin
    cmd_valid=1;
    random_byte = $urandom(seed);
  end
  wait(cmd_ready && cmd_valid)begin
    cmd_kind=READ_BYTE;
     mpu_reconstructed_byte=random_byte;
     bit_index=6;
     mpu_nack_next=0;
     read_ack=1;
     timing_check_active=1;
     final_phase_checked=0;
     low_phase_count=4'd0;
     high_phase_count=4'd0;
  end
  wait(busy)begin
    cmd_valid=0;
     mpu_sda_drive_low=~mpu_reconstructed_byte[7];
  end
  @(posedge done or posedge error)begin
    #1;
   if(busy)begin
    $error("Mismatch: expected %0d, received %0d",
            0,
            busy
    );
    message=message+1;
   end
   if(!cmd_ready)begin
    $error("Mismatch: expected %0d, received %0d",
            1,
            cmd_ready
    );
    message=message+1;
   end
    if(error)begin
      $error("Mismatch: expected %0d, received %0d",
            0,
            error
    );
    message=message+1;
    end
    if(!mpu_active)begin
      $error("Mismatch: expected %0d, received %0d",
            0,
            mpu_active
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
    if(error_timeout)begin
      $error("Mismatch: expected %0d, received %0d",
            0,
            error_timeout
    ); 
    message=message+1;
    end
    if(rx_data !== mpu_reconstructed_byte)begin
      $error("Mismatch: expected %0d, received %0d",
            rx_data,
            mpu_reconstructed_byte
    ); 
    message=message+1;
    end
    if (ninth_clock_check !== 4'd9) begin
      $error("Expected 9 SCL clocks, got %0d", ninth_clock_check);
      message = message + 1;
    end
    if (low_phase_count !== 4'd8) begin
      $error("Expected 8 complete low phases, got %0d", low_phase_count);
      message = message + 1;
    end
    if (high_phase_count !== 4'd9) begin
      $error("Expected 9 high phases, got %0d", high_phase_count);
      message = message + 1;
    end
    if (!final_phase_checked) begin
      $error("Final SCL high phase was not checked");
      message = message + 1;
    end
    ninth_clock_check = 4'd0;
    high_start_time_done = 0;
    low_start_time_done = 0;
    timing_check_active = 0;
    final_phase_checked = 0;
    cmd_valid=0;
    bit_index=0;
    mpu_read_done=0;
    tx_data=0;
    mpu_reconstructed_byte=0;
    mpu_sda_drive_low=0;
    read_ack=0;
  end
  @(negedge clk);
    reset = 0;
    cmd_valid=1;
  wait(cmd_valid && cmd_ready)begin
    cmd_kind=START;
  end
  wait(busy)begin
    cmd_valid=0;
  end
  @(posedge done or posedge error)begin
    #1;
   if(busy)begin
    $error("Mismatch: expected %0d, received %0d",
            0,
            busy
    );
    message=message+1;
   end
   if(!cmd_ready)begin
    $error("Mismatch: expected %0d, received %0d",
            1,
            cmd_ready
    );
    message=message+1;
   end
    if(error)begin
      $error("Mismatch: expected %0d, received %0d",
            0,
            error
    );
    message=message+1;
    end
    if(!mpu_active)begin
      $error("Mismatch: expected %0d, received %0d",
            1,
            mpu_active
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
    if(error_timeout)begin
      $error("Mismatch: expected %0d, received %0d",
            0,
            error_timeout
    );
    message=message+1;
    end
    cmd_valid=0;
    mpu_sda_drive_low=0;
  end
  @(negedge clk)begin
    cmd_valid=1;
    random_byte = $urandom(seed);
  end
  wait(cmd_ready && cmd_valid)begin
    cmd_kind=READ_BYTE;
     mpu_reconstructed_byte=random_byte;
     bit_index=6;
     mpu_nack_next=0;
     read_ack=1;
  end
  wait(busy)begin
    cmd_valid=0;
     mpu_sda_drive_low=~mpu_reconstructed_byte[7];
  end
  @(posedge done or posedge error)begin
    #1;
   if(busy)begin
    $error("Mismatch: expected %0d, received %0d",
            0,
            busy
    );
    message=message+1;
   end
   if(!cmd_ready)begin
    $error("Mismatch: expected %0d, received %0d",
            1,
            cmd_ready
    );
    message=message+1;
   end
    if(error)begin
      $error("Mismatch: expected %0d, received %0d",
            0,
            error
    );
    message=message+1;
    end
    if(!mpu_active)begin
      $error("Mismatch: expected %0d, received %0d",
            0,
            mpu_active
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
    if(error_timeout)begin
      $error("Mismatch: expected %0d, received %0d",
            0,
            error_timeout
    ); 
    message=message+1;
    end
    if(rx_data !== mpu_reconstructed_byte)begin
      $error("Mismatch: expected %0d, received %0d",
            rx_data,
            mpu_reconstructed_byte
    ); 
    message=message+1;
    end
    cmd_valid=0;
    bit_index=0;
    mpu_read_done=0;
    tx_data=0;
    mpu_reconstructed_byte=0;
    mpu_sda_drive_low=0;
    read_ack=0;
  end
  @(negedge clk);
    reset = 0;
    cmd_valid=1;
  wait(cmd_valid && cmd_ready)begin
    cmd_kind=START;
  end
  wait(busy)begin
    cmd_valid=0;
  end
  @(posedge done or posedge error)begin
    #1;
   if(busy)begin
    $error("Mismatch: expected %0d, received %0d",
            0,
            busy
    );
    message=message+1;
   end
   if(!cmd_ready)begin
    $error("Mismatch: expected %0d, received %0d",
            1,
            cmd_ready
    );
    message=message+1;
   end
    if(error)begin
      $error("Mismatch: expected %0d, received %0d",
            0,
            error
    );
    message=message+1;
    end
    if(!mpu_active)begin
      $error("Mismatch: expected %0d, received %0d",
            1,
            mpu_active
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
    if(error_timeout)begin
      $error("Mismatch: expected %0d, received %0d",
            0,
            error_timeout
    );
    message=message+1;
    end
    cmd_valid=0;
    mpu_sda_drive_low=0;
  end
  @(negedge clk)begin
    cmd_valid=1;
    random_byte = $urandom(seed);
  end
  wait(cmd_ready && cmd_valid)begin
    cmd_kind=READ_BYTE;
     mpu_reconstructed_byte=random_byte;
     bit_index=6;
     mpu_nack_next=0;
     read_ack=1;
  end
  wait(busy)begin
    cmd_valid=0;
     mpu_sda_drive_low=~mpu_reconstructed_byte[7];
  end
  @(posedge done or posedge error)begin
    #1;
   if(busy)begin
    $error("Mismatch: expected %0d, received %0d",
            0,
            busy
    );
    message=message+1;
   end
   if(!cmd_ready)begin
    $error("Mismatch: expected %0d, received %0d",
            1,
            cmd_ready
    );
    message=message+1;
   end
    if(error)begin
      $error("Mismatch: expected %0d, received %0d",
            0,
            error
    );
    message=message+1;
    end
    if(!mpu_active)begin
      $error("Mismatch: expected %0d, received %0d",
            0,
            mpu_active
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
    if(error_timeout)begin
      $error("Mismatch: expected %0d, received %0d",
            0,
            error_timeout
    ); 
    message=message+1;
    end
    if(rx_data !== mpu_reconstructed_byte)begin
      $error("Mismatch: expected %0d, received %0d",
            rx_data,
            mpu_reconstructed_byte
    ); 
    message=message+1;
    end
    cmd_valid=0;
    bit_index=0;
    mpu_read_done=0;
    tx_data=0;
    mpu_reconstructed_byte=0;
    mpu_sda_drive_low=0;
    read_ack=0;
  end
  @(negedge clk);
    reset = 0;
    cmd_valid=1;
  wait(cmd_valid && cmd_ready)begin
    cmd_kind=START;
  end
  wait(busy)begin
    cmd_valid=0;
  end
  @(posedge done or posedge error)begin
    #1;
   if(busy)begin
    $error("Mismatch: expected %0d, received %0d",
            0,
            busy
    );
    message=message+1;
   end
   if(!cmd_ready)begin
    $error("Mismatch: expected %0d, received %0d",
            1,
            cmd_ready
    );
    message=message+1;
   end
    if(error)begin
      $error("Mismatch: expected %0d, received %0d",
            0,
            error
    );
    message=message+1;
    end
    if(!mpu_active)begin
      $error("Mismatch: expected %0d, received %0d",
            1,
            mpu_active
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
    if(error_timeout)begin
      $error("Mismatch: expected %0d, received %0d",
            0,
            error_timeout
    );
    message=message+1;
    end
    cmd_valid=0;
    mpu_sda_drive_low=0;
  end
  @(negedge clk)begin
    cmd_valid=1;
    random_byte = $urandom(seed);
  end
  wait(cmd_ready && cmd_valid)begin
    cmd_kind=READ_BYTE;
     mpu_reconstructed_byte=random_byte;
     bit_index=6;
     mpu_nack_next=0;
     read_ack=1;
  end
  wait(busy)begin
    cmd_valid=0;
     mpu_sda_drive_low=~mpu_reconstructed_byte[7];
  end
  @(posedge done or posedge error)begin
    #1;
   if(busy)begin
    $error("Mismatch: expected %0d, received %0d",
            0,
            busy
    );
    message=message+1;
   end
   if(!cmd_ready)begin
    $error("Mismatch: expected %0d, received %0d",
            1,
            cmd_ready
    );
    message=message+1;
   end
    if(error)begin
      $error("Mismatch: expected %0d, received %0d",
            0,
            error
    );
    message=message+1;
    end
    if(!mpu_active)begin
      $error("Mismatch: expected %0d, received %0d",
            0,
            mpu_active
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
    if(error_timeout)begin
      $error("Mismatch: expected %0d, received %0d",
            0,
            error_timeout
    ); 
    message=message+1;
    end
    if(rx_data !== mpu_reconstructed_byte)begin
      $error("Mismatch: expected %0d, received %0d",
            rx_data,
            mpu_reconstructed_byte
    ); 
    message=message+1;
    end
    cmd_valid=0;
    bit_index=0;
    mpu_read_done=0;
    tx_data=0;
    mpu_reconstructed_byte=0;
    mpu_sda_drive_low=0;
    read_ack=0;
  end
  @(negedge clk);
    reset = 0;
    cmd_valid=1;
  wait(cmd_valid && cmd_ready)begin
    cmd_kind=START;
  end
  wait(busy)begin
    cmd_valid=0;
  end
  @(posedge done or posedge error)begin
    #1;
   if(busy)begin
    $error("Mismatch: expected %0d, received %0d",
            0,
            busy
    );
    message=message+1;
   end
   if(!cmd_ready)begin
    $error("Mismatch: expected %0d, received %0d",
            1,
            cmd_ready
    );
    message=message+1;
   end
    if(error)begin
      $error("Mismatch: expected %0d, received %0d",
            0,
            error
    );
    message=message+1;
    end
    if(!mpu_active)begin
      $error("Mismatch: expected %0d, received %0d",
            1,
            mpu_active
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
    if(error_timeout)begin
      $error("Mismatch: expected %0d, received %0d",
            0,
            error_timeout
    );
    message=message+1;
    end
    cmd_valid=0;
    mpu_sda_drive_low=0;
  end
  @(negedge clk)begin
    cmd_valid=1;
    random_byte = $urandom(seed);
  end
  wait(cmd_ready && cmd_valid)begin
    cmd_kind=READ_BYTE;
     mpu_reconstructed_byte=random_byte;
     bit_index=6;
     mpu_nack_next=0;
     read_ack=1;
  end
  wait(busy)begin
    cmd_valid=0;
     mpu_sda_drive_low=~mpu_reconstructed_byte[7];
  end
  @(posedge done or posedge error)begin
    #1;
   if(busy)begin
    $error("Mismatch: expected %0d, received %0d",
            0,
            busy
    );
    message=message+1;
   end
   if(!cmd_ready)begin
    $error("Mismatch: expected %0d, received %0d",
            1,
            cmd_ready
    );
    message=message+1;
   end
    if(error)begin
      $error("Mismatch: expected %0d, received %0d",
            0,
            error
    );
    message=message+1;
    end
    if(!mpu_active)begin
      $error("Mismatch: expected %0d, received %0d",
            0,
            mpu_active
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
    if(error_timeout)begin
      $error("Mismatch: expected %0d, received %0d",
            0,
            error_timeout
    ); 
    message=message+1;
    end
    if(rx_data !== mpu_reconstructed_byte)begin
      $error("Mismatch: expected %0d, received %0d",
            rx_data,
            mpu_reconstructed_byte
    ); 
    message=message+1;
    end
    cmd_valid=0;
    bit_index=0;
    mpu_read_done=0;
    tx_data=0;
    mpu_reconstructed_byte=0;
    mpu_sda_drive_low=0;
    read_ack=0;
  end
  @(negedge clk);
    reset = 0;
    cmd_valid=1;
  wait(cmd_valid && cmd_ready)begin
    cmd_kind=START;
  end
  wait(busy)begin
    cmd_valid=0;
  end
  @(posedge done or posedge error)begin
    #1;
   if(busy)begin
    $error("Mismatch: expected %0d, received %0d",
            0,
            busy
    );
    message=message+1;
   end
   if(!cmd_ready)begin
    $error("Mismatch: expected %0d, received %0d",
            1,
            cmd_ready
    );
    message=message+1;
   end
    if(error)begin
      $error("Mismatch: expected %0d, received %0d",
            0,
            error
    );
    message=message+1;
    end
    if(!mpu_active)begin
      $error("Mismatch: expected %0d, received %0d",
            1,
            mpu_active
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
    if(error_timeout)begin
      $error("Mismatch: expected %0d, received %0d",
            0,
            error_timeout
    );
    message=message+1;
    end
    cmd_valid=0;
  end
  @(negedge clk)begin
    cmd_valid=1;
  end
  wait(cmd_ready && cmd_valid)begin
    cmd_kind=WRITE_BYTE;
     tx_data=8'h55;
     bit_index=7;
     mpu_strech_bit=4;
     mpu_nack_next=1;
  end
  wait(busy)begin
    cmd_valid=0;
    time_begin<=$time;
  end
  @(posedge done or posedge error)begin
    #1;
    time_end=$time;
   if(busy)begin
    $error("Mismatch: expected %0d, received %0d",
            0,
            busy
    );
    message=message+1;
   end
   if(!cmd_ready)begin
    $error("Mismatch: expected %0d, received %0d",
            1,
            cmd_ready
    );
    message=message+1;
   end
    if(!error)begin
      $error("Mismatch: expected %0d, received %0d",
            1,
            error
    );
    message=message+1;
    end
    if(!mpu_active)begin
      $error("Mismatch: expected %0d, received %0d",
            1,
            mpu_active
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
    if (scl_drive_low) begin
      $error("Expected SCL released after write NACK");
      message = message + 1;
    end
    if(error_timeout)begin
      $error("Mismatch: expected %0d, received %0d",
            0,
            error_timeout
    ); 
    message=message+1;
    end
    if(tx_data!==mpu_reconstructed_byte)begin
      $error("Mismatch: expected %0d, received %0d",
            tx_data,
            mpu_reconstructed_byte
    ); 
    message=message+1;
    end
    stretched_write_duration = time_end - time_begin;
    if (stretched_write_duration + TIMING_TOLERANCE <
        MIN_STRETCHED_WRITE) begin
      $error("Stretched write too short: expected at least %0t, got %0t",
             MIN_STRETCHED_WRITE,
             stretched_write_duration);
      message = message + 1;
    end
      $display("Measured stretched WRITE duration = %0t",
         time_end - time_begin);
    cmd_valid=0;
    bit_index=0;
    mpu_read_done=0;
    tx_data=0;
    mpu_reconstructed_byte=0;
    mpu_sda_drive_low=0;
    mpu_strech_bit=10;
    mpu_nack_next=0;
  end
@(negedge clk);
    reset = 0;
    cmd_valid=1;
  wait(cmd_valid && cmd_ready)begin
    cmd_kind=START;
  end
  wait(busy)begin
    cmd_valid=0;
  end
  @(posedge done or posedge error)begin
    #1;
   if(busy)begin
    $error("Mismatch: expected %0d, received %0d",
            0,
            busy
    );
    message=message+1;
   end
   if(!cmd_ready)begin
    $error("Mismatch: expected %0d, received %0d",
            1,
            cmd_ready
    );
    message=message+1;
   end
    if(error)begin
      $error("Mismatch: expected %0d, received %0d",
            0,
            error
    );
    message=message+1;
    end
    if(!mpu_active)begin
      $error("Mismatch: expected %0d, received %0d",
            1,
            mpu_active
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
    if(error_timeout)begin
      $error("Mismatch: expected %0d, received %0d",
            0,
            error_timeout
    );
    message=message+1;
    end
    cmd_valid=0;
    mpu_sda_drive_low=0;
  end
  @(negedge clk)begin
    cmd_valid=1;
  end
  wait(cmd_ready && cmd_valid)begin
    cmd_kind=READ_BYTE;
     mpu_reconstructed_byte=8'hAA;
     bit_index=6;
     mpu_strech_bit=3;
  end
  wait(busy)begin
    cmd_valid=0;
     mpu_sda_drive_low=~mpu_reconstructed_byte[7];
  end
  @(posedge done or posedge error)begin
    #1;
   if(busy)begin
    $error("Mismatch: expected %0d, received %0d",
            0,
            busy
    );
    message=message+1;
   end
   if(!cmd_ready)begin
    $error("Mismatch: expected %0d, received %0d",
            1,
            cmd_ready
    );
    message=message+1;
   end
    if(error)begin
      $error("Mismatch: expected %0d, received %0d",
            0,
            error
    );
    message=message+1;
    end
    if(!mpu_active)begin
      $error("Mismatch: expected %0d, received %0d",
            0,
            mpu_active
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
    if(error_timeout)begin
      $error("Mismatch: expected %0d, received %0d",
            0,
            error_timeout
    ); 
    message=message+1;
    end
    if(rx_data!==mpu_reconstructed_byte)begin
      $error("Mismatch: expected %0d, received %0d",
            rx_data,
            mpu_reconstructed_byte
    ); 
    message=message+1;
    end
    cmd_valid=0;
    bit_index=0;
    mpu_read_done=0;
    tx_data=0;
    mpu_strech_bit=10;
    mpu_reconstructed_byte=0;
    read_ack=0;
    mpu_scl_drive_low=0;
    mpu_sda_drive_low=0;
  end
   @(negedge clk);
    reset = 0;
    cmd_valid=1;
  wait(cmd_valid && cmd_ready)begin
    cmd_kind=START;
  end
  wait(busy)begin
    cmd_valid=0;
  end
  @(posedge done or posedge error)begin
    #1;
   if(busy)begin
    $error("Mismatch: expected %0d, received %0d",
            0,
            busy
    );
    message=message+1;
   end
   if(!cmd_ready)begin
    $error("Mismatch: expected %0d, received %0d",
            1,
            cmd_ready
    );
    message=message+1;
   end
    if(error)begin
      $error("Mismatch: expected %0d, received %0d",
            0,
            error
    );
    message=message+1;
    end
    if(!mpu_active)begin
      $error("Mismatch: expected %0d, received %0d",
            1,
            mpu_active
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
    if(error_timeout)begin
      $error("Mismatch: expected %0d, received %0d",
            0,
            error_timeout
    );
    message=message+1;
    end
    cmd_valid=0;
  end
  @(negedge clk)begin
    cmd_valid=1;
  end
  wait(cmd_ready && cmd_valid)begin
    cmd_kind=WRITE_BYTE;
     tx_data=8'h01;
     bit_index=7;
  end
  wait(busy)begin
    cmd_valid=0;
    reset=0;
  end
  @(posedge done or posedge error)begin
    #1;
   if(busy)begin
    $error("Mismatch: expected %0d, received %0d",
            0,
            busy
    );
    message=message+1;
   end
   if(!cmd_ready)begin
    $error("Mismatch: expected %0d, received %0d",
            1,
            cmd_ready
    );
    message=message+1;
   end
    if(error)begin
      $error("Mismatch: expected %0d, received %0d",
            0,
            error
    );
    message=message+1;
    end
    if(!mpu_active)begin
      $error("Mismatch: expected %0d, received %0d",
            1,
            mpu_active
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
    if(error_timeout)begin
      $error("Mismatch: expected %0d, received %0d",
            0,
            error_timeout
    ); 
    message=message+1;
    end
    if(tx_data!==mpu_reconstructed_byte)begin
      $error("Mismatch: expected %0d, received %0d",
            tx_data,
            mpu_reconstructed_byte
    ); 
    message=message+1;
    end
    cmd_valid=0;
    bit_index=0;
    mpu_read_done=0;
    tx_data=0;
    mpu_reconstructed_byte=0;
    mpu_sda_drive_low=0;
  end
   @(negedge clk);
    reset = 0;
    cmd_valid=1;
  wait(cmd_valid && cmd_ready)begin
    cmd_kind=START;
  end
  wait(busy)begin
    cmd_valid=0;
  end
  @(posedge done or posedge error)begin
    #1;
   if(busy)begin
    $error("Mismatch: expected %0d, received %0d",
            0,
            busy
    );
    message=message+1;
   end
   if(!cmd_ready)begin
    $error("Mismatch: expected %0d, received %0d",
            1,
            cmd_ready
    );
    message=message+1;
   end
    if(error)begin
      $error("Mismatch: expected %0d, received %0d",
            0,
            error
    );
    message=message+1;
    end
    if(!mpu_active)begin
      $error("Mismatch: expected %0d, received %0d",
            1,
            mpu_active
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
    if(error_timeout)begin
      $error("Mismatch: expected %0d, received %0d",
            0,
            error_timeout
    );
    message=message+1;
    end
    cmd_valid=0;
  end
  @(negedge clk)begin
    cmd_valid=1;
    mpu_reconstructed_byte=0;
  end
  wait(cmd_ready && cmd_valid)begin
    cmd_kind=WRITE_BYTE;
     tx_data=8'h80;
     bit_index=7;
  end
  wait(busy)begin
    cmd_valid=0;
    reset=1;
  end
  @(posedge cmd_ready)begin
   if(busy)begin
    $error("Mismatch: expected %0d, received %0d",
            0,
            busy
    );
    message=message+1;
   end
   if(!cmd_ready)begin
    $error("Mismatch: expected %0d, received %0d",
            1,
            cmd_ready
    );
    message=message+1;
   end
    if(error)begin
      $error("Mismatch: expected %0d, received %0d",
            0,
            error
    );
    message=message+1;
    end
    if(!mpu_active)begin
      $error("Mismatch: expected %0d, received %0d",
            1,
            mpu_active
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
    if(error_timeout)begin
      $error("Mismatch: expected %0d, received %0d",
            0,
            error_timeout
    ); 
    message=message+1;
    end
    cmd_valid=0;
    bit_index=0;
    mpu_read_done=0;
    tx_data=0;
    mpu_reconstructed_byte=0;
    mpu_sda_drive_low=0;
    reset=0;
  end
   @(negedge clk);
    reset = 0;
    cmd_valid=1;
  wait(cmd_valid && cmd_ready)begin
    cmd_kind=START;
  end
  wait(busy)begin
    cmd_valid=0;
  end
  @(posedge done or posedge error)begin
    #1;
   if(busy)begin
    $error("Mismatch: expected %0d, received %0d",
            0,
            busy
    );
    message=message+1;
   end
   if(!cmd_ready)begin
    $error("Mismatch: expected %0d, received %0d",
            1,
            cmd_ready
    );
    message=message+1;
   end
    if(error)begin
      $error("Mismatch: expected %0d, received %0d",
            0,
            error
    );
    message=message+1;
    end
    if(!mpu_active)begin
      $error("Mismatch: expected %0d, received %0d",
            1,
            mpu_active
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
    if(error_timeout)begin
      $error("Mismatch: expected %0d, received %0d",
            0,
            error_timeout
    );
    message=message+1;
    end
    cmd_valid=0;
  end
  @(negedge clk)begin
    cmd_valid=1;
  end
  wait(cmd_ready && cmd_valid)begin
    cmd_kind=WRITE_BYTE;
     tx_data=8'h0F;
     bit_index=7;
     mpu_strech_bit=10;
  end
  wait(busy)begin
    cmd_valid=0;
  end
  @(posedge done or posedge error)begin
    #1;
   if(busy)begin
    $error("Mismatch: expected %0d, received %0d",
            0,
            busy
    );
    message=message+1;
   end
   if(!cmd_ready)begin
    $error("Mismatch: expected %0d, received %0d",
            1,
            cmd_ready
    );
    message=message+1;
   end
    if(error)begin
      $error("Mismatch: expected %0d, received %0d",
            0,
            error
    );
    message=message+1;
    end
    if(!mpu_active)begin
      $error("Mismatch: expected %0d, received %0d",
            1,
            mpu_active
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
    if(error_timeout)begin
      $error("Mismatch: expected %0d, received %0d",
            0,
            error_timeout
    ); 
    message=message+1;
    end
    if(tx_data==mpu_reconstructed_byte)begin
      $error("Mismatch: expected %0d, received %0d",
            tx_data,
            mpu_reconstructed_byte
    ); 
    message=message+1;
    end
    cmd_valid=0;
    bit_index=0;
    mpu_read_done=0;
    tx_data=0;
    mpu_reconstructed_byte=0;
    mpu_sda_drive_low=0;
    mpu_scl_drive_low=0;
  end
   @(negedge clk)begin
    cmd_valid=1;
  end
  wait(cmd_ready && cmd_valid)begin
    cmd_kind=STOP;
  end
  wait(busy)begin
    cmd_valid=0;
  end
  @(posedge done or posedge error)begin
    #1;
   if(busy)begin
    $error("Mismatch: expected %0d, received %0d",
            0,
            busy
    );
    message=message+1;
   end
   if(!cmd_ready)begin
    $error("Mismatch: expected %0d, received %0d",
            1,
            cmd_ready
    );
    message=message+1;
   end
    if(error)begin
      $error("Mismatch: expected %0d, received %0d",
            0,
            error
    );
    message=message+1;
    end
    if(mpu_active)begin
      $error("Mismatch: expected %0d, received %0d",
            0,
            mpu_active
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
    if(error_timeout)begin
      $error("Mismatch: expected %0d, received %0d",
            0,
            error_timeout
    ); 
    message=message+1;
    end
    if(tx_data!==mpu_reconstructed_byte)begin
      $error("Mismatch: expected %0d, received %0d",
            tx_data,
            mpu_reconstructed_byte
    ); 
    message=message+1;
    end
    cmd_valid=0;
    bit_index=0;
    mpu_read_done=0;
    tx_data=0;
    mpu_reconstructed_byte=0;
    mpu_sda_drive_low=0;
    mpu_active=0;
  end
  @(negedge clk);
    reset = 0;
    cmd_valid=1;
  wait(cmd_valid && cmd_ready)begin
    cmd_kind=START;
  end
  wait(busy)begin
    cmd_valid=0;
  end
  @(posedge done or posedge error)begin
    #1;
   if(busy)begin
    $error("Mismatch: expected %0d, received %0d",
            0,
            busy
    );
    message=message+1;
   end
   if(!cmd_ready)begin
    $error("Mismatch: expected %0d, received %0d",
            1,
            cmd_ready
    );
    message=message+1;
   end
    if(error)begin
      $error("Mismatch: expected %0d, received %0d",
            0,
            error
    );
    message=message+1;
    end
    if(!mpu_active)begin
      $error("Mismatch: expected %0d, received %0d",
            1,
            mpu_active
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
    if(error_timeout)begin
      $error("Mismatch: expected %0d, received %0d",
            0,
            error_timeout
    );
    message=message+1;
    end
    cmd_valid=0;
  end
  @(negedge clk)begin
    cmd_valid=1;
  end
  wait(cmd_ready && cmd_valid)begin
    cmd_kind=WRITE_BYTE;
     tx_data=8'hF0;
     bit_index=7;
     mpu_strech_bit=10;
  end
  wait(busy)begin
    cmd_valid=0;
    mpu_scl_drive_low<=1;
  end
  @(posedge done or posedge error)begin
    #1;
   if(busy)begin
    $error("Mismatch: expected %0d, received %0d",
            0,
            busy
    );
    message=message+1;
   end
   if(!cmd_ready)begin
    $error("Mismatch: expected %0d, received %0d",
            1,
            cmd_ready
    );
    message=message+1;
   end
    if(!error)begin
      $error("Mismatch: expected %0d, received %0d",
            1,
            error
    );
    message=message+1;
    end
    if(!mpu_active)begin
      $error("Mismatch: expected %0d, received %0d",
            1,
            mpu_active
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
    if(!error_timeout)begin
      $error("Mismatch: expected %0d, received %0d",
            1,
            error_timeout
    ); 
    message=message+1;
    end
    if(tx_data==mpu_reconstructed_byte)begin
      $error("Mismatch: expected %0d, received %0d",
            tx_data,
            mpu_reconstructed_byte
    ); 
    message=message+1;
    end
    cmd_valid=0;
    bit_index=0;
    mpu_read_done=0;
    tx_data=0;
    mpu_reconstructed_byte=0;
    mpu_sda_drive_low=0;
    mpu_scl_drive_low=0;
    // Let the wired-AND SCL bus return high before issuing recovery STOP.
    #1;
  end
   @(negedge clk)begin
    cmd_valid=1;
  end
  wait(cmd_ready && cmd_valid)begin
    cmd_kind=STOP;
  end
  wait(busy)begin
    cmd_valid=0;
  end
  @(posedge done or posedge error)begin
    #1;
   if(busy)begin
    $error("Mismatch: expected %0d, received %0d",
            0,
            busy
    );
    message=message+1;
   end
   if(!cmd_ready)begin
    $error("Mismatch: expected %0d, received %0d",
            1,
            cmd_ready
    );
    message=message+1;
   end
    if(error)begin
      $error("Mismatch: expected %0d, received %0d",
            0,
            error
    );
    message=message+1;
    end
    if(mpu_active)begin
      $error("Mismatch: expected %0d, received %0d",
            0,
            mpu_active
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
    if(error_timeout)begin
      $error("Mismatch: expected %0d, received %0d",
            0,
            error_timeout
    );
    message=message+1;
    end
    cmd_valid=0;
    mpu_active=0;
  end
   @(negedge clk);
    reset = 0;
    cmd_valid=1;
  wait(cmd_valid && cmd_ready)begin
    cmd_kind=START;
  end
  wait(busy)begin
    cmd_valid=0;
  end
  @(posedge done or posedge error)begin
    #1;
   if(busy)begin
    $error("Mismatch: expected %0d, received %0d",
            0,
            busy
    );
    message=message+1;
   end
   if(!cmd_ready)begin
    $error("Mismatch: expected %0d, received %0d",
            1,
            cmd_ready
    );
    message=message+1;
   end
    if(error)begin
      $error("Mismatch: expected %0d, received %0d",
            0,
            error
    );
    message=message+1;
    end
    if(!mpu_active)begin
      $error("Mismatch: expected %0d, received %0d",
            1,
            mpu_active
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
    if(error_timeout)begin
      $error("Mismatch: expected %0d, received %0d",
            0,
            error_timeout
    );
    message=message+1;
    end
    cmd_valid=0;
  end
  @(negedge clk)begin
    cmd_valid=1;
  end
  wait(cmd_ready && cmd_valid)begin
    cmd_kind=READ_BYTE;
     mpu_reconstructed_byte=8'h3C;
     bit_index=6;
     mpu_nack_next=0;
     mpu_read_done=0;
     read_ack=1;
  end
  wait(busy)begin
    cmd_valid=0;
     mpu_sda_drive_low=~mpu_reconstructed_byte[7];
  end
  @(posedge done or posedge error)begin
    #1;
   if(busy)begin
    $error("Mismatch: expected %0d, received %0d",
            0,
            busy
    );
    message=message+1;
   end
   if(!cmd_ready)begin
    $error("Mismatch: expected %0d, received %0d",
            1,
            cmd_ready
    );
    message=message+1;
   end
    if(error)begin
      $error("Mismatch: expected %0d, received %0d",
            0,
            error
    );
    message=message+1;
    end
    if(!mpu_active)begin
      $error("Mismatch: expected %0d, received %0d",
            1,
            mpu_active
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
    if(error_timeout)begin
      $error("Mismatch: expected %0d, received %0d",
            0,
            error_timeout
    );
    message=message+1;
    end
    if(rx_data !== mpu_reconstructed_byte)begin
      $error("Mismatch: expected %0d, received %0d",
            rx_data,
            mpu_reconstructed_byte
    );
    message=message+1;
    end
    if(!i2c_nack_next)begin
      $error("Mismatch: expected %0d, received %0d",
            1,
            i2c_nack_next
    );
    message=message+1;
    end
    cmd_valid=0;
    bit_index=0;
    mpu_read_done=0;
    tx_data=0;
    read_ack=0;
    mpu_reconstructed_byte=0;
  end
   @(negedge clk)begin
    cmd_valid=1;
  end
  wait(cmd_ready && cmd_valid)begin
    cmd_kind=STOP;
  end
  wait(busy)begin
    cmd_valid=0;
  end
  @(posedge done or posedge error)begin
    #1;
   if(busy)begin
    $error("Mismatch: expected %0d, received %0d",
            0,
            busy
    );
    message=message+1;
   end
   if(!cmd_ready)begin
    $error("Mismatch: expected %0d, received %0d",
            1,
            cmd_ready
    );
    message=message+1;
   end
    if(error)begin
      $error("Mismatch: expected %0d, received %0d",
            0,
            error
    );
    message=message+1;
    end
    if(mpu_active)begin
      $error("Mismatch: expected %0d, received %0d",
            0,
            mpu_active
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
    if(error_timeout)begin
      $error("Mismatch: expected %0d, received %0d",
            0,
            error_timeout
    );
    message=message+1;
    end
    cmd_valid=0;
    mpu_active=0;
    mpu_scl_drive_low=0;
    mpu_sda_drive_low=0;
  end
   @(negedge clk);
    reset = 0;
    cmd_valid=1;
  wait(cmd_valid && cmd_ready)begin
    cmd_kind=START;
  end
  wait(busy)begin
    cmd_valid=0;
  end
  @(posedge done or posedge error)begin
    #1;
   if(busy)begin
    $error("Mismatch: expected %0d, received %0d",
            0,
            busy
    );
    message=message+1;
   end
   if(!cmd_ready)begin
    $error("Mismatch: expected %0d, received %0d",
            1,
            cmd_ready
    );
    message=message+1;
   end
    if(error)begin
      $error("Mismatch: expected %0d, received %0d",
            0,
            error
    );
    message=message+1;
    end
    if(!mpu_active)begin
      $error("Mismatch: expected %0d, received %0d",
            1,
            mpu_active
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
    if(error_timeout)begin
      $error("Mismatch: expected %0d, received %0d",
            0,
            error_timeout
    );
    message=message+1;
    end
    cmd_valid=0;
  end
  @(negedge clk)begin
    cmd_valid=1;
  end
  wait(cmd_ready && cmd_valid)begin
    cmd_kind=READ_BYTE;
     mpu_reconstructed_byte=8'hC3;
     bit_index=6;
     mpu_nack_next=0;
     mpu_read_done=0;
     read_ack=0;
  end
  wait(busy)begin
    cmd_valid=0;
     mpu_sda_drive_low=~mpu_reconstructed_byte[7];
     #5000;
     reset=1;
  end
  @(posedge cmd_ready)begin
   if(busy)begin
    $error("Mismatch: expected %0d, received %0d",
            0,
            busy
    );
    message=message+1;
   end
   if(!cmd_ready)begin
    $error("Mismatch: expected %0d, received %0d",
            1,
            cmd_ready
    );
    message=message+1;
   end
    if(error)begin
      $error("Mismatch: expected %0d, received %0d",
            0,
            error
    );
    message=message+1;
    end
    if(!mpu_active)begin
      $error("Mismatch: expected %0d, received %0d",
            1,
            mpu_active
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
    if(error_timeout)begin
      $error("Mismatch: expected %0d, received %0d",
            0,
            error_timeout
    );
    message=message+1;
    end
    if(rx_data == mpu_reconstructed_byte)begin
      $error("Mismatch: expected %0d, received %0d",
            1,
            rx_data
    );
    message=message+1;
    end
    cmd_valid=0;
    bit_index=0;
    mpu_read_done=0;
    tx_data=0;
    read_ack=0;
    reset=0;
    mpu_reconstructed_byte=0;
  end
   @(negedge clk);
    reset = 0;
    cmd_valid=1;
  wait(cmd_valid && cmd_ready)begin
    cmd_kind=START;
  end
   wait(busy)begin
    cmd_valid=0;
   end
  @(posedge done or posedge error)begin
    #1;
   if(busy)begin
    $error("Mismatch: expected %0d, received %0d",
            0,
            busy
    );
    message=message+1;
   end
   if(!cmd_ready)begin
    $error("Mismatch: expected %0d, received %0d",
            1,
            cmd_ready
    );
    message=message+1;
   end
    if(error)begin
      $error("Mismatch: expected %0d, received %0d",
            0,
            error
    );
    message=message+1;
    end
    if(!mpu_active)begin
      $error("Mismatch: expected %0d, received %0d",
            1,
            mpu_active
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
    if(error_timeout)begin
      $error("Mismatch: expected %0d, received %0d",
            0,
            error_timeout
    );
    message=message+1;
    end
  end
    @(negedge clk)begin
      cmd_valid=1;
    end
  wait(cmd_ready && cmd_valid)begin
     mpu_reconstructed_byte=8'h69;
     bit_index=6;
     mpu_nack_next=0;
     mpu_read_done=0;
     cmd_kind=READ_BYTE;
     read_ack=1;
  end
  wait(busy)begin
    cmd_valid=0;
     mpu_sda_drive_low=~mpu_reconstructed_byte[7];
  end
  @(posedge done or posedge error)begin
    #1;
   if(busy)begin
    $error("Mismatch: expected %0d, received %0d",
            0,
            busy
    );
    message=message+1;
   end
   if(!cmd_ready)begin
    $error("Mismatch: expected %0d, received %0d",
            1,
            cmd_ready
    );
    message=message+1;
   end
    if(error)begin
      $error("Mismatch: expected %0d, received %0d",
            0,
            error
    );
    message=message+1;
    end
    if(!mpu_active)begin
      $error("Mismatch: expected %0d, received %0d",
            0,
            mpu_active
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
    if(error_timeout)begin
      $error("Mismatch: expected %0d, received %0d",
            0,
            error_timeout
    );
    message=message+1;
    end
    if(rx_data !== mpu_reconstructed_byte)begin
      $error("Mismatch: expected %0d, received %0d",
            rx_data,
            mpu_reconstructed_byte
    );
    message=message+1;
    end
    if(!i2c_nack_next)begin
      $error("Mismatch: expected %0d, received %0d",
            1,
            i2c_nack_next
    );
    message=message+1;
    end
    cmd_valid=0;
    bit_index=0;
    mpu_read_done=0;
    tx_data=0;
    read_ack=0;
    mpu_reconstructed_byte=0;
  end
   @(negedge clk);
    reset = 0;
    cmd_valid=1;
  wait(cmd_valid && cmd_ready)begin
    cmd_kind=START;
  end
   wait(!cmd_ready)begin
    #1;
    cmd_kind=WRITE_BYTE;
    tx_data=8'h96;
    cmd_valid=1;
    shadow_active=1;
  end
  @(posedge done or posedge error)begin
    #1;
   if(busy)begin
    $error("Mismatch: expected %0d, received %0d",
            0,
            busy
    );
    message=message+1;
   end
   if(!cmd_ready)begin
    $error("Mismatch: expected %0d, received %0d",
            1,
            cmd_ready
    );
    message=message+1;
   end
    if(error)begin
      $error("Mismatch: expected %0d, received %0d",
            0,
            error
    );
    message=message+1;
    end
    if(!mpu_active)begin
      $error("Mismatch: expected %0d, received %0d",
            1,
            mpu_active
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
    if(error_timeout)begin
      $error("Mismatch: expected %0d, received %0d",
            0,
            error_timeout
    );
    message=message+1;
    end
  end
  wait(cmd_ready && cmd_valid)begin
     bit_index=7;
     shadow_active=0;
  end
  wait(busy)begin
    cmd_valid=0;
  end
  @(posedge done or posedge error)begin
    #1;
   if(busy)begin
    $error("Mismatch: expected %0d, received %0d",
            0,
            busy
    );
    message=message+1;
   end
   if(!cmd_ready)begin
    $error("Mismatch: expected %0d, received %0d",
            1,
            cmd_ready
    );
    message=message+1;
   end
    if(error)begin
      $error("Mismatch: expected %0d, received %0d",
            0,
            error
    );
    message=message+1;
    end
    if(!mpu_active)begin
      $error("Mismatch: expected %0d, received %0d",
            1,
            mpu_active
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
    if(error_timeout)begin
      $error("Mismatch: expected %0d, received %0d",
            0,
            error_timeout
    );
    message=message+1;
    end
    if(tx_data!==mpu_reconstructed_byte)begin
      $error("Mismatch: expected %0d, received %0d",
            tx_data,
            mpu_reconstructed_byte
    );
    message=message+1;
    end
    if(shadow_cmd_kind!==cmd_kind)begin
      $error("Mismatch: expected %0d, received %0d",
            cmd_kind,
            shadow_cmd_kind
    );
    message=message+1;
    end
    if(shadow_tx_data!==tx_data)begin
      $error("Mismatch: expected %0d, received %0d",
            tx_data,
            shadow_tx_data
    );
    message=message+1;
    end
    cmd_valid=0;
    bit_index=0;
    mpu_read_done=0;
    tx_data=0;
    mpu_reconstructed_byte=0;
    mpu_sda_drive_low=0;
  end
   @(negedge clk)begin
    cmd_valid=1;
  end
  wait(cmd_ready && cmd_valid)begin
    cmd_kind=STOP;
  end
  wait(busy)begin
    cmd_valid=0;
  end
  @(posedge done or posedge error)begin
    #1;
   if(busy)begin
    $error("Mismatch: expected %0d, received %0d",
            0,
            busy
    );
    message=message+1;
   end
   if(!cmd_ready)begin
    $error("Mismatch: expected %0d, received %0d",
            1,
            cmd_ready
    );
    message=message+1;
   end
    if(error)begin
      $error("Mismatch: expected %0d, received %0d",
            0,
            error
    );
    message=message+1;
    end
    if(mpu_active)begin
      $error("Mismatch: expected %0d, received %0d",
            0,
            mpu_active
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
    if(error_timeout)begin
      $error("Mismatch: expected %0d, received %0d",
            0,
            error_timeout
    );
    message=message+1;
    end
    cmd_valid=0;
    mpu_active=0;
  end
  // START to open the bus before command A (every write elsewhere in this file needs one).
   @(negedge clk);
    reset = 0;
    cmd_valid=1;
  wait(cmd_valid && cmd_ready)begin
    cmd_kind=START;
  end
  wait(busy)begin
    cmd_valid=0;
  end
  @(posedge done or posedge error)begin
    #1;
   if(busy)begin
    $error("Mismatch: expected %0d, received %0d",
            0,
            busy
    );
    message=message+1;
   end
   if(!cmd_ready)begin
    $error("Mismatch: expected %0d, received %0d",
            1,
            cmd_ready
    );
    message=message+1;
   end
    if(error)begin
      $error("Mismatch: expected %0d, received %0d",
            0,
            error
    );
    message=message+1;
    end
    if(!mpu_active)begin
      $error("Mismatch: expected %0d, received %0d",
            1,
            mpu_active
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
    if(error_timeout)begin
      $error("Mismatch: expected %0d, received %0d",
            0,
            error_timeout
    );
    message=message+1;
    end
    cmd_valid=0;
  end
  // Command A (WRITE_BYTE, clock-stretched so busy stays high long enough to matter)
  @(negedge clk)begin
    cmd_valid=1;
  end
  wait(cmd_ready && cmd_valid)begin
    cmd_kind=WRITE_BYTE;
    tx_data=8'h7E;
    bit_index=7;
    mpu_strech_bit=4;
  end
  // Command A accepted (busy just went high) -- load command B's fields now and
  // hold cmd_valid high instead of dropping it, so B sits queued while A runs.
  wait(busy)begin
    cmd_kind=WRITE_BYTE;
    tx_data=8'h42;
    read_ack=1;
  end
  // Command A finishes -- check its postconditions. No cmd_valid=0 here: it must
  // stay high so command B (already queued above) gets picked up immediately.
  @(posedge done or posedge error)begin
    #1;
   if(busy)begin
    $error("Mismatch: expected %0d, received %0d",
            0,
            busy
    );
    message=message+1;
   end
   if(!cmd_ready)begin
    $error("Mismatch: expected %0d, received %0d",
            1,
            cmd_ready
    );
    message=message+1;
   end
    if(error)begin
      $error("Mismatch: expected %0d, received %0d",
            0,
            error
    );
    message=message+1;
    end
    if(!mpu_active)begin
      $error("Mismatch: expected %0d, received %0d",
            1,
            mpu_active
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
    if(error_timeout)begin
      $error("Mismatch: expected %0d, received %0d",
            0,
            error_timeout
    );
    message=message+1;
    end
    if(mpu_reconstructed_byte !== 8'h7E)begin
      $error("Mismatch: expected %0d, received %0d",
            8'h7E,
            mpu_reconstructed_byte
    );
    message=message+1;
    end
    bit_index=0;
    mpu_read_done=0;
    mpu_reconstructed_byte=0;
    mpu_sda_drive_low=0;
    mpu_strech_bit=10;
  end
  // Command B should be accepted essentially immediately, since cmd_valid never dropped.
  wait(cmd_ready && cmd_valid)begin
    bit_index=7;
  end
  wait(busy)begin
    cmd_valid=0;
  end
  @(posedge done or posedge error)begin
    #1;
   if(busy)begin
    $error("Mismatch: expected %0d, received %0d",
            0,
            busy
    );
    message=message+1;
   end
   if(!cmd_ready)begin
    $error("Mismatch: expected %0d, received %0d",
            1,
            cmd_ready
    );
    message=message+1;
   end
    if(error)begin
      $error("Mismatch: expected %0d, received %0d",
            0,
            error
    );
    message=message+1;
    end
    if(!mpu_active)begin
      $error("Mismatch: expected %0d, received %0d",
            1,
            mpu_active
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
    if(error_timeout)begin
      $error("Mismatch: expected %0d, received %0d",
            0,
            error_timeout
    );
    message=message+1;
    end
    if(tx_data!==mpu_reconstructed_byte)begin
      $error("Mismatch: expected %0d, received %0d",
            tx_data,
            mpu_reconstructed_byte
    );
    message=message+1;
    end
    if(shadow_cmd_kind!==cmd_kind)begin
      $error("Mismatch: expected %0d, received %0d",
            cmd_kind,
            shadow_cmd_kind
    );
    message=message+1;
    end
    if(shadow_tx_data!==tx_data)begin
      $error("Mismatch: expected %0d, received %0d",
            tx_data,
            shadow_tx_data
    );
    message=message+1;
    end
    if(shadow_read_ack!==read_ack)begin
      $error("Mismatch: expected %0d, received %0d",
            read_ack,
            shadow_read_ack
    );
    message=message+1;
    end
    cmd_valid=0;
    bit_index=0;
    mpu_read_done=0;
    tx_data=0;
    mpu_reconstructed_byte=0;
    mpu_sda_drive_low=0;
    read_ack=0;
  end
  // START to open the bus before command A.
   @(negedge clk);
    reset = 0;
    cmd_valid=1;
  wait(cmd_valid && cmd_ready)begin
    cmd_kind=START;
  end
  wait(busy)begin
    cmd_valid=0;
  end
  @(posedge done or posedge error)begin
    #1;
   if(busy)begin
    $error("Mismatch: expected %0d, received %0d",
            0,
            busy
    );
    message=message+1;
   end
   if(!cmd_ready)begin
    $error("Mismatch: expected %0d, received %0d",
            1,
            cmd_ready
    );
    message=message+1;
   end
    if(error)begin
      $error("Mismatch: expected %0d, received %0d",
            0,
            error
    );
    message=message+1;
    end
    if(!mpu_active)begin
      $error("Mismatch: expected %0d, received %0d",
            1,
            mpu_active
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
    if(error_timeout)begin
      $error("Mismatch: expected %0d, received %0d",
            0,
            error_timeout
    );
    message=message+1;
    end
    cmd_valid=0;
  end
  // Command A (READ_BYTE, clock-stretched so busy stays high long enough to matter)
  @(negedge clk)begin
    cmd_valid=1;
  end
  wait(cmd_ready && cmd_valid)begin
    cmd_kind=READ_BYTE;
    mpu_reconstructed_byte=8'hE7;
    bit_index=6;
    mpu_nack_next=0;
    mpu_read_done=0;
    mpu_strech_bit=3;
    read_ack=1;
  end
  // Command A accepted -- load command B's fields now (a READ_BYTE with a
  // different read_ack than A, so read_ack drift actually gets exercised) and
  // preload A's first read bit, then hold cmd_valid high so B sits queued.
  wait(busy)begin
    cmd_kind=READ_BYTE;
    read_ack=0;
    mpu_sda_drive_low=~mpu_reconstructed_byte[7];
  end
  // Command A finishes -- check its postconditions. No cmd_valid=0 here: it must
  // stay high so command B (already queued above) gets picked up immediately.
  @(posedge done or posedge error)begin
    #1;
   if(busy)begin
    $error("Mismatch: expected %0d, received %0d",
            0,
            busy
    );
    message=message+1;
   end
   if(!cmd_ready)begin
    $error("Mismatch: expected %0d, received %0d",
            1,
            cmd_ready
    );
    message=message+1;
   end
    if(error)begin
      $error("Mismatch: expected %0d, received %0d",
            0,
            error
    );
    message=message+1;
    end
    if(!mpu_active)begin
      $error("Mismatch: expected %0d, received %0d",
            1,
            mpu_active
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
    if(error_timeout)begin
      $error("Mismatch: expected %0d, received %0d",
            0,
            error_timeout
    );
    message=message+1;
    end
    if(rx_data !== mpu_reconstructed_byte)begin
      $error("Mismatch: expected %0d, received %0d",
            rx_data,
            mpu_reconstructed_byte
    );
    message=message+1;
    end
    if(!i2c_nack_next)begin
      $error("Mismatch: expected %0d, received %0d",
            1,
            i2c_nack_next
    );
    message=message+1;
    end
    bit_index=0;
    mpu_read_done=0;
    mpu_reconstructed_byte=0;
    mpu_sda_drive_low=0;
    mpu_strech_bit=10;
  end
  // Command B should be accepted essentially immediately, since cmd_valid never dropped.
  // Wait for cmd_ready && cmd_valid first (mirrors every other command's acceptance
  // check) but don't load B's model fields until busy actually re-asserts -- that's
  // the moment the DUT has genuinely accepted B (state==IDLE re-checked), one cycle
  // later than cmd_ready&&cmd_valid alone. Loading fields any earlier lets A's own
  // trailing ACK-bit edge see B's fresh bit_index/mpu_reconstructed_byte too soon.
  wait(cmd_ready && cmd_valid)begin
  end
  wait(busy)begin
    cmd_valid=0;
    mpu_reconstructed_byte=8'hA5;
    bit_index=6;
    mpu_nack_next=0;
    mpu_read_done=0;
     mpu_sda_drive_low=~mpu_reconstructed_byte[7];
  end
  @(posedge done or posedge error)begin
    #1;
   if(busy)begin
    $error("Mismatch: expected %0d, received %0d",
            0,
            busy
    );
    message=message+1;
   end
   if(!cmd_ready)begin
    $error("Mismatch: expected %0d, received %0d",
            1,
            cmd_ready
    );
    message=message+1;
   end
    if(error)begin
      $error("Mismatch: expected %0d, received %0d",
            0,
            error
    );
    message=message+1;
    end
    if(!mpu_active)begin
      $error("Mismatch: expected %0d, received %0d",
            1,
            mpu_active
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
    if(error_timeout)begin
      $error("Mismatch: expected %0d, received %0d",
            0,
            error_timeout
    );
    message=message+1;
    end
    if(rx_data !== mpu_reconstructed_byte)begin
      $error("Mismatch: expected %0d, received %0d",
            rx_data,
            mpu_reconstructed_byte
    );
    message=message+1;
    end
    if(i2c_nack_next)begin
      $error("Mismatch: expected %0d, received %0d",
            0,
            i2c_nack_next
    );
    message=message+1;
    end
    if(shadow_cmd_kind!==cmd_kind)begin
      $error("Mismatch: expected %0d, received %0d",
            cmd_kind,
            shadow_cmd_kind
    );
    message=message+1;
    end
    if(shadow_read_ack!==read_ack)begin
      $error("Mismatch: expected %0d, received %0d",
            read_ack,
            shadow_read_ack
    );
    message=message+1;
    end
    cmd_valid=0;
    bit_index=0;
    mpu_read_done=0;
    tx_data=0;
    mpu_reconstructed_byte=0;
    mpu_sda_drive_low=0;
    read_ack=0;
  end
  @(negedge clk);
    reset = 0;
    cmd_valid=1;
  wait(cmd_valid && cmd_ready)begin
    cmd_kind=START;
  end
  wait(busy)begin
    cmd_valid=0;
  end
  @(posedge done or posedge error)begin
    #1;
   if(busy)begin
    $error("Mismatch: expected %0d, received %0d",
            0,
            busy
    );
    message=message+1;
   end
   if(!cmd_ready)begin
    $error("Mismatch: expected %0d, received %0d",
            1,
            cmd_ready
    );
    message=message+1;
   end
    if(error)begin
      $error("Mismatch: expected %0d, received %0d",
            0,
            error
    );
    message=message+1;
    end
    if(!mpu_active)begin
      $error("Mismatch: expected %0d, received %0d",
            1,
            mpu_active
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
    if(error_timeout)begin
      $error("Mismatch: expected %0d, received %0d",
            0,
            error_timeout
    );
    message=message+1;
    end
    cmd_valid=0;
  end
  @(negedge clk);
  cmd_kind = WRITE_BYTE;
  tx_data = 8'hA5;
  bit_index = 7;
  mpu_nack_next = 0;
  mpu_timeout = 1;
  cmd_valid = 1;

do @(posedge clk);
while (!(cmd_valid && cmd_ready));

timeout_accept_time = $time;
  wait(busy)begin
    cmd_valid=0;
  end
  @(posedge error_timeout)begin
    timeout_error_time=$time;
    #1;
   if(busy)begin
    $error("Mismatch: expected %0d, received %0d",
            0,
            busy
    );
    message=message+1;
   end
   if(!cmd_ready)begin
    $error("Mismatch: expected %0d, received %0d",
            1,
            cmd_ready
    );
    message=message+1;
   end
    if(!error)begin
      $error("Mismatch: expected %0d, received %0d",
            1,
            error
    );
    message=message+1;
    end
    if(!mpu_active)begin
      $error("Mismatch: expected %0d, received %0d",
            1,
            mpu_active
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
    if(!error_timeout)begin
      $error("Mismatch: expected %0d, received %0d",
            1,
            error_timeout
    ); 
    message=message+1;
    end
    if(done)begin
      $error("Mismatch: expected done=0 during timeout"); 
    message=message+1;
    end
    timeout_elapsed=timeout_error_time-timeout_accept_time;
    if(timeout_elapsed !== EXPECTED_TIMEOUT)begin
      $error("Timeout interval wrong: expected %0t, got %0t",
         EXPECTED_TIMEOUT, timeout_elapsed);
  message = message + 1;
    end
    cmd_valid=0;
    bit_index=0;
    mpu_read_done=0;
    tx_data=0;
    mpu_reconstructed_byte=0;
    mpu_sda_drive_low=0;
     mpu_timeout=0;
  end
  if (message == 0)
    $display("PASS: no errors found");
else
    $fatal(1, "%0d errors found", message);

$finish;
end
always #5 clk = ~clk;

always @(scl_bus)begin
  if (scl_bus)
    scl_was_high <= 1'b1;
  else
    scl_was_high <= 1'b0;
end
always @(posedge clk)begin
  if(reset)begin
    accepted_cmd_kind<=START;
    accepted_cmd_active<=1'b0;
  end
  else if(cmd_valid && cmd_ready)begin
    accepted_cmd_kind<=cmd_kind;
    accepted_cmd_active<=1'b1;
  end
  else if(done || error)begin
    accepted_cmd_active<=1'b0;
  end
end
always @(scl_bus)begin
  scl_last_change=$time;
end
always @(posedge sda_bus) begin
  if(scl_was_high && $time != scl_last_change)begin
    mpu_active<=0;
  end
end
always @(posedge sda_bus)begin
  if(!reset && scl_was_high && $time != scl_last_change &&
     (!accepted_cmd_active || accepted_cmd_kind !== STOP)) begin
    $error(
      "I2C-ASSERT-01: unexpected STOP while command is %b",
      accepted_cmd_kind
    );
    message = message + 1;
  end
end

always @(negedge sda_bus) begin
  if (scl_bus) begin
    mpu_active <= 1;
  end
end
always @(negedge sda_bus)begin
  if (!reset && scl_bus &&
      (!accepted_cmd_active || accepted_cmd_kind !== START)) begin
    $error(
      "I2C-ASSERT-01: unexpected START while command is %b",
      accepted_cmd_kind
    );
    message = message + 1;
  end
end

always @(posedge scl_bus)begin
  if(mpu_active && cmd_kind == WRITE_BYTE)begin
    if(!mpu_read_done)begin
       mpu_reconstructed_byte[bit_index] = sda_bus;
    end
    if(bit_index == 0)begin
      mpu_read_done=1;
    end
    else begin
      bit_index=bit_index-1;
    end
  end
end
always @(negedge scl_bus) begin
  if(mpu_active && cmd_kind == WRITE_BYTE)begin
    if(mpu_read_done)begin
      mpu_sda_drive_low=~mpu_nack_next;
    end
  end
end
always @(negedge scl_bus)begin
  if(mpu_active && cmd_kind == READ_BYTE)begin
    if(mpu_strech_bit==bit_index)begin
    mpu_scl_drive_low<=1;
    #20000;
    mpu_scl_drive_low<=0;
   end
   if(final_read_bit_pending)begin
      mpu_read_done=1;
      mpu_sda_drive_low=0;
      final_read_bit_pending=0;
    end
    else if(!mpu_read_done)begin
        mpu_sda_drive_low= ~mpu_reconstructed_byte[bit_index];
        if(bit_index==0) final_read_bit_pending=1;
        else begin
          bit_index=bit_index-1;
        end
    end
  end
end
always @(posedge scl_bus)begin
  if(mpu_read_done && cmd_kind == READ_BYTE)begin
    i2c_nack_next<=~sda_bus;
    ack_phase_observed=1'b1;
  end
end
always @(negedge scl_bus)begin
  if(cmd_kind == WRITE_BYTE && mpu_strech_bit == bit_index)begin
    mpu_scl_drive_low<=1;
    #20000;
    mpu_scl_drive_low<=0;
  end
end
always @(posedge clk) begin : watchdog
  if (reset) begin
    command_cycle_count <= 19'd0;
  end
  else if (done || error) begin
    command_cycle_count <= 19'd0;
  end
  else if (command_outstanding) begin
    if (command_cycle_count >= 19'd500000) begin
      message = message + 1;
      $fatal(1, "I2C-ASSERT-04: command exceeded timeout");
    end
    else begin
      command_cycle_count <= command_cycle_count + 1'b1;
    end
  end
  else begin
    command_cycle_count <= 19'd0;
  end
end

always@(posedge clk)begin
  if(cmd_valid && !cmd_ready)begin
    if(!was_pending)begin
      shadow_cmd_kind<=cmd_kind;
      shadow_tx_data<=tx_data;
      shadow_read_ack<=read_ack;
      was_pending<=1;
    end
    else begin
        begin
          if(read_ack !== shadow_read_ack)begin
            $error("Mismatch: expected %0d, received %0d",
            shadow_read_ack,
            read_ack
           );
           message=message+1;
          end
           if(tx_data !== shadow_tx_data)begin
            $error("Mismatch: expected %0d, received %0d",
            shadow_tx_data,
            tx_data
           );
           message=message+1;
           end
           if(cmd_kind !== shadow_cmd_kind)begin
            $error("Mismatch: expected %0d, received %0d",
            shadow_cmd_kind,
            cmd_kind
           );
           message=message+1;
          end
        end
  end
  end
  else begin
     was_pending<=0;
  end
end

always @(posedge clk)begin
    if(reset)begin
      command_outstanding<=1'b0;
      error_last<=1'b0;
      done_last<=1'b0;
    end
    else begin
    if(done && error)begin
      $error("I2C-ASSERT-03: done and error asserted together");
      message = message + 1;
    end
    if((done||error) && !command_outstanding)begin
       $error("I2C-ASSERT-03: terminal result without an accepted command");
       message = message + 1;
    end 
    if (done && done_last) begin
      $error("I2C-ASSERT-03: done asserted for more than one clock");
      message = message + 1;
     end

    if (error && error_last) begin
      $error("I2C-ASSERT-03: error asserted for more than one clock");
     message = message + 1;
    end
    if(done||error)begin
      command_outstanding<= cmd_valid && cmd_ready;
    end
    else if(cmd_valid && cmd_ready)begin
      command_outstanding<=1;
    end
    done_last  <= done;
    error_last <= error;
    end
end
always @(posedge clk)begin
  if(reset_check_pending)begin
    if(busy)begin
      $error("Mismatch expected %0d recived %0d", 0, busy);
      message=message+1;
    end
    if(done)begin
      $error("Mismatch expected %0d recived %0d", 0, done);
      message=message+1;
    end
    if(sda_drive_low)begin
      $error("Mismatch expected %0d recived %0d", 0, sda_drive_low);
      message=message+1;
    end
    if(scl_drive_low)begin
      $error("Mismatch expected %0d recived %0d", 0, scl_drive_low);
      message=message+1;
    end
    if(error)begin
      $error("Mismatch expected %0d recived %0d", 0, error);
      message=message+1;
    end
    if(!cmd_ready)begin
      $error("Reset postcondition: expected cmd_ready=1, got %0d", cmd_ready);
      message=message+1;
    end
    if(error_nack)begin
      $error("Reset postcondition: expected error_nack=0, got %0d", error_nack);
      message=message+1;
    end
    if(error_timeout)begin
      $error("Reset postcondition: expected error_timeout=0, got %0d", error_timeout);
      message=message+1;
    end
    if(rx_data !== 8'h00)begin
      $error("Reset postcondition: expected rx_data=0, got %0h", rx_data);
      message=message+1;
    end
  end
  reset_check_pending<=reset && busy;
end
always @(posedge clk)begin
  if(!reset &&(sda_drive_low) !== 1'b0 && (sda_drive_low !== 1'b1))begin
    $error(
        "I2C-ASSERT-02: sda_drive_low is unknown");
        message=message+1;
  end
end
always @(posedge clk)begin
  if(!reset &&(scl_drive_low) !== 1'b0 && (scl_drive_low !== 1'b1))begin
    $error(
        "I2C-ASSERT-02: scl_drive_low is unknown");
        message=message+1;
  end
end
always @(negedge scl_bus)begin
  if(cmd_kind == WRITE_BYTE && mpu_timeout)begin
    mpu_scl_drive_low<=1;
    #5_500_000;
    mpu_scl_drive_low<=0;
  end
end
always @(negedge scl_bus) begin
  if((accepted_cmd_kind == WRITE_BYTE || accepted_cmd_kind == READ_BYTE) 
  && timing_check_active) begin
     low_start_time = $time;
     low_start_time_done=1;
     if(high_start_time_done)begin
      high_duration = $time - high_start_time;
     
  if ((high_duration + TIMING_TOLERANCE < EXPECTED_SCL_HALF) ||
      (high_duration > EXPECTED_SCL_HALF + TIMING_TOLERANCE)) begin
    $error("High phase violation on clock %0d: expected %0t, got %0t",
       ninth_clock_check, EXPECTED_SCL_HALF, high_duration);
    message=message+1;
  end
  high_phase_count = high_phase_count + 4'd1;
  end
  if(ninth_clock_check == 4'd9)begin
    final_phase_checked=1;
  end
end
end

always @(posedge scl_bus) begin
  if ((accepted_cmd_kind == WRITE_BYTE ||
       accepted_cmd_kind == READ_BYTE) &&
      timing_check_active) begin
    if (low_start_time_done) begin
      low_duration = $time - low_start_time;

      if ((low_duration + TIMING_TOLERANCE < EXPECTED_SCL_HALF) ||
          (low_duration > EXPECTED_SCL_HALF + TIMING_TOLERANCE)) begin
        $error("Low phase violation on clock %0d: expected %0t, got %0t",
       ninth_clock_check, EXPECTED_SCL_HALF, low_duration);
        message = message + 1;
      end
      low_phase_count = low_phase_count + 4'd1;
    end

    high_start_time = $time;
    high_start_time_done = 1;

    if (ninth_clock_check == 4'd8) begin
  // Current edge is clock 9.
        ninth_clock_check = 4'd9;
  end
  else if(ninth_clock_check>=4'd9)begin
     $error("Too many rising edges: expected 9, count was %0d",
         ninth_clock_check);
  message = message + 1;
  end
  else begin
    ninth_clock_check = ninth_clock_check + 4'd1;
  end
  end
end
endmodule
