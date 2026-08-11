// Self-checking testbench for timing_enable_gen.
module tb_timing_enable_gen;
logic reset, clk,i2c_step,sample_tick,expected_i2c,expected_sample;
logic [1:0]expected_i2c_count;
logic [3:0]expected_sample_count;
timing_enable_gen #(
    .STEP_CYCLES(4),
    .SAMPLE_CYCLES(10)
)
dut (
    .reset(reset),
    .clk(clk),
    .i2c_step(i2c_step),
    .sample_tick(sample_tick)
);
int message=0;
initial begin
    $dumpfile("time_enable_gen.vcd");
    $dumpvars(0,tb_timing_enable_gen);
    clk=0;
    reset=1;
    expected_i2c=0;
    expected_sample=0;
    expected_i2c_count=0;
    expected_sample_count=0;
   repeat(4)@(negedge clk);
    reset=0;
    repeat(12)@(negedge clk);
    reset=1;
    @(negedge clk);
    if(message!==0)begin
            $fatal(1,"amount of errors %0d",message);
    end
     else
    $display("Pass no errors found");
    $finish;
end
always  #5 clk=~clk;

always @(posedge clk ) begin
    expected_i2c=0;
    expected_sample=0;
    if(reset) begin
    expected_i2c=0;
    expected_sample=0;
    expected_i2c_count=0;
    expected_sample_count=0;
    end
    else begin
        if(expected_i2c_count==3)begin
            expected_i2c=1;
            expected_i2c_count=0;
        end
        else begin
            expected_i2c_count= expected_i2c_count+1;
        end
        if(expected_sample_count==9)begin
        expected_sample=1;
        expected_sample_count=0;
        end
        else begin
            expected_sample_count= expected_sample_count+1;
        end
    end
    #1;
    if(expected_i2c!==i2c_step) begin
        $error(
            "Mismatch: expected %0d, received %0d",
            expected_i2c,
            i2c_step
        );
        message=message+1;
    end
    if(expected_sample!==sample_tick) begin
        $error(
            "Mismatch: expected %0d, received %0d",
            expected_sample,
            sample_tick
        );
        message=message+1;
    end
end

endmodule
// Learner-authored testbench code goes here.
