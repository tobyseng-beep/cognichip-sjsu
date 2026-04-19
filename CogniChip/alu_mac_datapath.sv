// =============================================================================
// Module  : alu_mac_datapath
// Description: Top-level combinational datapath muxing between the 32-bit ALU
//              and the MAC unit. The unit_sel signal routes the result.
//
//              Operand isolation: inputs to the inactive unit are forced to
//              zero, preventing unnecessary switching activity and reducing
//              dynamic power consumption in the ALU adder tree and MAC
//              multiplier array.
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

    // -------------------------------------------------------------------------
    // Operand isolation — gate inputs to the inactive unit to zero.
    // This prevents switching activity in the ALU adder/logic tree when the
    // MAC is selected, and in the MAC multiplier array when ALU is selected.
    // -------------------------------------------------------------------------
    logic [31:0] alu_a, alu_b;
    logic [31:0] mac_a, mac_b, mac_acc;

    assign alu_a   = unit_sel ? 32'h0 : a_in;
    assign alu_b   = unit_sel ? 32'h0 : b_in;
    assign mac_a   = unit_sel ? a_in  : 32'h0;
    assign mac_b   = unit_sel ? b_in  : 32'h0;
    assign mac_acc = unit_sel ? acc_in : 32'h0;

    // -------------------------------------------------------------------------
    // Opcode isolation — freeze the inactive unit's opcode to a benign value.
    // When MAC is selected, the ALU opcode is zeroed so the ALU case-select
    // logic sees a stable input and produces no glitch switching.
    // When ALU is selected, the MAC opcode is set to 2'b11 (invalid/default)
    // so the MAC output mux stays at its default zero branch.
    // -------------------------------------------------------------------------
    logic [3:0] alu_opcode_g;
    logic [1:0] mac_opcode_g;
    assign alu_opcode_g = unit_sel ? 4'h0  : alu_opcode;   // ALU frozen when MAC active
    assign mac_opcode_g = unit_sel ? mac_opcode : 2'b11;   // MAC frozen to invalid when ALU active

    // 32-bit ALU — full datapath width
    alu_32bit u_alu (
        .a      (alu_a),
        .b      (alu_b),
        .opcode (alu_opcode_g),
        .result (alu_result),
        .flags  (alu_flags_int)
    );

    // MAC unit — operates on packed 8-bit vectors within the 32-bit operands
    mac_unit u_mac (
        .a_in   (mac_a),
        .b_in   (mac_b),
        .acc_in (mac_acc),
        .opcode (mac_opcode_g),
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
