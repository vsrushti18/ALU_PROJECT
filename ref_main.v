//------------------------------------------
//Reference Model for the ALU.
//Implements the same arithmetic and logical operation as the DUT
//Used by the testbench to generate expected outputs for comparison.
//-----------------------------------------

`timescale 1ns / 1ps

`default_nettype none

module ref_main #
(
    parameter IN_SIZE  = 8,
    parameter CMD_SIZE = 4,
    parameter OUT_SIZE = 2*IN_SIZE
)
(
    input wire CLK,
    input wire RST,
    input wire CE,
    input wire [IN_SIZE-1:0] OPA,
    input wire [IN_SIZE-1:0] OPB,
    input wire CIN,
    input wire MODE,
    input wire [CMD_SIZE-1:0] CMD,
    input wire [1:0] INP_VALID,
    output reg [(2*IN_SIZE)-1:0] RES,
    output reg COUT,
    output reg OFLOW,
    output reg G,
    output reg L,
    output reg E,
    output reg ERR
);
    //Internal Resgistered copies of inputs (latched at count=0)
    reg [(2*IN_SIZE)-1:0] out;
    reg gout, lout, eout;
    reg cout_out, oflow_out, err_out;
    reg [IN_SIZE-1:0] opa_i, opb_i;
    reg cin_i;
    reg mode_i;
    reg [CMD_SIZE-1:0] cmd_i;
    reg [1:0] inp_valid_i;

    //count: 0(latch) ,1(intermediate,mul only), 2=output result
    reg [1:0] count;

    reg signed [(2*IN_SIZE)-1:0] signed_temp; //used for signed ADD/SUB
    
    //Shift amount for rotate: takes lower bits of OPB only
    wire [IN_SIZE-1:0] sh;
    assign sh = opb_i % IN_SIZE;
    
    //Sequential: latch inputs, advance pipeline counter, register outputs
    always @(posedge CLK or posedge RST) begin
        if(RST)begin
            RES <= 0;
            COUT <= 0;
            OFLOW <= 0;
            G <= 0;
            L <= 0;
            E <= 0;
            ERR <= 0;
            opa_i <= 0;
            opb_i <= 0;
            cin_i <= 0;
            mode_i <= 0;
            cmd_i <= 0;
            inp_valid_i <= 0;
            count <= 0;
        end else if(CE)begin
            if(count == 0) begin
	        //Latch all inputs, clear outputs while computing
                RES <= 0;
                COUT <= 0;
                OFLOW <= 0;
                G <= 0;
                L <= 0;
                E <= 0;
                ERR <= 0;
                opa_i <= OPA;
                opb_i <= OPB;
                cin_i <= CIN;
                mode_i <= MODE;
                cmd_i <= CMD;
                inp_valid_i <= INP_VALID;
		//MUL needs extra pipeline cycle: all others go straight to count=2
                if(MODE && (CMD == 4'd9 || CMD == 4'd10)) count <= 1;
                else count <= 2;
            end else if(count == 1)begin
	    	//MUL intermediate cycle: holds output as x
                RES <= {(2*IN_SIZE){1'bx}};
                COUT <= 0;
                OFLOW <= 0;
                G <= 0;
                L <= 0;
                E <= 0;
                ERR <= 0;
                count <= 2;
            end else if(count == 2) begin
	        //Register combinational results to outputs
                RES <= out;
                COUT <= cout_out;
                OFLOW <= oflow_out;
                G <= gout;
                L <= lout;
                E <= eout;
                ERR <= err_out;
		//Relatch inputs for the next operation
                opa_i <= OPA;
                opb_i <= OPB;
                cin_i <= CIN;
                mode_i <= MODE;
                cmd_i <= CMD;
                inp_valid_i <= INP_VALID;
                if(MODE && (CMD == 4'd9 || CMD == 4'd10)) count <= 1;
                else count <= 2;
            end
        end
    end

    //Combinational: compute result from latched inputs
    always @(*)begin
        //Default all outputs to 0 before case decode
        out = 0;
        gout = 0;
        lout = 0;
        eout = 0;
        cout_out = 0;
        oflow_out = 0;
        err_out = 0;
        signed_temp = 0;
        if(mode_i) begin
            case(cmd_i)
                4'd0: begin //ADD
                    if(inp_valid_i == 2'd3) begin
                        {cout_out,out[IN_SIZE-1:0]} = opa_i + opb_i;
                        out = opa_i + opb_i;
                    end else err_out = 1;
                end
                4'd1: begin //SUB
                    if(inp_valid_i == 2'd3) begin
                        out = opa_i - opb_i;
                        oflow_out = (opa_i < opb_i);
                    end else err_out = 1;
                end
                4'd2: begin //ADD_CIN
                    if(inp_valid_i == 2'd3) begin
                        {cout_out,out[IN_SIZE-1:0]} = opa_i + opb_i + cin_i;
                        out = opa_i + opb_i + cin_i;
                    end else err_out = 1;
                end
                4'd3:begin //SUB_CIN
                    if(inp_valid_i == 2'd3) begin
                        out = opa_i - opb_i - cin_i;
                        oflow_out = (opa_i < (opb_i + cin_i));
                    end else err_out = 1;
                end
                4'd4: begin //INC_A
                    if(inp_valid_i[0]) out[IN_SIZE-1:0] = opa_i + 1;
                    else err_out = 1;
                end
                4'd5: begin //DEC_A
                    if(inp_valid_i[0]) out[IN_SIZE-1:0] = opa_i - 1;
                    else err_out = 1;
                end
                4'd6: begin //INC_B
                    if(inp_valid_i[1]) out[IN_SIZE-1:0] = opb_i + 1;
                    else err_out = 1;
                end
                4'd7: begin // DEC_B
                    if(inp_valid_i[1]) out[IN_SIZE-1:0] = opb_i - 1;
                    else err_out = 1;
                end
                4'd8: begin //CMP_G_E_L
                    if(inp_valid_i == 2'd3) begin
                        gout = (opa_i > opb_i);
                        lout = (opa_i < opb_i);
                        eout = (opa_i == opb_i);
                    end else err_out = 1;
                end
                4'd9: begin //MUL_ADD
                    if(inp_valid_i == 2'd3) begin
                        out = (opa_i + 1) *(opb_i + 1);
                    end else begin err_out = 1; out = 0; end
                end
                4'd10: begin //MUL_SHIFT
                    if(inp_valid_i == 2'd3) begin
                        out = (opa_i << 1) * opb_i;
                    end else begin err_out = 1; out = 0; end
                end
                4'd11: begin //SIG_ADD
                    if(inp_valid_i == 2'd3) begin
                        signed_temp = $signed(opa_i) + $signed(opb_i);
                        out = signed_temp;
                        oflow_out = (opa_i[IN_SIZE-1] == opb_i[IN_SIZE-1]) && (signed_temp[IN_SIZE-1] != opa_i[IN_SIZE-1]);
                    end else err_out = 1;
                end
                4'd12: begin //SIG_SUB
                    if(inp_valid_i == 2'd3) begin
                        signed_temp = $signed(opa_i) - $signed(opb_i);
                        out = signed_temp;
                        oflow_out = (opa_i[IN_SIZE-1] != opb_i[IN_SIZE-1]) && (signed_temp[IN_SIZE-1] != opa_i[IN_SIZE-1]);
                    end else err_out = 1;
                end
                default: err_out = 1; //Undefined CMD
            endcase
        end else begin
            case(cmd_i)
                4'd0: begin //AND
                    if(inp_valid_i == 2'd3) out[IN_SIZE-1:0] = opa_i & opb_i;
                    else err_out = 1;
                end
                4'd1: begin //NAND
                    if(inp_valid_i == 2'd3) out[IN_SIZE-1:0] = ~(opa_i & opb_i);
                    else err_out = 1;
                end
                4'd2: begin //OR
                    if(inp_valid_i == 2'd3) out[IN_SIZE-1:0] = opa_i | opb_i;
                    else err_out = 1;
                end
                4'd3: begin //NOR
                    if(inp_valid_i == 2'd3) out[IN_SIZE-1:0] = ~(opa_i | opb_i);
                    else err_out = 1;
                end
                4'd4: begin //XOR
                    if(inp_valid_i == 2'd3) out[IN_SIZE-1:0] = opa_i ^ opb_i;
                    else err_out = 1;
                end
                4'd5: begin //XNOR
                    if(inp_valid_i == 2'd3) out[IN_SIZE-1:0] = ~(opa_i ^ opb_i);
                    else err_out = 1;
                end
                4'd6: begin //NOT_A
                    if(inp_valid_i == 2'd1 || inp_valid_i == 2'd3) out[IN_SIZE-1:0] = ~opa_i;
                    else err_out = 1;
                end
                4'd7: begin //NOT_B
                    if(inp_valid_i == 2'd2 || inp_valid_i == 2'd3) out[IN_SIZE-1:0] = ~opb_i;
                    else err_out = 1;
                end
                4'd8: begin //SHR1_A
                    if(inp_valid_i == 2'd1 || inp_valid_i == 2'd3) out[IN_SIZE-1:0] = opa_i >> 1;
                    else err_out = 1;
                end
                4'd9: begin //SHL1_A
                    if(inp_valid_i == 2'd1 || inp_valid_i == 2'd3) out[IN_SIZE-1:0] = opa_i << 1;
                    else err_out = 1;
                end
                4'd10: begin //SHR1_B
                    if(inp_valid_i == 2'd2 || inp_valid_i == 2'd3) out[IN_SIZE-1:0] = opb_i >> 1;
                    else err_out = 1;
                end
                4'd11: begin //SHL1_B
                    if(inp_valid_i == 2'd2 || inp_valid_i == 2'd3) out[IN_SIZE-1:0] = opb_i << 1;
                    else err_out = 1;
                end
                4'd12: begin //ROL
                    if(inp_valid_i == 2'd3) begin
                        out[IN_SIZE-1:0] = (opa_i >> sh) | (opa_i << (IN_SIZE - sh));
                        if(|opb_i[IN_SIZE-1:4]) err_out = 1;
                    end else err_out = 1;
                end
                4'd13: begin //ROR
                    if(inp_valid_i == 2'd3) begin
                        out[IN_SIZE-1:0] = (opa_i << sh) | (opa_i >> (IN_SIZE - sh));
                        if(|opb_i[IN_SIZE-1:4]) err_out = 1;
                    end else err_out = 1;
                end
                default: err_out = 1;//Undefined CMD in logical
            endcase
        end
    end
endmodule

