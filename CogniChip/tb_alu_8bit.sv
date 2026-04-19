// =============================================================================
// Module  : tb_alu_8bit
// Description: Directed + constrained-random testbench for alu_8bit.
//              Covers all 16 opcodes, boundary values, edge cases, and all
//              four status flags: carry, overflow, zero, negative.
//
// Coverage:
//   - All 16 opcodes exercised
//   - Boundary inputs: 0x00, 0x7F, 0x80, 0xFF for each opcode
//   - 200 random vectors per opcode
//   - All four flags verified independently
// =============================================================================

module tb_alu_8bit;

    // -------------------------------------------------------------------------
    // Opcode parameters
    // -------------------------------------------------------------------------
    localparam logic [3:0] OP_ADD  = 4'h0;
    localparam logic [3:0] OP_SUB  = 4'h1;
    localparam logic [3:0] OP_AND  = 4'h2;
    localparam logic [3:0] OP_OR   = 4'h3;
    localparam logic [3:0] OP_XOR  = 4'h4;
    localparam logic [3:0] OP_NOT  = 4'h5;
    localparam logic [3:0] OP_NAND = 4'h6;
    localparam logic [3:0] OP_NOR  = 4'h7;
    localparam logic [3:0] OP_XNOR = 4'h8;
    localparam logic [3:0] OP_SHL  = 4'h9;
    localparam logic [3:0] OP_SHR  = 4'hA;
    localparam logic [3:0] OP_ASR  = 4'hB;
    localparam logic [3:0] OP_ROL  = 4'hC;
    localparam logic [3:0] OP_ROR  = 4'hD;
    localparam logic [3:0] OP_INC  = 4'hE;
    localparam logic [3:0] OP_DEC  = 4'hF;

    // -------------------------------------------------------------------------
    // DUT signals
    // -------------------------------------------------------------------------
    logic [7:0] a, b;
    logic [3:0] opcode;
    logic [7:0] result;
    logic [3:0] flags;

    // Unpacked flags
    logic        flag_carry, flag_overflow, flag_zero, flag_negative;
    assign flag_carry    = flags[3];
    assign flag_overflow = flags[2];
    assign flag_zero     = flags[1];
    assign flag_negative = flags[0];

    // -------------------------------------------------------------------------
    // DUT instantiation
    // -------------------------------------------------------------------------
    alu_8bit dut (
        .a      (a),
        .b      (b),
        .opcode (opcode),
        .result (result),
        .flags  (flags)
    );

    // -------------------------------------------------------------------------
    // Test tracking
    // -------------------------------------------------------------------------
    int test_count;
    int fail_count;

    // -------------------------------------------------------------------------
    // Golden reference model
    // -------------------------------------------------------------------------
    // Returns {flags[3:0], result[7:0]} = 12-bit packed value
    function automatic logic [11:0] golden (
        input logic [7:0] op_a,
        input logic [7:0] op_b,
        input logic [3:0] op
    );
        logic [8:0]  arith9;
        logic [7:0]  res;
        logic        c, ov, z, n;

        c  = 1'b0;
        ov = 1'b0;
        res = 8'h00;

        case (op)
            OP_ADD: begin
                arith9 = {1'b0, op_a} + {1'b0, op_b};
                res    = arith9[7:0];
                c      = arith9[8];
                ov     = (~op_a[7] & ~op_b[7] &  res[7]) |
                         ( op_a[7] &  op_b[7] & ~res[7]);
            end
            OP_SUB: begin
                arith9 = {1'b0, op_a} - {1'b0, op_b};
                res    = arith9[7:0];
                c      = arith9[8];
                ov     = ( op_a[7] & ~op_b[7] & ~res[7]) |
                         (~op_a[7] &  op_b[7] &  res[7]);
            end
            OP_AND:  res = op_a & op_b;
            OP_OR:   res = op_a | op_b;
            OP_XOR:  res = op_a ^ op_b;
            OP_NOT:  res = ~op_a;
            OP_NAND: res = ~(op_a & op_b);
            OP_NOR:  res = ~(op_a | op_b);
            OP_XNOR: res = ~(op_a ^ op_b);
            OP_SHL: begin
                res = op_a << 1;
                c   = op_a[7];
            end
            OP_SHR: begin
                res = op_a >> 1;
                c   = op_a[0];
            end
            OP_ASR:  res = $signed(op_a) >>> 1;
            OP_ROL:  res = {op_a[6:0], op_a[7]};
            OP_ROR:  res = {op_a[0], op_a[7:1]};
            OP_INC: begin
                arith9 = {1'b0, op_a} + 9'd1;
                res    = arith9[7:0];
                c      = arith9[8];
                ov     = ~op_a[7] & res[7];
            end
            OP_DEC: begin
                arith9 = {1'b0, op_a} - 9'd1;
                res    = arith9[7:0];
                c      = arith9[8];
                ov     = op_a[7] & ~res[7];
            end
            default: begin
                res = 8'hXX;
                c   = 1'bX;
                ov  = 1'bX;
            end
        endcase

        z = (res == 8'h00);
        n = res[7];

        return {c, ov, z, n, res};
    endfunction

    // -------------------------------------------------------------------------
    // Check task — applies stimulus, waits, compares against golden model
    // -------------------------------------------------------------------------
    task automatic check (
        input logic [7:0] tv_a,
        input logic [7:0] tv_b,
        input logic [3:0] tv_op,
        input string       test_name
    );
        logic [11:0] exp;
        logic [7:0]  exp_result;
        logic [3:0]  exp_flags;

        a      = tv_a;
        b      = tv_b;
        opcode = tv_op;
        #5; // combinational settling time

        exp        = golden(tv_a, tv_b, tv_op);
        exp_result = exp[7:0];
        exp_flags  = exp[11:8];

        test_count++;

        if (result !== exp_result) begin
            fail_count++;
            $display("LOG: %0t : ERROR : tb_alu_8bit : dut.result : expected_value: 8'h%02h actual_value: 8'h%02h [%s op=4'h%1h a=8'h%02h b=8'h%02h]",
                     $time, exp_result, result, test_name, tv_op, tv_a, tv_b);
        end
        if (flags !== exp_flags) begin
            fail_count++;
            $display("LOG: %0t : ERROR : tb_alu_8bit : dut.flags : expected_value: 4'b%04b actual_value: 4'b%04b [%s op=4'h%1h a=8'h%02h b=8'h%02h]",
                     $time, exp_flags, flags, test_name, tv_op, tv_a, tv_b);
        end
    endtask

    // -------------------------------------------------------------------------
    // Directed test vectors — boundary and edge cases per opcode
    // -------------------------------------------------------------------------
    task automatic run_directed_tests();
        $display("LOG: %0t : INFO : tb_alu_8bit : directed_tests : expected_value: N/A actual_value: N/A [Starting directed tests]", $time);

        // ADD
        check(8'h00, 8'h00, OP_ADD, "ADD zero+zero");
        check(8'h7F, 8'h01, OP_ADD, "ADD pos-overflow");
        check(8'h80, 8'h80, OP_ADD, "ADD neg-overflow");
        check(8'hFF, 8'h01, OP_ADD, "ADD carry-out");
        check(8'hFF, 8'hFF, OP_ADD, "ADD FF+FF");
        check(8'h01, 8'hFE, OP_ADD, "ADD 1+FE=FF");

        // SUB
        check(8'h00, 8'h01, OP_SUB, "SUB underflow-borrow");
        check(8'h80, 8'h01, OP_SUB, "SUB neg-overflow");
        check(8'h7F, 8'hFF, OP_SUB, "SUB pos-overflow");
        check(8'hFF, 8'hFF, OP_SUB, "SUB same=zero");
        check(8'h05, 8'h03, OP_SUB, "SUB normal");
        check(8'h00, 8'h00, OP_SUB, "SUB zero");

        // AND
        check(8'hFF, 8'h00, OP_AND, "AND FF&00=zero");
        check(8'hFF, 8'hFF, OP_AND, "AND FF&FF=FF");
        check(8'hAA, 8'h55, OP_AND, "AND checkerboard=zero");
        check(8'hF0, 8'h0F, OP_AND, "AND nibbles=zero");

        // OR
        check(8'h00, 8'h00, OP_OR, "OR 00|00=zero");
        check(8'hAA, 8'h55, OP_OR, "OR checkerboard=FF");
        check(8'hF0, 8'h0F, OP_OR, "OR nibbles=FF");
        check(8'h00, 8'hFF, OP_OR, "OR 00|FF=FF");

        // XOR
        check(8'hFF, 8'hFF, OP_XOR, "XOR same=zero");
        check(8'hAA, 8'h55, OP_XOR, "XOR checkerboard=FF");
        check(8'h00, 8'hFF, OP_XOR, "XOR 00^FF=FF");
        check(8'h00, 8'h00, OP_XOR, "XOR zero");

        // NOT
        check(8'h00, 8'h00, OP_NOT, "NOT 00=FF");
        check(8'hFF, 8'h00, OP_NOT, "NOT FF=00");
        check(8'h55, 8'h00, OP_NOT, "NOT 55=AA");
        check(8'hAA, 8'h00, OP_NOT, "NOT AA=55");
        check(8'h80, 8'h00, OP_NOT, "NOT 80=7F");

        // NAND
        check(8'hFF, 8'hFF, OP_NAND, "NAND FF&FF=00");
        check(8'h00, 8'hFF, OP_NAND, "NAND 00&FF=FF");
        check(8'hAA, 8'h55, OP_NAND, "NAND checkerboard=FF");

        // NOR
        check(8'h00, 8'h00, OP_NOR, "NOR 00|00=FF");
        check(8'hFF, 8'h00, OP_NOR, "NOR FF|00=00");
        check(8'hAA, 8'h55, OP_NOR, "NOR checkerboard=00");

        // XNOR
        check(8'hFF, 8'hFF, OP_XNOR, "XNOR same=FF");
        check(8'hAA, 8'h55, OP_XNOR, "XNOR checkerboard=00");
        check(8'h00, 8'h00, OP_XNOR, "XNOR 00^00=FF");

        // SHL
        check(8'h80, 8'h00, OP_SHL, "SHL 80→00 carry=1");
        check(8'h01, 8'h00, OP_SHL, "SHL 01→02");
        check(8'hFF, 8'h00, OP_SHL, "SHL FF→FE carry=1");
        check(8'h00, 8'h00, OP_SHL, "SHL 00→00 zero");
        check(8'h40, 8'h00, OP_SHL, "SHL 40→80 negative");

        // SHR
        check(8'h01, 8'h00, OP_SHR, "SHR 01→00 carry=1 zero");
        check(8'h80, 8'h00, OP_SHR, "SHR 80→40");
        check(8'hFF, 8'h00, OP_SHR, "SHR FF→7F carry=1");
        check(8'h00, 8'h00, OP_SHR, "SHR 00→00 zero");

        // ASR
        check(8'h80, 8'h00, OP_ASR, "ASR 80→C0 sign-extend");
        check(8'hFF, 8'h00, OP_ASR, "ASR FF→FF sign-extend");
        check(8'h7E, 8'h00, OP_ASR, "ASR 7E→3F positive");
        check(8'h00, 8'h00, OP_ASR, "ASR 00→00 zero");

        // ROL
        check(8'h80, 8'h00, OP_ROL, "ROL 80→01 wrap");
        check(8'h01, 8'h00, OP_ROL, "ROL 01→02");
        check(8'hFF, 8'h00, OP_ROL, "ROL FF→FF");
        check(8'h00, 8'h00, OP_ROL, "ROL 00→00 zero");
        check(8'hA5, 8'h00, OP_ROL, "ROL A5→4B carry-wrap");

        // ROR
        check(8'h01, 8'h00, OP_ROR, "ROR 01→80 wrap");
        check(8'h80, 8'h00, OP_ROR, "ROR 80→40");
        check(8'hFF, 8'h00, OP_ROR, "ROR FF→FF");
        check(8'h00, 8'h00, OP_ROR, "ROR 00→00 zero");
        check(8'hA5, 8'h00, OP_ROR, "ROR A5→D2 wrap");

        // INC
        check(8'hFF, 8'h00, OP_INC, "INC FF→00 carry");
        check(8'h7F, 8'h00, OP_INC, "INC 7F→80 overflow");
        check(8'h00, 8'h00, OP_INC, "INC 00→01");
        check(8'hFE, 8'h00, OP_INC, "INC FE→FF negative");

        // DEC
        check(8'h00, 8'h00, OP_DEC, "DEC 00→FF borrow");
        check(8'h80, 8'h00, OP_DEC, "DEC 80→7F overflow");
        check(8'h01, 8'h00, OP_DEC, "DEC 01→00 zero");
        check(8'hFF, 8'h00, OP_DEC, "DEC FF→FE negative");

        $display("LOG: %0t : INFO : tb_alu_8bit : directed_tests : expected_value: N/A actual_value: N/A [Directed tests complete]", $time);
    endtask

    // -------------------------------------------------------------------------
    // Random test sweep — 200 vectors per opcode
    // -------------------------------------------------------------------------
    task automatic run_random_tests();
        logic [7:0] rnd_a, rnd_b;
        int         i;

        $display("LOG: %0t : INFO : tb_alu_8bit : random_tests : expected_value: N/A actual_value: N/A [Starting random tests]", $time);

        for (int op = 0; op <= 15; op++) begin
            for (i = 0; i < 200; i++) begin
                rnd_a = $urandom_range(0, 255);
                rnd_b = $urandom_range(0, 255);
                check(rnd_a, rnd_b, op[3:0], "RANDOM");
            end
        end

        $display("LOG: %0t : INFO : tb_alu_8bit : random_tests : expected_value: N/A actual_value: N/A [Random tests complete]", $time);
    endtask

    // -------------------------------------------------------------------------
    // Flag-targeted tests — verify each flag independently
    // -------------------------------------------------------------------------
    task automatic run_flag_tests();
        $display("LOG: %0t : INFO : tb_alu_8bit : flag_tests : expected_value: N/A actual_value: N/A [Starting flag-targeted tests]", $time);

        // Zero flag
        check(8'hFF, 8'hFF, OP_XOR,  "FLAG_ZERO: XOR same");
        check(8'h00, 8'h00, OP_ADD,  "FLAG_ZERO: ADD 0+0");
        check(8'hFF, 8'h01, OP_ADD,  "FLAG_ZERO: ADD FF+1");
        check(8'h01, 8'h01, OP_SUB,  "FLAG_ZERO: SUB same");
        check(8'hFF, 8'h00, OP_INC,  "FLAG_ZERO: INC FF");

        // Negative flag
        check(8'h80, 8'h00, OP_INC,  "FLAG_NEG: INC 80");
        check(8'hFF, 8'h00, OP_OR,   "FLAG_NEG: OR FF");
        check(8'h7F, 8'h01, OP_ADD,  "FLAG_NEG: ADD 7F+1=80");
        check(8'h80, 8'h00, OP_ASR,  "FLAG_NEG: ASR 80");

        // Carry flag
        check(8'hFF, 8'h01, OP_ADD,  "FLAG_CARRY: ADD wrap");
        check(8'h00, 8'h01, OP_SUB,  "FLAG_CARRY: SUB borrow");
        check(8'hFF, 8'h00, OP_INC,  "FLAG_CARRY: INC wrap");
        check(8'h00, 8'h00, OP_DEC,  "FLAG_CARRY: DEC borrow");
        check(8'h80, 8'h00, OP_SHL,  "FLAG_CARRY: SHL MSB out");
        check(8'h01, 8'h00, OP_SHR,  "FLAG_CARRY: SHR LSB out");

        // Overflow flag
        check(8'h7F, 8'h01, OP_ADD,  "FLAG_OVF: ADD pos+pos=neg");
        check(8'h80, 8'hFF, OP_ADD,  "FLAG_OVF: ADD neg+neg=pos");
        check(8'h80, 8'h01, OP_SUB,  "FLAG_OVF: SUB neg-pos=pos");
        check(8'h7F, 8'hFF, OP_SUB,  "FLAG_OVF: SUB pos-neg=neg");
        check(8'h7F, 8'h00, OP_INC,  "FLAG_OVF: INC 7F");
        check(8'h80, 8'h00, OP_DEC,  "FLAG_OVF: DEC 80");

        $display("LOG: %0t : INFO : tb_alu_8bit : flag_tests : expected_value: N/A actual_value: N/A [Flag-targeted tests complete]", $time);
    endtask

    // -------------------------------------------------------------------------
    // Main test sequence
    // -------------------------------------------------------------------------
    initial begin
        $display("TEST START");

        test_count = 0;
        fail_count = 0;
        a          = 8'h00;
        b          = 8'h00;
        opcode     = OP_ADD;

        #10; // initial settling

        run_directed_tests();
        run_flag_tests();
        run_random_tests();

        #10;

        // Final result
        $display("LOG: %0t : INFO : tb_alu_8bit : summary : expected_value: 0_failures actual_value: %0d_failures [Total tests: %0d]",
                 $time, fail_count, test_count);

        if (fail_count == 0) begin
            $display("TEST PASSED");
        end else begin
            $display("ERROR");
            $error("tb_alu_8bit: %0d out of %0d tests FAILED", fail_count, test_count);
        end

        $finish;
    end

    // -------------------------------------------------------------------------
    // Timeout watchdog
    // -------------------------------------------------------------------------
    initial begin
        #500000;
        $display("ERROR");
        $fatal(1, "tb_alu_8bit: TIMEOUT — simulation exceeded 500000 time units");
    end

    // -------------------------------------------------------------------------
    // Waveform dump
    // -------------------------------------------------------------------------
    initial begin
        $dumpfile("dumpfile.fst");
        $dumpvars(0);
    end

endmodule
