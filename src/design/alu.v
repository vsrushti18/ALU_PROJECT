//--------------------------------------------------
//Main Design Code for ALU
//--------------------------------------------------

`timescale 1ns / 1ps

`default_nettype none

module alu #(parameter width = 8,cmd_width=4)(
    input wire [width-1:0]opa,opb,
    input wire [1:0]inp_valid,
    input wire cin,clk,rst,ce,mode,
    input wire [cmd_width-1:0]cmd,
    output reg [2*width-1:0]res, 
    output reg oflow,cout,g,l,e,err
    );
    //Combinatinoal result 
    reg[2*width-1:0]out;
    reg gout,eout,lout;
    reg cout_out,oflow_out,err_out;

    //Latched copies of inputs
    reg [width-1:0]opa_i,opb_i;
    reg [3:0]cmd_i;
    reg [1:0]inp_valid_i;
    reg mode_i;
    reg cin_i;

    //count: 0(latched) 1(intermediate mul) 2(output result)
    reg [1:0]count;

    //Rotate shift amount
    wire [width-1:0] sh;
    assign sh = opb_i % width;

    //Sequential : latch inputs, advance pipeline, register output
    always@(posedge clk or posedge rst) begin
        if(rst) begin
            res<=0;
            gout<=0; eout<=0; lout<=0;
            count<=0;
        end
        else begin
            if(ce) begin
                if(count==0) begin
                    if(inp_valid) begin
                        opa_i<=opa;
                        opb_i<=opb;
                        cin_i<=cin;
                        cmd_i<=cmd;
                        mode_i<=mode;
                        inp_valid_i<=inp_valid;
                        if((cmd==9 || cmd==10) && mode)count<=1; 
                        else count<=2;
                    end
                end else if(count==1) begin
                    res<={2*width{1'bx}};
                    count<=2;
                end else if(count==2) begin
                    res<=out;
                    g<=gout;
                    e<=eout;
                    l<=lout;
                    cout<=cout_out;
                    oflow<=oflow_out;
                    err<=err_out;
                    if(inp_valid) begin
                        opa_i <= opa;
                        opb_i <= opb;
                        cin_i <= cin;
                        cmd_i <= cmd;
                        mode_i <= mode;
                        inp_valid_i <= inp_valid;
                        if((cmd==9 || cmd==10) && mode)
                            count <= 1;
                        else
                            count <= 2;
                    end else begin
                        count <= 0;
                    end
                end
            end
        end
    end
    
    //Combinational : compute result from lathced inputs
    always@(*) begin
                out = 0;
                oflow_out = 0; cout_out = 0;
                gout = 0; lout = 0; eout = 0; err_out = 0;
                if(mode_i)begin //Arithmetic
                    case(cmd_i)
                    4'd0: begin //ADD
                          if(inp_valid_i==2'd3) begin
                              {cout_out,out[width-1:0]} = opa_i + opb_i;
                              out = opa_i + opb_i;
                              oflow_out = 0;
			  end
			  else err_out = 1;
                          end
                    4'd1: begin //SUB
                          if(inp_valid_i==2'd3) begin
                              out = opa_i - opb_i;
                              oflow_out = (opa_i<opb_i)? 1:0;
                          end
			  else err_out = 1;
                          end
                    4'd2: begin //ADD CIN
                          if(inp_valid_i==2'd3) begin
                              {cout_out,out[width-1:0]} = opa_i + opb_i + cin_i;
                              out = opa_i + opb_i + cin_i;
                              oflow_out = 0;
			  end
			  else err_out = 1;
                          end
                    4'd3: begin //SUB CIN
                          if(inp_valid_i==2'd3) begin
                              out = opa_i - opb_i - cin_i;
                              oflow_out = (opa_i<(opb_i+cin_i))? 1:0;
                          end
			  else err_out = 1;
                          end
                    4'd4: begin //INC A
                          if(inp_valid_i[0]) begin
                              out[width-1:0] = opa_i + 1;
                          end
			  else err_out = 1;
                          end
                    4'd5: begin //DEC A
                          if(inp_valid_i[0]) begin
                              out[width-1:0] = opa_i - 1;
                          end
			  else err_out = 1;
                          end
                    4'd6: begin //INC B
                          if(inp_valid_i[1]) begin
                              out[width-1:0] = opb_i + 1;
                          end
			  else err_out = 1;
                          end
                    4'd7: begin //DEC B
                          if(inp_valid_i[1]) begin
                              out[width-1:0] = opb_i - 1;
                          end
			  else err_out = 1;
                          end
                    4'd8: begin //CMP
                          if(inp_valid_i==2'd3) begin
                               gout = (opa_i > opb_i);
                               lout = (opa_i < opb_i);
                               eout = (opa_i == opb_i);
                          end
			  else err_out = 1;
                          end
                    4'd9: begin //MUL ADD
                          if(inp_valid_i==2'd3) begin
                              out = (opa_i+1) * (opb_i+1);
                          end
			  else err_out = 1;
                          end
                    4'd10: begin //MUL SHF
                           if(inp_valid_i==2'd3) begin
                               out = (opa_i<<1) * opb_i;
                           end
			   else err_out = 1;
                           end
                    4'd11: begin//SIG ADD
                          if(inp_valid_i==2'd3) begin
                              out = $signed(opa_i) + $signed(opb_i);
                              oflow_out = (opa_i[width-1] == opb_i[width-1]) && (out[width-1] != opa_i[width-1]);
                          end
			  else err_out = 1;
                          end
                   4'd12: begin//SIG SUB
                          if(inp_valid_i==2'd3) begin
                              out = $signed(opa_i) - $signed(opb_i);
                              oflow_out = (opa_i[width-1] != opb_i[width-1]) && (out[width-1] != opa_i[width-1]);
                          end
			  else err_out = 1;
                          end
                  default: err_out = 1; //Undefined CMD
                  endcase
              end else begin //Logical
                  case(cmd_i) 
                  4'd0: begin //AND
					    if(inp_valid_i==2'd3) out[width-1:0] = opa_i & opb_i;
					  	else err_out = 1;
				  end
                  4'd1:begin //NAND
					    if(inp_valid_i==2'd3) out[width-1:0] = ~(opa_i & opb_i);
					  	else err_out = 1;
				  end  
                  4'd2: begin //OR
					    if(inp_valid_i==2'd3) out[width-1:0] = opa_i | opb_i;
					  	else err_out = 1;
				  end 
					  
                  4'd3: begin //NOR
					    if(inp_valid_i==2'd3) out[width-1:0] = ~(opa_i | opb_i);
					  	else err_out = 1;
				  end 
					  
                  4'd4:begin //XOR
					     if(inp_valid_i==2'd3) out[width-1:0] = opa_i ^ opb_i;
					  	else err_out = 1;
				  end  
					 
                  4'd5: begin //XNOR
					    if(inp_valid_i==2'd3) out[width-1:0] = ~(opa_i ^ opb_i);
					  	else err_out = 1;
				  end 
					  
                  4'd6: begin //NOT A
					    if(inp_valid_i==2'd3 || inp_valid_i==2'd1) out[width-1:0] = ~opa_i;
					  	else err_out = 1;
				  end 
					  
                  4'd7: begin //NOT B
					    if(inp_valid_i==2'd3 || inp_valid_i==2'd2) out[width-1:0] = ~opb_i;
					  	else err_out = 1;
				  end 
					  
                  4'd8: begin //SHR1_A
					    if(inp_valid_i==2'd3 || inp_valid_i==2'd1) out[width-1:0] = opa_i >> 1;
					  	else err_out = 1;
				  end 
					  
                  4'd9: begin //SHL1_A
					    if(inp_valid_i==2'd3 || inp_valid_i==2'd1) out[width-1:0] = opa_i << 1;
					  	else err_out = 1;
				  end 
					  
                  4'd10: begin //SHR1_B
					    if(inp_valid_i==2'd3 || inp_valid_i==2'd2) out[width-1:0] = opb_i >> 1;
					  	else err_out = 1;
				  end 
					  
                  4'd11: begin //SHL1_B
					    if(inp_valid_i==2'd3 || inp_valid_i==2'd2) out[width-1:0] = opb_i << 1;
					  	else err_out = 1;
				  end 
					  
                   4'd12: begin //ROL
                    if(inp_valid_i == 2'd3) begin
                        out[width-1:0] = (opa_i >> sh) | (opa_i << (width - sh));
                        if(|opb_i[width-1:4]) err_out = 1;
                    end else err_out = 1;
                end
                4'd13: begin //ROR
                    if(inp_valid_i == 2'd3) begin
                        out[width-1:0] = (opa_i << sh) | (opa_i >> (width- sh));
                        if(|opb_i[width-1:4]) err_out = 1;
                    end else err_out = 1;
                end
    
                  default: err_out = 1; //Undefined CMD
                  endcase
              end
    end
 endmodule
                  
               
           
               
            
                      
                    

                          
           
            
