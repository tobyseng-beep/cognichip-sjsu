// =============================================================================
// Module  : riscv_decoder
// Description: Instruction decoder for the custom RISC-V core.
//              Supports:
//                R-type  (opcode 0110011): ADD, SUB, AND, OR, XOR, SLL, SRL, SRA
//                I-type  (opcode 0010011): ADDI
//                U-type  (opcode 0110111): LUI
//                CUSTOM0 (opcode 0001011): MAC, DOT, MATMUL
//
//              New outputs:
//                imm_val  [31:0] — sign-extended immediate (I-type) or
//                                   upper-20 immediate << 12 (LUI)
//                use_imm         — '1' when op_b should come from imm_val
//                lui_sel         — '1' for LUI: forces op_a = 0 in the core
// =============================================================================

module riscv_decoder (
    input  logic [31:0] instr,
    output logic [4:0]  rs1,
    output logic [4:0]  rs2,
    output logic [4:0]  rd,
    output logic        unit_sel,       // 0 = ALU, 1 = MAC
    output logic [3:0]  alu_opcode,
    output logic [1:0]  mac_opcode,
    output logic        reg_write,
    output logic        valid_instr,
    output logic [31:0] imm_val,        // sign-extended / shifted immediate
    output logic        use_imm,        // '1' → use imm_val as operand B
    output logic        lui_sel         // '1' → force operand A = 0 (LUI)
);
    localparam logic [6:0] OP_RTYPE   = 7'b0110011;   // R-type ALU
    localparam logic [6:0] OP_ITYPE   = 7'b0010011;   // I-type (ADDI)
    localparam logic [6:0] OP_LUI     = 7'b0110111;   // U-type LUI
    localparam logic [6:0] OP_CUSTOM0 = 7'b0001011;   // Custom MAC/DOT/MATMUL

    localparam logic [2:0] F3_ADD_SUB = 3'b000;
    localparam logic [2:0] F3_SLL     = 3'b001;
    localparam logic [2:0] F3_XOR     = 3'b100;
    localparam logic [2:0] F3_SRL_SRA = 3'b101;
    localparam logic [2:0] F3_OR      = 3'b110;
    localparam logic [2:0] F3_AND     = 3'b111;
    localparam logic [2:0] F3_MAC     = 3'b000;
    localparam logic [2:0] F3_DOT     = 3'b001;
    localparam logic [2:0] F3_MATMUL  = 3'b010;

    // -------------------------------------------------------------------------
    // Instruction field extraction
    // -------------------------------------------------------------------------
    logic [6:0] opcode;
    logic [2:0] funct3;
    logic [6:0] funct7;

    assign opcode = instr[6:0];
    assign rd     = instr[11:7];
    assign funct3 = instr[14:12];
    assign rs1    = instr[19:15];
    assign rs2    = instr[24:20];
    assign funct7 = instr[31:25];

    // -------------------------------------------------------------------------
    // Immediate generation
    //   I-type : sign-extend instr[31:20] to 32 bits
    //   U-type : {instr[31:12], 12'h0}
    // -------------------------------------------------------------------------
    logic [31:0] imm_i;
    logic [31:0] imm_u;

    assign imm_i = {{20{instr[31]}}, instr[31:20]};
    assign imm_u = {instr[31:12], 12'h0};

    // -------------------------------------------------------------------------
    // Decode
    // -------------------------------------------------------------------------
    always_comb begin
        unit_sel    = 1'b0;
        alu_opcode  = 4'h0;
        mac_opcode  = 2'b00;
        reg_write   = 1'b0;
        valid_instr = 1'b0;
        imm_val     = 32'h0;
        use_imm     = 1'b0;
        lui_sel     = 1'b0;

        case (opcode)

            // R-type
            OP_RTYPE: begin
                reg_write   = 1'b1;
                valid_instr = 1'b1;
                unit_sel    = 1'b0;
                case (funct3)
                    F3_ADD_SUB: alu_opcode = funct7[5] ? 4'h1 : 4'h0;
                    F3_AND:     alu_opcode = 4'h2;
                    F3_OR:      alu_opcode = 4'h3;
                    F3_XOR:     alu_opcode = 4'h4;
                    F3_SLL:     alu_opcode = 4'h9;
                    F3_SRL_SRA: alu_opcode = funct7[5] ? 4'hB : 4'hA;
                    default:    valid_instr = 1'b0;
                endcase
            end

            // I-type: ADDI — rd = rs1 + sign_ext(imm[11:0])
            OP_ITYPE: begin
                reg_write   = 1'b1;
                valid_instr = 1'b1;
                unit_sel    = 1'b0;
                use_imm     = 1'b1;
                imm_val     = imm_i;
                case (funct3)
                    F3_ADD_SUB: alu_opcode = 4'h0;   // ADDI → ADD opcode
                    default:    valid_instr = 1'b0;
                endcase
            end

            // U-type: LUI — rd = {imm[31:12], 12'b0}
            //   Implemented as 0 + imm_u; lui_sel forces op_a = 0 in core
            OP_LUI: begin
                reg_write   = 1'b1;
                valid_instr = 1'b1;
                unit_sel    = 1'b0;
                use_imm     = 1'b1;
                lui_sel     = 1'b1;
                imm_val     = imm_u;
                alu_opcode  = 4'h0;  // ADD: 0 + imm_u
            end

            // CUSTOM0: MAC / DOT / MATMUL
            OP_CUSTOM0: begin
                reg_write   = 1'b1;
                valid_instr = 1'b1;
                unit_sel    = 1'b1;
                case (funct3)
                    F3_MAC:    mac_opcode = 2'b00;
                    F3_DOT:    mac_opcode = 2'b01;
                    F3_MATMUL: mac_opcode = 2'b10;
                    default:   valid_instr = 1'b0;
                endcase
            end

            default: valid_instr = 1'b0;

        endcase
    end

endmodule
