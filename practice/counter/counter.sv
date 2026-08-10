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
typedef enum logic {LOCKED,UNLOCKED} state_t;

module turnstile(
    input logic clk,
    input logic reset,
    input  logic coin,
    input  logic push,
    output logic unlocked
);

state_t state, next_state;
always_ff @(posedge clk) begin
    if(reset) state<=LOCKED;
    else state<=next_state;
end
always_comb begin 
    next_state = state;
    unlocked =(state == UNLOCKED);
end
endmodule
 // Output: 4-bit count.
