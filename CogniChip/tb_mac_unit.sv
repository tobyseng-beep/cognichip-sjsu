module tb_mac_unit;
    localparam logic [1:0] OP_MAC    = 2'b00;
    localparam logic [1:0] OP_DOT    = 2'b01;
    localparam logic [1:0] OP_MATMUL = 2'b10;
    localparam logic [3:0] ALU_ADD   = 4'h0;
    localparam logic [3:0] ALU_SUB   = 4'h1;

    logic [31:0] a_in, b_in, acc_in;
    logic [1:0]  mac_opcode;
    logic [63:0] mac_result;
    logic        mac_valid;

    logic [31:0] dp_a, dp_b, dp_acc;
    logic        dp_unit_sel;
    logic [3:0]  dp_alu_opcode;
    logic [1:0]  dp_mac_opcode;
    logic [63:0] dp_result;
    logic [3:0]  dp_flags;
    logic        dp_valid;

    mac_unit u_mac (
        .a_in   (a_in),
        .b_in   (b_in),
        .acc_in (acc_in),
        .opcode (mac_opcode),
        .result (mac_result),
        .valid  (mac_valid)
    );

    alu_mac_datapath u_dp (
        .a_in        (dp_a),
        .b_in        (dp_b),
        .acc_in      (dp_acc),
        .unit_sel    (dp_unit_sel),
        .alu_opcode  (dp_alu_opcode),
        .mac_opcode  (dp_mac_opcode),
        .result      (dp_result),
        .alu_flags   (dp_flags),
        .result_valid(dp_valid)
    );

    int test_count;
    int fail_count;

    function automatic logic [31:0] pack4(input logic [7:0] e0, e1, e2, e3);
        return {e3, e2, e1, e0};
    endfunction

    task automatic check_mac(
        input logic [31:0] ta, tb, tacc,
        input logic [1:0]  top,
        input logic [63:0] expected,
        input string        tname
    );
        a_in = ta; b_in = tb; acc_in = tacc; mac_opcode = top;
        #5;
        test_count++;
        if (mac_result !== expected) begin
            fail_count++;
            $display("LOG: %0t : ERROR : tb_mac_unit : dut.mac_result : expected_value: 64'h%016h actual_value: 64'h%016h [%s]",
                     $time, expected, mac_result, tname);
        end
    endtask

    task automatic check_dp_alu(
        input logic [7:0] ta, tb,
        input logic [3:0] top,
        input logic [7:0] exp_r,
        input string       tname
    );
        dp_a = {24'h0,ta}; dp_b = {24'h0,tb}; dp_acc = 0;
        dp_unit_sel = 1'b0; dp_alu_opcode = top; dp_mac_opcode = 2'b00;
        #5;
        test_count++;
        if (dp_result[7:0] !== exp_r) begin
            fail_count++;
            $display("LOG: %0t : ERROR : tb_mac_unit : dut.dp_result[7:0] : expected_value: 8'h%02h actual_value: 8'h%02h [%s]",
                     $time, exp_r, dp_result[7:0], tname);
        end
    endtask

    task automatic check_dp_mac(
        input logic [31:0] ta, tb, tacc,
        input logic [1:0]  top,
        input logic [63:0] expected,
        input string        tname
    );
        dp_a = ta; dp_b = tb; dp_acc = tacc;
        dp_unit_sel = 1'b1; dp_mac_opcode = top; dp_alu_opcode = 4'h0;
        #5;
        test_count++;
        if (dp_result !== expected) begin
            fail_count++;
            $display("LOG: %0t : ERROR : tb_mac_unit : dut.dp_result : expected_value: 64'h%016h actual_value: 64'h%016h [%s]",
                     $time, expected, dp_result, tname);
        end
    endtask

    task automatic run_mac_tests();
        $display("LOG: %0t : INFO : tb_mac_unit : mac_tests : expected_value: N/A actual_value: N/A [Starting MAC tests]", $time);
        check_mac(pack4(8'd2,8'd0,8'd0,8'd0), pack4(8'd3,8'd0,8'd0,8'd0), 32'd10, OP_MAC, 64'd16, "MAC 2*3+10=16");
        check_mac(pack4(8'd0,8'd0,8'd0,8'd0), pack4(8'd5,8'd0,8'd0,8'd0), 32'd0,  OP_MAC, 64'd0,  "MAC 0*5+0=0");
        check_mac(pack4(8'd255,8'd0,8'd0,8'd0), pack4(8'd255,8'd0,8'd0,8'd0), 32'd0, OP_MAC, 64'd65025, "MAC 255*255");
        check_mac(pack4(8'd255,8'd0,8'd0,8'd0), pack4(8'd255,8'd0,8'd0,8'd0), 32'd100, OP_MAC, 64'd65125, "MAC 255*255+100");
        check_mac(pack4(8'd10,8'd0,8'd0,8'd0), pack4(8'd10,8'd0,8'd0,8'd0), 32'd0, OP_MAC, 64'd100, "MAC 10*10=100");
        check_mac(pack4(8'd0,8'd0,8'd0,8'd0), pack4(8'd0,8'd0,8'd0,8'd0), 32'd42, OP_MAC, 64'd42, "MAC 0*0+42=42");
        $display("LOG: %0t : INFO : tb_mac_unit : mac_tests : expected_value: N/A actual_value: N/A [MAC tests complete]", $time);
    endtask

    task automatic run_dot_tests();
        $display("LOG: %0t : INFO : tb_mac_unit : dot_tests : expected_value: N/A actual_value: N/A [Starting DOT tests]", $time);
        check_mac(pack4(8'd1,8'd2,8'd3,8'd4), pack4(8'd1,8'd2,8'd3,8'd4), 32'd0, OP_DOT, 64'd30,     "DOT [1,2,3,4].[1,2,3,4]=30");
        check_mac(pack4(8'd0,8'd0,8'd0,8'd0), pack4(8'd5,8'd6,8'd7,8'd8), 32'd0, OP_DOT, 64'd0,      "DOT zeros=0");
        check_mac(pack4(8'd1,8'd0,8'd0,8'd0), pack4(8'd7,8'd8,8'd9,8'd10),32'd0, OP_DOT, 64'd7,      "DOT unit_vec[0]=7");
        check_mac(pack4(8'd0,8'd0,8'd0,8'd1), pack4(8'd7,8'd8,8'd9,8'd10),32'd0, OP_DOT, 64'd10,     "DOT unit_vec[3]=10");
        check_mac(pack4(8'd255,8'd255,8'd255,8'd255), pack4(8'd255,8'd255,8'd255,8'd255), 32'd0, OP_DOT, 64'd260100, "DOT max=260100");
        check_mac(pack4(8'd1,8'd2,8'd3,8'd4), pack4(8'd4,8'd3,8'd2,8'd1), 32'd0, OP_DOT, 64'd20,     "DOT reversed=20");
        check_mac(pack4(8'd10,8'd20,8'd30,8'd40), pack4(8'd1,8'd1,8'd1,8'd1), 32'd0, OP_DOT, 64'd100,"DOT sum=100");
        $display("LOG: %0t : INFO : tb_mac_unit : dot_tests : expected_value: N/A actual_value: N/A [DOT tests complete]", $time);
    endtask

    task automatic run_matmul_tests();
        logic [15:0] c00, c01, c10, c11;
        logic [63:0] exp;
        $display("LOG: %0t : INFO : tb_mac_unit : matmul_tests : expected_value: N/A actual_value: N/A [Starting MATMUL tests]", $time);

        // I * I = I
        c00=1; c01=0; c10=0; c11=1; exp={c11,c10,c01,c00};
        check_mac(pack4(8'd1,8'd0,8'd0,8'd1), pack4(8'd1,8'd0,8'd0,8'd1), 32'd0, OP_MATMUL, exp, "MATMUL I*I=I");

        // Zero * M = 0
        c00=0; c01=0; c10=0; c11=0; exp={c11,c10,c01,c00};
        check_mac(pack4(8'd0,8'd0,8'd0,8'd0), pack4(8'd5,8'd6,8'd7,8'd8), 32'd0, OP_MATMUL, exp, "MATMUL 0*M=0");

        // A * I = A
        c00=1; c01=2; c10=3; c11=4; exp={c11,c10,c01,c00};
        check_mac(pack4(8'd1,8'd2,8'd3,8'd4), pack4(8'd1,8'd0,8'd0,8'd1), 32'd0, OP_MATMUL, exp, "MATMUL A*I=A");

        // [[1,2],[3,4]] * [[5,6],[7,8]] = [[19,22],[43,50]]
        c00=19; c01=22; c10=43; c11=50; exp={c11,c10,c01,c00};
        check_mac(pack4(8'd1,8'd2,8'd3,8'd4), pack4(8'd5,8'd6,8'd7,8'd8), 32'd0, OP_MATMUL, exp, "MATMUL [[1,2],[3,4]]*[[5,6],[7,8]]");

        // [[2,3],[4,5]] * [[6,7],[8,9]] = [[36,41],[64,73]]
        c00=36; c01=41; c10=64; c11=73; exp={c11,c10,c01,c00};
        check_mac(pack4(8'd2,8'd3,8'd4,8'd5), pack4(8'd6,8'd7,8'd8,8'd9), 32'd0, OP_MATMUL, exp, "MATMUL [[2,3],[4,5]]*[[6,7],[8,9]]");

        // Max boundary: all-255 * all-ones -> each element = 255+255 = 510
        c00=510; c01=510; c10=510; c11=510; exp={c11,c10,c01,c00};
        check_mac(pack4(8'd255,8'd255,8'd255,8'd255), pack4(8'd1,8'd1,8'd1,8'd1), 32'd0, OP_MATMUL, exp, "MATMUL all255*ones=510");

        $display("LOG: %0t : INFO : tb_mac_unit : matmul_tests : expected_value: N/A actual_value: N/A [MATMUL tests complete]", $time);
    endtask

    task automatic run_random_tests();
        logic [7:0] ra0,ra1,ra2,ra3,rb0,rb1,rb2,rb3;
        logic [31:0] dot_exp, mac_exp;
        $display("LOG: %0t : INFO : tb_mac_unit : random_tests : expected_value: N/A actual_value: N/A [Starting random tests]", $time);
        for (int i = 0; i < 300; i++) begin
            ra0=$urandom_range(0,255); ra1=$urandom_range(0,255);
            ra2=$urandom_range(0,255); ra3=$urandom_range(0,255);
            rb0=$urandom_range(0,255); rb1=$urandom_range(0,255);
            rb2=$urandom_range(0,255); rb3=$urandom_range(0,255);
            dot_exp = ({16'h0,ra0}*{16'h0,rb0}) + ({16'h0,ra1}*{16'h0,rb1})
                    + ({16'h0,ra2}*{16'h0,rb2}) + ({16'h0,ra3}*{16'h0,rb3});
            check_mac(pack4(ra0,ra1,ra2,ra3), pack4(rb0,rb1,rb2,rb3), 32'd0, OP_DOT, {32'h0,dot_exp}, "RND_DOT");
            mac_exp = {16'h0,ra0} * {16'h0,rb0};
            check_mac(pack4(ra0,ra1,ra2,ra3), pack4(rb0,rb1,rb2,rb3), 32'd0, OP_MAC, {32'h0,mac_exp}, "RND_MAC");
        end
        $display("LOG: %0t : INFO : tb_mac_unit : random_tests : expected_value: N/A actual_value: N/A [Random tests complete]", $time);
    endtask

    task automatic run_datapath_tests();
        logic [15:0] c00, c01, c10, c11;
        logic [63:0] exp;
        $display("LOG: %0t : INFO : tb_mac_unit : datapath_tests : expected_value: N/A actual_value: N/A [Starting datapath tests]", $time);
        check_dp_alu(8'd10, 8'd5,  ALU_ADD, 8'd15,  "DP ADD 10+5=15");
        check_dp_alu(8'hFF, 8'h01, ALU_ADD, 8'h00,  "DP ADD wrap");
        check_dp_alu(8'd20, 8'd8,  ALU_SUB, 8'd12,  "DP SUB 20-8=12");
        check_dp_alu(8'd0,  8'd0,  ALU_ADD, 8'd0,   "DP ADD 0+0=0");
        check_dp_mac(pack4(8'd1,8'd2,8'd3,8'd4), pack4(8'd1,8'd2,8'd3,8'd4), 32'd0, OP_DOT,    64'd30, "DP DOT=30");
        check_dp_mac(pack4(8'd5,8'd0,8'd0,8'd0), pack4(8'd6,8'd0,8'd0,8'd0), 32'd4, OP_MAC,    64'd34, "DP MAC 5*6+4=34");
        c00=1; c01=0; c10=0; c11=1; exp={c11,c10,c01,c00};
        check_dp_mac(pack4(8'd1,8'd0,8'd0,8'd1), pack4(8'd1,8'd0,8'd0,8'd1), 32'd0, OP_MATMUL, exp,    "DP MATMUL I*I=I");
        $display("LOG: %0t : INFO : tb_mac_unit : datapath_tests : expected_value: N/A actual_value: N/A [Datapath tests complete]", $time);
    endtask

    initial begin
        $display("TEST START");
        test_count=0; fail_count=0;
        a_in=0; b_in=0; acc_in=0; mac_opcode=0;
        dp_a=0; dp_b=0; dp_acc=0; dp_unit_sel=0; dp_alu_opcode=0; dp_mac_opcode=0;
        #10;
        run_mac_tests();
        run_dot_tests();
        run_matmul_tests();
        run_random_tests();
        run_datapath_tests();
        #10;
        $display("LOG: %0t : INFO : tb_mac_unit : summary : expected_value: 0_failures actual_value: %0d_failures [Total tests: %0d]",
                 $time, fail_count, test_count);
        if (fail_count == 0) begin
            $display("TEST PASSED");
        end else begin
            $display("ERROR");
            $error("tb_mac_unit: %0d / %0d FAILED", fail_count, test_count);
        end
        $finish;
    end

    initial begin
        #200000;
        $display("ERROR");
        $fatal(1, "tb_mac_unit: TIMEOUT");
    end

    initial begin
        $dumpfile("dumpfile.fst");
        $dumpvars(0);
    end
endmodule
