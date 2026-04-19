module fetch_stage #(parameter int IMEM_DEPTH = 16) (
    input  logic        clock,
    input  logic        reset,
    input  logic        stall,
    output logic [31:0] instr,
    output logic [31:0] pc
);
    logic [31:0] pc_reg;
    logic [31:0] imem [0:IMEM_DEPTH-1];

    // -------------------------------------------------------------------------
    // Demo program — 2x2 matrix multiply + DOT product showcase
    //
    //   x1 = 0x04030201  packed vector A: [1, 2, 3, 4] (4x 8-bit elements)
    //   x2 = 0x08070605  packed vector B: [5, 6, 7, 8] (4x 8-bit elements)
    //   x3 = DOT(x1,x2)  = 1*5+2*6+3*7+4*8 = 70 = 0x00000046
    //   x4 = MATMUL lower = {C[0][1], C[0][0]} = {22, 19} = 0x00160013
    //   x5 = MATMUL upper = {C[1][1], C[1][0]} = {50, 43} = 0x0032002B
    //   x6 = 100, x7 = 200, x8 = ADD(x6,x7) = 300  (32-bit scalar demo)
    //
    // Instruction encodings (little-endian 32-bit words):
    //   LUI  rd, imm20  : {imm[31:12], rd, 7'b0110111}
    //   ADDI rd,rs1,imm : {imm[11:0], rs1, 3'b000, rd, 7'b0010011}
    //   ADD  rd,rs1,rs2 : {7'b0, rs2, rs1, 3'b000, rd, 7'b0110011}
    //   DOT  rd,rs1,rs2 : {7'b0, rs2, rs1, 3'b001, rd, 7'b0001011}
    //   MATMUL rd,rs1,rs2:{7'b0, rs2, rs1, 3'b010, rd, 7'b0001011}
    //   NOP             : 32'h00000013  (ADDI x0,x0,0)
    // -------------------------------------------------------------------------
    integer k;
    initial begin
        for (k = 0; k < IMEM_DEPTH; k = k + 1) imem[k] = 32'h00000013; // NOP

        // [0]  LUI x1, 0x04030  →  x1[31:12] = 0x04030
        imem[0]  = 32'h040300B7;
        // [1]  ADDI x1, x1, 0x201  →  x1 = 0x04030201
        imem[1]  = 32'h20108093;
        // [2]  LUI x2, 0x08070  →  x2[31:12] = 0x08070
        imem[2]  = 32'h08070137;
        // [3]  ADDI x2, x2, 0x605  →  x2 = 0x08070605
        imem[3]  = 32'h60510113;
        // [4]  DOT x3, x1, x2  →  x3 = 70 = 0x46
        imem[4]  = 32'h0020918B;
        // [5]  MATMUL x4, x1, x2  →  x4 = 0x00160013, x5 = 0x0032002B
        imem[5]  = 32'h0020A20B;
        // [6]  ADDI x6, x0, 100
        imem[6]  = 32'h06400313;
        // [7]  ADDI x7, x0, 200
        imem[7]  = 32'h0C800393;
        // [8]  ADD  x8, x6, x7  →  x8 = 300
        imem[8]  = 32'h00730433;
        // [9-15] NOP (already filled above)
    end

    always_ff @(posedge clock or posedge reset) begin
        if (reset) pc_reg <= 32'h0;
        else if (!stall) pc_reg <= pc_reg + 32'd4;
    end

    assign pc    = pc_reg;
    assign instr = imem[pc_reg[$clog2(IMEM_DEPTH)+1:2]];

endmodule
