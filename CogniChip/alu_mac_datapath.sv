// =============================================================================
// Module  : alu_mac_datapath
// Description: Top-level combinational datapath muxing between the 32-bit ALU
//              and the MAC unit. The unit_sel signal routes the result.
//
//              Both units are instantiated but synthesis will clock-gate or
//              prune unused paths based on unit_sel. For explicit power
//              reduction, add enable gating on a_in/b_in if needed.
//
//              Note: immediate muxing (use_imm / lui_sel) is performed
//              upstream in riscv_core before operands reach this module.
// =============================================================================

module alu_mac_datapath (
    input  logic [31:0] a_in,           // Operand A (post-forwarding, 32-bit)
    input  logic [31:0] b_in,           // Operand B (post-forwarding/imm, 32-bit)
    input  logic [31:0] acc_in,         // Accumulator (MAC only)
    input  logic        unit_sel,       // 0 = ALU, 1 = MAC
    input  logic [3:0]  alu_opcode,
    input  logic [1:0]  mac_opcode,
    output logic [63:0] result,
    output logic [3:0]  alu_flags,
    output logic        result_valid
);
    logic [31:0] alu_result;
    logic [3:0]  alu_flags_int;
    logic [63:0] mac_result;
    logic        mac_valid;

    // 32-bit ALU — full datapath width
    alu_32bit u_alu (
        .a      (a_in),
        .b      (b_in),
        .opcode (alu_opcode),
        .result (alu_result),
        .flags  (alu_flags_int)
    );

    // MAC unit — operates on packed 8-bit vectors within the 32-bit operands
    mac_unit u_mac (
        .a_in   (a_in),
        .b_in   (b_in),
        .acc_in (acc_in),
        .opcode (mac_opcode),
        .result (mac_result),
        .valid  (mac_valid)
    );

    always_comb begin
        if (unit_sel == 1'b0) begin
            result       = {32'h0, alu_result};
            alu_flags    = alu_flags_int;
            result_valid = 1'b1;
        end else begin
            result       = mac_result;
            alu_flags    = 4'h0;
            result_valid = mac_valid;
        end
    end

endmodule
