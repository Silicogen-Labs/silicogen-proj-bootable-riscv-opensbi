#include <verilated.h>
#include <verilated_vcd_c.h>
#include "Vtb_soc.h"
#include <iostream>

vluint64_t main_time = 0;  // Current simulation time

double sc_time_stamp() {  // Called by $time in Verilog
    return main_time;
}

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    Verilated::traceEverOn(true);
    
    // Create instance of the testbench
    Vtb_soc* tb = new Vtb_soc;
    
    // Create VCD trace
    VerilatedVcdC* tfp = new VerilatedVcdC;
    tb->trace(tfp, 99);
    tfp->open("sim/waveforms/tb_soc.vcd");
    
    std::cout << "=== Starting RISC-V SoC Verilator Simulation ===" << std::endl;
    
    // Run simulation - let the testbench timing control everything
    while (!Verilated::gotFinish() && main_time < 100000000) {
        // Evaluate model
        tb->eval();
        
        // Dump trace
        tfp->dump(main_time);
        
        // Time advances
        main_time++;
    }
    
    // Final model cleanup
    tb->final();
    
    // Close trace
    tfp->close();
    
    // Cleanup
    delete tfp;
    delete tb;
    
    std::cout << "=== Simulation Complete ===" << std::endl;
    std::cout << "Total simulation time: " << main_time << " ns" << std::endl;
    
    return 0;
}
