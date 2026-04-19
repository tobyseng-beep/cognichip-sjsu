module register_file (
    input  logic        clock,
    input  logic        reset,
    input  logic [4:0]  rs1,
    input  logic [4:0]  rs2,
    input  logic [4:0]  rd,
    input  logic [31:0] write_data,
    input  logic        reg_write,
    output logic [31:0] read_data1,
    output logic [31:0] read_data2
);
    logic [31:0] regs [0:31];

    always_ff @(posedge clock or posedge reset) begin
        if (reset) begin
            for (int i = 0; i < 32; i++) regs[i] <= 32'h0;
        end else if (reg_write && (rd != 5'h0)) begin
            regs[rd] <= write_data;
        end
    end

    assign read_data1 = (rs1 == 5'h0) ? 32'h0 : regs[rs1];
    assign read_data2 = (rs2 == 5'h0) ? 32'h0 : regs[rs2];
endmodule
