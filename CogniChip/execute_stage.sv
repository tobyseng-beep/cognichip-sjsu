module execute_stage (
    input  logic        clock,
    input  logic        reset,
    input  logic [31:0] instr,
    input  logic [31:0] acc_in,
    output logic [63:0] result,
    output logic [3:0]  alu_flags,
    output logic [4:0]  wb_rd,
    output logic        wb_reg_write,
    output logic        wb_valid
);
    logic [4:0]  rs1, rs2, rd;
    logic        unit_sel;
    logic [3:0]  alu_opcode;
    logic [1:0]  mac_opcode;
    logic        reg_write;
    logic        valid_instr;

    logic [31:0] read_data1, read_data2;
    logic [63:0] dp_result;
    logic [3:0]  dp_flags;
    logic        dp_valid;

    logic [63:0] result_q;
    logic [3:0]  flags_q;
    logic [4:0]  rd_q;
    logic        rw_q;
    logic        valid_q;

    riscv_decoder u_dec (
        .instr      (instr),
        .rs1        (rs1),
        .rs2        (rs2),
        .rd         (rd),
        .unit_sel   (unit_sel),
        .alu_opcode (alu_opcode),
        .mac_opcode (mac_opcode),
        .reg_write  (reg_write),
        .valid_instr(valid_instr)
    );

    register_file u_rf (
        .clock      (clock),
        .reset      (reset),
        .rs1        (rs1),
        .rs2        (rs2),
        .rd         (rd_q),
        .write_data (result_q[31:0]),
        .reg_write  (rw_q),
        .read_data1 (read_data1),
        .read_data2 (read_data2)
    );

    alu_mac_datapath u_dp (
        .a_in        (read_data1),
        .b_in        (read_data2),
        .acc_in      (acc_in),
        .unit_sel    (unit_sel),
        .alu_opcode  (alu_opcode),
        .mac_opcode  (mac_opcode),
        .result      (dp_result),
        .alu_flags   (dp_flags),
        .result_valid(dp_valid)
    );

    always_ff @(posedge clock or posedge reset) begin
        if (reset) begin
            result_q <= 64'h0;
            flags_q  <= 4'h0;
            rd_q     <= 5'h0;
            rw_q     <= 1'b0;
            valid_q  <= 1'b0;
        end else begin
            result_q <= dp_result;
            flags_q  <= dp_flags;
            rd_q     <= rd;
            rw_q     <= reg_write & valid_instr;
            valid_q  <= valid_instr;
        end
    end

    assign result       = result_q;
    assign alu_flags    = flags_q;
    assign wb_rd        = rd_q;
    assign wb_reg_write = rw_q;
    assign wb_valid     = valid_q;
endmodule
