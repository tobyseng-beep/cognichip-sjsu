// =============================================================================
// Module  : mac_unit
// Description: Dedicated Multiply-Accumulate Unit for RISC-V custom ISA
//              extensions targeting small-scale linear algebra workloads.
//
//              Implements three custom instructions:
//                MAC    (2'b00) : result = acc_in + (a[7:0] * b[7:0])
//                DOT    (2'b01) : result = sum of a[i]*b[i] for i=0..3
//                                 (dot product of two 4-element 8-bit vectors)
//                MATMUL (2'b10) : result = 2x2 matrix multiply
//                                 (A and B are 2x2 matrices of 8-bit elements)
//
//  Operand packing (a_in / b_in — 32 bits = 4 x 8-bit elements):
//    bits [7:0]   = element[0]  (row0, col0 for matrix)
//    bits [15:8]  = element[1]  (row0, col1 for matrix)
//    bits [23:16] = element[2]  (row1, col0 for matrix)
//    bits [31:24] = element[3]  (row1, col1 for matrix)
//
//  Result packing (result — 64 bits):
//    MAC    : result[31:0]  = acc_in + a[0]*b[0]   (upper 32 bits = 0)
//    DOT    : result[31:0]  = dot product sum       (upper 32 bits = 0)
//    MATMUL : result[15:0]  = C[0][0]  (row0,col0)
//             result[31:16] = C[0][1]  (row0,col1)
//             result[47:32] = C[1][0]  (row1,col0)
//             result[63:48] = C[1][1]  (row1,col1)
//
//  All operations are purely combinational — no clock or reset required.
//  Intermediate products are 16-bit (8x8) and accumulation is 32-bit.
//  MATMUL outputs are 16-bit per element to preserve full precision.
// =============================================================================

module mac_unit (
    input  logic [31:0] a_in,       // Packed operand A: 4 x 8-bit elements
    input  logic [31:0] b_in,       // Packed operand B: 4 x 8-bit elements
    input  logic [31:0] acc_in,     // Accumulator input (used by MAC only)
    input  logic [1:0]  opcode,     // Operation: MAC=2'b00, DOT=2'b01, MATMUL=2'b10
    output logic [63:0] result,     // Result (see packing description above)
    output logic        valid       // High when opcode is a supported operation
);

    // -------------------------------------------------------------------------
    // Opcode definitions (matching RISC-V custom extension encoding intent)
    // -------------------------------------------------------------------------
    localparam logic [1:0] OP_MAC    = 2'b00;
    localparam logic [1:0] OP_DOT    = 2'b01;
    localparam logic [1:0] OP_MATMUL = 2'b10;

    // -------------------------------------------------------------------------
    // Unpack operands into named element arrays
    // a[0..3] and b[0..3] are the 8-bit elements of each packed 32-bit operand
    // -------------------------------------------------------------------------
    logic [7:0] a [0:3];
    logic [7:0] b [0:3];

    assign a[0] = a_in[7:0];
    assign a[1] = a_in[15:8];
    assign a[2] = a_in[23:16];
    assign a[3] = a_in[31:24];

    assign b[0] = b_in[7:0];
    assign b[1] = b_in[15:8];
    assign b[2] = b_in[23:16];
    assign b[3] = b_in[31:24];

    // -------------------------------------------------------------------------
    // Opcode-based gate enables — used to silence multiplier inputs when a
    // product is not needed by the active operation, reducing dynamic power.
    //
    //   Products required per opcode:
    //     OP_MAC    : prod_00 only                            (1 of 10 active)
    //     OP_DOT    : prod_00, prod_11, prod_22, prod_33      (4 of 10 active)
    //     OP_MATMUL : prod_00, prod_01, prod_12, prod_13,     (8 of 10 active)
    //                 prod_20, prod_21, prod_32, prod_33
    //
    //   6 products (prod[0][2], prod[0][3], prod[1][0], prod[2][3],
    //               prod[3][0], prod[3][1]) are NEVER needed and removed.
    // -------------------------------------------------------------------------
    logic dot_en;       // high for DOT (diagonal products)
    logic matmul_en;    // high for MATMUL (off-diagonal products)
    logic dot_mm_en;    // high for DOT or MATMUL (prod_33 shared)

    assign dot_en    = (opcode == OP_DOT);
    assign matmul_en = (opcode == OP_MATMUL);
    assign dot_mm_en = dot_en | matmul_en;

    // -------------------------------------------------------------------------
    // Partial products — only the 10 products actually consumed by any op.
    // Gate operand A to zero for inactive products; multiplier output = 0.
    // -------------------------------------------------------------------------

    // prod[0][0] = a[0]*b[0] — used by MAC, DOT, MATMUL (always active)
    logic [15:0] prod_00;
    assign prod_00 = {8'h0, a[0]} * {8'h0, b[0]};

    // prod[0][1] = a[0]*b[1] — MATMUL only (c01)
    logic [15:0] prod_01;
    assign prod_01 = {8'h0, (matmul_en ? a[0] : 8'h0)} * {8'h0, b[1]};

    // prod[1][1] = a[1]*b[1] — DOT only
    logic [15:0] prod_11;
    assign prod_11 = {8'h0, (dot_en ? a[1] : 8'h0)} * {8'h0, b[1]};

    // prod[1][2] = a[1]*b[2] — MATMUL only (c00)
    logic [15:0] prod_12;
    assign prod_12 = {8'h0, (matmul_en ? a[1] : 8'h0)} * {8'h0, b[2]};

    // prod[1][3] = a[1]*b[3] — MATMUL only (c01)
    logic [15:0] prod_13;
    assign prod_13 = {8'h0, (matmul_en ? a[1] : 8'h0)} * {8'h0, b[3]};

    // prod[2][0] = a[2]*b[0] — MATMUL only (c10)
    logic [15:0] prod_20;
    assign prod_20 = {8'h0, (matmul_en ? a[2] : 8'h0)} * {8'h0, b[0]};

    // prod[2][1] = a[2]*b[1] — MATMUL only (c11)
    logic [15:0] prod_21;
    assign prod_21 = {8'h0, (matmul_en ? a[2] : 8'h0)} * {8'h0, b[1]};

    // prod[2][2] = a[2]*b[2] — DOT only
    logic [15:0] prod_22;
    assign prod_22 = {8'h0, (dot_en ? a[2] : 8'h0)} * {8'h0, b[2]};

    // prod[3][2] = a[3]*b[2] — MATMUL only (c10)
    logic [15:0] prod_32;
    assign prod_32 = {8'h0, (matmul_en ? a[3] : 8'h0)} * {8'h0, b[2]};

    // prod[3][3] = a[3]*b[3] — DOT and MATMUL (c11)
    logic [15:0] prod_33;
    assign prod_33 = {8'h0, (dot_mm_en ? a[3] : 8'h0)} * {8'h0, b[3]};

    // -------------------------------------------------------------------------
    // DOT product: sum a[i]*b[i] for i = 0..3
    //   = a[0]*b[0] + a[1]*b[1] + a[2]*b[2] + a[3]*b[3]
    //   Max value: 4 * (255*255) = 260,100 → fits in 18 bits → use 32-bit
    // -------------------------------------------------------------------------
    logic [31:0] dot_result;
    assign dot_result = {16'h0, prod_00}
                      + {16'h0, prod_11}
                      + {16'h0, prod_22}
                      + {16'h0, prod_33};

    // -------------------------------------------------------------------------
    // MAC: acc_in + a[0] * b[0]
    //   Single element multiply-accumulate, 32-bit accumulation
    // -------------------------------------------------------------------------
    logic [31:0] mac_result;
    assign mac_result = acc_in + {16'h0, prod_00};

    // -------------------------------------------------------------------------
    // MATMUL: 2x2 matrix multiply
    //   Matrix A layout (row-major in a_in):
    //     A = | a[0]  a[1] |
    //         | a[2]  a[3] |
    //
    //   Matrix B layout (row-major in b_in):
    //     B = | b[0]  b[1] |
    //         | b[2]  b[3] |
    //
    //   C = A * B:
    //     C[0][0] = a[0]*b[0] + a[1]*b[2]   (row0·col0)
    //     C[0][1] = a[0]*b[1] + a[1]*b[3]   (row0·col1)
    //     C[1][0] = a[2]*b[0] + a[3]*b[2]   (row1·col0)
    //     C[1][1] = a[2]*b[1] + a[3]*b[3]   (row1·col1)
    //
    //   Each C element is 16-bit (max: 2 * 255*255 = 130,050 < 2^17)
    // -------------------------------------------------------------------------
    logic [15:0] c00, c01, c10, c11;

    assign c00 = prod_00 + prod_12;   // a[0]*b[0] + a[1]*b[2]
    assign c01 = prod_01 + prod_13;   // a[0]*b[1] + a[1]*b[3]
    assign c10 = prod_20 + prod_32;   // a[2]*b[0] + a[3]*b[2]
    assign c11 = prod_21 + prod_33;   // a[2]*b[1] + a[3]*b[3]

    // -------------------------------------------------------------------------
    // Output mux and valid flag
    // -------------------------------------------------------------------------
    always_comb begin
        result = 64'h0;
        valid  = 1'b1;

        unique case (opcode)
            OP_MAC: begin
                result = {32'h0, mac_result};
            end
            OP_DOT: begin
                result = {32'h0, dot_result};
            end
            OP_MATMUL: begin
                result = {c11, c10, c01, c00};
            end
            default: begin
                result = 64'h0;
                valid  = 1'b0;
            end
        endcase
    end

endmodule
