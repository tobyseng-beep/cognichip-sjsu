module alu_mac_datapath (
    input  logic [31:0] a_in,
    input  logic [31:0] b_in,
    input  logic [31:0] acc_in,
    input  logic        unit_sel,
    input  logic [3:0]  alu_opcode,
    input  logic [1:0]  mac_opcode,
    output logic [63:0] result,
    output logic [3:0]  alu_flags,
    output logic        result_valid
);
    logic [7:0]  alu_result;
    logic [3:0]  alu_flags_int;
    logic [63:0] mac_result;
    logic        mac_valid;

    alu_8bit u_alu (
        .a      (a_in[7:0]),
        .b      (b_in[7:0]),
        .opcode (alu_opcode),
        .result (alu_result),
        .flags  (alu_flags_int)
    );

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
            result       = {56'h0, alu_result};
            alu_flags    = alu_flags_int;
            result_valid = 1'b1;
        end else begin
            result       = mac_result;
            alu_flags    = 4'h0;
            result_valid = mac_valid;
        end
    end
endmodule
