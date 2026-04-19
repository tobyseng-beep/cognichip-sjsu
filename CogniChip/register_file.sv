// =============================================================================
// Module  : register_file
// Description: 32-entry x 32-bit register file with two read ports and
//              two synchronous write ports.
//
//   Port 1 (primary)  : writes ALU / ADDI / LUI / MAC / DOT results (wb_data_lo)
//   Port 2 (secondary): writes MATMUL upper half into rd+1 (wb_data_hi)
//
//   x0 is hardwired to zero — writes to rd==0 or rd2==0 are silently ignored.
// =============================================================================

module register_file (
    input  logic        clock,
    input  logic        reset,
    // Read ports (combinational)
    input  logic [4:0]  rs1,
    input  logic [4:0]  rs2,
    output logic [31:0] read_data1,
    output logic [31:0] read_data2,
    // Write port 1 — primary result
    input  logic [4:0]  rd,
    input  logic [31:0] write_data,
    input  logic        reg_write,
    // Write port 2 — MATMUL upper half (rd+1)
    input  logic [4:0]  rd2,
    input  logic [31:0] write_data2,
    input  logic        reg_write2
);

    logic [31:0] regs [0:31];

    always_ff @(posedge clock or posedge reset) begin
        if (reset) begin
            for (int i = 0; i < 32; i++) regs[i] <= 32'h0;
        end else begin
            if (reg_write  && (rd  != 5'h0)) regs[rd]  <= write_data;
            if (reg_write2 && (rd2 != 5'h0)) regs[rd2] <= write_data2;
        end
    end

    assign read_data1 = (rs1 == 5'h0) ? 32'h0 : regs[rs1];
    assign read_data2 = (rs2 == 5'h0) ? 32'h0 : regs[rs2];

endmodule
