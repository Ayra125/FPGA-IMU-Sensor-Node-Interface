// Phase 0 exercise: write the 4-bit synchronous counter here.
module counter (
    input logic clk,
    input logic reset,
    input logic enable,
    output logic [3:0]count
);
 always_ff @(posedge clk) begin
        if (reset) count <= 0;
        else if (enable && !reset) count <= count +1;

    end
endmodule
// Inputs: clk, active-high synchronous reset, enable.
 // Output: 4-bit count.
