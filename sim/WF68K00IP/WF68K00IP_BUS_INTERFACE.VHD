----------------------------------------------------------------------
----                                                              ----
---- MC68000 compatible IP Core					                  ----
----                                                              ----
---- This file is part of the SUSKA ATARI clone project.          ----
---- http://www.experiment-s.de                                   ----
----                                                              ----
---- Description:                                                 ----
---- This model provides an opcode and bus timing compatible ip   ----
---- core compared to Motorola's MC68000 microprocessor.          ----
----                                                              ----
---- This file contains the 68Ks bus interface unit.              ----
----                                                              ----
---- This file contains the 68Ks bus interface unit.              ----
----                                                              ----
---- Description:                                                 ----
---- This module provides bus control during read cycles, write   ----
---- cycles and read modify write cycles. It also provides 2 and  ----
---- 3 wire bus arbitration control, halt and rerun operation,    ----
---- bus and address error generation, wait state insertion and   ----
---- synchronous bus operation (68000).                           ----
---- In the following there are some remarks on the working       ----
---- principle of this core.                                      ----
----                                                              ----
---- Bus cycle operation:                                         ----
---- A bus cycle is released by either asserting RD_BUS for       ----
---- entering a read cycleor WR_BUS for entering a write cycle.   ----
---- There must not be asserted both signals at the same time.    ----
---- Once the bus cycle is started, the RD_BUS or the WR_BUS      ----
---- must be asserted until the cycle finishes. This is indicated ----
---- by the signal BUS_CYC_RDY, which is valid for one clock      ----
---- cycle after the bus operation finished.                      ----
----                                                              ----
---- Synchronous timing topics:                                   ----
---- During the synchronous timing, the DTACKn must not be        ----
---- asserted and due to asynchronous timing, the VPAn must not   ----
---- be asserted, otherwise unpredictable behavior will result.   ----
----                                                              ----
---- Bus arbitration topics:                                      ----
---- No bus arbitration during read modify write cycle.           ----
---- In the case of a 2 wire bus arbitration, no re-entry for     ----
----   another device is possible.                                ----
----                                                              ----
---- Bus error topics:                                            ----
---- During a bus error, the bus cycle finishes also asserting    ----
---- the BUS_CYC_RDY signal during S7.                            ----
----                                                              ----
---- Bus re-run topics:                                           ----
---- During a re-run condition, the bus cycle finishes also       ----
---- asserting the BUS_CYC_RDY signal during S7.                  ----
----                                                              ----
---- RESET topics:                                                ----
---- When a reset is released by the CPU due to the RESET_EN      ----
---- control, the RESET_RDY indicates the finishing of the reset  ----
---- cycle 124 clock cycles later. The RESET_EN may be asserted   ----
---- until RESET_RDY indicates 'ready'. The RESET_RDY is a strobe ----
---- and therefore valid for one clock cycle.                     ----
----                                                              ----
---- Author(s):                                                   ----
---- - Wolfgang Foerster, wf@experiment-s.de; wf@inventronik.de   ----
----                                                              ----
----------------------------------------------------------------------
----                                                              ----
---- Copyright (C) 2006 - 2010 Wolfgang Foerster                  ----
----                                                              ----
---- This source file is free software; you can redistribute it   ----
---- and/or modify it under the terms of the GNU General Public   ----
---- License as published by the Free Software Foundation; either ----
---- version 2 of the License, or (at your option) any later      ----
---- version.                                                     ----
----                                                              ----
---- This program is distributed in the hope that it will be      ----
---- useful, but WITHOUT ANY WARRANTY; without even the implied   ----
---- warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR      ----
---- PURPOSE.  See the GNU General Public License for more        ----
---- details.                                                     ----
----                                                              ----
---- You should have received a copy of the GNU General Public    ----
---- License along with this program; if not, write to the Free   ----
---- Software Foundation, Inc., 51 Franklin Street, Fifth Floor,  ----
---- Boston, MA 02110-1301, USA.                                  ----
----                                                              ----
----------------------------------------------------------------------
-- 
-- Revision History
-- 
-- Revision 2K6B  2006/12/24 WF
--   Initial Release.
-- Revision 2K7A  2007/05/31 WF
--   Updated all modules.
-- Revision 2K7B  2007/12/24 WF
--   See the 68K00 top level file.
-- Revision 2K8A  2008/07/14 WF
--   See the 68K00 top level file.
-- Revision 2K8B  2008/12/24 WF
--   Fixed a minor bug in the RESET operation.
--   Changes regarding the read modify write logic of the TAS operation.
--   Several changes to provide correct bus arbitration.
-- Revision 2K9A  2009/06/20 WF
--   Changed the E_TIMER process concerning synchronous reset.
--   ADR_EN logic is now synchronous.
--   Various changes concerning HALTn, RESET_CPUn, RD_BUS and WR_BUS.
-- Revision 2K9B  2009/12/24 WF
--   Fixed a timing bug in the bus arbitration state register.
--   Fixed UDSn and LDSn logic not working correct with waitstates in some cases.
--

library work;
use work.wf68k00ip_pkg.all;

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity WF68K00IP_BUS_INTERFACE is
	port (
		-- System control:
		CLK				: in bit; -- System clock.
		RESETn			: in bit; -- Core reset.
		RESET_INn		: in bit; -- System's reset input.
		RESET_OUT_EN	: out bit; -- System's reset output open drain enable.
		RESET_CPUn		: out bit; -- Internal reset used for CPU initialization.
		RESET_EN		: in bit; -- Force reset control.
		RESET_RDY		: out bit; -- Indicates the end of a forced reset cycle (strobe).

		-- Data lines:
		DATA_IN			: in std_logic_vector(15 downto 0); -- Data bus input lines.

		-- Receive buffers:
		SEL_A_HI		: in bit; -- Select data A buffer high byte.
		SEL_A_MIDHI		: in bit; -- Select data A buffer midhigh byte.
		SEL_A_MIDLO		: in bit; -- Select data A buffer midlow byte.
		SEL_A_LO		: in bit; -- Select data A buffer low byte.
		SEL_BUFF_A_LO	: in bit; -- Select data A buffer low word.
		SEL_BUFF_A_HI	: in bit; -- Select data A buffer high word.
		SEL_BUFF_B_LO	: in bit; -- Select data B buffer low word.
		SEL_BUFF_B_HI	: in bit; -- Select data B buffer high word.
		SYS_INIT		: in bit; -- Indicates the system initialisation (PC, SSP).
		OP_SIZE			: in OP_SIZETYPE; -- Used for the input multiplexer (buffers).
		BUFFER_A		: out std_logic_vector(31 downto 0); -- Receive buffer A.
		BUFFER_B		: out std_logic_vector(31 downto 0); -- Receive buffer B.
		DATA_CORE_OUT	: out std_logic_vector(15 downto 0); -- Data buffer.

		-- Control signals:
		RD_BUS			: in bit; -- Read bus request.
		WR_BUS			: in bit; -- Write request.
        TAS_LOCK        : in bit; -- Read modify write locking.
		A0				: in std_logic; -- Least significant bit of the address counter.
		BYTEn_WORD		: in bit; -- Byte or Word format for read or write bus cycles.
		EXEC_ABORT		: in bit; -- Skip the current bus cycle, if '1'.
		BUS_CYC_RDY		: out bit; -- Indicates 'Ready' (strobe).
		DATA_VALID		: out bit;

		-- Bus control signals:
		DTACKn			: in bit;
		BERRn			: in bit;
		AVECn			: in bit;
		HALTn			: in std_logic;

		ADR_EN			: out bit;
		WR_HI			: in bit;
		HI_WORD_EN		: out bit;
		HI_BYTE_EN		: out bit;
		LO_BYTE_EN		: out bit;
		FC_EN			: out bit;
		ASn				: out bit;
		AS_EN			: out bit;
		UDSn			: out bit;
		UDS_EN			: out bit;
		LDSn			: out bit;
		LDS_EN			: out bit;
		RWn				: out bit;
		RW_EN			: out bit;

		-- Synchronous Bus controls:
		VPAn			: in bit;
		VMAn			: out bit;
		VMA_EN			: out bit;
		E				: out bit;

		-- Bus arbitration:
		BRn				: in bit;
		BGACKn			: in bit;
		BGn				: out bit
		);
end entity WF68K00IP_BUS_INTERFACE;
	
architecture BEHAVIOR of WF68K00IP_BUS_INTERFACE is
type ARB_STATES is(IDLE, GRANT, WAIT_RELEASE_3WIRE);
type TIME_SLICES is (S0, S1, S2, S3, S4, S5, S6, S7);
signal RESET_OUT_EN_I	: bit;
signal RESET_CPU_In		: bit;
signal ARB_STATE		: ARB_STATES;
signal NEXT_ARB_STATE	: ARB_STATES;
signal T_SLICE			: TIME_SLICES;
signal SLICE_CNT		: std_logic_vector(1 downto 0);
signal BERR				: bit;
signal FC_ENAB			: bit;
signal VMA_In			: bit;
signal UDS_RD_EN_N		: bit;
signal UDS_RD_EN_P		: bit;
signal UDS_RD_EN		: bit;
signal LDS_RD_EN_N		: bit;
signal LDS_RD_EN_P		: bit;
signal LDS_RD_EN		: bit;
signal UDS_WR_EN_N		: bit;
signal UDS_WR_EN_P		: bit;
signal UDS_WR_EN		: bit;
signal LDS_WR_EN_N		: bit;
signal LDS_WR_EN_P		: bit;
signal LDS_WR_EN		: bit;
signal AS_ENAB_N		: bit;
signal AS_ENAB_P		: bit;
signal AS_ENAB			: bit;
signal ADR_EN_N			: bit;
signal ADR_EN_P			: bit;
signal DATA_EN_N		: bit;
signal DATA_EN_P		: bit;
signal DATA_EN			: bit;
signal WR_ENAB_P		: bit;
signal WR_ENAB			: bit;
signal WAITSTATES		: bit;
signal SYNCn			: bit;
begin
	-- Three state controls:
    UDS_EN <= '1' when ARB_STATE = IDLE else '0'; -- Hi-Z during arbitration.
    LDS_EN <= '1' when ARB_STATE = IDLE else '0'; -- Hi-Z during arbitration.
    AS_EN <= '1' when ARB_STATE = IDLE else '0'; -- Hi-Z during arbitration.
    RW_EN <= '1' when ARB_STATE = IDLE else '0'; -- Hi-Z during arbitration.
		
    FC_EN <= '1' when TAS_LOCK = '1' else FC_ENAB;

	-- Read and write timing:
	UDS_WR_EN <= UDS_WR_EN_N or UDS_WR_EN_P; 			-- '1' when           S4 | S5 | S6.
	LDS_WR_EN <= LDS_WR_EN_N or LDS_WR_EN_P; 			-- '1' when           S4 | S5 | S6.
	UDS_RD_EN <= UDS_RD_EN_N or UDS_RD_EN_P; 			-- '1' when S2 | S3 | S4 | S5 | S6.
	LDS_RD_EN <= LDS_RD_EN_N or LDS_RD_EN_P; 			-- '1' when S2 | S3 | S4 | S5 | S6.
	AS_ENAB <= AS_ENAB_N or AS_ENAB_P; 					-- '1' when S2 | S3 | S4 | S5 | S6.
	WR_ENAB <= WR_ENAB_P; 								-- '1' when S2 | S3 | S4 | S5 | S6 | S7.
	DATA_EN <= DATA_EN_N or DATA_EN_P; 					-- '1' when      S3 | S4 | S5 | S6 | S7.
	ADR_EN <= '0' when ARB_STATE /= IDLE else
			  '1' when TAS_LOCK = '1' else
			  (ADR_EN_N or ADR_EN_P);					-- '1' when S1 | S2 | S3 | S4 | S5 | S6 | S7.

	-- Timing valid for all modes:
	FC_ENAB <= 	'0' when ARB_STATE /= IDLE else -- During arbitration.
                '0' when T_SLICE = S0 and HALTn = '0' else -- During halt.
				'0' when RD_BUS = '0' and WR_BUS = '0' and T_SLICE = S0 else '1'; -- Normal operation.
	
    VMA_EN <= '0' when ARB_STATE /= IDLE else '1';
	VMAn <= VMA_In;

	BGn <= 	'0' when ARB_STATE = GRANT else '1';

	DATA_VALID <= '1' when T_SLICE = S6 else '0'; -- Sample the data during S6.

	BUS_BUFFER: process(RESETn, CLK)
	-- This process samples the data from the data bus during the bus phase S6.
	-- During S6 the received data from the bus is valid depending on the selection
	-- of UDSn and LDSn. This means that the respective byte (high or low) is valid,
	-- if wether UDSn or LDSn is asserted. If both are asserted, both bytes are valid.
	-- For S6 is followed by a falling clock edge, the process reacts on it.
	begin
		if RESETn = '0' then
			BUFFER_A <= (others => '0');
			BUFFER_B <= (others => '0');
		elsif CLK = '0' and CLK' event then
			if T_SLICE = S6 and SEL_A_HI = '1' and A0 = '0' and RD_BUS = '1' then -- Read Byte from even address.
				BUFFER_A(31 downto 24) <= DATA_IN(15 downto 8);
			elsif T_SLICE = S6 and SEL_A_HI = '1' and RD_BUS = '1' then -- Read Byte from odd address.
				BUFFER_A(31 downto 24) <= DATA_IN(7 downto 0);
			elsif T_SLICE = S6 and SEL_A_MIDHI = '1' and A0 = '0' and RD_BUS = '1' then
				BUFFER_A(23 downto 16) <= DATA_IN(15 downto 8);
			elsif T_SLICE = S6 and SEL_A_MIDHI = '1' and RD_BUS = '1' then
				BUFFER_A(23 downto 16) <= DATA_IN(7 downto 0);
			elsif T_SLICE = S6 and SEL_A_MIDLO = '1' and A0 = '0' and RD_BUS = '1' then
				BUFFER_A(15 downto 8) <= DATA_IN(15 downto 8);
			elsif T_SLICE = S6 and SEL_A_MIDLO = '1' and RD_BUS = '1' then
				BUFFER_A(15 downto 8) <= DATA_IN(7 downto 0);
			elsif T_SLICE = S6 and SEL_A_LO = '1' and A0 = '0' and RD_BUS = '1' then
				BUFFER_A(7 downto 0) <= DATA_IN(15 downto 8);
			elsif T_SLICE = S6 and SEL_A_LO = '1' and RD_BUS = '1' then
				BUFFER_A(7 downto 0) <= DATA_IN(7 downto 0);
			--
			elsif T_SLICE = S6 and SYS_INIT = '1' and SEL_BUFF_A_HI = '1' then -- During system startup.
				BUFFER_A(31 downto 16) <= DATA_IN;
			elsif T_SLICE = S6 and SYS_INIT = '1' and SEL_BUFF_A_LO = '1' then -- During system startup.
				BUFFER_A(15 downto 0) <= DATA_IN;
			elsif T_SLICE = S6 and SEL_BUFF_A_LO = '1' and OP_SIZE = BYTE and A0 = '0' then -- Byte from an even address.
				BUFFER_A <= x"000000" & DATA_IN(15 downto 8);
			elsif T_SLICE = S6 and SEL_BUFF_A_LO = '1' and OP_SIZE = BYTE then -- Byte from an odd address.
				BUFFER_A <= x"000000" & DATA_IN(7 downto 0);
			elsif T_SLICE = S6 and SEL_BUFF_A_LO = '1' then -- Word or long access.
				BUFFER_A(15 downto 0) <= DATA_IN;
			elsif T_SLICE = S6 and SEL_BUFF_A_HI = '1' then -- Long access.
				BUFFER_A(31 downto 16) <= DATA_IN;
			--
			elsif T_SLICE = S6 and SEL_BUFF_B_LO = '1' and OP_SIZE = BYTE and A0 = '0' then -- Byte from an even address.
				BUFFER_B <= x"000000" & DATA_IN(15 downto 8);
			elsif T_SLICE = S6 and SEL_BUFF_B_LO = '1' and OP_SIZE = BYTE then -- Byte from an odd address.
				BUFFER_B <= x"000000" & DATA_IN(7 downto 0);
			elsif T_SLICE = S6 and SEL_BUFF_B_LO = '1' then -- Word or long access.
				BUFFER_B(15 downto 0) <= DATA_IN;
			elsif T_SLICE = S6 and SEL_BUFF_B_HI = '1' then -- Long access.
				BUFFER_B(31 downto 16) <= DATA_IN;
			end if;
			if T_SLICE = S6 then
				DATA_CORE_OUT <= DATA_IN; -- Transparent buffer.
			end if;
		end if;
	end process BUS_BUFFER;

	-- For the condition of the bus error see the 68K family user manual.
	-- Bus errors during S0, S1 and S2 cannot occur.
	-- There are no retry cycles in the read modify write mode (during TAS).
	BERR <= '1' when BERRn = '0' and HALTn = '1' and DTACKn = '1' and T_SLICE /= S0 and T_SLICE /= S1 and T_SLICE /= S2 else
			'1' when BERRn = '0' and HALTn = '0' and TAS_LOCK = '1' and T_SLICE /= S0 and T_SLICE /= S1 and T_SLICE /= S2 else '0';

    BUS_CYC_RDY <= '1' when T_SLICE = S6 or T_SLICE = S7 else '0';

	ASn  <= '0' when AS_ENAB = '1' else '1';

	UDSn <= '0' when RD_BUS = '1' and UDS_RD_EN = '1' and A0 = '0' and BYTEn_WORD = '0' else
			'0' when WR_BUS = '1' and UDS_WR_EN = '1' and A0 = '0' and BYTEn_WORD = '0' else
			'0' when RD_BUS = '1' and UDS_RD_EN = '1' and BYTEn_WORD = '1' else
			'0' when WR_BUS = '1' and UDS_WR_EN = '1' and BYTEn_WORD = '1' else '1';

	LDSn <= '0' when RD_BUS = '1' and LDS_RD_EN = '1' and A0 = '1' and BYTEn_WORD = '0' else
			'0' when WR_BUS = '1' and LDS_WR_EN = '1' and A0 = '1' and BYTEn_WORD = '0' else
			'0' when RD_BUS = '1' and LDS_RD_EN = '1' and BYTEn_WORD = '1' else
			'0' when WR_BUS = '1' and LDS_WR_EN = '1' and BYTEn_WORD = '1' else '1';

	RWn  <= '0' when WR_BUS = '1' and WR_ENAB = '1' else '1';

	-- To meet the behavior of the bus during bus error, the HI_WORD_EN must have higher priority than
	-- HI_BYTE_EN or LOW_BYTE_EN (using these signals for the bus drivers).
	-- Nevertheless during bus error, there will be written invalid data via the HI_WORD_EN signal to the bus.
	HI_WORD_EN <= '1' when WR_BUS = '1' and DATA_EN = '1' and WR_HI = '1' else '0';
	HI_BYTE_EN <= '1' when WR_BUS = '1' and DATA_EN = '1' and A0 = '0' and BYTEn_WORD = '0' else
				  '1' when WR_BUS = '1' and DATA_EN = '1' and BYTEn_WORD = '1' else '0';
	LO_BYTE_EN <= '1' when WR_BUS = '1' and DATA_EN = '1' and A0 = '1' and BYTEn_WORD = '0' else
				  '1' when WR_BUS = '1' and DATA_EN = '1' and BYTEn_WORD = '1' else '0';

    P_WAITSTATES: process
	-- During read, write or read modify write processes, the read access is delayed by wait 
	-- states (slow read, slow write) if there is no DTACKn asserted until the end of S4.
	-- This is done by stopping the slice counter. After the halt, in principle a S5 would be
	-- possible. This is not correct for not asserted DTACKn. This process provides a locking
	-- of this forbidden case and the stop control for the slice counter. For more information
	-- see the 68000 processor data sheet (bus cycles).
	-- In case of a bus error, the bus cycle is finished by realeasing the WAITSTATES via BERR.
	-- In case of a CPU reset, the bus cycle is finished by realeasing the WAITSTATES via RESET_CPUn.
	-- In case of a HALT, the bus cycle is finished by realeasing the WAITSTATES via HALTn.
	-- The SYNCn controls the synchronous bus timing. The AVECn ends the bus cycle in case of 
	-- an autovector interrupt acknowledge cycle.
	-- This synchronous process provides clock cycle accurate switching of the T_SLICE information.
	begin
        wait until CLK = '0' and CLK' event;
        if T_SLICE = S4 then
            WAITSTATES <= DTACKn and SYNCn and AVECn and not BERR and To_Bit(HALTn) and RESET_CPU_In;
		else
			WAITSTATES <= '0';
		end if;
	end process P_WAITSTATES;

	SLICES: process(RESETn, CLK)
	-- This process provides the central timing for the read, write and read modify write cycle 
    -- as also for the bus arbitration procedure.
	begin
		if RESETn = '0' then
            SLICE_CNT <= "00";
		elsif CLK = '1' and CLK' event then
			-- Cycle reset:

			if ARB_STATE /= IDLE then
                SLICE_CNT <= "00";
			-- Initialization:
			elsif RD_BUS = '0' and WR_BUS = '0' then
                SLICE_CNT <= "00"; -- Init.
            elsif SLICE_CNT = "00" and HALTn = '0' then
                SLICE_CNT <= "00"; -- Wait in retry or halt operation until HALTn is deasserted.
			-- Counting:
			elsif WAITSTATES = '0' then -- Insert waitstates when required.
				SLICE_CNT <= SLICE_CNT + '1'; -- Cycle active.
			end if;
		end if;
	end process SLICES;

    T_SLICE <=  S0 when RD_BUS = '0' and WR_BUS = '0' else -- IDLE Mode.
                S0 when SLICE_CNT = "00" and CLK = '1' else
                S0 when SLICE_CNT = "00" and CLK = '0' and HALTn = '0' else -- Stay in IDLE during retry with HALTn asserted.
                S1 when SLICE_CNT = "00" and CLK = '0' else
                S2 when SLICE_CNT = "01" and CLK = '1' else
                S3 when SLICE_CNT = "01" and CLK = '0' else
                S4 when SLICE_CNT = "10" and CLK = '1' else
                S4 when WAITSTATES = '1' and SLICE_CNT = "10" and CLK = '0' else
                S5 when WAITSTATES = '0' and SLICE_CNT = "10" and CLK = '0' else
                S6 when SLICE_CNT = "11" and CLK = '1' else S7;

	-- The modelling with the two processes working on the positive and negative clock edge
	-- is a bit complicated. But it results in rather 'clean' (glitch free) bus control
	-- signals. Every signal is modelled with it's own timing to give the core a high degree
	-- of freedom.
    N: process
	begin
		wait until CLK = '0' and CLK' event;
		case T_SLICE is
			when S4 => UDS_WR_EN_N <= '1';
			when others => UDS_WR_EN_N <= '0';
		end case;	
		case T_SLICE is
			when S4 => LDS_WR_EN_N <= '1';
			when others => LDS_WR_EN_N <= '0';
		end case;	
		case T_SLICE is
			when S2 | S4 => UDS_RD_EN_N <= '1';
			when others => UDS_RD_EN_N <= '0';
		end case;	
		case T_SLICE is
			when S2 | S4 => LDS_RD_EN_N <= '1';
			when others => LDS_RD_EN_N <= '0';
		end case;	

		case T_SLICE is
			when S2 | S4 => AS_ENAB_N <= '1';
			when others => AS_ENAB_N <= '0';
		end case;	
		case T_SLICE is
			when S2 => DATA_EN_N <= '1';
			when others => DATA_EN_N <= '0';
		end case;	
		--
		if RESETn = '0' then
			ADR_EN_N <= '0';
		elsif SLICE_CNT = "00" and (RD_BUS = '1' or WR_BUS = '1') and HALTn = '1' and ARB_STATE = IDLE then
			ADR_EN_N <= '1';
		elsif SLICE_CNT = "11" then
			ADR_EN_N <= '0';
		end if;
	end process N;

	P: process
	begin
		wait until CLK = '1' and CLK' event;
		case T_SLICE is
            when S1 | S3 => AS_ENAB_P <= '1';
			when others => AS_ENAB_P <= '0';
		end case;	
		case T_SLICE is
            when S3 | S4 => UDS_WR_EN_P <= '1'; -- S4 due to wait states.
			when others => UDS_WR_EN_P <= '0';
		end case;	
		case T_SLICE is
            when S3 | S4 => LDS_WR_EN_P <= '1'; -- S4 due to wait states.
			when others => LDS_WR_EN_P <= '0';
		end case;	
		case T_SLICE is
            when S1 | S3 => UDS_RD_EN_P <= '1';
			when others => UDS_RD_EN_P <= '0';
		end case;	
		case T_SLICE is
            when S1 | S3 => LDS_RD_EN_P <= '1';
			when others => LDS_RD_EN_P <= '0';
		end case;	
		case T_SLICE is
			when S1 | S3 | S4 | S5 => WR_ENAB_P <= '1'; -- S4 due to wait states.
			when others => WR_ENAB_P <= '0';
		end case;	
		case T_SLICE is
			when S3 | S4 | S5 => DATA_EN_P <= '1'; -- S4 due to wait states.
			when others => DATA_EN_P <= '0';
		end case;	
		--
		if RESETn = '0' then
			ADR_EN_P <= '0';
		elsif SLICE_CNT = "01" then
			ADR_EN_P <= '1';
		elsif SLICE_CNT = "11" then
			ADR_EN_P <= '0';
		end if;
	end process P;

	-- Synchronous bus timing:
	E_TIMER: process
	-- The E clock is a free running clock with a period of 10 times
	-- the CLK period. The pulse ratio is 4 CLK high and 6 CLK low.
	-- Use a synchronous reset due to FPGA constraints.
	variable TMP : std_logic_vector(3 downto 0);
	begin
		wait until CLK = '1' and CLK' event;
		if RESETn = '0' then
			TMP := x"0";
			VMA_In <= '1';
			SYNCn <= '1';
			E <= '1';
		elsif TMP < x"9" then
			TMP := TMP + '1';
		else
			TMP := x"0";
		end if;
		
		-- E logic:
		if TMP = x"0" then
			E <= '1';
		elsif TMP = x"4" then
			E <= '0';
		end if;

		-- VMA logic:
		if VPAn = '0' and TMP >= x"4" then -- Switch, when E is low.
			VMA_In <= '0';
		elsif T_SLICE = S7 then
			VMA_In <= '1';
		end if;
		
		-- SYNCn logic (wait states controlling):
		if VPAn = '0' and VMA_In = '0' and TMP = x"0" then -- Switch, when E is just high.
			SYNCn <= '0';
		elsif VPAn = '1' or VMA_In = '1' then
			SYNCn <= '1';
		end if;
	end process E_TIMER;

	-- Bus arbitration:
	ARB_REG: process(RESETn, CLK)
    -- This is the arbiters state register.
    -- It works on the negative clock edge to
    -- interfere correctly with the slice timer.
	begin
		if RESETn = '0' then
			ARB_STATE <= IDLE;
        elsif CLK = '0' and CLK' event then
			ARB_STATE <= NEXT_ARB_STATE;
		end if;
	end process ARB_REG;
	
    ARB_DEC: process(ARB_STATE, TAS_LOCK, BRn, RD_BUS, WR_BUS, SLICE_CNT, BGACKn)
    -- This is the bus arbitration state machine's decoder. It can handle two wire arbitration
    -- or three wire arbitration. The two wire arbitration is done in the GRANT state.
	begin
		case ARB_STATE is
			when IDLE =>
				if TAS_LOCK = '1' then
					NEXT_ARB_STATE <= IDLE; -- No bus arbitration during read modify write cycle.
                elsif BRn = '0' and SLICE_CNT = "00" then
					NEXT_ARB_STATE <= GRANT; -- Bus grant delayed in case of S1, otherwise immediately.
				else
					NEXT_ARB_STATE <= IDLE;
				end if;
			when GRANT =>
				if BGACKn = '0' then
					NEXT_ARB_STATE <= WAIT_RELEASE_3WIRE;
				elsif BRn = '1' then
					NEXT_ARB_STATE <= IDLE; -- Resume normal operation.
				else
					NEXT_ARB_STATE <= GRANT;
				end if;
			when WAIT_RELEASE_3WIRE =>
				if BGACKn = '1' and BRn = '0' then
					NEXT_ARB_STATE <= GRANT; -- Re-enter new arbitration.
				elsif BGACKn = '1' then
					NEXT_ARB_STATE <= IDLE;
				else
					NEXT_ARB_STATE <= WAIT_RELEASE_3WIRE;
				end if;
		end case;
	end process ARB_DEC;

	-- RESET logic:
	RESET_FILTER: process(RESETn, CLK)
	-- This process filters the incoming reset pin.
	-- If RESET_INn and HALTn are asserted together for longer
	-- than 10 clock cycles over the execution of a CPU reset
	-- command, the CPU reset is released.
	variable TMP	: std_logic_vector(3 downto 0);
	begin
		if RESETn = '0' then
			TMP := x"F"; -- For correct startup.
			RESET_CPU_In <= '0';
		elsif CLK = '1' and CLK' event then
			if RESET_INn = '0' and HALTn = '0' and RESET_OUT_EN_I = '0' and TMP < x"F" then
				TMP := TMP + '1';
			elsif RESET_INn = '1' or HALTn = '1' or RESET_OUT_EN_I = '1' then
				TMP := x"0";
			end if;
			if TMP > x"A" then
				RESET_CPU_In <= '0'; -- Release internal reset.
			else
				RESET_CPU_In <= '1';
			end if;
		end if;
	end process RESET_FILTER;

	RESET_TIMER: process(RESETn, CLK)
	-- This logic is responsible for the assertion of the
	-- reset output for 124 clock cycles, during the reset
	-- command. The LOCK variable avoids re-initialisation
	-- of the counter in the case that the RESET_EN is no
	-- strobe.
	variable TMP	: std_logic_vector(6 downto 0);
	variable LOCK	: boolean;
	begin
		if RESETn = '0' then
			TMP := (others => '0');
			LOCK := false;
		elsif CLK = '1' and CLK' event then
			if RESET_EN = '1' and LOCK = false then
				TMP := "1111100"; -- 124 initial value.
				LOCK := true; -- Lock the counter initialisation.
			elsif TMP > "0000000" then
				TMP := TMP - '1';
			elsif RESET_EN = '0' then
				LOCK := false; -- Unlock the counter initialisation.
			end if;
			if TMP = "0000001" then 
				RESET_OUT_EN_I <= '0';
				RESET_RDY <= '1';
			elsif TMP <= "0000011" then
				RESET_OUT_EN_I <= '0';
				RESET_RDY <= '0';
			else
				RESET_OUT_EN_I <= '1';
				RESET_RDY <= '0';
			end if;
		end if;
	end process RESET_TIMER;

	RESET_OUT_EN <= RESET_OUT_EN_I;
	RESET_CPUn <= RESET_CPU_In;
end BEHAVIOR;
