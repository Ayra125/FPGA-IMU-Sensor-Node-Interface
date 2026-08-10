// Phase 0 exercise: write the self-checking FSM testbench here.
module tb_fsm;

    logic clk, reset, start, clear, busy,expected_busy;

    fsm dut (
        .clk   (clk),
        .reset (reset),
        .start (start),
        .clear (clear),
        .busy  (busy)
    );
    int message=0;
    initial begin
        $dumpfile("fsm.vcd");
        $dumpvars(0,tb_fsm);
        clk=0;
        reset=1;
        start=0;
        clear=0;
        expected_busy=0;
        // TODO: drive the stimulus scenarios you list out — reset, hold in
        //       IDLE, IDLE->BUSY, hold in BUSY, BUSY->IDLE, and anything
        //       else you decide is worth checking.
        repeat(4) @(negedge clk);
        reset=0;
        start=1;
        repeat(4) @(negedge clk);
        reset=1;
        start=0;
        repeat(4) @(negedge clk);
        start=1;
        @(negedge clk);
        reset=0;
        start=0;
        repeat(4) @(negedge clk);
        clear=1;
        @(negedge clk);
        clear=0;
         repeat(4) @(negedge clk);
        start=1;
        @(negedge clk);
        clear=1;
        @(negedge clk);
        clear=0;
        // TODO: print a verdict and end the simulation. Same rule as the
        //       counter: $fatal if the error count is nonzero, $finish if not.
        if(message!==0)begin
            $fatal(1,"amount of errors %0d",message);
    end
    else 
    $display("Pass no errors found");
    $finish;
    end

   always  #5 clk=~clk;
    always @(posedge clk) begin
        
         if (reset) expected_busy=0;
       else case (expected_busy)
    1'b0: if (start) expected_busy = 1;   // modeling IDLE — only start matters
    1'b1: if (clear) expected_busy = 0;   // modeling BUSY — only clear matters
endcase
 #1
    if(expected_busy!==busy) begin 
        $error(
      "Mismatch: expected %0d, received %0d",
      expected_busy,
      busy  
      );
    message+=1;
    end
end     
endmodule
// Signals: clk, reset, start, clear drive the DUT; busy is observed.
