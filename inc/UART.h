/*
\file UART.h
\brief Basic TLM-2 UART module
\author Dylan Granger
\date March 2026
*/

#ifndef __UART_H__
#define __UART_H__

#include <iostream>
#include <fstream>

#define SC_INCLUDE_DYNAMIC_PROCESSES

#include "systemc"

#include "tlm.h"
#include "tlm_utils/simple_target_socket.h"

namespace riscv_tlm::peripherals {

	class UART : sc_core::sc_module {
		public:
	   /**
		*@brief Bus Socket
		*/	
		tlm_utils::simple_target_socket<UART> socket;
		
	/**
	 *	@brief Constructor
	 *	@param name Module name
	 */
		explicit UART(sc_core::sc_module_name const &name);
	/**
	 *@brief Destructor
	 */
		~UART() override;

	private:
		
		// UART regs
    	enum { DR = 0x00, FR = 0x18, CR = 0x30 }; // etc.
    	uint32_t regs[16];
    	bool tx_empty;
    	bool rx_ready;
    	uint8_t rx_data;	
		virtual void b_transport(tlm::tlm_generic_payload &trans,
								 sc_core::sc_time &delay);
		
		void uart_rx_process();
		void xtermLaunch(char *slaveName) const;

		void xtermKill();

		void xtermSetup();

		int ptSlave{};
		int ptMaster{};
		int xtermPid{};
	};
}
#endif

