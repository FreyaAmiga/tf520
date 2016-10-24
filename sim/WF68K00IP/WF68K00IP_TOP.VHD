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
---- The following operations are additionally supported by this  ----
---- core:                                                        ----
----   - LINK (long).                                             ----
----   - MOVE FROM CCR.                                           ----
----   - MULS, MULU: all operation modes word and long.           ----
----   - DIVS, DIVU: all operation modes word and long.           ----
----   - DIVSL, DIVUL.                                            ----
----   - Direct addressing mode enhancements for TST etc.         ----
----   - PC relative addressing modes for operations like TST.    ----
----                                                              ----
---- This file is the top level file of the ip core.              ----
----                                                              ----
----                                                              ----
----                                                              ----
----                                                              ----
---- Author(s):                                                   ----
---- - Wolfgang Foerster, wf@experiment-s.de; wf@inventronik.de   ----
----                                                              ----
----------------------------------------------------------------------
----                                                              ----
---- Copyright (C) 2008 Wolfgang Foerster                         ----
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
-- Revision 2K8B  2008/12/24 WF
--   Initial Release.
-- 

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity WF68K00IP_TOP is
	port (
		CLK			: in bit;
		RESET_COREn	: in bit; -- Core reset.
		
		-- Address and data:
		ADR		: out std_logic_vector(23 downto 0);
		DATA	: inout std_logic_vector(15 downto 0);

		-- System control:
		BERRn	: in bit;
		RESETn	: inout std_logic; -- Open drain.
		HALTn	: inout std_logic; -- Open drain.
		
		-- Processor status:
		FC		: out std_logic_vector(2 downto 0);
		
		-- Interrupt control:
		AVECn	: in bit; -- Originally 68Ks use VPAn.
		IPLn	: in std_logic_vector(2 downto 0);
		
		-- Aynchronous bus control:
		DTACKn	: in bit;
		ASn		: out std_logic;
		RWn		: out std_logic;
		UDSn	: out std_logic;
		LDSn	: out std_logic;
		
		-- Synchronous peripheral control:
		E		: out bit;
		VMAn	: out std_logic;
		VPAn	: in bit;
		
		-- Bus arbitration control:
		BRn		: in bit;
		BGn		: out bit;
		BGACKn	: in bit
	);
end entity WF68K00IP_TOP;
	
architecture STRUCTURE of WF68K00IP_TOP is
component WF68K00IP_TOP_SOC -- CPU.
    port (
        CLK				: in bit;
        RESET_COREn		: in bit; -- Core reset.
        ADR_OUT			: out std_logic_vector(23 downto 0);
        ADR_EN			: out bit;
        DATA_IN			: in std_logic_vector(15 downto 0);
        DATA_OUT		: out std_logic_vector(15 downto 0);
        DATA_EN			: out bit;
        BERRn			: in bit;
        RESET_INn		: in bit;
        RESET_OUT_EN	: out bit; -- Open drain.
        HALT_INn		: in std_logic;
        HALT_OUT_EN		: out bit; -- Open drain.
        FC_OUT			: out std_logic_vector(2 downto 0);
        FC_OUT_EN		: out bit;
        AVECn			: in bit;
        IPLn			: in std_logic_vector(2 downto 0);
        DTACKn			: in bit;
        AS_OUTn			: out bit;
        AS_OUT_EN		: out bit;
        RWn_OUT			: out bit;
        RW_OUT_EN		: out bit;
        UDS_OUTn		: out bit;
        UDS_OUT_EN		: out bit;
        LDS_OUTn		: out bit;
        LDS_OUT_EN		: out bit;
        E				: out bit;
        VMA_OUTn		: out bit;
        VMA_OUT_EN		: out bit;
        VPAn			: in bit;
        BRn				: in bit;
        BGn				: out bit;
        BGACKn			: in bit
        );
end component WF68K00IP_TOP_SOC;
signal RESET_INn    : bit;
signal RESET_EN     : bit;
signal HALT_EN      : bit;
signal ADR_EN       : bit;
signal ADR_OUT      : std_logic_vector(23 downto 0);
signal DATA_EN      : bit;
signal DATA_OUT     : std_logic_vector(15 downto 0);
signal FC_EN        : bit;
signal FC_OUT       : std_logic_vector(2 downto 0);
signal AS_OUTn      : bit;
signal AS_EN        : bit;
signal RWn_OUT      : bit;
signal RW_EN        : bit;
signal UDS_OUTn     : bit;
signal UDS_EN       : bit;
signal LDS_OUTn     : bit;
signal LDS_EN       : bit;
signal IPL_INn		: std_logic_vector(2 downto 0);
signal VMA_OUTn     : bit;
signal VMA_EN       : bit;
begin
    ADR <= ADR_OUT when ADR_EN = '1' else (others => 'Z');
    DATA <= DATA_OUT when DATA_EN = '1' else (others => 'Z');

    -- Inputs:
    RESET_INn <= To_Bit(RESETn);
    IPL_INn <= IPLn;

	-- Open drain outputs:
	RESETn <= '0' when RESET_EN = '1' else 'Z';
	HALTn <= '0' when HALT_EN = '1' else 'Z';

	-- Bus controls:
	ASn	<= '1'	when AS_OUTn = '1' and AS_EN = '1' else
           '0'	when AS_OUTn = '0' and AS_EN = '1' else 'Z';
	UDSn <= '1' when UDS_OUTn = '1' and UDS_EN = '1' else
			'0' when UDS_OUTn = '0' and UDS_EN = '1' else 'Z';
	LDSn <= '1' when LDS_OUTn= '1' and LDS_EN = '1' else
			'0' when LDS_OUTn = '0' and LDS_EN = '1' else 'Z';
	RWn <= '1' when RWn_OUT = '1' and RW_EN = '1' else
           '0' when RWn_OUT = '0' and RW_EN = '1' else 'Z';
	VMAn <= '1' when VMA_OUTn = '1' and VMA_EN = '1' else
			'0' when VMA_OUTn = '0' and VMA_EN = '1' else 'Z';

	-- The function code:
	FC <= FC_OUT when FC_EN = '1' else (others => 'Z');

    I_68K00: WF68K00IP_TOP_SOC
        port map(
            CLK             => CLK,
            RESET_COREn     => RESET_COREn,
            ADR_OUT         => ADR_OUT,
            ADR_EN          => ADR_EN,
            DATA_IN         => DATA,
            DATA_OUT        => DATA_OUT,
            DATA_EN         => DATA_EN,
            BERRn           => BERRn,
            RESET_INn       => RESET_INn,
            RESET_OUT_EN    => RESET_EN,
            HALT_INn        => HALTn,
            HALT_OUT_EN     => HALT_EN,
            FC_OUT          => FC_OUT,
            FC_OUT_EN       => FC_EN,
            AVECn           => AVECn,
            IPLn            => IPL_INn,
            DTACKn          => DTACKn,
            AS_OUTn         => AS_OUTn,
            AS_OUT_EN       => AS_EN,
            RWn_OUT         => RWn_OUT,
            RW_OUT_EN       => RW_EN,
            UDS_OUTn        => UDS_OUTn,
            UDS_OUT_EN      => UDS_EN,
            LDS_OUTn        => LDS_OUTn,
            LDS_OUT_EN      => LDS_EN,
            E               => E,
            VMA_OUTn        => VMA_OUTn,
            VMA_OUT_EN      => VMA_EN,
            VPAn            => VPAn,
            BRn             => BRn,
            BGn             => BGn,
            BGACKn          => BGACKn
            );
end STRUCTURE;
