`timescale 1ns / 1ps

`default_nettype none

module alu #(parameter width = 8)(
    input wire [width-1:0]opa,opb,
    input wire [1:0]inp_valid,
    input wire cin,clk,rst,ce,mode,
    input wire [3:0]cmd,
    output reg [2*width-1:0]res, 
    output reg oflow,cout,g,l,e,err
    );
    reg[2*width-1:0]out;
    reg gout,eout,lout;
    reg cout_out,oflow_out,err_out;
    reg [width-1:0]opa_i,opb_i;
    reg [3:0]cmd_i;
    reg [1:0]inp_valid_i;
    reg mode_i;
    reg cin_i;
    reg [1:0]count;
    wire [width-1:0] sh;
    assign sh = opb_i % width;
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
                   
    always@(*) begin
                out = 0;
                oflow_out = 0; cout_out = 0;
                gout = 0; lout = 0; eout = 0; err_out = 0;
                if(mode_i)begin
                    case(cmd_i)
                    4'd0: begin
                          if(inp_valid_i==2'd3) begin
                              {cout_out,out[width-1:0]} = opa_i + opb_i;
                              out = opa_i + opb_i;
                              oflow_out = 0;
			  end
			  else err_out = 1;
                          end
                    4'd1: begin
                          if(inp_valid_i==2'd3) begin
                              out = opa_i - opb_i;
                              oflow_out = (opa_i<opb_i)? 1:0;
                          end
			  else err_out = 1;
                          end
                    4'd2: begin
                          if(inp_valid_i==2'd3) begin
                              {cout_out,out[width-1:0]} = opa_i + opb_i + cin_i;
                              out = opa_i + opb_i + cin_i;
                              oflow_out = 0;
			  end
			  else err_out = 1;
                          end
                    4'd3: begin
                          if(inp_valid_i==2'd3) begin
                              out = opa_i - opb_i - cin_i;
                              oflow_out = (opa_i<(opb_i+cin_i))? 1:0;
                          end
			  else err_out = 1;
                          end
                    4'd4: begin
                          if(inp_valid_i==2'd1) begin
                              out[width-1:0] = opa_i + 1;
                          end
			  else err_out = 1;
                          end
                    4'd5: begin
                          if(inp_valid_i==2'd1) begin
                              out[width-1:0] = opa_i - 1;
                          end
			  else err_out = 1;
                          end
                    4'd6: begin
                          if(inp_valid_i==2'd2) begin
                              out[width-1:0] = opb_i + 1;
                          end
			  else err_out = 1;
                          end
                    4'd7: begin
                          if(inp_valid_i==2'd2) begin
                              out[width-1:0] = opb_i - 1;
                          end
			  else err_out = 1;
                          end
                    4'd8: begin
                          if(inp_valid_i==2'd3) begin
                               gout = (opa_i > opb_i);
                               lout = (opa_i < opb_i);
                               eout = (opa_i == opb_i);
                          end
			  else err_out = 1;
                          end
                    4'd9: begin
                          if(inp_valid_i==2'd3) begin
                              out = (opa_i+1) * (opb_i+1);
                          end
			  else err_out = 1;
                          end
                    4'd10: begin
                           if(inp_valid_i==2'd3) begin
                               out = (opa_i<<1) * opb_i;
                           end
			   else err_out = 1;
                           end
                    4'd11: begin
                          if(inp_valid_i==2'd3) begin
                              out = $signed(opa_i) + $signed(opb_i);
                              oflow_out = (opa_i[width-1] == opb_i[width-1]) && (out[width-1] != opa_i[width-1]);
                          end
			  else err_out = 1;
                          end
                   4'd12: begin
                          if(inp_valid_i==2'd3) begin
                              out = $signed(opa_i) - $signed(opb_i);
                              oflow_out = (opa_i[width-1] != opb_i[width-1]) && (out[width-1] != opa_i[width-1]);
                          end
			  else err_out = 1;
                          end
                  default: err_out = 1;
                  endcase
              end else begin
                  case(cmd_i) 
                  4'd0: if(inp_valid_i==2'd3) out[width-1:0] = opa_i & opb_i;
                  4'd1: if(inp_valid_i==2'd3) out[width-1:0] = ~(opa_i & opb_i);
                  4'd2: if(inp_valid_i==2'd3) out[width-1:0] = opa_i | opb_i;
                  4'd3: if(inp_valid_i==2'd3) out[width-1:0] = ~(opa_i | opb_i);
                  4'd4: if(inp_valid_i==2'd3) out[width-1:0] = opa_i ^ opb_i;
                  4'd5: if(inp_valid_i==2'd3) out[width-1:0] = ~(opa_i ^ opb_i);
                  4'd6: if(inp_valid_i==2'd3 || inp_valid_i==2'd1) out[width-1:0] = ~opa_i;
                  4'd7: if(inp_valid_i==2'd3 || inp_valid_i==2'd2) out[width-1:0] = ~opb_i;
                  4'd8: if(inp_valid_i==2'd3 || inp_valid_i==2'd1) out[width-1:0] = opa_i >> 1;
                  4'd9: if(inp_valid_i==2'd3 || inp_valid_i==2'd1) out[width-1:0] = opa_i << 1;
                  4'd10: if(inp_valid_i==2'd3 || inp_valid_i==2'd2) out[width-1:0] = opb_i >> 1;
                  4'd11: if(inp_valid_i==2'd3 || inp_valid_i==2'd2) out[width-1:0] = opb_i << 1;
                  4'd12: begin 
			  if(inp_valid_i==2'd3) begin
                              if (|opb_i[7:4]) begin
                                  err_out = 1;
                              end else begin
                                  if (sh == 0)
                                      out[width-1:0] = opa_i;
                                  else
                                      out[width-1:0] = (opa_i >> sh) | (opa_i << (width - sh));
                                  end 
                         end
			 
			  else err_out = 1;
			end
                   4'd13: begin 
			  if(inp_valid_i==2'd3)begin
                              if (|opb_i[7:4]) begin
                                 err_out = 1;
                              end else begin
                                 if (sh == 0)
                                     out[width-1:0] = opa_i;
                                 else
                                     out[width-1:0] = (opa_i << sh) | (opa_i >> (width - sh));
                                 end
                            
			  end 
			  else err_out = 1; 
			  end      
                  default: err_out = 1;
                  endcase
              end
    end
 endmodule
                  
               
           
               
            
                      
                    

                          
           
            
