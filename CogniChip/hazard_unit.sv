module hazard_unit (
    input  logic [4:0] ex_rd,
    input  logic       ex_reg_write,
    input  logic [4:0] dec_rs1,
    input  logic [4:0] dec_rs2,
    output logic       stall
);
    always_comb begin
        stall = 1'b0;
        if (ex_reg_write && (ex_rd != 5'h0)) begin
            if ((ex_rd == dec_rs1) || (ex_rd == dec_rs2))
                stall = 1'b1;
        end
    end
endmodule
