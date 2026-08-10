// Phase 0 exercise: write the two-state FSM here.
module fsm (
    input  logic clk,
    input  logic reset,
    input  logic start,
    input  logic clear,
    output logic busy
);

    typedef enum logic {IDLE, BUSY} state_t;
    state_t state, next_state;

    always_ff @(posedge clk) begin
       if(reset) state<=IDLE;
    else state<=next_state;
     
    end

    always_comb begin
        next_state = state;
        busy =(state == BUSY);
       case (state)
        IDLE: if (start) next_state = BUSY;
        BUSY: if (clear) next_state = IDLE;
    endcase

        busy =(state == BUSY);
    end
endmodule
// Inputs: clk, synchronous active-high reset, start, clear.
// Output: busy (1 in BUSY, 0 in IDLE).
