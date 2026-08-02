// Phase 0 exercise: write the self-checking counter testbench here.
module tb_counter;
 logic clk, reset, enable;
 logic [3:0]count;
 logic [3:0]expected_count;
 logic [3:0]message;
 counter dut(
    .clk(clk),
    .reset(reset),
    .enable(enable),
    .count(count)
 );
    initial begin
        clk=0;
        reset=1;
        expected_count=0;
        enable=0;
        message=0;
    repeat(4)@(negedge clk);
    reset=0;
    enable=1;
    repeat(4)@(negedge clk);
    reset=0;
    enable=0;
    repeat(2)@(negedge clk);
    reset=1;
    enable=1;
    @(negedge clk);
    reset=0; 
    repeat(16)@(negedge clk);
        enable=1;

    if (count !== 4'd0) begin
  $error(
    "Wraparound failed: expected 0, received %0d",
    count
  );
    message += 1;
    end
    else if(message==0)begin 
      $display("PASS: counter tests completed");
    @(negedge clk);
    end
    else
    $display("Wraparound PASS but Count FAIL");
    $finish;
    end
    always #5 clk=~clk;
 always @(posedge clk) begin
  if (reset)
    expected_count = 4'd0;
  else if (enable)
    expected_count +=1;
  #1;

  if (count !== expected_count) begin
    $error(
      "Mismatch: expected %0d, received %0d",
      expected_count,
      count
    );
    message+=1;
  end
end
endmodule
// Test reset, enabled counting, disabled hold behavior, and 15-to-0 wraparound.
// Generate a VCD waveform using $dumpfile and $dumpvars.
