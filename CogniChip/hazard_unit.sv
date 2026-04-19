// =============================================================================
// Module  : hazard_unit
// Description: Forwarding control for the single-issue in-order RISC-V core.
//
//              With execute-result forwarding, RAW hazards are resolved without
//              stalls. This unit computes per-operand forwarding selects and
//              drives stall=0 (no loads in this ISA, so no load-use hazards).
//
//   fwd_a = '1'  operand A should come from the writeback result register
//   fwd_b = '1'  operand B should come from the writeback result register
//   stall = '0'  no pipeline stall required
// =============================================================================

module hazard_unit (
    input  logic [4:0] ex_rd,           // rd of instruction in writeback
    input  logic       ex_reg_write,    // writeback will write a register
    input  logic [4:0] dec_rs1,         // rs1 of instruction in decode
    input  logic [4:0] dec_rs2,         // rs2 of instruction in decode
    output logic       fwd_a,           // forward wb_result → operand A
    output logic       fwd_b,           // forward wb_result → operand B
    output logic       stall            // stall the fetch stage
);
    always_comb begin
        fwd_a = 1'b0;
        fwd_b = 1'b0;
        stall = 1'b0;   // no load-use hazards in this ISA

        if (ex_reg_write && (ex_rd != 5'h0)) begin
            if (ex_rd == dec_rs1) fwd_a = 1'b1;
            if (ex_rd == dec_rs2) fwd_b = 1'b1;
        end
    end
endmodule
