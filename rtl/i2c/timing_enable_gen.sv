// Phase 2 I2C timing-enable generator.
module timing_enable_gen#(
    parameter int STEP_CYCLES = 500,
    parameter int SAMPLE_CYCLES = 1_000_000
) (
    input logic reset,
    input logic clk,
    output logic i2c_step,
    output logic sample_tick


);
    logic [$clog2(STEP_CYCLES)-1:0] i2c_count;
    logic [$clog2(SAMPLE_CYCLES)-1:0] sample_count;
    always_ff @(posedge clk ) begin
         i2c_step<=0;
        sample_tick<=0;
        if(reset) begin
            i2c_count<=0;
            sample_count<=0;
            i2c_step<=0;
            sample_tick<=0;
        end
        else begin
        if(i2c_count==STEP_CYCLES-1)begin
            i2c_step<=1;
            i2c_count<=0;
        end
        else begin
            i2c_count<= i2c_count+1;
        end
         if (sample_count == SAMPLE_CYCLES-1)begin
            sample_tick<=1;
            sample_count<=0;
        end
        else begin
        sample_count<= sample_count+1;
        end
        end
    end


endmodule
// Learner-authored RTL goes here.
