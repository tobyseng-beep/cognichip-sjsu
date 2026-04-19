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
    // Pre-compute all 8x8 partial products (shared across DOT and MATMUL)
    //   prod[i][j] = a[i] * b[j]  (16-bit result, no overflow)
    // -------------------------------------------------------------------------
    logic [15:0] prod [0:3][0:3];

    genvar gi, gj;
    generate
        for (gi = 0; gi < 4; gi++) begin : gen_row
            for (gj = 0; gj < 4; gj++) begin : gen_col
                assign prod[gi][gj] = {8'h00, a[gi]} * {8'h00, b[gj]};
            end
        end
    endgenerate

    // -------------------------------------------------------------------------
    // DOT product: sum a[i]*b[i] for i = 0..3
    //   = a[0]*b[0] + a[1]*b[1] + a[2]*b[2] + a[3]*b[3]
    //   Max value: 4 * (255*255) = 260,100 → fits in 18 bits → use 32-bit
    // -------------------------------------------------------------------------
    logic [31:0] dot_result;
    assign dot_result = {16'h0, prod[0][0]}
                      + {16'h0, prod[1][1]}
                      + {16'h0, prod[2][2]}
                      + {16'h0, prod[3][3]};

    // -------------------------------------------------------------------------
    // MAC: acc_in + a[0] * b[0]
    //   Single element multiply-accumulate, 32-bit accumulation
    // -------------------------------------------------------------------------
    logic [31:0] mac_result;
    assign mac_result = acc_in + {16'h0, prod[0][0]};

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

    assign c00 = prod[0][0] + prod[1][2];   // a[0]*b[0] + a[1]*b[2]
    assign c01 = prod[0][1] + prod[1][3];   // a[0]*b[1] + a[1]*b[3]
    assign c10 = prod[2][0] + prod[3][2];   // a[2]*b[0] + a[3]*b[2]
    assign c11 = prod[2][1] + prod[3][3];   // a[2]*b[1] + a[3]*b[3]

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
