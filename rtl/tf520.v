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

module sjl520(

           input 	 CLKCPU,
           input 	 CLK7M,

           input 	 BG20,
           input 	 AS20,
           input 	 DS20_1,
           input 	 DS20_2,
           input 	 RW20,
           output 	 RW00,

           
           input [2:0] 	 FC,
           input [1:0] 	 SIZ,

           input         A0,   
           input [19:16] A,

           input 	 BGACK,
           input 	 VPA,
           input 	 DTACK,

           output 	 BG,
           output 	 LDS,
           output 	 UDS,
           output 	 VMA,
           output reg E,
           output 	 AS,
           output    BERR,
        
           output 	 DSACK1,
           output 	 AVEC, 
           
           input HIGH

       );
       
wire DS20DLY;
wire AS20DLY;

reg SYSDSACK1 = 1'b1;
reg RW20DLY = 1'b1;
reg CLK7MB2 = 1'b1;
reg BGACKD1 = 1'b1;
reg BGACKD2 = 1'b1;

reg [3:0] Q = 'hF;

reg VMA_SYNC = 1'b1;

initial begin 

	E = 'b0;
	
end

reg  DTQUAL = 1'b0;

wire DS20 = DS20_1 & DS20_2;

wire DTRIG;
wire DTRIG_SYNC;

wire CPUSPACE = &FC;

wire CPCS = CPUSPACE & ({A[19:16]} === {4'b0010});
wire BKPT = CPUSPACE & ({A[19:16]} === {4'b0000});
wire IACK = CPUSPACE & ({A[19:16]} === {4'b1111});
wire DTACKPRELIM = CLK7M | CLK7MB2;

FDCP #(.INIT(1'b1)) 
	AS20DLY_FF (
		.Q(AS20DLY), // Data output
		.C(CLK7M), // Clock input
		.CLR(1'b0), // Asynchronous clear input
		.D(AS20), // Data input
		.PRE(AS20) // Asynchronous set input
);

FDCP #(.INIT(1'b1)) 
	DS20DLY_FF (
		.Q(DS20DLY), // Data output
		.C(CLK7M), // Clock input
		.CLR(1'b0), // Asynchronous clear input
		.D(DS20), // Data input
		.PRE(DS20) // Asynchronous set input
);

FDCP #(.INIT(1'b1)) 
	DTTRIG1_FF (
		.Q(DSACK1INT), // Data output
		.C(~DTRIG), // Clock input
		.CLR(1'b0), // Asynchronous clear input
		.D(AS), // Data input
		.PRE(AS) // Asynchronous set input
);

always @(posedge CLKCPU) begin 

	SYSDSACK1 <= DSACK1INT | CPUSPACE;

end

always @(posedge CLK7M) begin

	 DTQUAL 	<= AS20DLY;
	 RW20DLY <= RW20 & HIGH;
     
    BGACKD1 <= BGACK;
    BGACKD2 <= BGACKD1;
    
    // 7Mhz Clock divided by 2
    CLK7MB2 <= ~CLK7MB2;
      
   if (Q == 'd9) begin

      VMA_SYNC <= 1'b1;
      Q <= 'd0;

   end else begin

      Q <= Q + 'd1;

      if (Q == 'd4) begin
	 E <= 'b1;       
      end

      if (Q == 'd8) begin
	 E <= 'b0;
      end

      if (Q == 'd2) begin

         VMA_SYNC <= VPA | CPUSPACE;
		 
      end 
      
   end
 
end
   
//wire HIGHZ = BG20 | //(BG20 & (AS20DLY | AS20)) | CPUSPACE;
wire HIGHZ = (BG20 & (AS20DLY | AS20)) | CPUSPACE;
wire AS_INT = AS20DLY | AS20;
wire UDS_INT = DS20 | DS20DLY | A0;
wire LDS_INT = DS20 | DS20DLY | ({A0, SIZ[1:0]} == 3'b001);  
wire VMA_INT = VMA_SYNC;  
 
assign RW00 = RW20DLY;      
assign AS = AS_INT;   
assign UDS =  UDS_INT;
assign LDS =   LDS_INT;
assign VMA =  VMA_INT;

assign DTRIG_SYNC = ~Q[3] | VMA_SYNC;
assign DTRIG = DTACK & DTRIG_SYNC;
assign DSACK1 = (AS20DLY | AS20 | SYSDSACK1);

assign BG = BG20 | AS20DLY | AS20;
assign AVEC = IACK & ~VPA;
assign BERR = ~CPCS;
      
endmodule
