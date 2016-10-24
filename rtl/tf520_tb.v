`timescale 1ns / 1ps

/*
Copyright (c) 2016, Stephen J. Leary
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:
1. Redistributions of source code must retain the above copyright
   notice, this list of conditions and the following disclaimer.
2. Redistributions in binary form must reproduce the above copyright
   notice, this list of conditions and the following disclaimer in the
   documentation and/or other materials provided with the distribution.
3. All advertising materials mentioning features or use of this software
   must display the following acknowledgement:
   This product includes software developed by the <organization>.
4. Neither the name of the <organization> nor the
   names of its contributors may be used to endorse or promote products
   derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY <COPYRIGHT HOLDER> ''AS IS'' AND ANY
EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL <COPYRIGHT HOLDER> BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

*/

module tf520_tb;

// Inputs
reg CLK20M;
reg CLK7M;
reg BG20;
reg AS20;
reg DS20;
   reg RW20;
   
reg [2:0] FC;
reg [1:0] SIZ;
reg 	  A0;
  
reg [23:0] A;
reg BGACK;
reg VPA;
reg DTACK;
reg HIGH;

// Outputs
wire AVEC;
wire DSACK1;
wire BG;
wire LDS;
wire UDS;
wire VMA;
wire E;
wire AS;
wire RW00;

wire CLKCPU = CLK20M;
   

// Instantiate the Unit Under Test (UUT)
tf520 uut (
            .CLK20M(CLK20M),
            .CLK7M(CLK7M),
            .BG20(BG20),
            .AS20(AS20),
	    .RW00(RW00),
	    .RW20(RW20),
            .DS20_1(DS20),
	    .DS20_2(DS20),
            .AVEC(AVEC),
            .FC(FC),
            .SIZ(SIZ),
            .DSACK1(DSACK1),
            .A0(A[0]),
	    .A({A[19:16]}),
            .BGACK(BGACK),
            .VPA(VPA),
            .DTACK(DTACK),
            .BG(BG),
            .LDS(LDS),
            .UDS(UDS),
            .VMA(VMA),
            .E(E),
            .AS(AS),
            .HIGH(HIGH)
       );

task assert;
input value;
input expected;
begin 
    if (value != expected) begin 
        $display ("Asserion failed: Expected %b but got %b", expected, value);
        $finish;
    end 
end
endtask

task NegEdge;
input signal;   
begin       
    wait(CLK20M == 1);
    wait(CLK20M == 0);#1;
end
endtask
   
task Read;
input [32:0] address;
begin 
   $display("moo");
   
    NegEdge(CLK20M);

    AS20 = 1;
    DS20 = 1;
    RW20 = 1;
   
    NegEdge(CLK20M);
      
    FC = 'b010;
    A = address;

    AS20 = 0;
    DS20 = 0;

    wait(DSACK1 == 0);
   
   #1;
   NegEdge(CLK20M);

  
    AS20 = 1;
    DS20 = 1;
    RW20 = 1; 
   
   NegEdge(CLKCPU);
   
 
end
endtask

task ReadByte;
input [32:0] address;
begin
   SIZ = 2'b01;
   Read(address);
end
endtask // ReadByte
   
     
task ReadWord;
input [32:0] address;
begin 
   SIZ = 2'b10;
   Read(address);
end
endtask

task ReadLong;
input [32:0] address;
begin 
   SIZ = 2'b11;
   Read(address);
end
endtask
   
initial begin

    $dumpfile("tf520_tb.vcd");
    $dumpvars(0, uut);

    // Initialize Inputs
    CLK20M = 0;
    CLK7M = 0;
    BG20 = 1;
    RW20 = 1;
    AS20 = 1;
    DS20 = 1;
    FC = 'h7;
    SIZ = 'h3;
    A = 0;
    BGACK = 1;
    VPA = 0;
    DTACK = 1;
    HIGH = 1;

    // Add stimulus here
    #1000;

    ReadByte(0); 
    ReadWord(0);    
    ReadLong(0);    
    ReadByte(1);    
    
    ReadByte(2);    
    ReadByte(3);    
    ReadByte(4);    
    ReadByte(5);    
    ReadByte(6);    
    ReadByte(7);
    wait(E == 1);
   
    ReadByte(24'hBFE101);
    ReadByte(24'hBFE101);
    ReadByte(24'hBFE101);    
    $finish;

end

always 	begin
    #25; CLK20M = ~CLK20M;
end

always 	begin
    #71; CLK7M = ~CLK7M;
end

reg [7:0] C;   
   
always @(posedge CLK7M) begin

   DTACK <= 1;
   VPA <=   1;

   if (AS == 1'b0) begin
      C <= C + 'd1;
   end else begin
      C <= 'd0;
   end

   if ((AS == 1'b0) & (C > 'd1)) begin   
      
      if ((A >= 24'h00_0000) & (A < 24'h01_0000)) begin

	 DTACK <= 0;
	 
      end else if ((A >= 24'hBF_E000) & (A < 24'hC0_0000)) begin

	 VPA <= 0;
	 
      end
      
   end 
   
end

   
endmodule

