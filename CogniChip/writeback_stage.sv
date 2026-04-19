module writeback_stage (
    input  logic [63:0] result,
    input  logic        unit_sel,
    input  logic [1:0]  mac_opcode,
    input  logic [4:0]  rd,
    input  logic        reg_write,
    output logic [31:0] wb_data_lo,
    output logic [31:0] wb_data_hi,
    output logic [4:0]  wb_rd_lo,
    output logic [4:0]  wb_rd_hi,
    output logic        wb_en_lo,
    output logic        wb_en_hi
);
    localparam logic [1:0] OP_MATMUL = 2'b10;

    assign wb_data_lo = result[31:0];
    assign wb_data_hi = result[63:32];
    assign wb_rd_lo   = rd;
    assign wb_rd_hi   = (rd != 5'd31) ? rd + 5'd1 : 5'd0;
    assign wb_en_lo   = reg_write;
    assign wb_en_hi   = reg_write & unit_sel & (mac_opcode == OP_MATMUL) & (rd != 5'd31);
endmodule
