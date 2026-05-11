//==============================================
// Compares DUT against Reference Model
//==============================================

`timescale 1ns/1ps
`include "test_design.v"
`include "ref_main.v"

module testbench_main;
    parameter IN_SIZE = 8;
    parameter CMD_SIZE = 4;
    parameter OUT_SIZE = 2*IN_SIZE;

    reg f; //set during  apply_test_mul

    // DUT signals
    reg [IN_SIZE-1:0] OPA, OPB;
    reg [1:0] INP_VALID;
    reg CLK, RST, CE, MODE, CIN;
    reg [CMD_SIZE-1:0] CMD;
    wire [OUT_SIZE-1:0] RES_dut;
    wire COUT_dut, OFLOW_dut, G_dut, E_dut, L_dut, ERR_dut;

    // Reference model signals
    wire [OUT_SIZE-1:0] RES_ref;
    wire COUT_ref, OFLOW_ref, G_ref, E_ref, L_ref, ERR_ref;

    // Test counters
    integer pass_count = 0;
    integer fail_count = 0;
    integer test_count = 0;

    // DUT instantiation
   test_design #(
        .IN_SIZE(IN_SIZE),.OUT_SIZE(OUT_SIZE),.CMD_SIZE(CMD_SIZE)
    ) dut (
        .OPA(OPA), .OPB(OPB), .CIN(CIN),
        .CLK(CLK), .RST(RST), .CMD(CMD),
        .CE(CE), .MODE(MODE), .INP_VALID(INP_VALID),
        .COUT(COUT_dut), .OFLOW(OFLOW_dut),
        .RES(RES_dut),
        .G(G_dut), .E(E_dut), .L(L_dut),
        .ERR(ERR_dut)
    );

    // Reference model instantiation
    ref_main #(
        .CMD_SIZE(CMD_SIZE),
        .IN_SIZE(IN_SIZE)
    ) ref_model (
        .OPA(OPA), .OPB(OPB), .CIN(CIN),
        .CLK(CLK), .RST(RST), .CE(CE),
        .MODE(MODE), .CMD(CMD), .INP_VALID(INP_VALID),
        .RES(RES_ref),
        .COUT(COUT_ref), .OFLOW(OFLOW_ref),
        .G(G_ref), .E(E_ref), .L(L_ref),
        .ERR(ERR_ref)
    );

    // Clock generation
    initial begin
        CLK = 0;
        forever #5 CLK = ~CLK;
    end

    // Main Test stimulus
    initial begin
        // Hold reset; all inputs at safe defaults
        RST = 1; CE = 1; CIN = 0; INP_VALID = 3;
        OPA = 0; OPB = 0; MODE = 0; CMD = 0;

        @(posedge CLK);
        RST = 0;  // Release reset
       
        // First Operation after reset: multiply to verify clean stste
        MODE = 1;
	apply_test_mul(8'h5,8'd3,2'b11,1,0,1,9,"MUL_FIRST_AFTER_RESET");
	
	 @(posedge CLK);

	//Mid-multiply abort: drive INP_VALID=0 + CMD chnge while counter=1
	//Expected: FSM transitions st1->st0(multiply aborted)
	@(negedge CLK);
	OPA = 8'h05; OPB = 8'h03; INP_VALID = 2'b11;
	MODE = 1; CMD = 9; CE = 1;
	@(posedge CLK);   // count 0->1
	INP_VALID = 2'b00;
	CMD = 0;          // change CMD while count=1
	@(posedge CLK);   // st1->st0 triggered
	@(negedge CLK);

        // Test Arithmetic Operations(MODE=1)
        $display("\n=== Testing Arithmetic Operations (MODE=1) ===");
        MODE = 1;
        test_arithmetic();

        // Test Logical Operations(MODE=0)
        $display("\n=== Testing Logical Operations (MODE=0) ===");
        MODE = 0;
        test_logical();

	// RST mid operation test
        $display("\n=== Testing RST Mid Operation ===");
        @(negedge CLK);
        OPA = 8'hFF; OPB = 8'hFF; INP_VALID = 2'b11;
        MODE = 1; CMD = 0; CE = 1;
        @(posedge CLK);
        RST = 1;  // assert RST mid-operation
        @(posedge CLK);
        RST = 0;
        @(posedge CLK);
        @(negedge CLK);

        // Summary
        $display("\n=== TEST SUMMARY ===");
        $display("Total Tests: %0d", test_count);
        $display("PASS: %0d", pass_count);
        $display("FAIL: %0d", fail_count);

        if (fail_count == 0)
            $display("\n*** ALL TESTS PASSED ***\n");
        else
            $display("\n*** SOME TESTS FAILED ***\n");

        #100;
        $finish;
    end

    // Test arithmetic operations
    task test_arithmetic();
        begin
            // ADD
            apply_test(1,8'h0C,8'h05,0,1,0,2'b11,"ADD_AB_VALID");
            apply_test(1,8'hFF,8'hFF,0,1,0,2'b11,"ADD_M_M");
            apply_test(1,8'hFF,8'h01,0,1,0,2'b11,"ADD_M_1");
            apply_test(1,8'hFF,8'h01,0,1,0,2'b01,"ADD_INP_INVALID_B");
            apply_test(1,8'hFF,8'h01,0,1,0,2'b10,"ADD_INP_INVALID_A");
            apply_test(1,8'hFF,8'h01,0,1,0,2'b00,"ADD_INP_INVALID_A_B");
	    apply_test(1,8'hFF,8'b01,0,1,0,2'b11,"ADD_COUT_TOGGLE");

            // SUB
            apply_test(1,8'h0C,8'h05,1,1,0,2'b11,"SUB_AB_VALID");
            apply_test(1,8'hFF,8'hFF,1,1,0,2'b11,"SUB_SAME");
            apply_test(1,8'h00,8'h0F,1,1,0,2'b11,"SUM_0_NZ");
            apply_test(1,8'h00,8'h01,1,1,0,2'b11,"SUM_UNDERFLOW");
            apply_test(1,8'hFF,8'h01,1,1,0,2'b01,"SUM_INP_INVALID_B");
            apply_test(1,8'hFF,8'h01,1,1,0,2'b10,"SUM_INP_INVALID_A");
            apply_test(1,8'hFF,8'h01,1,1,0,2'b00,"SUM_INP_INVALID_A_B");
            apply_test(1,8'h0C,8'h05,2,1,0,2'b11,"ADD_ABCIN0_VALID");
            apply_test(1,8'hFF,8'hFF,2,1,0,2'b11,"ADDCIN_MAX_0");
            // ADD_CIN CIN = 1
            apply_test(1,8'h0C,8'h05,2,1,1,2'b11,"ADD_ABCIN1_VALID");
            apply_test(1,8'hFF,8'hFF,2,1,1,2'b11,"ADDCIN_MAX_1");
            apply_test(1,8'hFF,8'h00,2,1,1,2'b11,"ADD_WRAP_1");
            apply_test(1,8'hFF,8'hFF,2,1,1,2'b01,"ADDCIN_INP_INVALID_B");
            apply_test(1,8'hFF,8'h01,2,1,1,2'b10,"ADDCIN_INP_INVALID_A");
            apply_test(1,8'hFF,8'h01,2,1,1,2'b00,"ADDCIN_INP_INVALID_A_B");
            //SUB_CIN CIN=0
            apply_test(1,8'h0C,8'h05,3,1,0,2'b11,"SUB_ABCIN0_VALID");
            apply_test(1,8'h37,8'h37,3,1,0,2'b11,"SUBCIN_EQUAL_CIN0");
	    //SUB_CIN CIN=1
            apply_test(1,8'h0C,8'h05,3,1,1,2'b11,"SUB_ABCIN1_VALID");
            apply_test(1,8'h00,8'h00,3,1,1,2'b11,"SUBCIN_001");
            apply_test(1,8'h37,8'h37,3,1,1,2'b11,"SUBCIN_SAME_1");
            apply_test(1,8'h00,8'h0C,3,1,1,2'b11,"SUBCIN_0_NZ_1");
            apply_test(1,8'hFF,8'hFF,3,1,1,2'b01,"SUBCIN_INP_INVALID_B");
            apply_test(1,8'hFF,8'h01,3,1,1,2'b10,"SUBCIN_INP_INVALID_A");
            apply_test(1,8'hFF,8'h01,3,1,1,2'b00,"SUBCIN_INP_INVALID_A_B");
            // INC_A
            apply_test(1,8'h0C,8'h00,4,1,0,2'b11,"INC_A_VALID_3");
            apply_test(1,8'h0C,8'h00,4,1,0,2'b01,"INC_A_VALID_1");
            apply_test(1,8'hFF,8'h00,4,1,0,2'b11,"INC_A_MAX_3");
            apply_test(1,8'hFF,8'h00,4,1,0,2'b01,"INC_A_MAX_1");
            apply_test(1,8'hFF,8'h00,4,1,0,2'b10,"INC_A_INP_INVALID_A");
            apply_test(1,8'hFF,8'h00,4,1,0,2'b00,"INC_A_INP_INVALID_A_B");
            //DEC_A
            apply_test(1,8'h0C,8'h00,5,1,0,2'b11,"DEC_A_VALID_3");
            apply_test(1,8'h0C,8'h00,5,1,0,2'b01,"DEC_A_VALID_1");
            apply_test(1,8'h00,8'h00,5,1,0,2'b11,"DEC_A_MIN_3");
            apply_test(1,8'h00,8'h00,5,1,0,2'b01,"DEC_A_MIN_1");
            apply_test(1,8'hFF,8'h00,5,1,0,2'b10,"DEC_A_INP_INVALID_A");
            apply_test(1,8'hFF,8'h00,5,1,0,2'b00,"DEC_A_INP_INVALID_A_B");
            //INC_B
            apply_test(1,8'h00,8'hCC,6,1,0,2'b11,"INC_B_VALID_3");
            apply_test(1,8'h00,8'hCC,6,1,0,2'b10,"INC_B_VALID_2");
            apply_test(1,8'h00,8'hFF,6,1,0,2'b11,"INC_B_MAX_3");
            apply_test(1,8'h00,8'hFF,6,1,0,2'b10,"INC_B_MAX_2");
            apply_test(1,8'hFF,8'h00,6,1,0,2'b01,"INC_B_INP_INVALID_B");
            apply_test(1,8'hFF,8'h00,6,1,0,2'b00,"INC_B_INP_INVALID_A_B");
            //DEC_B
            apply_test(1,8'h00,8'h0C,7,1,0,2'b11,"DEC_B_VALID_3");
            apply_test(1,8'h00,8'h0C,7,1,0,2'b10,"DEC_B_VALID_2");
            apply_test(1,8'h00,8'h00,7,1,0,2'b11,"DEC_B_MIN_3");
            apply_test(1,8'h00,8'h00,7,1,0,2'b10,"DEC_B_MIN_2");
            apply_test(1,8'hFF,8'h00,7,1,0,2'b01,"DEC_B_INP_INVALID_B");
            apply_test(1,8'hFF,8'h00,7,1,0,2'b00,"DEC_B_INP_INVALID_A_B");
            //CMD
            apply_test(1,8'h0C,8'h05,8,1,0,2'b11,"CMP_GREATER");
            apply_test(1,8'h05,8'h0C,8,1,0,2'b11,"CMP_LESS");
            apply_test(1,8'hFF,8'hFF,8,1,0,2'b11,"CMP_EQUAL");
            apply_test(1,8'hFF,8'h01,8,1,0,2'b01,"CMP_INP_INVALID_B");
            apply_test(1,8'hFF,8'h01,8,1,0,2'b10,"CMP_INP_INVALID_A");
            apply_test(1,8'hFF,8'h01,8,1,0,2'b00,"CMP_INP_INVALID_A_B");
            //MUL
            apply_test_mul(8'd23,8'd12,3,1,0,1,9,"MUL ADD");
            apply_test_mul(8'd50,8'd225,3,1,0,1,9,"MUL ADD");
            apply_test_mul(8'd255,8'd255,3,1,0,1,9,"MUL ADD");
            apply_test_mul(8'd23,8'd12,3,1,0,1,10,"MUL SHIFT");
            apply_test_mul(8'd1,8'd3,3,1,0,1,10,"MUL SHIFT");
            apply_test_mul(8'd128,8'd1,3,1,0,1,10,"MUL SHIFT");
            apply_test_mul(8'd23,8'd12,2'b00,1,0,1,9,"MUL09_INV");
	    apply_test_mul(8'd23,8'd12,2'b00,1,0,1,10,"MUL10_INV");
	    apply_test_mul(8'hBF,8'h0F,2'b11,1,0,1,9,"MUL_TEMPA_UPPER");
	    apply_test_mul(8'h05,8'h0F,2'b11,1,0,1,9,"MUL_TEMPB_BIT4");
	    apply_test_mul(8'h05, 8'h1F, 2'b11, 1, 0, 1, 10, "MUL10_TEMPB_BIT4_HL");
	    apply_test_mul(8'h05, 8'h00, 2'b11, 1, 0, 1, 10, "MUL10_TEMPB_BIT4_LO");
            //SIGNED_ADD
            apply_test(1,8'd20,8'd10,11,1,0,2'b11,"SADD_VALID_POS");
            apply_test(1,-8'd10,-8'd5,11,1,0,2'b11,"SADD_VALID_NEG");
            apply_test(1,8'd20,-8'd5,11,1,0,2'b11,"SADD_POS_NEG");
            apply_test(1,8'd127,8'd1,11,1,0,2'b11,"SADD_POS_OFLOW");
            apply_test(1,-8'd128,-8'd1,11,1,0,2'b11,"SADD_NEG_OFLOW");
            apply_test(1,8'hFF,8'h01,11,1,0,2'b01,"SADD_INP_INVALID_B");
            apply_test(1,8'hFF,8'h01,11,1,0,2'b10,"SADD_INP_INVALID_A");
            apply_test(1,8'hFF,8'h01,11,1,0,2'b00,"SADD_INP_INVALID_A_B");
            //SIGNED_SUB
            apply_test(1,8'd20,8'd10,12,1,0,2'b11,"SSUB_VALID_POS");
            apply_test(1,-8'd20,-8'd10,12,1,0,2'b11,"SSUB_VALID_NEG");
            apply_test(1,8'd20,-8'd5,12,1,0,2'b11,"SSUB_POS_NEG");
            apply_test(1,-8'd20,8'd5,12,1,0,2'b11,"SSUB_NEG_POS");
            apply_test(1,8'd127,-8'd1,12,1,0,2'b11,"SSUB_POS_OFLOW");
            apply_test(1,-8'd128,8'd1,12,1,0,2'b11,"SSUB_NEG_OFLOW");
            apply_test(1,8'hFF,8'h01,12,1,0,2'b01,"SSUB_INP_INVALID_B");
            apply_test(1,8'hFF,8'h01,12,1,0,2'b10,"SSUB_INP_INVALID_A");
            apply_test(1,8'hFF,8'h01,12,1,0,2'b00,"SSUB_INP_INVALID_A_B");
	    //Undefined Arithmetic CMD: expcted ERR
	    apply_test(1,8'hAA,8'hBB,15,1,0,2'b11,"ARITHMETIC_DEFAULT_INVALID");
        end
    endtask

    // Test logical operations(MODE=0)
    task test_logical();
        begin
            //AND
            apply_test(1,8'hCC,8'hAA,0,0,0,2'b11,"AND_VALID");
            apply_test(1,8'hAA,8'h00,0,0,0,2'b11,"AND_ZERO");
            apply_test(1,8'hCC,8'hAA,0,0,0,2'b01,"AND_INP_INVALID_B");
            apply_test(1,8'hCC,8'hAA,0,0,0,2'b10,"AND_INP_INVALID_A");
            apply_test(1,8'hCC,8'hAA,0,0,0,2'b00,"AND_INP_INVALID_A_B");
            //NAND
            apply_test(1,8'hCC,8'hAA,1,0,0,2'b11,"NAND_VALID");
            apply_test(1,8'hFF,8'hFF,1,0,0,2'b11,"NAND_ALL_ONES");
            apply_test(1,8'hF0,8'h00,1,0,0,2'b11,"NAND_ZERO");
            apply_test(1,8'hCC,8'hAA,1,0,0,2'b01,"NAND_INP_INVALID_B");
            apply_test(1,8'hCC,8'hAA,1,0,0,2'b10,"NAND_INP_INVALID_A");
            apply_test(1,8'hCC,8'hAA,1,0,0,2'b00,"NAND_INP_INVALID_A_B");
            //OR
            apply_test(1,8'hCC,8'hAA,2,0,0,2'b11,"OR_VALID");
            apply_test(1,8'h00,8'h00,2,0,0,2'b11,"OR_ZERO");
                apply_test(1,8'hCC,8'hAA,2,0,0,2'b01,"OR_INP_INVALID_B");
            apply_test(1,8'hCC,8'hAA,2,0,0,2'b10,"OR_INP_INVALID_A");
            apply_test(1,8'hCC,8'hAA,2,0,0,2'b00,"OR_INP_INVALID_A_B");
                //NOR
            apply_test(1,8'hCC,8'hAA,3,0,0,2'b11,"NOR_VALID");
                apply_test(1,8'h00,8'h00,3,0,0,2'b11,"NOR_ZERO");
                apply_test(1,8'hCC,8'hAA,3,0,0,2'b01,"NOR_INP_INVALID_B");
            apply_test(1,8'hCC,8'hAA,3,0,0,2'b10,"NOR_INP_INVALID_A");
            apply_test(1,8'hCC,8'hAA,3,0,0,2'b00,"NOR_INP_INVALID_A_B");
                //XOR
            apply_test(1,8'hCC,8'hAA,4,0,0,2'b11,"XOR_VALID");
                apply_test(1,8'hFF,8'hFF,4,0,0,2'b11,"XOR_SAME");
                apply_test(1,8'hCC,8'hAA,4,0,0,2'b01,"XOR_INP_INVALID_B");
            apply_test(1,8'hCC,8'hAA,4,0,0,2'b10,"XOR_INP_INVALID_A");
            apply_test(1,8'hCC,8'hAA,4,0,0,2'b00,"XOR_INP_INVALID_A_B");
            //XNOR
            apply_test(1,8'hCC,8'hAA,5,0,0,2'b11,"XNOR_VALID");
            apply_test(1,8'hFF,8'hFF,5,0,0,2'b11,"XNOR_SAME");
            apply_test(1,8'hCC,8'hAA,5,0,0,2'b01,"XNOR_INP_INVALID_B");
            apply_test(1,8'hCC,8'hAA,5,0,0,2'b10,"XNOR_INP_INVALID_A");
            apply_test(1,8'hCC,8'hAA,5,0,0,2'b00,"XNOR_INP_INVALID_A_B");
            //NOT_A
            apply_test(1,8'hCC,8'h00,6,0,0,2'b11,"NOT_A_VALID_3");
            apply_test(1,8'hCC,8'h00,6,0,0,2'b01,"NOT_A_VALID_1");
            apply_test(1,8'h00,8'h00,6,0,0,2'b11,"NOT_A_ZERO_3");
            apply_test(1,8'h00,8'h00,6,0,0,2'b01,"NOT_A_ZERO_1");
            apply_test(1,8'hAA,8'h00,6,0,0,2'b10,"NOT_A_INP_INVALID_B");
            apply_test(1,8'hAA,8'h00,6,0,0,2'b00,"NOT_A_INP_INVALID_A_B");
            //NOT_B
            apply_test(1,8'h00,8'hCC,7,0,0,2'b11,"NOT_B_VALID_3");
            apply_test(1,8'h00,8'hCC,7,0,0,2'b10,"NOT_B_VALID_2");
            apply_test(1,8'h00,8'h00,7,0,0,2'b11,"NOT_B_ZERO_3");
            apply_test(1,8'h00,8'h00,7,0,0,2'b10,"NOT_B_ZERO_2");
            apply_test(1,8'h00,8'hAA,7,0,0,2'b01,"NOT_B_INP_INVALID_B");
            apply_test(1,8'h00,8'hAA,7,0,0,2'b00,"NOT_B_INP_INVALID_A_B");
            //SHR1_A
            apply_test(1,8'h11,8'h00,8,0,0,2'b11,"SHR1_A_VALID_3");
            apply_test(1,8'h11,8'h00,8,0,0,2'b01,"SHR1_A_VALID_1");
            apply_test(1,8'h80,8'h00,8,0,0,2'b11,"SHR1_A_LSB_3");
            apply_test(1,8'h80,8'h00,8,0,0,2'b01,"SHR1_A_LSB_1");
            apply_test(1,8'hAA,8'h00,8,0,0,2'b10,"SHR1_A_INP_INVALID_A");
            apply_test(1,8'hAA,8'h00,8,0,0,2'b00,"SHR1_A_INP_INVALID_A_B");
            //SHL1_A
            apply_test(1,8'h11,8'h00,9,0,0,2'b11,"SHL1_A_VALID_3");
            apply_test(1,8'h11,8'h00,9,0,0,2'b01,"SHL1_A_VALID_1");
            apply_test(1,8'h80,8'h00,9,0,0,2'b11,"SHL1_A_MSB_3");
            apply_test(1,8'h80,8'h00,9,0,0,2'b01,"SHL1_A_MSB_1");
            apply_test(1,8'hAA,8'h00,9,0,0,2'b10,"SHL1_A_INP_INVALID_A");
            apply_test(1,8'hAA,8'h00,9,0,0,2'b00,"SHL1_A_INP_INVALID_A_B");
            //SHR1_B
            apply_test(1,8'h00,8'h11,10,0,0,2'b11,"SHR1_B_VALID_3");
            apply_test(1,8'h00,8'h11,10,0,0,2'b10,"SHR1_B_VALID_2");
            apply_test(1,8'h00,8'h80,10,0,0,2'b11,"SHR1_B_LSB_3");
            apply_test(1,8'h00,8'h80,10,0,0,2'b10,"SHR1_B_LSB_2");
            apply_test(1,8'h00,8'hAA,10,0,0,2'b01,"SHR1_B_INP_INVALID_B");
            apply_test(1,8'h00,8'hAA,10,0,0,2'b00,"SHR1_B_INP_INVALID_A_B");
            //SHL1_B
            apply_test(1,8'h00,8'h11,11,0,0,2'b11,"SHL1_B_VALID_3");
            apply_test(1,8'h00,8'h11,11,0,0,2'b10,"SHL1_B_VALID_2");
            apply_test(1,8'h00,8'h80,11,0,0,2'b11,"SHL1_B_MSB_3");
            apply_test(1,8'h00,8'h80,11,0,0,2'b10,"SHL1_B_MSB_2");
            apply_test(1,8'h00,8'hAA,11,0,0,2'b01,"SHL1_B_INP_INVALID_B");
            apply_test(1,8'h00,8'hAA,11,0,0,2'b00,"SHL1_B_INP_INVALID_A_B");
            //ROL_A_B
            apply_test(1,8'hB1,8'h00,12,0,0,2'b11,"ROL_NO_SHIFT");
            apply_test(1,8'hB1,8'h01,12,0,0,2'b11,"ROL_BY_1");
            apply_test(1,8'hB1,8'h07,12,0,0,2'b11,"ROL_BY_7");
            apply_test(1,8'hB1,8'h84,12,0,0,2'b11,"ROL_UPPERBIT");
            apply_test(1,4'hC,4'h2,12,0,0,2'b11,"ROL_4");
            apply_test(1,8'hCC,8'hAA,12,0,0,2'b01,"ROL_INP_INVALID_B");
            apply_test(1,8'hCC,8'hAA,12,0,0,2'b10,"ROR_INP_INVALID_A");
            apply_test(1,8'hCC,8'hAA,12,0,0,2'b00,"ROR_INP_INVALID_A_B");
            //ROR_A_B
            apply_test(1,8'hB1,8'h00,13,0,0,2'b11,"ROR_NO_SHIFT");
            apply_test(1,8'hB1,8'h01,13,0,0,2'b11,"ROR_BY_1");
            apply_test(1,8'hB1,8'h07,13,0,0,2'b11,"ROR_BY_7");
            apply_test(1,8'hB1,8'h84,13,0,0,2'b11,"ROR_UPPERBIT");
            apply_test(1,8'hCC,8'hAA,13,0,0,2'b01,"ROR_INP_INVALID_B");
            apply_test(1,8'hCC,8'hAA,13,0,0,2'b10,"ROR_INP_INVALID_A");
            apply_test(1,8'hCC,8'hAA,13,0,0,2'b00,"ROR_INP_INVALID_A_B");
            //CE=0: output should not update
	    apply_test(0,8'hB1,8'h00,13,0,0,2'b11,"ROR_NO_SHIFT");
	    //CE=1: confirm output updates
	    apply_test(1,8'hB1,8'h01,13,0,0,2'b11,"ROR_CE1");
	    //Undefined CMD : expected ERR
	    apply_test(1,8'hAA,8'hBB,15,0,0,2'b11,"LOGICAL_DEFAULT_INVALID");
        end
    endtask

    // Apply a single cycle test and compare DUT vs reference
    // Drives inputs on negedge, sampled on posedge+1 cycle settle.
    task apply_test(
        input ce,
        input [IN_SIZE-1:0] a, b,
        input [CMD_SIZE-1:0] cmd,
        input mode, cin,
        input [1:0] inp_valid,
        input [80*8:1] test_name
    );
        begin
            @(negedge CLK);
            OPA = a;
            OPB = b;
            CMD = cmd;
            INP_VALID = inp_valid;
                MODE = mode;
            CIN = cin;
            CE = ce;

            @(posedge CLK);
            INP_VALID = 2'b00;//de-assert after one active cycle
            @(posedge CLK);
            @(negedge CLK);

            test_count = test_count + 1;

            if (compare_outputs(COUT_dut, COUT_ref)) begin
                $display("[PASS] %s: OPA=0x%h OPB=0x%h CMD=0x%h",test_name, a, b, cmd);
                pass_count = pass_count + 1;
                display_mismatch();
            end else begin
                $display("[FAIL] %s: OPA=0x%h OPB=0x%h CMD=0x%h",test_name, a, b, cmd);
                fail_count = fail_count + 1;
                display_mismatch();
            end
        end
    endtask

    // Apply a multiply test(multi-cycle operation)
    // Cycle 1: check that result is still x.
    // Cycle 2: compare final result against reference.
    task apply_test_mul(
        input[IN_SIZE-1:0] a,b,
        input [1:0] inp,
        input mode, cin, ce,
        input [CMD_SIZE-1:0] cmd,
        input [80*8:1] test_name
    );
        begin
	    f=0;
            @(negedge CLK);
            OPA = a;
            OPB = b;
            INP_VALID = inp;
            MODE = mode;
            CIN = cin;
            CE = ce;
            CMD = cmd;

            @(posedge CLK);
            INP_VALID = 2'b00; //de-assert result should still be x
	    @(posedge CLK);
	    @(negedge CLK);

            //Cycle 1 check: result must not be valid yet (x)
            if(RES_dut !== {(2*IN_SIZE){1'bx}}) begin  
                f=1; //mark early valid failure
                test_count = test_count + 1;
                $display("[FAIL] %s: OPA=0x%h OPB=0x%h INP_VALID=0x%h MODE=0x%h CIN=0x%h CE=0x%h CMD=0x%h",test_name,a,b,inp,mode,cin,ce,cmd);
                fail_count = fail_count + 1;
                display_mismatch();
            end 

	    //Cycle 2 check: final result vs reference
            @(posedge CLK);
            @(negedge CLK);
            if(f==0) begin
		test_count = test_count + 1;
                if(compare_outputs(COUT_dut,COUT_ref)) begin
                   $display("[PASS] %s: OPA=0x%h OPB=0x%h INP_VALID=0x%h MODE=0x%h CIN=0x%h CE=0x%h CMD=0x%h",test_name,a,b,inp,mode,cin,ce,cmd);
                    pass_count = pass_count + 1;
                    display_mismatch();
                end else begin
                    $display("[FAIL] %s: OPA=0x%h OPB=0x%h INP_VALID=0x%h MODE=0x%h CIN=0x%h CE=0x%h CMD=0x%h",test_name,a,b,inp,mode,cin,ce,cmd);
                    display_mismatch();
                    fail_count = fail_count + 1;
                end
            end
        end
    endtask

    // Compare DUT vs Reference
    function compare_outputs(input COUT_dut, COUT_ref);
        begin
            compare_outputs = 1;
            if (RES_dut !== RES_ref) compare_outputs = 0;
            if (COUT_dut !== COUT_ref) compare_outputs = 0;
            if (OFLOW_dut !== OFLOW_ref) compare_outputs = 0;
            if (ERR_dut !== ERR_ref) compare_outputs = 0;
            if (E_dut !== E_ref) compare_outputs = 0;
            if (G_dut !== G_ref) compare_outputs = 0;
            if (L_dut !== L_ref) compare_outputs = 0;
        end
    endfunction

    // Display mismatch details
    task display_mismatch();
        begin
            $display("DUT: RES=0x%h COUT=%b OFLOW=%b G=%b E=%b L=%b ERR=%b",RES_dut, COUT_dut, OFLOW_dut, G_dut, E_dut, L_dut, ERR_dut);
            $display("  REF:     RES=0x%h COUT=%b OFLOW=%b G=%b E=%b L=%b ERR=%b",RES_ref, COUT_ref, OFLOW_ref, G_ref, E_ref, L_ref, ERR_ref);
        end
    endtask

    // Waveform dump
    initial begin
        $dumpfile("alu_test.vcd");
        $dumpvars(0,testbench_main);
    end

endmodule

