// =============================================================================
// Module  : execute_stage
// Description: Execute stage — receives pre-decoded control signals and
//              post-forwarding operands from riscv_core. No internal decoder
//              or register file (duplicate decoder removed). Pipeline register
//              at output captures result/flags/control on rising clock edge.
// =============================================================================

module execute_stage (
    input  logic        clock,
    input  logic        reset,

    // Pre-decoded control (from riscv_core's single riscv_decoder)
    input  logic [4:0]  rd_in,
    input  logic        unit_sel,
    input  logic [3:0]  alu_opcode,
    input  logic [1:0]  mac_opcode,
    input  logic        reg_write_in,
    input  logic        valid_instr,

    // Post-forwarding operands
    input  logic [31:0] op_a,
    input  logic [31:0] op_b,
    input  logic [31:0] acc_in,

    // Writeback outputs (pipeline-registered)
    output logic [63:0] result,
    output logic [3:0]  alu_flags,
    output logic [4:0]  wb_rd,
    output logic        wb_unit_sel,
    output logic [1:0]  wb_mac_opcode,
    output logic        wb_reg_write,
    output logic        wb_valid
);
    // -------------------------------------------------------------------------
    // Combinational datapath
    // -------------------------------------------------------------------------
    logic [63:0] dp_result;
    logic [3:0]  dp_flags;
    logic        dp_valid;

    alu_mac_datapath u_dp (
        .a_in        (op_a),
        .b_in        (op_b),
        .acc_in      (acc_in),
        .unit_sel    (unit_sel),
        .alu_opcode  (alu_opcode),
        .mac_opcode  (mac_opcode),
        .result      (dp_result),
        .alu_flags   (dp_flags),
        .result_valid(dp_valid)
    );

    // -------------------------------------------------------------------------
    // Pipeline register — clock-enabled on valid_instr.
    // When a NOP/bubble flows through (valid_instr=0), the 64-bit result and
    // flag registers are held stable to avoid unnecessary switching activity.
    // Write-enable outputs are explicitly cleared to prevent spurious writes.
    // -------------------------------------------------------------------------
    always_ff @(posedge clock or posedge reset) begin
        if (reset) begin
            result        <= 64'h0;
            alu_flags     <= 4'h0;
            wb_rd         <= 5'h0;
            wb_unit_sel   <= 1'b0;
            wb_mac_opcode <= 2'b00;
            wb_reg_write  <= 1'b0;
            wb_valid      <= 1'b0;
        end else if (valid_instr) begin
            // Valid instruction: capture full result and control
            result        <= dp_result;
            alu_flags     <= dp_flags;
            wb_rd         <= rd_in;
            wb_unit_sel   <= unit_sel;
            wb_mac_opcode <= mac_opcode;
            wb_reg_write  <= reg_write_in;
            wb_valid      <= 1'b1;
        end else begin
            // NOP/bubble: fully quiesce all control outputs.
            // Zeroing rd, unit_sel, mac_opcode prevents writeback_stage from
            // seeing stale toggling values and eliminates switching in the
            // downstream register file write-port address decode logic.
            wb_reg_write  <= 1'b0;
            wb_valid      <= 1'b0;
            wb_rd         <= 5'h0;
            wb_unit_sel   <= 1'b0;
            wb_mac_opcode <= 2'b00;
        end
    end

endmodule
