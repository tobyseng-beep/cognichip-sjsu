module fetch_stage #(parameter int IMEM_DEPTH = 16) (
    input  logic        clock,
    input  logic        reset,
    input  logic        stall,
    output logic [31:0] instr,
    output logic [31:0] pc
);
    logic [31:0] pc_reg;
    logic [31:0] imem [0:IMEM_DEPTH-1];

    integer k;
    initial begin
        for (k = 0; k < IMEM_DEPTH; k = k + 1) imem[k] = 32'h0;
    end

    always_ff @(posedge clock or posedge reset) begin
        if (reset) pc_reg <= 32'h0;
        else if (!stall) pc_reg <= pc_reg + 32'd4;
    end

    assign pc    = pc_reg;
    assign instr = imem[pc_reg[$clog2(IMEM_DEPTH)+1:2]];
endmodule
