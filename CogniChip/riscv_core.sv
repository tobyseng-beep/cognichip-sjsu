// =============================================================================
// Module  : riscv_core
// Description: Pipeline top-level: fetch, decode, register read, forwarding
//              mux, execute, and writeback. Single decoder instance.
//              Forwarding eliminates all RAW stalls (no loads in ISA).
// =============================================================================

module riscv_core #(parameter int IMEM_DEPTH = 16) (
    input  logic        clock,
    input  logic        reset,
    input  logic [31:0] acc_in,
    output logic [63:0] result,
    output logic [3:0]  alu_flags,
    output logic [4:0]  wb_rd,
    output logic        wb_reg_write,
    output logic        wb_valid,
    output logic [31:0] pc_out
);
    // -------------------------------------------------------------------------
    // Fetch
    // -------------------------------------------------------------------------
    logic [31:0] fetch_instr;
    logic [31:0] pc;
    logic        stall;

    fetch_stage #(.IMEM_DEPTH(IMEM_DEPTH)) u_fetch (
        .clock (clock),
        .reset (reset),
        .stall (stall),
        .instr (fetch_instr),
        .pc    (pc)
    );

    assign pc_out = pc;

    // -------------------------------------------------------------------------
    // Decode — single instance
    // -------------------------------------------------------------------------
    logic [4:0]  dec_rs1, dec_rs2, dec_rd;
    logic        dec_unit_sel;
    logic [3:0]  dec_alu_opcode;
    logic [1:0]  dec_mac_opcode;
    logic        dec_reg_write;
    logic        dec_valid;
    logic [31:0] dec_imm_val;
    logic        dec_use_imm;
    logic        dec_lui_sel;

    // Insert NOP bubble on stall (ADDI x0,x0,0 = 32'h00000013)
    logic [31:0] instr_muxed;
    assign instr_muxed = stall ? 32'h00000013 : fetch_instr;

    riscv_decoder u_dec (
        .instr       (instr_muxed),
        .rs1         (dec_rs1),
        .rs2         (dec_rs2),
        .rd          (dec_rd),
        .unit_sel    (dec_unit_sel),
        .alu_opcode  (dec_alu_opcode),
        .mac_opcode  (dec_mac_opcode),
        .reg_write   (dec_reg_write),
        .valid_instr (dec_valid),
        .imm_val     (dec_imm_val),
        .use_imm     (dec_use_imm),
        .lui_sel     (dec_lui_sel)
    );

    // -------------------------------------------------------------------------
    // Register file — owned here, dual write ports
    // -------------------------------------------------------------------------
    logic [31:0] rf_data1, rf_data2;
    logic [31:0] wb_data_lo, wb_data_hi;
    logic [4:0]  wb_rd_lo,  wb_rd_hi;
    logic        wb_en_lo,  wb_en_hi;

    register_file u_rf (
        .clock       (clock),
        .reset       (reset),
        .rs1         (dec_rs1),
        .rs2         (dec_rs2),
        .read_data1  (rf_data1),
        .read_data2  (rf_data2),
        .rd          (wb_rd_lo),
        .write_data  (wb_data_lo),
        .reg_write   (wb_en_lo),
        .rd2         (wb_rd_hi),
        .write_data2 (wb_data_hi),
        .reg_write2  (wb_en_hi)
    );

    // -------------------------------------------------------------------------
    // Hazard / forwarding unit
    // -------------------------------------------------------------------------
    logic fwd_a, fwd_b;

    hazard_unit u_haz (
        .ex_rd       (wb_rd),
        .ex_reg_write(wb_reg_write),
        .dec_rs1     (dec_rs1),
        .dec_rs2     (dec_rs2),
        .fwd_a       (fwd_a),
        .fwd_b       (fwd_b),
        .stall       (stall)
    );

    // -------------------------------------------------------------------------
    // Forwarding mux + immediate mux
    //   op_a: LUI→0, fwd_a→result[31:0], else rf_data1
    //   op_b: use_imm→dec_imm_val, fwd_b→result[31:0], else rf_data2
    // -------------------------------------------------------------------------
    logic [31:0] op_a, op_b;

    always_comb begin
        if (dec_lui_sel)
            op_a = 32'h0;
        else if (fwd_a)
            op_a = result[31:0];
        else
            op_a = rf_data1;

        if (dec_use_imm)
            op_b = dec_imm_val;
        else if (fwd_b)
            op_b = result[31:0];
        else
            op_b = rf_data2;
    end

    // -------------------------------------------------------------------------
    // Execute stage
    // -------------------------------------------------------------------------
    logic        ex_unit_sel;
    logic [1:0]  ex_mac_opcode;

    execute_stage u_exec (
        .clock        (clock),
        .reset        (reset),
        .rd_in        (dec_rd),
        .unit_sel     (dec_unit_sel),
        .alu_opcode   (dec_alu_opcode),
        .mac_opcode   (dec_mac_opcode),
        .reg_write_in (dec_reg_write),
        .valid_instr  (dec_valid),
        .op_a         (op_a),
        .op_b         (op_b),
        .acc_in       (acc_in),
        .result       (result),
        .alu_flags    (alu_flags),
        .wb_rd        (wb_rd),
        .wb_unit_sel  (ex_unit_sel),
        .wb_mac_opcode(ex_mac_opcode),
        .wb_reg_write (wb_reg_write),
        .wb_valid     (wb_valid)
    );

    // -------------------------------------------------------------------------
    // Writeback stage — splits 64-bit result for dual RF write
    // -------------------------------------------------------------------------
    writeback_stage u_wb (
        .result     (result),
        .unit_sel   (ex_unit_sel),
        .mac_opcode (ex_mac_opcode),
        .rd         (wb_rd),
        .reg_write  (wb_reg_write),
        .wb_data_lo (wb_data_lo),
        .wb_data_hi (wb_data_hi),
        .wb_rd_lo   (wb_rd_lo),
        .wb_rd_hi   (wb_rd_hi),
        .wb_en_lo   (wb_en_lo),
        .wb_en_hi   (wb_en_hi)
    );

endmodule
