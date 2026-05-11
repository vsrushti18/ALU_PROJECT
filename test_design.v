//----------------------------------------------------------
//DUT Tested in the TB
//----------------------------------------------------------

`timescale 1ns / 1ps
`default_nettype none

module test_design #(
    parameter CMD_SIZE = 4,
    parameter IN_SIZE  = 8,
    parameter OUT_SIZE = 2*IN_SIZE
)(
    input  wire                    CLK,
    input  wire                    RST,
    input  wire                    CIN,
    input  wire                    CE,
    input  wire                    MODE,

    input  wire [1:0]              INP_VALID,
    input  wire [IN_SIZE-1:0]      OPA,
    input  wire [IN_SIZE-1:0]      OPB,
    input  wire [CMD_SIZE-1:0]     CMD,

    output reg                     OFLOW,
    output reg                     COUT,
    output reg                     G,
    output reg                     L,
    output reg                     E,
    output reg                     ERR,

    output reg [OUT_SIZE-1:0]      RES
);

////////////////////////////////////////////////////////
// VALID VALUES
////////////////////////////////////////////////////////

parameter NOT_VALID  = 2'b00;
parameter VALID_A    = 2'b01;
parameter VALID_B    = 2'b10;
parameter BOTH_VALID = 2'b11;

////////////////////////////////////////////////////////
// ARITHMETIC COMMANDS
////////////////////////////////////////////////////////

parameter ADD      = 4'd0;
parameter SUB      = 4'd1;
parameter ADD_CIN  = 4'd2;
parameter SUB_CIN  = 4'd3;

parameter INC_A    = 4'd4;
parameter DEC_A    = 4'd5;
parameter INC_B    = 4'd6;
parameter DEC_B    = 4'd7;

parameter CMP      = 4'd8;
parameter OP_09    = 4'd9;
parameter OP_10    = 4'd10;
parameter OP_11    = 4'd11;
parameter OP_12    = 4'd12;

////////////////////////////////////////////////////////
// LOGICAL COMMANDS
////////////////////////////////////////////////////////

parameter AND_     = 4'd0;
parameter NAND_    = 4'd1;
parameter OR_      = 4'd2;
parameter NOR_     = 4'd3;

parameter XOR_     = 4'd4;
parameter XNOR_    = 4'd5;
parameter NOT_A    = 4'd6;
parameter NOT_B    = 4'd7;

parameter SHR1_A   = 4'd8;
parameter SHL1_A   = 4'd9;
parameter SHR1_B   = 4'd10;
parameter SHL1_B   = 4'd11;

parameter ROL_A_B  = 4'd12;
parameter ROR_A_B  = 4'd13;

////////////////////////////////////////////////////////
// INTERNAL REGS
////////////////////////////////////////////////////////

reg [1:0] count;

reg [IN_SIZE-1:0] temp_a;
reg [IN_SIZE-1:0] temp_b;

////////////////////////////////////////////////////////
// MAIN BLOCK
////////////////////////////////////////////////////////

always @(posedge CLK or posedge RST)
begin

    if(RST)
    begin
        RES    <= 0;
        COUT   <= 0;
        OFLOW  <= 0;
        G      <= 0;
        L      <= 0;
        E      <= 0;
        ERR    <= 0;

        count  <= 0;
        temp_a <= 0;
        temp_b <= 0;
    end

    else if(CE)
    begin

        ////////////////////////////////////////////////
        // DEFAULTS
        ////////////////////////////////////////////////

        COUT  <= 0;
        OFLOW <= 0;
        G     <= 0;
        L     <= 0;
        E     <= 0;
        ERR   <= 0;

        ////////////////////////////////////////////////
        // ARITHMETIC MODE
        ////////////////////////////////////////////////

        if(MODE)
        begin

            case(CMD)

            ////////////////////////////////////////////
            // ADD
            ////////////////////////////////////////////

            ADD:
            begin
                if(INP_VALID == BOTH_VALID)
                begin
                    {COUT,RES} <= OPA + OPB;
                end
                else
                    RES <= 0;
            end

            ////////////////////////////////////////////
            // SUB
            ////////////////////////////////////////////

            SUB:
            begin
                if(INP_VALID == BOTH_VALID)
                begin
                    RES    <= OPA - OPB;
                    OFLOW <= (OPA < OPB);
                end
                else
                    RES <= 0;
            end

            ////////////////////////////////////////////
            // ADD_CIN
            ////////////////////////////////////////////

            ADD_CIN:
            begin
                if(INP_VALID == BOTH_VALID)
                begin
                    {COUT,RES} <= OPA + OPB + CIN;
                end
                else
                    RES <= 0;
            end

            ////////////////////////////////////////////
            // SUB_CIN
            ////////////////////////////////////////////

            SUB_CIN:
            begin
                if(INP_VALID == BOTH_VALID)
                begin
                    RES <= OPA - OPB - CIN;

                    OFLOW <= ((OPA < OPB) ||
                               ((OPA == OPB) && CIN));
                end
                else
                    RES <= 0;
            end

            ////////////////////////////////////////////
            // INC/DEC
            ////////////////////////////////////////////

            INC_A:
            begin
                if(INP_VALID == VALID_A)
                    RES <= OPA + 1'b1;
                else
                    RES <= 0;
            end

            DEC_A:
            begin
                if(INP_VALID == VALID_A)
                    RES <= OPA - 1'b1;
                else
                    RES <= 0;
            end

            INC_B:
            begin
                if(INP_VALID == VALID_B)
                    RES <= OPB + 1'b1;
                else
                    RES <= 0;
            end

            DEC_B:
            begin
                if(INP_VALID == VALID_B)
                    RES <= OPB - 1'b1;
                else
                    RES <= 0;
            end

            ////////////////////////////////////////////
            // CMP
            ////////////////////////////////////////////

            CMP:
            begin
                RES <= 0;

                if(INP_VALID == BOTH_VALID)
                begin
                    if(OPA > OPB)
                        G <= 1'b1;

                    else if(OPA < OPB)
                        L <= 1'b1;

                    else
                        E <= 1'b1;
                end
            end

            ////////////////////////////////////////////
            // OP_09
            // (OPA+1)*(OPB+1)
            // 3-CYCLE OPERATION
            ////////////////////////////////////////////

            OP_09:
            begin

                case(count)

                    2'd0:
                    begin
                        if(INP_VALID == BOTH_VALID)
                        begin
                            temp_a <= OPA + 1'b1;
                            temp_b <= OPB + 1'b1;
                            count  <= 2'd1;
                        end
                    end

                    2'd1:
                    begin
                        count <= 2'd2;
                    end

                    2'd2:
                    begin
                        RES   <= temp_a * temp_b;
                        count <= 2'd0;
                    end

                endcase
            end

            ////////////////////////////////////////////
            // OP_10
            // (OPA<<1)*OPB
            // 3-CYCLE OPERATION
            ////////////////////////////////////////////

            OP_10:
            begin

                case(count)

                    2'd0:
                    begin
                        if(INP_VALID == BOTH_VALID)
                        begin
                            temp_a <= (OPA << 1);
                            temp_b <= OPB;
                            count  <= 2'd1;
                        end
                    end

                    2'd1:
                    begin
                        count <= 2'd2;
                    end

                    2'd2:
                    begin
                        RES   <= temp_a * temp_b;
                        count <= 2'd0;
                    end

                endcase
            end

            ////////////////////////////////////////////
            // SIGNED ADD
            ////////////////////////////////////////////

            OP_11:
            begin
                if(INP_VALID == BOTH_VALID)
                begin
                    RES <= $signed(OPA) + $signed(OPB);

                    if((OPA[IN_SIZE-1] == OPB[IN_SIZE-1]) &&
                       (RES[IN_SIZE-1] != OPA[IN_SIZE-1]))
                        OFLOW <= 1'b1;
                end
                else
                    RES <= 0;
            end

            ////////////////////////////////////////////
            // SIGNED SUB
            ////////////////////////////////////////////

            OP_12:
            begin
                if(INP_VALID == BOTH_VALID)
                begin
                    RES <= $signed(OPA) - $signed(OPB);

                    if((OPA[IN_SIZE-1] != OPB[IN_SIZE-1]) &&
                       (RES[IN_SIZE-1] != OPA[IN_SIZE-1]))
                        OFLOW <= 1'b1;
                end
                else
                    RES <= 0;
            end

            default:
            begin
                RES <= 0;
            end

            endcase

        end

        ////////////////////////////////////////////////
        // LOGICAL MODE
        ////////////////////////////////////////////////

        else
        begin

            case(CMD)

            AND_:
                RES <= (INP_VALID == BOTH_VALID) ? (OPA & OPB) : 0;

            NAND_:
                RES <= (INP_VALID == BOTH_VALID) ? ~(OPA & OPB) : 0;

            OR_:
                RES <= (INP_VALID == BOTH_VALID) ? (OPA | OPB) : 0;

            NOR_:
                RES <= (INP_VALID == BOTH_VALID) ? ~(OPA | OPB) : 0;

            XOR_:
                RES <= (INP_VALID == BOTH_VALID) ? (OPA ^ OPB) : 0;

            XNOR_:
                RES <= (INP_VALID == BOTH_VALID) ? ~(OPA ^ OPB) : 0;

            NOT_A:
                RES <= (INP_VALID == VALID_A) ? (~OPA) : 0;

            NOT_B:
                RES <= (INP_VALID == VALID_B) ? (~OPB) : 0;

            SHR1_A:
                RES <= (INP_VALID == VALID_A) ? (OPA >> 1) : 0;

            SHL1_A:
                RES <= (INP_VALID == VALID_A) ? (OPA << 1) : 0;

            SHR1_B:
                RES <= (INP_VALID == VALID_B) ? (OPB >> 1) : 0;

            SHL1_B:
                RES <= (INP_VALID == VALID_B) ? (OPB << 1) : 0;

            ////////////////////////////////////////////
            // ROL
            ////////////////////////////////////////////

            ROL_A_B:
            begin

                if(INP_VALID == BOTH_VALID)
                begin

                    RES <= (OPA << OPB[2:0]) |
                           (OPA >> (IN_SIZE - OPB[2:0]));

                    if(OPB[7:4] != 0)
                        ERR <= 1'b1;
                end
                else
                    RES <= 0;
            end

            ////////////////////////////////////////////
            // ROR
            ////////////////////////////////////////////

            ROR_A_B:
            begin

                if(INP_VALID == BOTH_VALID)
                begin

                    RES <= (OPA >> OPB[2:0]) |
                           (OPA << (IN_SIZE - OPB[2:0]));

                    if(OPB[7:4] != 0)
                        ERR <= 1'b1;
                end
                else
                    RES <= 0;
            end

            default:
            begin
                RES <= 0;
            end

            endcase

        end

    end

end

endmodule
