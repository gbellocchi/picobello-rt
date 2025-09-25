// Copyright 2022 ETH Zurich and University of Bologna.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Modified version of the RISC-V Frontend Server 
// (https://github.com/riscvarchive/riscv-fesvr, e41cfc3001293b5625c25412bd9b26e6e4ab8f7e)
//
// Nicole Narr <narrn@student.ethz.ch>
// Christopher Reinwardt <creinwar@student.ethz.ch>

#include <svdpi.h>
#include <cstring>
#include <string>
#include <sys/stat.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <assert.h>
#include <unistd.h>
#include <stdlib.h>
#include <stdio.h>
#include <vector>
#include <map>
#include <iostream>
#include <stdint.h>

extern "C" {
  char hello_world();
  char axi_test_sequence();  // Function called from SystemVerilog context
  
  // DPI-C task imports from SystemVerilog
  extern void sv_picobello_write(unsigned long long addr, unsigned long long data, unsigned int strb, unsigned int* resp);
  // void sv_picobello_read(unsigned long long addr, unsigned long long* data, unsigned int* resp);
  // void sv_wait_clocks(unsigned int num_clocks);
  
  // High-level C functions
  int axi_write_word(uint32_t addr, uint32_t data);
  // uint32_t axi_read_word(uint32_t addr);
}

extern "C" char hello_world()
{
  printf("Hello, World!\n");
  return 0;
}

template<int NumClusters>
class ClusterController {
private:
  extern void set_cluster_tg_start(int cluster_id, unsigned char value);
  extern unsigned char get_cluster_tg_idle(int cluster_id);

public:
  void start_traffic_generator(int cluster_id) {
    if (cluster_id < NumClusters) {
      set_cluster_tg_start(cluster_id, 1);
    }
  }
  
  void stop_traffic_generator(int cluster_id) {
    if (cluster_id < NumClusters) {
      set_cluster_tg_start(cluster_id, 0);
    }
  }
  
  bool is_idle(int cluster_id) {
    if (cluster_id < NumClusters) {
      return get_cluster_tg_idle(cluster_id);
    }
    return false;
  }
  
  void start_all() {
    for (int i = 0; i < NumClusters; i++) {
      start_traffic_generator(i);
    }
  }
  
  void wait_all_idle() {
    bool all_idle = false;
    while (!all_idle) {
      all_idle = true;
      for (int i = 0; i < NumClusters; i++) {
        if (!is_idle(i)) {
          all_idle = false;
          break;
        }
      }
      sv_wait_clocks(1); // Wait one clock cycle
    }
  }
};

// This function will be called from SystemVerilog context
extern "C" char axi_test_sequence()
{
  printf("[DPI-C] Starting AXI4 test sequence...\n");
  
  // // Wait a few clock cycles
  // sv_wait_clocks(10);
  
  // Example: Write to some test addresses
  // uint32_t test_addr = 0xD0000000;  // Memory tile base address
  // uint32_t test_addr = 0xC0000000;  // Memory tile base address
  uint32_t test_addr = 0xC0040000;  // Memory tile base address
  uint32_t test_data = 0x0000000F;
  
  printf("[DPI-C] Writing 0x%08x to address 0x%08x\n", test_data, test_addr);
  int write_result = axi_write_word(test_addr, test_data);
  
  if (write_result == 0) {
    printf("[DPI-C] Write successful!\n");
    
    // // Read back the data
    // printf("[DPI-C] Reading back from address 0x%08x\n", test_addr);
    // uint32_t read_data = axi_read_word(test_addr);
    
    // if (read_data == test_data) {
    //   printf("[DPI-C] Read-write test PASSED! Got 0x%08x\n", read_data);
    // } else {
    //   printf("[DPI-C] Read-write test FAILED! Expected 0x%08x, got 0x%08x\n", test_data, read_data);
    // }
  } else {
    printf("[DPI-C] Write failed with response %d\n", write_result);
  }
  
  printf("[DPI-C] AXI4 test sequence completed.\n");
  return 0;
}

extern "C" int axi_write_word(uint32_t addr, uint32_t data)
{
  unsigned int resp;
  sv_picobello_write((unsigned long long)addr, (unsigned long long)data, 0xF, &resp);
  return resp;  // 0 = OKAY, non-zero = error
}

// extern "C" uint32_t axi_read_word(uint32_t addr)
// {
//   unsigned long long data;
//   unsigned int resp;
//   sv_picobello_read((unsigned long long)addr, &data, &resp);
  
//   if (resp != 0) {
//     printf("[DPI-C] AXI read error: response = %d\n", resp);
//     return 0xFFFFFFFF;  // Error indicator
//   }
  
//   return (uint32_t)(data & 0xFFFFFFFF);
// }