// =============================================================================
// Module  : alu_32bit
// Description: 32-bit ALU supporting standard arithmetic and logic operations.
//              Purely combinational for power efficiency. Outputs a 4-bit flag
//              bus: {carry, overflow, zero, negative}.
//
//              Widened from alu_8bit to operate on full 32-bit RISC-V datapath.
//
// Opcodes (matching alu_8bit encoding — opcode field unchanged):
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
//   4'hC : ROL    - result = {a[30:0], a[31]} (rotate left)
//   4'hD : ROR    - result = {a[0], a[31:1]}  (rotate right)
//   4'hE : INC    - result = a + 1
//   4'hF : DEC    - result = a - 1
//
// Flags: {carry, overflow, zero, negative}
//   carry    : unsigned carry/borrow out of bit 31
//   overflow : signed two's-complement overflow
//   zero     : result == 32'h0
//   negative : result[31]
// =============================================================================

module alu_32bit (
    input  logic [31:0] a,        // Operand A
    input  logic [31:0] b,        // Operand B
    input  logic [3:0]  opcode,   // Operation select
    output logic [31:0] result,   // ALU result
    output logic [3:0]  flags     // {carry, overflow, zero, negative}
);

    // -------------------------------------------------------------------------
    // 33-bit arithmetic signals to capture carry/borrow out of bit 31
    // -------------------------------------------------------------------------
    logic [32:0] add_result;
    logic [32:0] sub_result;
    logic [32:0] inc_result;
    logic [32:0] dec_result;

    logic        carry;
    logic        overflow;
    logic        zero;
    logic        negative;

    // Pre-compute arithmetic — shared between result mux and flag logic
    assign add_result = {1'b0, a} + {1'b0, b};
    assign sub_result = {1'b0, a} - {1'b0, b};
    assign inc_result = {1'b0, a} + 33'd1;
    assign dec_result = {1'b0, a} - 33'd1;

    // -------------------------------------------------------------------------
    // Main ALU operation
    // -------------------------------------------------------------------------
    always_comb begin
        result   = 32'h0;
        carry    = 1'b0;
        overflow = 1'b0;

        unique case (opcode)
            4'h0: begin // ADD
                result   = add_result[31:0];
                carry    = add_result[32];
                overflow = (~a[31] & ~b[31] &  result[31]) |
                           ( a[31] &  b[31] & ~result[31]);
            end

            4'h1: begin // SUB
                result   = sub_result[31:0];
                carry    = sub_result[32];           // borrow flag
                overflow = ( a[31] & ~b[31] & ~result[31]) |
                           (~a[31] &  b[31] &  result[31]);
            end

            4'h2: result = a & b;                   // AND

            4'h3: result = a | b;                   // OR

            4'h4: result = a ^ b;                   // XOR

            4'h5: result = ~a;                      // NOT

            4'h6: result = ~(a & b);                // NAND

            4'h7: result = ~(a | b);                // NOR

            4'h8: result = ~(a ^ b);                // XNOR

            4'h9: begin // SHL (logical shift left by 1)
                result = a << 1;
                carry  = a[31];
            end

            4'hA: begin // SHR (logical shift right by 1)
                result = a >> 1;
                carry  = a[0];
            end

            4'hB: result = $signed(a) >>> 1;        // ASR (arithmetic shift right)

            4'hC: result = {a[30:0], a[31]};        // ROL (rotate left)

            4'hD: result = {a[0], a[31:1]};         // ROR (rotate right)

            4'hE: begin // INC
                result   = inc_result[31:0];
                carry    = inc_result[32];
                overflow = (~a[31] & result[31]);
            end

            4'hF: begin // DEC
                result   = dec_result[31:0];
                carry    = dec_result[32];
                overflow = (a[31] & ~result[31]);
            end
        endcase
    end

    // -------------------------------------------------------------------------
    // Flag generation — derived directly from result
    // -------------------------------------------------------------------------
    assign zero     = (result == 32'h0);
    assign negative = result[31];
    assign flags    = {carry, overflow, zero, negative};

endmodule
