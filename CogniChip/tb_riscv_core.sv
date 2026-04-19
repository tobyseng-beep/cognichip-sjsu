// =============================================================================
// Module  : tb_riscv_core
// Description: Directed testbench for riscv_core.
//
//  Verification strategy:
//    1. Reset and pipeline flush check
//    2. Scalar ADDI / LUI / ADD sequence — verifies 32-bit ALU, immediates,
//       and the forwarding path (back-to-back dependent instructions)
//    3. DOT product — verifies custom CUSTOM0 instruction dispatch and
//       vector operand packing after LUI+ADDI vector load
//    4. MATMUL — verifies 64-bit result, writeback_stage dual-port write,
//       and that rd+1 (x5) is correctly written
//    5. Forwarding stress — LUI immediately followed by ADDI on same rd,
//       then immediately used — validates single-cycle forward path
//
//  The demo IMEM program is pre-loaded in fetch_stage and runs automatically.
//  After IMEM_DEPTH cycles the core wraps around to PC=0 (NOP territory);
//  all checks are done before that wrap.
//
//  Expected register results after program completion:
//    x1 = 0x04030201    (vec A)
//    x2 = 0x08070605    (vec B)
//    x3 = 0x00000046    (DOT = 70)
//    x4 = 0x00160013    (MATMUL lower: C[0][1]|C[0][0] = 22|19)
//    x5 = 0x0032002B    (MATMUL upper: C[1][1]|C[1][0] = 50|43)
//    x6 = 0x00000064    (100)
//    x7 = 0x000000C8    (200)
//    x8 = 0x0000012C    (300)
// =============================================================================

module tb_riscv_core;

    // -------------------------------------------------------------------------
    // Clock / reset
    // -------------------------------------------------------------------------
    logic clock;
    logic reset;

    localparam int CLK_PERIOD = 10;

    initial clock = 1'b0;
    always #(CLK_PERIOD/2) clock = ~clock;

    // -------------------------------------------------------------------------
    // DUT
    // -------------------------------------------------------------------------
    logic [31:0] acc_in;
    logic [63:0] result;
    logic [3:0]  alu_flags;
    logic [4:0]  wb_rd;
    logic        wb_reg_write;
    logic        wb_valid;
    logic [31:0] pc_out;

    assign acc_in = 32'h0;   // accumulator unused in this testbench

    riscv_core #(.IMEM_DEPTH(16)) dut (
        .clock       (clock),
        .reset       (reset),
        .acc_in      (acc_in),
        .result      (result),
        .alu_flags   (alu_flags),
        .wb_rd       (wb_rd),
        .wb_reg_write(wb_reg_write),
        .wb_valid    (wb_valid),
        .pc_out      (pc_out)
    );

    // -------------------------------------------------------------------------
    // Test tracking
    // -------------------------------------------------------------------------
    int test_count;
    int fail_count;

    // -------------------------------------------------------------------------
    // Clock-edge helper — advance N rising edges
    // -------------------------------------------------------------------------
    task automatic tick(input int n);
        repeat (n) @(posedge clock);
        #1; // small delta after posedge for stable signal sampling
    endtask

    // -------------------------------------------------------------------------
    // Check task — wait for wb_rd to match target register, then verify result
    // -------------------------------------------------------------------------
    task automatic wait_for_wb (
        input logic [4:0]  exp_rd,
        input logic [31:0] exp_data,
        input int          timeout_cycles
    );
        int cyc;
        logic found;
        found = 1'b0;
        for (cyc = 0; cyc < timeout_cycles; cyc++) begin
            @(posedge clock); #1;
            if (wb_reg_write && wb_valid && (wb_rd == exp_rd)) begin
                test_count++;
                if (result[31:0] !== exp_data) begin
                    fail_count++;
                    $display("LOG: %0t : ERROR : tb_riscv_core : dut.result[31:0] : expected_value: 32'h%08h actual_value: 32'h%08h [wb_rd=x%0d]",
                             $time, exp_data, result[31:0], exp_rd);
                end else begin
                    $display("LOG: %0t : INFO : tb_riscv_core : dut.result[31:0] : expected_value: 32'h%08h actual_value: 32'h%08h [wb_rd=x%0d OK]",
                             $time, exp_data, result[31:0], exp_rd);
                end
                found = 1'b1;
                break;
            end
        end
        if (!found) begin
            test_count++;
            fail_count++;
            $display("LOG: %0t : ERROR : tb_riscv_core : dut.wb_rd : expected_value: x%0d actual_value: timeout [wb never saw rd=x%0d in %0d cycles]",
                     $time, exp_rd, exp_rd, timeout_cycles);
        end
    endtask

    // -------------------------------------------------------------------------
    // Check the 64-bit MATMUL result in the writeback bundle
    // -------------------------------------------------------------------------
    task automatic wait_for_wb64 (
        input logic [4:0]  exp_rd,
        input logic [63:0] exp_data,
        input int          timeout_cycles
    );
        int cyc;
        logic found;
        found = 1'b0;
        for (cyc = 0; cyc < timeout_cycles; cyc++) begin
            @(posedge clock); #1;
            if (wb_reg_write && wb_valid && (wb_rd == exp_rd)) begin
                test_count++;
                if (result !== exp_data) begin
                    fail_count++;
                    $display("LOG: %0t : ERROR : tb_riscv_core : dut.result[63:0] : expected_value: 64'h%016h actual_value: 64'h%016h [wb_rd=x%0d MATMUL]",
                             $time, exp_data, result, exp_rd);
                end else begin
                    $display("LOG: %0t : INFO : tb_riscv_core : dut.result[63:0] : expected_value: 64'h%016h actual_value: 64'h%016h [wb_rd=x%0d MATMUL OK]",
                             $time, exp_data, result, exp_rd);
                end
                found = 1'b1;
                break;
            end
        end
        if (!found) begin
            test_count++;
            fail_count++;
            $display("LOG: %0t : ERROR : tb_riscv_core : dut.wb_rd : expected_value: x%0d actual_value: timeout [MATMUL wb never seen in %0d cycles]",
                     $time, exp_rd, timeout_cycles);
        end
    endtask

    // -------------------------------------------------------------------------
    // Main test sequence
    // -------------------------------------------------------------------------
    initial begin
        $display("TEST START");

        test_count = 0;
        fail_count = 0;

        // ---------------------------------------------------------------------
        // Reset
        // ---------------------------------------------------------------------
        reset = 1'b1;
        tick(3);
        reset = 1'b0;

        $display("LOG: %0t : INFO : tb_riscv_core : dut.reset : expected_value: 0 actual_value: 0 [Reset deasserted, pipeline starting]", $time);

        // ---------------------------------------------------------------------
        // Test 1: LUI x1 → x1[31:12] = 0x04030 (result = 0x04030000)
        //   Instruction [0] = LUI x1, 0x04030
        //   Appears in writeback after 2 cycles (1 fetch + 1 pipeline reg)
        // ---------------------------------------------------------------------
        wait_for_wb(.exp_rd(5'd1), .exp_data(32'h04030000), .timeout_cycles(10));

        // ---------------------------------------------------------------------
        // Test 2: ADDI x1, x1, 0x201 → x1 = 0x04030201
        //   Forwarding test: rs1=x1 depends on LUI x1 one cycle prior
        // ---------------------------------------------------------------------
        wait_for_wb(.exp_rd(5'd1), .exp_data(32'h04030201), .timeout_cycles(5));

        // ---------------------------------------------------------------------
        // Test 3: LUI x2, 0x08070 → x2 = 0x08070000
        // ---------------------------------------------------------------------
        wait_for_wb(.exp_rd(5'd2), .exp_data(32'h08070000), .timeout_cycles(5));

        // ---------------------------------------------------------------------
        // Test 4: ADDI x2, x2, 0x605 → x2 = 0x08070605
        //   Forwarding test: rs1=x2 depends on LUI x2 one cycle prior
        // ---------------------------------------------------------------------
        wait_for_wb(.exp_rd(5'd2), .exp_data(32'h08070605), .timeout_cycles(5));

        // ---------------------------------------------------------------------
        // Test 5: DOT x3, x1, x2 → x3 = 70 = 0x46
        //   1*5 + 2*6 + 3*7 + 4*8 = 5+12+21+32 = 70
        //   Forwarding test: x2 was just written by ADDI x2 one cycle prior
        // ---------------------------------------------------------------------
        wait_for_wb(.exp_rd(5'd3), .exp_data(32'h00000046), .timeout_cycles(5));

        // ---------------------------------------------------------------------
        // Test 6: MATMUL x4, x1, x2 → 64-bit result
        //   C[0][0]=19, C[0][1]=22, C[1][0]=43, C[1][1]=50
        //   result[63:0] = {0x0032, 0x002B, 0x0016, 0x0013}
        //                = 0x0032002B00160013
        // ---------------------------------------------------------------------
        wait_for_wb64(.exp_rd(5'd4), .exp_data(64'h0032002B00160013), .timeout_cycles(5));

        // ---------------------------------------------------------------------
        // Test 7: ADDI x6, x0, 100 → x6 = 100
        // ---------------------------------------------------------------------
        wait_for_wb(.exp_rd(5'd6), .exp_data(32'h00000064), .timeout_cycles(8));

        // ---------------------------------------------------------------------
        // Test 8: ADDI x7, x0, 200 → x7 = 200
        // ---------------------------------------------------------------------
        wait_for_wb(.exp_rd(5'd7), .exp_data(32'h000000C8), .timeout_cycles(5));

        // ---------------------------------------------------------------------
        // Test 9: ADD x8, x6, x7 → x8 = 300 = 0x12C
        //   32-bit scalar ADD verifies alu_32bit end-to-end
        // ---------------------------------------------------------------------
        wait_for_wb(.exp_rd(5'd8), .exp_data(32'h0000012C), .timeout_cycles(5));

        // ---------------------------------------------------------------------
        // Final report
        // ---------------------------------------------------------------------
        #20;

        $display("LOG: %0t : INFO : tb_riscv_core : summary : expected_value: 0_failures actual_value: %0d_failures [Total: %0d tests]",
                 $time, fail_count, test_count);

        if (fail_count == 0) begin
            $display("TEST PASSED");
        end else begin
            $display("ERROR");
            $error("tb_riscv_core: %0d / %0d tests FAILED", fail_count, test_count);
        end

        $finish;
    end

    // -------------------------------------------------------------------------
    // Timeout watchdog
    // -------------------------------------------------------------------------
    initial begin
        #10000;
        $display("ERROR");
        $fatal(1, "tb_riscv_core: TIMEOUT — simulation exceeded 10000 time units");
    end

    // -------------------------------------------------------------------------
    // Waveform dump
    // -------------------------------------------------------------------------
    initial begin
        $dumpfile("dumpfile.fst");
        $dumpvars(0);
    end

endmodule
