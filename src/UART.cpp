#include <cstdio>
#include <iostream>
#include <termios.h>
#include <cstdlib>
#include <unistd.h>
#include <fcntl.h>
#include <cstring>
#include <sys/wait.h>


#include "UART.h"

namespace riscv_tlm::peripherals {


	void UART::xtermLaunch(char *slaveName) const {
        char *arg;
        char *fin = &(slaveName[strlen(slaveName) - 2]);

        if (nullptr == strchr(fin, '/')) {
            arg = new char[2 + 1 + 1 + 20 + 1];
            sprintf(arg, "-S%c%c%d", fin[0], fin[1], ptMaster);
        } else {
            char *slaveBase = ::basename(slaveName);
            arg = new char[2 + strlen(slaveBase) + 1 + 20 + 1];
            sprintf(arg, "-S%s/%d", slaveBase, ptMaster);
        }
		printf("xtermLaunch: built arg='%s'\n", arg);

        char *argv[3];
        argv[0] = (char *) ("xterm");
        argv[1] = arg;
        argv[2] = nullptr;

        execvp("xterm", argv);
    }

    void UART::xtermKill() {

        if (-1 != ptSlave) {        // Close down the slave
            close(ptSlave);            // Close the FD
            ptSlave = -1;
        }

        if (-1 != ptMaster) {        // Close down the master
            close(ptMaster);
            ptMaster = -1;
        }

        if (xtermPid > 0) {            // Kill the terminal
            kill(xtermPid, SIGKILL);
            waitpid(xtermPid, nullptr, 0);
        }
    }

    void UART::xtermSetup() {
        ptMaster = open("/dev/ptmx", O_RDWR);

        if (ptMaster != -1) {
            grantpt(ptMaster);

            unlockpt(ptMaster);

            char *ptSlaveName = ptsname(ptMaster);
            ptSlave = open(ptSlaveName, O_RDWR);    // In and out are the same

            struct termios termInfo{};
            tcgetattr(ptSlave, &termInfo);

            termInfo.c_lflag &= ECHO;
            termInfo.c_lflag &= ~ICANON;
            tcsetattr(ptSlave, TCSADRAIN, &termInfo);

            xtermPid = fork();
			printf("UART %s: ptMaster=%d, ptSlave=%s\n",name(), ptMaster, ptSlaveName);

            if (xtermPid == 0) {
                xtermLaunch(ptSlaveName);
            }
        }
    }
	
	SC_HAS_PROCESS(UART);

	UART::UART(sc_core::sc_module_name const &name) :
			sc_module(name), socket("socket") {

		socket.register_b_transport(this, &UART::b_transport);

		SC_THREAD(uart_rx_process); 
		xtermSetup();
	}

	UART::~UART() {
		xtermKill();
	}

	void UART::b_transport(tlm::tlm_generic_payload &trans,
					 sc_core::sc_time & delay){
		uint64_t addr = trans.get_address() & 0xFFF;
		unsigned char* ptr = trans.get_data_ptr();
		unsigned int len = trans.get_data_length();
		tlm::tlm_command cmd = trans.get_command();

		std::cout << "UART access: addr=0x" << std::hex << addr << " local=0x" << addr << std::dec << std::endl;
		if (len != 4) {
			trans.set_response_status(tlm::TLM_ADDRESS_ERROR_RESPONSE);
			return;
		}

		uint32_t reg_idx = addr / 4;
		if(reg_idx >= 16) {
			trans.set_response_status(tlm::TLM_ADDRESS_ERROR_RESPONSE);
			return;
		}

		if (cmd == tlm::TLM_READ_COMMAND) {
			
			regs[FR] = 0;
			if (tx_empty) regs[FR] |= (1 << 5);  //TXFE
			if (!rx_ready) regs[FR] |= (1 << 4);  //RXFE
													 //
			*(uint32_t*)ptr = regs[reg_idx];
			if (addr == DR * 4 && rx_ready) {
				rx_ready = false;
			}

		} else { // WRITE
			uint32_t val = *(uint32_t*)ptr;
			if (addr == DR * 4){
				uint8_t ch = val & 0xFF;
       			 std::cout << "TX CHAR: '" << ch << "' (0x" << std::hex << (int)ch << ")" << std::dec << std::endl;
				if (ptSlave != -1) {
					ssize_t bytes = write(ptSlave, &ch, 1);
            		std::cout << "Wrote " << bytes << " bytes to ptSlave=" << ptSlave << std::endl;

				}
				tx_empty = true;
			} else {
				regs[reg_idx] = val;
			}
		}
		trans.set_response_status(tlm::TLM_OK_RESPONSE);
		delay = sc_core::sc_time(10, sc_core::SC_NS);

	}


void UART::uart_rx_process() {
        fd_set readfds;
        struct timeval tv;
        
       while (true) {
    if (ptMaster != -1) {

        FD_ZERO(&readfds);
        FD_SET(ptMaster, &readfds);
        tv.tv_sec  = 0;
        tv.tv_usec = 0;

        int r = select(ptMaster + 1, &readfds, nullptr, nullptr, &tv);
        if (r == -1) {
            perror("UART RX: select failed");
        } else if (r == 0) {
            // timeout; normal, no input
        } else {
            printf("UART RX: select returned %d, FD_ISSET=%d\n",
                   r, FD_ISSET(ptMaster, &readfds));
            if (FD_ISSET(ptMaster, &readfds)) {
                uint8_t ch;
                ssize_t bytes = read(ptMaster, &ch, 1);
                if (bytes > 0) {
                    rx_data = ch;
                    rx_ready = true;
                    printf("UART RX: char='\\x%02x' (%c)\n", ch, isprint(ch) ? ch : '?');
                    SC_REPORT_INFO("UART", "RX data ready");
                }
            }
        }
    }
    wait(sc_core::SC_ZERO_TIME);
}
}
};
