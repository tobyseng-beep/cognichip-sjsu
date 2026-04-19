// =============================================================================
// Module  : alu_8bit
// Description: 8-bit ALU supporting standard arithmetic and logic operations.
//              Purely combinational for power efficiency. Outputs a 4-bit flag
//              bus: {carry, overflow, zero, negative}.
//
// Opcodes:
//   4'h0 : ADD    - result = a + b
//   4'h1 : SUB    - result = a - b
//   4'h2 : AND    - result = a & b
//   4'h3 : OR     - result = a | b
//   4'h4 : XOR    - result = a ^ b
//   4'h5 : NOT    - result = ~a
//   4'h6 : NAND   - result = ~(a & b)
//   4'h7 : NOR    - result = ~(a | b)
//   4'h8 : XNOR   - result = ~(a ^ b)
//   4'h9 : SHL    - result = a << 1  (logical shift left)
//   4'hA : SHR    - result = a >> 1  (logical shift right)
//   4'hB : ASR    - result = a >>> 1 (arithmetic shift right)
//   4'hC : ROL    - result = {a[6:0], a[7]} (rotate left)
//   4'hD : ROR    - result = {a[0], a[7:1]} (rotate right)
//   4'hE : INC    - result = a + 1
//   4'hF : DEC    - result = a - 1
//
// Flags: {carry, overflow, zero, negative}
// =============================================================================

module alu_8bit (
    input  logic [7:0] a,        // Operand A
    input  logic [7:0] b,        // Operand B
    input  logic [3:0] opcode,   // Operation select
    output logic [7:0] result,   // ALU result
    output logic [3:0] flags     // {carry, overflow, zero, negative}
);

    // Internal signals for arithmetic with carry
    logic [8:0] add_result;
    logic [8:0] sub_result;
    logic [8:0] inc_result;
    logic [8:0] dec_result;

    logic        carry;
    logic        overflow;
    logic        zero;
    logic        negative;

    // Pre-compute arithmetic results to share across flag logic
    assign add_result = {1'b0, a} + {1'b0, b};
    assign sub_result = {1'b0, a} - {1'b0, b};
    assign inc_result = {1'b0, a} + 9'd1;
    assign dec_result = {1'b0, a} - 9'd1;

    // -------------------------------------------------------------------------
    // Main ALU operation
    // -------------------------------------------------------------------------
    always_comb begin
        // Default outputs to avoid latches
        result   = 8'h00;
        carry    = 1'b0;
        overflow = 1'b0;

        unique case (opcode)
            4'h0: begin // ADD
                result   = add_result[7:0];
                carry    = add_result[8];
                overflow = (~a[7] & ~b[7] &  result[7]) |
                           ( a[7] &  b[7] & ~result[7]);
            end

            4'h1: begin // SUB
                result   = sub_result[7:0];
                carry    = sub_result[8];           // borrow flag
                overflow = ( a[7] & ~b[7] & ~result[7]) |
                           (~a[7] &  b[7] &  result[7]);
            end

            4'h2: result = a & b;                  // AND

            4'h3: result = a | b;                  // OR

            4'h4: result = a ^ b;                  // XOR

            4'h5: result = ~a;                     // NOT

            4'h6: result = ~(a & b);               // NAND

            4'h7: result = ~(a | b);               // NOR

            4'h8: result = ~(a ^ b);               // XNOR

            4'h9: begin // SHL (logical shift left)
                result = a << 1;
                carry  = a[7];
            end

            4'hA: begin // SHR (logical shift right)
                result = a >> 1;
                carry  = a[0];
            end

            4'hB: result = $signed(a) >>> 1;       // ASR (arithmetic shift right)

            4'hC: result = {a[6:0], a[7]};         // ROL (rotate left)

            4'hD: result = {a[0], a[7:1]};         // ROR (rotate right)

            4'hE: begin // INC
                result   = inc_result[7:0];
                carry    = inc_result[8];
                overflow = (~a[7] & result[7]);
            end

            4'hF: begin // DEC
                result   = dec_result[7:0];
                carry    = dec_result[8];
                overflow = (a[7] & ~result[7]);
            end
        endcase
    end

    // -------------------------------------------------------------------------
    // Flag generation
    // -------------------------------------------------------------------------
    assign zero     = (result == 8'h00);
    assign negative = result[7];
    assign flags    = {carry, overflow, zero, negative};

endmodule
