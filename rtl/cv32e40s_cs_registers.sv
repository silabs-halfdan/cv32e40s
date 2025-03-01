// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Copyright 2018 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.

////////////////////////////////////////////////////////////////////////////////
// Engineer:       Sven Stucki - svstucki@student.ethz.ch                     //
//                                                                            //
// Additional contributions by:                                               //
//                 Andreas Traber - atraber@iis.ee.ethz.ch                    //
//                 Michael Gautschi - gautschi@iis.ee.ethz.ch                 //
//                 Davide Schiavone - pschiavo@iis.ee.ethz.ch                 //
//                 Andrea Bettati - andrea.bettati@studenti.unipr.it          //
//                 Øystein Knauserud - oystein.knauserud@silabs.com           //
//                 Øivind Ekelund - oivind.ekelund@silabs.com                 //
//                                                                            //
// Design Name:    Control and Status Registers                               //
// Project Name:   RI5CY                                                      //
// Language:       SystemVerilog                                              //
//                                                                            //
// Description:    Control and Status Registers (CSRs)                        //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////

module cv32e40s_cs_registers import cv32e40s_pkg::*;
#(
  parameter              LIB              = 0,
  parameter rv32_e       RV32             = RV32I,
  parameter m_ext_e      M_EXT            = M,
  parameter bit          ZC_EXT           = 0,
  parameter bit          CLIC             = 0,
  parameter int unsigned CLIC_ID_WIDTH    = 5,
  parameter int unsigned NUM_MHPMCOUNTERS = 1,
  parameter int          PMP_NUM_REGIONS  = 0,
  parameter int unsigned PMP_GRANULARITY  = 0,
  parameter pmpncfg_t    PMP_PMPNCFG_RV[PMP_NUM_REGIONS-1:0] = '{default:PMPNCFG_DEFAULT},
  parameter logic [31:0] PMP_PMPADDR_RV[PMP_NUM_REGIONS-1:0] = '{default:32'h0},
  parameter mseccfg_t    PMP_MSECCFG_RV                      = MSECCFG_DEFAULT,
  parameter lfsr_cfg_t   LFSR0_CFG        = LFSR_CFG_DEFAULT,
  parameter lfsr_cfg_t   LFSR1_CFG        = LFSR_CFG_DEFAULT,
  parameter lfsr_cfg_t   LFSR2_CFG        = LFSR_CFG_DEFAULT,
  parameter bit          DEBUG            = 1,
  parameter int          DBG_NUM_TRIGGERS = 1,
  parameter int unsigned MTVT_ADDR_WIDTH  = 26
)
(
  // Clock and Reset
  input  logic                          clk,
  input  logic                          rst_n,
  input  logic                          scan_cg_en_i,

  // Configuration
  input  logic [31:0]                   mhartid_i,
  input  logic  [3:0]                   mimpid_patch_i,
  input  logic [31:0]                   mtvec_addr_i,
  input  logic                          csr_mtvec_init_i,

  // CSRs
  output dcsr_t                         dcsr_o,
  output logic [31:0]                   dpc_o,
  output logic [JVT_ADDR_WIDTH-1:0]     jvt_addr_o,
  output logic [5:0]                    jvt_mode_o,
  output mcause_t                       mcause_o,
  output logic [63:0]                   mcycle_o,
  output logic [31:0]                   mepc_o,
  output logic [31:0]                   mie_o,
  output mintstatus_t                   mintstatus_o,
  output logic [7:0]                    mintthresh_th_o,
  output mstatus_t                      mstatus_o,
  output logic [24:0]                   mtvec_addr_o,
  output logic  [1:0]                   mtvec_mode_o,
  output logic [MTVT_ADDR_WIDTH-1:0]    mtvt_addr_o,
  output logic [31:0]                   mstateen0_o,


  output privlvl_t                      priv_lvl_o,
  output privlvlctrl_t                  priv_lvl_if_ctrl_o,
  output privlvl_t                      priv_lvl_lsu_o,

  // IF/ID pipeline
  input logic                           sys_en_id_i,
  input logic                           sys_mret_id_i,

  // ID/EX pipeline
  input id_ex_pipe_t                    id_ex_pipe_i,
  output logic                          csr_illegal_o,

  // EX/WB pipeline
  input  ex_wb_pipe_t                   ex_wb_pipe_i,

  // From controller_fsm
  input  ctrl_fsm_t                     ctrl_fsm_i,

  // To controller_bypass
  output logic                          csr_counter_read_o,
  output logic                          csr_mnxti_read_o,
  output csr_hz_t                       csr_hz_o,

  // Interface to CSRs (SRAM like)
  output logic [31:0]                   csr_rdata_o,

  // Interrupts
  input  logic [31:0]                   mip_i,
  input  logic                          mnxti_irq_pending_i,
  input  logic [CLIC_ID_WIDTH-1:0]      mnxti_irq_id_i,
  input  logic [7:0]                    mnxti_irq_level_i,
  output logic                          clic_pa_valid_o,        // CSR read data is an address to a function pointer
  output logic [31:0]                   clic_pa_o,              // Address to CLIC function pointer
  output logic                          csr_irq_enable_write_o, // An irq enable write is being performed in WB

  // PMP
  output pmp_csr_t                      csr_pmp_o,

  // Xsecure
  output logic                          csr_err_o,
  output logic                          lfsr_lockup_o,
  input  logic                          lfsr_shift_if_i,
  input  logic                          lfsr_shift_id_i,
  output xsecure_ctrl_t                 xsecure_ctrl_o,

  // CSR write strobes
  output logic                          csr_wr_in_wb_flush_o,

  // Debug
  input  logic [31:0]                   pc_if_i,
  input  logic                          ptr_in_if_i,
  input  privlvl_t                      priv_lvl_if_i,
  output logic [31:0]                   trigger_match_if_o,
  output logic [31:0]                   trigger_match_ex_o,
  output logic                          etrigger_wb_o,
  input  logic                          lsu_valid_ex_i,
  input  logic [31:0]                   lsu_addr_ex_i,
  input  logic                          lsu_we_ex_i,
  input  logic [3:0]                    lsu_be_ex_i
);

  localparam bit PMP = SECURE;

  localparam PMP_ADDR_WIDTH = (PMP_GRANULARITY > 0) ? 33 - PMP_GRANULARITY : 32;

  localparam bit USER = SECURE;

  localparam logic [31:0] MISA_VALUE =
    (32'(1)             <<  2) | // C - Compressed extension
    (32'(RV32 == RV32E) <<  4) | // E - RV32E/64E base ISA
    (32'(RV32 == RV32I) <<  8) | // I - RV32I/64I/128I base ISA
    (32'(M_EXT == M)    << 12) | // M - Integer Multiply/Divide extension
    (32'(USER)          << 20) | // U - User mode implemented
    (32'(1)             << 23) | // X - Non-standard extensions present
    (32'(MXL)           << 30); // M-XLEN


  localparam logic [31:0] CSR_MTVT_MASK = {{MTVT_ADDR_WIDTH{1'b1}}, {(32-MTVT_ADDR_WIDTH){1'b0}}};

  // CSR update logic
  logic [31:0]                  csr_wdata_int;
  logic [31:0]                  csr_rdata_int;
  logic                         csr_we_int;

  csr_opcode_e                  csr_op;
  csr_num_e                     csr_waddr;
  csr_num_e                     csr_raddr;
  logic [31:0]                  csr_wdata;
  logic                         csr_en_gated;

  logic                         illegal_csr_read;                               // Current CSR cannot be read
  logic                         illegal_csr_write;                              // Current CSR cannot be written

  logic                         instr_valid;                                    // Local instr_valid

  logic                         unused_signals;

  // Interrupt control signals
  logic [31:0]                  mepc_q, mepc_n, mepc_rdata;
  logic                         mepc_we;

  // Trigger
  // Trigger CSR write enables are decoded in cs_registers, all other (WARL behavior, write data and trigger matches)
  // are handled within cv32e40s_debug_triggers
  logic [31:0]                  tselect_rdata;
  logic                         tselect_we;

  logic [31:0]                  tdata1_rdata;
  logic                         tdata1_we;

  logic [31:0]                  tdata2_rdata;
  logic                         tdata2_we;

  logic [31:0]                  tinfo_rdata;
  logic                         tinfo_we;

  // Debug
  dcsr_t                        dcsr_q, dcsr_n, dcsr_rdata;
  logic                         dcsr_we;

  logic [31:0]                  dpc_q, dpc_n, dpc_rdata;
  logic                         dpc_we;

  logic [31:0]                  dscratch0_q, dscratch0_n, dscratch0_rdata;
  logic                         dscratch0_we;

  logic [31:0]                  dscratch1_q, dscratch1_n, dscratch1_rdata;
  logic                         dscratch1_we;

  logic [31:0]                  mscratch_q, mscratch_n, mscratch_rdata;
  logic                         mscratch_we;

  jvt_t                         jvt_q, jvt_n, jvt_rdata;
  logic                         jvt_we;

  mstatus_t                     mstatus_q, mstatus_n, mstatus_rdata;
  logic                         mstatus_we;

  logic [31:0]                  mstatush_n, mstatush_rdata;                     // No CSR module instance
  logic                         mstatush_we;                                    // Not used in RTL (used by RVFI)

  logic [31:0]                  misa_n, misa_rdata;                             // No CSR module instance
  logic                         misa_we;                                        // Not used in RTL (used by RVFI)

  mcause_t                      mcause_q, mcause_n, mcause_rdata;
  logic                         mcause_we;

  mtvec_t                       mtvec_q, mtvec_n, mtvec_rdata;
  logic                         mtvec_we;

  mtvt_t                        mtvt_q, mtvt_n, mtvt_rdata;
  logic                         mtvt_we;

  logic [31:0]                  mnxti_n, mnxti_rdata;                           // No CSR module instance
  logic                         mnxti_we;

  mintstatus_t                  mintstatus_q, mintstatus_n, mintstatus_rdata;
  logic                         mintstatus_we;

  logic [31:0]                  mintthresh_q, mintthresh_n, mintthresh_rdata;
  logic                         mintthresh_we;

  logic [31:0]                  mscratchcsw_n, mscratchcsw_rdata;
  logic                         mscratchcsw_we;

  logic [31:0]                  mscratchcswl_n, mscratchcswl_rdata;
  logic                         mscratchcswl_we;

  logic [31:0]                  mip_n, mip_rdata;                               // No CSR module instance
  logic                         mip_we;                                         // Not used in RTL (used by RVFI)

  logic [31:0]                  mie_q, mie_n, mie_rdata;                        // Bits are masked according to IRQ_MASK
  logic                         mie_we;

  logic [31:0]                  mvendorid_n, mvendorid_rdata;                   // No CSR module instance
  logic                         mvendorid_we;                                   // Always 0 (MRO), not used in RTL (used by RVFI)

  logic [31:0]                  marchid_n, marchid_rdata;                       // No CSR module instance
  logic                         marchid_we;                                     // Always 0 (MRO), not used in RTL (used by RVFI)

  logic [31:0]                  mimpid_n, mimpid_rdata;                         // No CSR module instance
  logic                         mimpid_we;                                      // Always 0 (MRO), not used in RTL (used by RVFI)

  logic [31:0]                  mhartid_n, mhartid_rdata;                       // No CSR module instance
  logic                         mhartid_we;                                     // Always 0 (MRO), not used in RTL (used by RVFI)

  logic [31:0]                  mconfigptr_n, mconfigptr_rdata;                 // No CSR module instance
  logic                         mconfigptr_we;                                  // Always 0 (MRO), not used in RTL (used by RVFI)

  logic [31:0]                  mtval_n, mtval_rdata;                           // No CSR module instance
  logic                         mtval_we;                                       // Not used in RTL (used by RVFI)

  logic [31:0]                  mcounteren_n, mcounteren_rdata;                 // No CSR module instance
  logic                         mcounteren_we;                                  // Not used in RTL (used by RVFI)

  pmpncfg_t                     pmpncfg_n[PMP_MAX_REGIONS];
  pmpncfg_t                     pmpncfg_n_int[PMP_MAX_REGIONS];
  pmpncfg_t                     pmpncfg_q[PMP_MAX_REGIONS];
  pmpncfg_t                     pmpncfg_rdata[PMP_MAX_REGIONS];
  logic [PMP_MAX_REGIONS-1:0]   pmpncfg_we;
  logic [PMP_MAX_REGIONS-1:0]   pmpncfg_locked;
  logic [PMP_MAX_REGIONS-1:0]   pmpaddr_locked;
  logic [PMP_MAX_REGIONS-1:0]   pmpncfg_wr_addr_match;
  logic [PMP_MAX_REGIONS-1:0]   pmpncfg_warl_ignore_wr;
  logic [PMP_MAX_REGIONS-1:0]   pmpaddr_wr_addr_match;
  logic [PMP_MAX_REGIONS-1:0]   unused_pmp_region_signals;

  logic [PMP_ADDR_WIDTH-1:0]    pmp_addr_n[PMP_MAX_REGIONS];                    // Value written is not necessarily the value read
  logic                         pmp_addr_bit_0_n[PMP_MAX_REGIONS];
  logic [PMP_ADDR_WIDTH-1:0]    pmp_addr_q[PMP_MAX_REGIONS];
  logic [31:0]                  pmp_addr_n_r[PMP_MAX_REGIONS];                  // Not used in RTL (used by RVFI) (next read value)
  logic [PMP_MAX_REGIONS-1:0]   pmp_addr_n_r_unused;
  logic [31:0]                  pmp_addr_rdata[PMP_MAX_REGIONS];
  logic [PMP_MAX_REGIONS-1:0]   pmp_addr_we;

  mseccfg_t                     pmp_mseccfg_n;
  mseccfg_t                     pmp_mseccfg_q;
  mseccfg_t                     pmp_mseccfg_rdata;
  logic                         pmp_mseccfg_we;

  mseccfg_t                     pmp_mseccfgh_n;                                 // No CSR module instance
  mseccfg_t                     pmp_mseccfgh_rdata;
  logic                         pmp_mseccfgh_we;                                // Not used in RTL (used by RVFI)

  logic [31:0]                  menvcfgh_n, menvcfgh_rdata;                     // No CSR module instance
  logic                         menvcfgh_we;                                    // Not used in RTL (used by RVFI)

  logic [31:0]                  menvcfg_n, menvcfg_rdata;                       // No CSR module instance
  logic                         menvcfg_we;                                     // Not used in RTL (used by RVFI)

  cpuctrl_t                     cpuctrl_n, cpuctrl_q, cpuctrl_rdata;
  logic                         cpuctrl_we;

  logic [31:0]                  secureseed0_n, secureseed1_n, secureseed2_n;    // No CSR module instance
  logic                         secureseed0_we, secureseed1_we, secureseed2_we;
  logic [31:0]                  secureseed0_rdata, secureseed1_rdata, secureseed2_rdata;

  privlvl_t                     priv_lvl_n, priv_lvl_q, priv_lvl_rdata;
  logic                         priv_lvl_we;
  logic [1:0]                   priv_lvl_q_int;

  logic [31:0]                  mstateen0_n, mstateen0_q, mstateen0_rdata;
  logic                         mstateen0_we;

  logic [31:0]                  mstateen1_n, mstateen1_rdata;                   // No CSR module instance
  logic                         mstateen1_we;                                   // Not used in RTL (used by RVFI)
  logic [31:0]                  mstateen2_n, mstateen2_rdata;                   // No CSR module instance
  logic                         mstateen2_we;                                   // Not used in RTL (used by RVFI)
  logic [31:0]                  mstateen3_n, mstateen3_rdata;                   // No CSR module instance
  logic                         mstateen3_we;                                   // Not used in RTL (used by RVFI)

  logic [31:0]                  mstateen0h_n, mstateen0h_rdata;                 // No CSR module instance
  logic                         mstateen0h_we;                                  // Not used in RTL (used by RVFI)
  logic [31:0]                  mstateen1h_n, mstateen1h_rdata;                 // No CSR module instance
  logic                         mstateen1h_we;                                  // Not used in RTL (used by RVFI)
  logic [31:0]                  mstateen2h_n, mstateen2h_rdata;                 // No CSR module instance
  logic                         mstateen2h_we;                                  // Not used in RTL (used by RVFI)
  logic [31:0]                  mstateen3h_n, mstateen3h_rdata;                 // No CSR module instance
  logic                         mstateen3h_we;

  // Special we signal for aliased writes between mstatus and mcause.
  // Only used for explicit writes to either mcause or mstatus, to signal that
  // mpp and mpie of the aliased CSR should be written.
  // All implicit writes (upon taking exceptions etc) handle the aliasing by also
  // writing mcause.mpp/mpie to mstatus and vice versa.
  logic                         mcause_alias_we;
  logic                         mstatus_alias_we;


  // Performance Counter Signals
  logic [31:0] [63:0]           mhpmcounter_q;                                  // Performance counters
  logic [31:0] [63:0]           mhpmcounter_n;                                  // Performance counters next value
  logic [31:0] [63:0]           mhpmcounter_rdata;                              // Performance counters next value
  logic [31:0] [1:0]            mhpmcounter_we;                                 // Performance counters write enable
  logic [31:0] [31:0]           mhpmevent_q, mhpmevent_n, mhpmevent_rdata;      // Event enable
  logic [31:0]                  mcountinhibit_q, mcountinhibit_n, mcountinhibit_rdata; // Performance counter inhibit
  logic [NUM_HPM_EVENTS-1:0]    hpm_events;                                     // Events for performance counters
  logic [31:0] [63:0]           mhpmcounter_increment;                          // Increment of mhpmcounter_q
  logic [31:0]                  mhpmcounter_write_lower;                        // Write 32 lower bits of mhpmcounter_q
  logic [31:0]                  mhpmcounter_write_upper;                        // Write 32 upper bits mhpmcounter_q
  logic [31:0]                  mhpmcounter_write_increment;                    // Write increment of mhpmcounter_q

  logic                         illegal_csr_write_priv, illegal_csr_read_priv;
  logic                         illegal_jvt_access;

  logic                         csr_wr_in_wb;
  logic                         xsecure_csr_wr_in_wb;
  logic                         pmp_csr_wr_in_wb;
  // Detect JVT writes (requires pipeline flush)
  logic                         jvt_wr_in_wb;

  logic                         mscratch_rd_error;
  logic                         mstatus_rd_error;
  logic                         mtvec_rd_error;
  logic [PMP_MAX_REGIONS-1:0]   pmpncfg_rd_error;
  logic [PMP_MAX_REGIONS-1:0]   pmp_addr_rd_error;
  logic                         pmp_mseccfg_rd_error;
  logic                         pmp_rd_error;
  logic                         cpuctrl_rd_error;
  logic                         dcsr_rd_error;
  logic                         mie_rd_error;
  logic                         mepc_rd_error;
  logic                         mtvt_rd_error;
  logic                         mintstatus_rd_error;
  logic                         mintthresh_rd_error;
  logic                         jvt_rd_error;
  logic                         priv_lvl_rd_error;
  logic                         mstateen0_rd_error;
  logic                         mcause_rd_error;

  logic                         dpc_rd_error;                                   // Not used
  logic                         dscratch0_rd_error;                             // Not used
  logic                         dscratch1_rd_error;                             // Not used

  // Signal used for RVFI to set rmask, not used internally
  logic                         mscratchcsw_in_wb;
  logic                         mscratchcswl_in_wb;
  logic                         mnxti_in_wb;

  // Local padded version of mnxti_irq_id_i
  logic [32-MTVT_ADDR_WIDTH-2-1:0] mnxti_irq_id;

  // Pad mnxti_irq_i with zeroes if CLIC_ID_WIDTH is not 4 or more.
  generate
    if (CLIC_ID_WIDTH < 4) begin : mnxti_irq_id_lt4
      assign mnxti_irq_id = {{(4-CLIC_ID_WIDTH){1'b0}}, mnxti_irq_id_i};
    end
    else begin: mnxti_irq_id_ge4
      assign mnxti_irq_id = mnxti_irq_id_i;
    end
  endgenerate

  // Local instr_valid for write portion (WB)
  // Not factoring in ctrl_fsm_i.halt_limited_wb. This signal is only set during SLEEP mode, and while in SLEEP
  // there cannot be any CSR instruction in WB.
  assign instr_valid = ex_wb_pipe_i.instr_valid && !ctrl_fsm_i.kill_wb && !ctrl_fsm_i.halt_wb;

  // CSR access. Read in EX, write in WB
  // Setting csr_raddr to zero in case of unused csr to save power (alu_operand_b toggles a lot)
  assign csr_raddr = csr_num_e'((id_ex_pipe_i.csr_en && id_ex_pipe_i.instr_valid) ? id_ex_pipe_i.alu_operand_b[11:0] : 12'b0);

  // Not suppressing csr_waddr to zero when unused since its source are dedicated flipflops and would not save power as for raddr
  assign csr_waddr = csr_num_e'(ex_wb_pipe_i.csr_addr);
  assign csr_wdata = ex_wb_pipe_i.csr_wdata;

  assign csr_op    =  ex_wb_pipe_i.csr_op;

  // CSR write operations in WB, actual csr_we_int may still become 1'b0 in case of CSR_OP_READ
  assign csr_en_gated    = ex_wb_pipe_i.csr_en && instr_valid;

  // Combine all CSR read error outputs
  assign csr_err_o = mscratch_rd_error ||
    mstatus_rd_error ||
    mtvec_rd_error ||
    pmp_rd_error ||
    cpuctrl_rd_error ||
    dcsr_rd_error ||
    mie_rd_error ||
    mepc_rd_error ||
    mtvt_rd_error ||
    mintstatus_rd_error ||
    mintthresh_rd_error ||
    jvt_rd_error ||
    priv_lvl_rd_error ||
    mstateen0_rd_error ||
    mcause_rd_error;

  ////////////////////////////////////////
  // Determine if CSR access is illegal //
  // Both read and write validity is    //
  // checked in the first (EX) stage    //
  // Invalid writes will suppress ex_wb //
  // signals and avoid writing in WB    //
  ////////////////////////////////////////

  // Bits [9:8] in csr_addr indicate priviledge level needed to access CSR's.
  // The exception is access to perfomance counters from user mode, which is configured through mcounteren.
  assign illegal_csr_write_priv =  csr_raddr[9:8] > id_ex_pipe_i.priv_lvl;
  assign illegal_csr_read_priv  = (csr_raddr[9:8] > id_ex_pipe_i.priv_lvl);

  assign illegal_csr_write = (id_ex_pipe_i.csr_op != CSR_OP_READ) &&
                             (id_ex_pipe_i.csr_en) &&
                             ((csr_raddr[11:10] == 2'b11) || illegal_csr_write_priv); // Priv spec section 2.1

  // Any access to JVT is only legal from machine mode, or from user mode when mstateen[2] is 1.
  assign illegal_jvt_access = ((csr_raddr == CSR_JVT) && ((id_ex_pipe_i.priv_lvl < PRIV_LVL_M) && !mstateen0_rdata[2]));

  assign csr_illegal_o = (id_ex_pipe_i.instr_valid && id_ex_pipe_i.csr_en) ? illegal_csr_write || illegal_csr_read || illegal_csr_read_priv || illegal_jvt_access : 1'b0;


  ////////////////////////////////////////////
  //   ____ ____  ____    ____              //
  //  / ___/ ___||  _ \  |  _ \ ___  __ _   //
  // | |   \___ \| |_) | | |_) / _ \/ _` |  //
  // | |___ ___) |  _ <  |  _ <  __/ (_| |  //
  //  \____|____/|_| \_\ |_| \_\___|\__, |  //
  //                                |___/   //
  ////////////////////////////////////////////


  ////////////////////////////////////////////
  // CSR read logic

  always_comb
  begin
    illegal_csr_read    = 1'b0;
    csr_counter_read_o  = 1'b0;
    csr_mnxti_read_o    = 1'b0;
    csr_hz_o.impl_re_ex = 1'b0;
    csr_hz_o.impl_wr_ex = 1'b0;

    case (csr_raddr)
      // jvt: Jump vector table
      CSR_JVT:  begin
        if (ZC_EXT) begin
          csr_rdata_int = jvt_rdata;
        end else begin
          csr_rdata_int    = '0;
          illegal_csr_read = 1'b1;
        end
      end

      // mstatus
      CSR_MSTATUS: begin
        csr_rdata_int = mstatus_rdata;
        if (CLIC) begin
          csr_hz_o.impl_wr_ex = 1'b1; // Writes to mcause as well
        end
      end

      // misa
      CSR_MISA: csr_rdata_int = misa_rdata;

      // mie: machine interrupt enable
      CSR_MIE: begin
        csr_rdata_int = mie_rdata;
      end

      // mtvec: machine trap-handler base address
      CSR_MTVEC: csr_rdata_int = mtvec_rdata;

      // mcounteren: machine counter enable
      CSR_MCOUNTEREN: begin
        if (USER) begin
          csr_rdata_int = mcounteren_rdata;
        end else begin
          csr_rdata_int    = '0;
          illegal_csr_read = 1'b1;
        end
      end

      // mtvt: machine trap-handler vector table base address
      CSR_MTVT: begin
        if (CLIC) begin
          csr_rdata_int = mtvt_rdata;
        end else begin
          csr_rdata_int    = '0;
          illegal_csr_read = 1'b1;
        end
      end

      // mstatush
      CSR_MSTATUSH: csr_rdata_int = mstatush_rdata;

      CSR_MCOUNTINHIBIT: csr_rdata_int = mcountinhibit_rdata;

      CSR_MHPMEVENT3,
      CSR_MHPMEVENT4,  CSR_MHPMEVENT5,  CSR_MHPMEVENT6,  CSR_MHPMEVENT7,
      CSR_MHPMEVENT8,  CSR_MHPMEVENT9,  CSR_MHPMEVENT10, CSR_MHPMEVENT11,
      CSR_MHPMEVENT12, CSR_MHPMEVENT13, CSR_MHPMEVENT14, CSR_MHPMEVENT15,
      CSR_MHPMEVENT16, CSR_MHPMEVENT17, CSR_MHPMEVENT18, CSR_MHPMEVENT19,
      CSR_MHPMEVENT20, CSR_MHPMEVENT21, CSR_MHPMEVENT22, CSR_MHPMEVENT23,
      CSR_MHPMEVENT24, CSR_MHPMEVENT25, CSR_MHPMEVENT26, CSR_MHPMEVENT27,
      CSR_MHPMEVENT28, CSR_MHPMEVENT29, CSR_MHPMEVENT30, CSR_MHPMEVENT31:
        csr_rdata_int = mhpmevent_rdata[csr_raddr[4:0]];

      // mscratch: machine scratch
      CSR_MSCRATCH: csr_rdata_int = mscratch_rdata;

      // mepc: exception program counter
      CSR_MEPC: csr_rdata_int = mepc_rdata;

      // mcause: exception cause
      CSR_MCAUSE: begin
        csr_rdata_int = mcause_rdata;
        if (CLIC) begin
          csr_hz_o.impl_wr_ex = 1'b1; // Writes to mstatus as well
        end
      end

      // mtval
      CSR_MTVAL: csr_rdata_int = mtval_rdata;

      // mip: interrupt pending
      CSR_MIP: csr_rdata_int = mip_rdata;

      // mnxti: Next Interrupt Handler Address and Interrupt Enable
      CSR_MNXTI: begin
        if (CLIC) begin
          // The data read here is what will be used in the read-modify-write portion of the CSR access.
          // For mnxti, this is actually mstatus. The value written back to the GPR will be the address of
          // the function pointer to the interrupt handler. This is muxed in the WB stage.
          csr_rdata_int = mstatus_rdata;
          csr_hz_o.impl_re_ex = 1'b1; // Reads mstatus
          csr_hz_o.impl_wr_ex = 1'b1; // Writes mstatus, mcause and mintstatus
          csr_mnxti_read_o = 1'b1;
        end else begin
          csr_rdata_int    = '0;
          illegal_csr_read = 1'b1;
        end
      end

      // mintstatus: Interrupt Status
      CSR_MINTSTATUS: begin
        if (CLIC) begin
          csr_rdata_int = mintstatus_rdata;
        end else begin
          csr_rdata_int    = '0;
          illegal_csr_read = 1'b1;
        end
      end

      // mintthresh: Interrupt-Level Threshold
      CSR_MINTTHRESH: begin
        if (CLIC) begin
          csr_rdata_int = mintthresh_rdata;
        end else begin
          csr_rdata_int    = '0;
          illegal_csr_read = 1'b1;
        end
      end

      // mscratchcsw: Scratch Swap for Multiple Privilege Modes
      CSR_MSCRATCHCSW: begin
        if (CLIC && USER) begin
          // CLIC spec 13.2
          // Depending on mstatus.MPP, we return either mscratch_rdata or rs1 to rd.
          // Safe to use mstatus_rdata here (EX timing), as there is a generic stall of the ID stage
          // whenever a CSR instruction follows another CSR instruction. Alternative implementation using
          // a local forward of mstatus_rdata is identical (SEC).
          csr_hz_o.impl_re_ex = 1'b1; // Reads mstatus and mscratch
          csr_hz_o.impl_wr_ex = 1'b1; // Writes mscratch
          if (mstatus_rdata.mpp != PRIV_LVL_M) begin
            // Return mscratch for writing to GPR
            csr_rdata_int = mscratch_rdata;
          end else begin
            // return rs1 for writing to GPR
            csr_rdata_int = id_ex_pipe_i.alu_operand_a;
          end
        end else begin
          csr_rdata_int    = '0;
          illegal_csr_read = 1'b1;
        end
      end

      // mscratchcswl: Scratch Swap for Interrupt Levels
      CSR_MSCRATCHCSWL: begin
        if (CLIC) begin
          // CLIC spec 14.1
          // Depending on mcause.pil and mintstatus.mil, either mscratch or rs1 is returned to rd.
          // Safe to use mcause_rdata and mintstatus_rdata here (EX timing), as there is a generic stall of the ID stage
          // whenever a CSR instruction follows another CSR instruction. Alternative implementation using
          // a local forward of mcause_rdata and mintstatus_rdata is identical (SEC).
          csr_hz_o.impl_re_ex = 1'b1; // Reads mscratch, mcause and mintstatus
          csr_hz_o.impl_wr_ex = 1'b1; // Writes mscratch
          if ((mcause_rdata.mpil == '0) != (mintstatus_rdata.mil == 0)) begin
            // Return mscratch for writing to GPR
            csr_rdata_int = mscratch_rdata;
          end else begin
            // return rs1 for writing to GPR
            csr_rdata_int = id_ex_pipe_i.alu_operand_a;
          end
        end else begin
          csr_rdata_int    = '0;
          illegal_csr_read = 1'b1;
        end
      end

      CSR_TSELECT: begin
        if (DBG_NUM_TRIGGERS > 0) begin
          csr_rdata_int = tselect_rdata;
          csr_hz_o.impl_wr_ex = 1'b1; // Changing tselect may change tdata1 and tdata2 as well
        end else begin
          csr_rdata_int = '0;
          illegal_csr_read = 1'b1;
        end
      end

      CSR_TDATA1: begin
        if (DBG_NUM_TRIGGERS > 0) begin
          csr_rdata_int = tdata1_rdata;
        end else begin
          csr_rdata_int = '0;
          illegal_csr_read = 1'b1;
        end
      end

      CSR_TDATA2: begin
        if (DBG_NUM_TRIGGERS > 0) begin
          csr_rdata_int = tdata2_rdata;
        end else begin
          csr_rdata_int = '0;
          illegal_csr_read = 1'b1;
        end
      end

      CSR_TINFO: begin
        if (DBG_NUM_TRIGGERS > 0) begin
          csr_rdata_int = tinfo_rdata;
        end else begin
          csr_rdata_int = '0;
          illegal_csr_read = 1'b1;
        end
      end

      CSR_DCSR: begin
        if (DEBUG) begin
          csr_rdata_int = dcsr_rdata;
          illegal_csr_read = !ctrl_fsm_i.debug_mode;
        end else begin
          csr_rdata_int    = '0;
          illegal_csr_read = 1'b1;
        end
      end

      CSR_DPC: begin
        if (DEBUG) begin
          csr_rdata_int = dpc_rdata;
          illegal_csr_read = !ctrl_fsm_i.debug_mode;
        end else begin
          csr_rdata_int    = '0;
          illegal_csr_read = 1'b1;
        end
      end

      CSR_DSCRATCH0: begin
        if (DEBUG) begin
          csr_rdata_int = dscratch0_rdata;
          illegal_csr_read = !ctrl_fsm_i.debug_mode;
        end else begin
          csr_rdata_int    = '0;
          illegal_csr_read = 1'b1;
        end
      end

      CSR_DSCRATCH1: begin
        if (DEBUG) begin
          csr_rdata_int = dscratch1_rdata;
          illegal_csr_read = !ctrl_fsm_i.debug_mode;
        end else begin
          csr_rdata_int    = '0;
          illegal_csr_read = 1'b1;
        end
      end

      // Hardware Performance Monitor
      CSR_MCYCLE,
      CSR_MINSTRET,
      CSR_MHPMCOUNTER3,
      CSR_MHPMCOUNTER4,  CSR_MHPMCOUNTER5,  CSR_MHPMCOUNTER6,  CSR_MHPMCOUNTER7,
      CSR_MHPMCOUNTER8,  CSR_MHPMCOUNTER9,  CSR_MHPMCOUNTER10, CSR_MHPMCOUNTER11,
      CSR_MHPMCOUNTER12, CSR_MHPMCOUNTER13, CSR_MHPMCOUNTER14, CSR_MHPMCOUNTER15,
      CSR_MHPMCOUNTER16, CSR_MHPMCOUNTER17, CSR_MHPMCOUNTER18, CSR_MHPMCOUNTER19,
      CSR_MHPMCOUNTER20, CSR_MHPMCOUNTER21, CSR_MHPMCOUNTER22, CSR_MHPMCOUNTER23,
      CSR_MHPMCOUNTER24, CSR_MHPMCOUNTER25, CSR_MHPMCOUNTER26, CSR_MHPMCOUNTER27,
      CSR_MHPMCOUNTER28, CSR_MHPMCOUNTER29, CSR_MHPMCOUNTER30, CSR_MHPMCOUNTER31: begin
        csr_rdata_int = mhpmcounter_rdata[csr_raddr[4:0]][31:0];
        csr_counter_read_o = 1'b1;
      end

      CSR_MCYCLEH,
      CSR_MINSTRETH,
      CSR_MHPMCOUNTER3H,
      CSR_MHPMCOUNTER4H,  CSR_MHPMCOUNTER5H,  CSR_MHPMCOUNTER6H,  CSR_MHPMCOUNTER7H,
      CSR_MHPMCOUNTER8H,  CSR_MHPMCOUNTER9H,  CSR_MHPMCOUNTER10H, CSR_MHPMCOUNTER11H,
      CSR_MHPMCOUNTER12H, CSR_MHPMCOUNTER13H, CSR_MHPMCOUNTER14H, CSR_MHPMCOUNTER15H,
      CSR_MHPMCOUNTER16H, CSR_MHPMCOUNTER17H, CSR_MHPMCOUNTER18H, CSR_MHPMCOUNTER19H,
      CSR_MHPMCOUNTER20H, CSR_MHPMCOUNTER21H, CSR_MHPMCOUNTER22H, CSR_MHPMCOUNTER23H,
      CSR_MHPMCOUNTER24H, CSR_MHPMCOUNTER25H, CSR_MHPMCOUNTER26H, CSR_MHPMCOUNTER27H,
      CSR_MHPMCOUNTER28H, CSR_MHPMCOUNTER29H, CSR_MHPMCOUNTER30H, CSR_MHPMCOUNTER31H: begin
        csr_rdata_int = mhpmcounter_rdata[csr_raddr[4:0]][63:32];
        csr_counter_read_o = 1'b1;
      end

      // mvendorid: Machine Vendor ID
      CSR_MVENDORID: csr_rdata_int = mvendorid_rdata;

      // marchid: Machine Architecture ID
      CSR_MARCHID: csr_rdata_int = marchid_rdata;

      // mimpid: implementation id
      CSR_MIMPID: csr_rdata_int = mimpid_rdata;

      // mhartid: unique hardware thread id
      CSR_MHARTID: csr_rdata_int = mhartid_rdata;

      // mconfigptr: Pointer to configuration data structure
      CSR_MCONFIGPTR: csr_rdata_int = mconfigptr_rdata;

      CSR_PMPCFG0, CSR_PMPCFG1, CSR_PMPCFG2,  CSR_PMPCFG3,  CSR_PMPCFG4,  CSR_PMPCFG5,  CSR_PMPCFG6,  CSR_PMPCFG7,
      CSR_PMPCFG8, CSR_PMPCFG9, CSR_PMPCFG10, CSR_PMPCFG11, CSR_PMPCFG12, CSR_PMPCFG13, CSR_PMPCFG14, CSR_PMPCFG15: begin
       if (PMP) begin
          csr_rdata_int = {pmpncfg_rdata[6'(csr_raddr[3:0]*4 + 3)], pmpncfg_rdata[6'(csr_raddr[3:0]*4 + 2)],
            pmpncfg_rdata[6'(csr_raddr[3:0]*4 + 1)], pmpncfg_rdata[6'(csr_raddr[3:0]*4 + 0)]};
         end else begin
          csr_rdata_int    = '0;
          illegal_csr_read = 1'b1;
        end
      end

      CSR_PMPADDR0,  CSR_PMPADDR1,  CSR_PMPADDR2,  CSR_PMPADDR3,  CSR_PMPADDR4,  CSR_PMPADDR5,  CSR_PMPADDR6,  CSR_PMPADDR7,
      CSR_PMPADDR8,  CSR_PMPADDR9,  CSR_PMPADDR10, CSR_PMPADDR11, CSR_PMPADDR12, CSR_PMPADDR13, CSR_PMPADDR14, CSR_PMPADDR15: begin
        if (PMP) begin
          csr_rdata_int = pmp_addr_rdata[6'(16*0 + csr_raddr[3:0])];
        end else begin
          csr_rdata_int    = '0;
          illegal_csr_read = 1'b1;
        end
      end

      CSR_PMPADDR16, CSR_PMPADDR17, CSR_PMPADDR18, CSR_PMPADDR19, CSR_PMPADDR20, CSR_PMPADDR21, CSR_PMPADDR22, CSR_PMPADDR23,
      CSR_PMPADDR24, CSR_PMPADDR25, CSR_PMPADDR26, CSR_PMPADDR27, CSR_PMPADDR28, CSR_PMPADDR29, CSR_PMPADDR30, CSR_PMPADDR31: begin
        if (PMP) begin
          csr_rdata_int = pmp_addr_rdata[6'(16*1 + csr_raddr[3:0])];
        end else begin
          csr_rdata_int    = '0;
          illegal_csr_read = 1'b1;
        end
      end

      CSR_PMPADDR32, CSR_PMPADDR33, CSR_PMPADDR34, CSR_PMPADDR35, CSR_PMPADDR36, CSR_PMPADDR37, CSR_PMPADDR38, CSR_PMPADDR39,
      CSR_PMPADDR40, CSR_PMPADDR41, CSR_PMPADDR42, CSR_PMPADDR43, CSR_PMPADDR44, CSR_PMPADDR45, CSR_PMPADDR46, CSR_PMPADDR47: begin
        if (PMP) begin
          csr_rdata_int = pmp_addr_rdata[6'(16*2 + csr_raddr[3:0])];
        end else begin
          csr_rdata_int    = '0;
          illegal_csr_read = 1'b1;
        end
      end

      CSR_PMPADDR48, CSR_PMPADDR49, CSR_PMPADDR50, CSR_PMPADDR51, CSR_PMPADDR52, CSR_PMPADDR53, CSR_PMPADDR54, CSR_PMPADDR55,
      CSR_PMPADDR56, CSR_PMPADDR57, CSR_PMPADDR58, CSR_PMPADDR59, CSR_PMPADDR60, CSR_PMPADDR61, CSR_PMPADDR62, CSR_PMPADDR63: begin
        if (PMP) begin
          csr_rdata_int =  pmp_addr_rdata[6'(16*3 + csr_raddr[3:0])];
        end else begin
          csr_rdata_int    = '0;
          illegal_csr_read = 1'b1;
        end
      end

      CSR_MSECCFG: begin
        if (PMP) begin
          csr_rdata_int = pmp_mseccfg_rdata;
        end else begin
          csr_rdata_int    = '0;
          illegal_csr_read = 1'b1;
        end
      end

      CSR_MSECCFGH: begin
        if (PMP) begin
          csr_rdata_int = pmp_mseccfgh_rdata;
        end else begin
          csr_rdata_int    = '0;
          illegal_csr_read = 1'b1;
        end
      end

      CSR_MENVCFG: begin
        if (USER) begin
          csr_rdata_int = menvcfg_rdata;
        end else begin
          csr_rdata_int    = '0;
          illegal_csr_read = 1'b1;
        end
      end

      CSR_MENVCFGH: begin
        if (USER) begin
          csr_rdata_int = menvcfgh_rdata;
        end else begin
          csr_rdata_int    = '0;
          illegal_csr_read = 1'b1;
        end
      end

      CSR_SECURESEED0: begin
        if (SECURE) begin
          csr_rdata_int = secureseed0_rdata;
        end else begin
          // Cause illegal CSR access
          csr_rdata_int    = '0;
          illegal_csr_read = 1'b1;
        end
      end

      CSR_SECURESEED1: begin
        if (SECURE) begin
          csr_rdata_int = secureseed1_rdata;
        end else begin
          csr_rdata_int    = '0;
          illegal_csr_read = 1'b1;
        end
      end

      CSR_SECURESEED2: begin
        if (SECURE) begin
          csr_rdata_int = secureseed2_rdata;
        end else begin
          csr_rdata_int    = '0;
          illegal_csr_read = 1'b1;
        end
      end

      CSR_CPUCTRL: begin
        if (SECURE) begin
          csr_rdata_int = cpuctrl_rdata;
        end else begin
          csr_rdata_int    = '0;
          illegal_csr_read = 1'b1;
        end
      end

      CSR_MSTATEEN0: begin
        if (USER) begin
          csr_rdata_int = mstateen0_rdata;
        end else begin
          csr_rdata_int    = '0;
          illegal_csr_read = 1'b1;
        end
      end

      CSR_MSTATEEN1: begin
        if (USER) begin
          csr_rdata_int = mstateen1_rdata;
        end else begin
          csr_rdata_int    = '0;
          illegal_csr_read = 1'b1;
        end
      end

      CSR_MSTATEEN2: begin
        if (USER) begin
          csr_rdata_int = mstateen2_rdata;
        end else begin
          csr_rdata_int    = '0;
          illegal_csr_read = 1'b1;
        end
      end

      CSR_MSTATEEN3: begin
        if (USER) begin
          csr_rdata_int = mstateen3_rdata;
        end else begin
          csr_rdata_int    = '0;
          illegal_csr_read = 1'b1;
        end
      end

      CSR_MSTATEEN0H: begin
        if (USER) begin
          csr_rdata_int = mstateen0h_rdata;
        end else begin
          csr_rdata_int    = '0;
          illegal_csr_read = 1'b1;
        end
      end

      CSR_MSTATEEN1H: begin
        if (USER) begin
          csr_rdata_int = mstateen1h_rdata;
        end else begin
          csr_rdata_int    = '0;
          illegal_csr_read = 1'b1;
        end
      end

      CSR_MSTATEEN2H: begin
        if (USER) begin
          csr_rdata_int = mstateen2h_rdata;
        end else begin
          csr_rdata_int    = '0;
          illegal_csr_read = 1'b1;
        end
      end

      CSR_MSTATEEN3H: begin
        if (USER) begin
          csr_rdata_int = mstateen3h_rdata;
        end else begin
          csr_rdata_int    = '0;
          illegal_csr_read = 1'b1;
        end
      end

      default: begin
        csr_rdata_int    = '0;
        illegal_csr_read = 1'b1;
      end
    endcase
  end

  ////////////////////////////////////////////
  // CSR write logic

  always_comb
  begin

    jvt_n         = csr_next_value(csr_wdata_int, CSR_JVT_MASK, JVT_RESET_VAL);
    jvt_we        = 1'b0;

    mscratch_n    = csr_next_value(csr_wdata_int, CSR_MSCRATCH_MASK, MSCRATCH_RESET_VAL);
    mscratch_we   = 1'b0;

    mepc_n        = csr_next_value(csr_wdata_int, CSR_MEPC_MASK, MEPC_RESET_VAL);
    mepc_we       = 1'b0;

    dpc_n         = csr_next_value(csr_wdata_int, CSR_DPC_MASK, DPC_RESET_VAL);
    dpc_we        = 1'b0;

    dcsr_n        = csr_next_value(dcsr_t'{
                                            xdebugver : dcsr_rdata.xdebugver,
                                            ebreakm   : csr_wdata_int[15],
                                            ebreaku   : dcsr_ebreaku_resolve(dcsr_rdata.ebreaku, csr_wdata_int[DCSR_EBREAKU_BIT]),
                                            stepie    : csr_wdata_int[11],
                                            stopcount : csr_wdata_int[10],
                                            mprven    : dcsr_rdata.mprven,
                                            step      : csr_wdata_int[2],
                                            prv       : dcsr_prv_resolve(dcsr_rdata.prv, csr_wdata_int[DCSR_PRV_BIT_HIGH:DCSR_PRV_BIT_LOW]),
                                            cause     : dcsr_rdata.cause,
                                            default   : 'd0
                                          },
                                    CSR_DCSR_MASK, DCSR_RESET_VAL);
    dcsr_we       = 1'b0;

    dscratch0_n   = csr_next_value(csr_wdata_int, CSR_DSCRATCH0_MASK, DSCRATCH0_RESET_VAL);
    dscratch0_we  = 1'b0;

    dscratch1_n   = csr_next_value(csr_wdata_int, CSR_DSCRATCH1_MASK, DSCRATCH1_RESET_VAL);
    dscratch1_we  = 1'b0;

    tselect_we    = 1'b0;

    tdata1_we     = 1'b0;

    tdata2_we     = 1'b0;

    tinfo_we      = 1'b0;

    mstatus_n     = csr_next_value(mstatus_t'{
                                              tw:   mstatus_tw_resolve(mstatus_rdata.tw, csr_wdata_int[MSTATUS_TW_BIT]),
                                              mprv: mstatus_mprv_resolve(mstatus_rdata.mprv, csr_wdata_int[MSTATUS_MPRV_BIT]),
                                              mpp:  mstatus_mpp_resolve(mstatus_rdata.mpp, csr_wdata_int[MSTATUS_MPP_BIT_HIGH:MSTATUS_MPP_BIT_LOW]),
                                              mpie: csr_wdata_int[MSTATUS_MPIE_BIT],
                                              mie:  csr_wdata_int[MSTATUS_MIE_BIT],
                                              default: 'b0
                                            },
                                  CSR_MSTATUS_MASK, MSTATUS_RESET_VAL);
    mstatus_we    = 1'b0;

    mstatush_n    = mstatush_rdata; // Read only
    mstatush_we   = 1'b0;
    mstatus_alias_we = 1'b0;

    misa_n        = misa_rdata; // Read only
    misa_we       = 1'b0;

    priv_lvl_n    = priv_lvl_rdata;
    priv_lvl_we   = 1'b0;

    if (CLIC) begin
      mtvec_n       = csr_next_value(mtvec_t'{
                                              addr:    csr_mtvec_init_i ? mtvec_addr_i[31:7] : csr_wdata_int[31:7],
                                              zero0:   mtvec_rdata.zero0,
                                              submode: mtvec_rdata.submode,
                                              mode:    csr_mtvec_init_i ? mtvec_rdata.mode : mtvec_mode_clic_resolve(mtvec_rdata.mode, csr_wdata_int[MTVEC_MODE_BIT_HIGH:MTVEC_MODE_BIT_LOW])
                                            },
                                      CSR_CLIC_MTVEC_MASK, MTVEC_CLIC_RESET_VAL);
      mtvec_we        = csr_mtvec_init_i;

      mtvt_n                   = csr_next_value({csr_wdata_int[31:(32-MTVT_ADDR_WIDTH)], {(32-MTVT_ADDR_WIDTH){1'b0}}}, CSR_MTVT_MASK, MTVT_RESET_VAL);
      mtvt_we                  = 1'b0;

      mnxti_we                 = 1'b0;

      mintstatus_n             = mintstatus_rdata; // Read only
      mintstatus_we            = 1'b0;

      mintthresh_n             = csr_next_value(csr_wdata_int, CSR_MINTTHRESH_MASK, MINTTHRESH_RESET_VAL);
      mintthresh_we            = 1'b0;

      mscratchcsw_n            = mscratch_n; // mscratchcsw operates conditionally on mscratch
      mscratchcsw_we           = 1'b0;

      mscratchcswl_n           = mscratch_n; // mscratchcsw operates conditionally on mscratch
      mscratchcswl_we          = 1'b0;

      mie_n                    = '0;
      mie_we                   = 1'b0;

      mip_n                    = mip_rdata; // Read only;
      mip_we                   = 1'b0;

      mcause_n                 = csr_next_value(mcause_t'{
                                                          irq:            csr_wdata_int[31],
                                                          minhv:          csr_wdata_int[30],
                                                          mpp:            mcause_mpp_resolve(mcause_rdata.mpp, csr_wdata_int[MCAUSE_MPP_BIT_HIGH:MCAUSE_MPP_BIT_LOW]),
                                                          mpie:           csr_wdata_int[MCAUSE_MPIE_BIT],
                                                          mpil:           csr_wdata_int[23:16],
                                                          exception_code: csr_wdata_int[10:0],
                                                          default:        'b0
                                                        },
                                                CSR_CLIC_MCAUSE_MASK, MCAUSE_CLIC_RESET_VAL);
      mcause_we                = 1'b0;
      mcause_alias_we          = 1'b0;
    end else begin // !CLIC
      mtvec_n                  = csr_next_value(mtvec_t'{
                                                        addr:    csr_mtvec_init_i ? mtvec_addr_i[31:7] : csr_wdata_int[31:7],
                                                        zero0:   mtvec_rdata.zero0,
                                                        submode: mtvec_rdata.submode,
                                                        mode:    csr_mtvec_init_i ? mtvec_rdata.mode : mtvec_mode_clint_resolve(mtvec_rdata.mode, csr_wdata_int[MTVEC_MODE_BIT_HIGH:MTVEC_MODE_BIT_LOW])
                                                      },
                                                CSR_BASIC_MTVEC_MASK, MTVEC_BASIC_RESET_VAL);
      mtvec_we                 = csr_mtvec_init_i;

      mtvt_n                   = '0;
      mtvt_we                  = 1'b0;

      mnxti_we                 = 1'b0;

      mintstatus_n             = '0;
      mintstatus_we            = 1'b0;

      mintthresh_n             = '0;
      mintthresh_we            = 1'b0;

      mscratchcsw_n            = '0;
      mscratchcsw_we           = 1'b0;

      mscratchcswl_n           = '0;
      mscratchcswl_we          = 1'b0;

      mie_n                    = csr_next_value(csr_wdata_int, IRQ_MASK, MIE_BASIC_RESET_VAL);
      mie_we                   = 1'b0;

      mip_n                    = mip_rdata; // Read only;
      mip_we                   = 1'b0;

      mcause_n                 = csr_next_value(mcause_t'{
                                                          irq:            csr_wdata_int[31],
                                                          exception_code: csr_wdata_int[10:0],
                                                          default:        'b0
                                                        },
                                                        CSR_BASIC_MCAUSE_MASK, MCAUSE_BASIC_RESET_VAL);
      mcause_we                = 1'b0;
      mcause_alias_we          = 1'b0;
    end

    pmpncfg_we      = {PMP_MAX_REGIONS{1'b0}};
    pmp_addr_we     = {PMP_MAX_REGIONS{1'b0}};
    pmp_mseccfg_we  = 1'b0;

    pmp_mseccfgh_n  = pmp_mseccfgh_rdata;         // Read-only
    pmp_mseccfgh_we = 1'b0;                       // Always 0

    mcounteren_n    = mcounteren_rdata;           // Read-only
    mcounteren_we   = 1'b0;

    menvcfg_n       = menvcfg_rdata;              // Read-only
    menvcfg_we      = 1'b0;

    menvcfgh_n      = menvcfgh_rdata;             // Read-only
    menvcfgh_we     = 1'b0;

    cpuctrl_n       = csr_next_value(csr_wdata_int, CSR_CPUCTRL_MASK, CPUCTRL_RESET_VAL);
    cpuctrl_we      = 1'b0;

    secureseed0_n   = secureseed0_rdata;          // Read-only (LFSR write uses csr_wdata_int directly)
    secureseed0_we  = 1'b0;

    secureseed1_n   = secureseed1_rdata;          // Read-only (LFSR write uses csr_wdata_int directly)
    secureseed1_we  = 1'b0;

    secureseed2_n   = secureseed2_rdata;          // Read-only (LFSR write uses csr_wdata_int directly)
    secureseed2_we  = 1'b0;

    mtval_n         = mtval_rdata;                // Read-only
    mtval_we        = 1'b0;

    // Read-only CSRS
    mhartid_n       = mhartid_rdata;              // Read-only
    mhartid_we      = 1'b0;                       // Always 0

    mimpid_n        = mimpid_rdata;               // Read-only
    mimpid_we       = 1'b0;                       // Always 0

    mconfigptr_n    = mconfigptr_rdata;           // Read-only
    mconfigptr_we   = 1'b0;                       // Always 0

    mvendorid_n     = mvendorid_rdata;            // Read-only
    mvendorid_we    = 1'b0;                       // Always 0

    marchid_n       = marchid_rdata;              // Read-only
    marchid_we      = 1'b0;                       // Always 0

    mstateen0_n     = csr_next_value(csr_wdata_int, CSR_MSTATEEN0_MASK, MSTATEEN0_RESET_VAL);
    mstateen0_we    = 1'b0;

    mstateen1_n     = mstateen1_rdata;            // Read-only
    mstateen1_we    = 1'b0;                       // Always 0

    mstateen2_n     = mstateen2_rdata;            // Read-only
    mstateen2_we    = 1'b0;                       // Always 0

    mstateen3_n     = mstateen3_rdata;            // Read-only
    mstateen3_we    = 1'b0;                       // Always 0

    mstateen0h_n    = mstateen0h_rdata;           // Read-only
    mstateen0h_we   = 1'b0;                       // Always 0

    mstateen1h_n    = mstateen1h_rdata;            // Read-only
    mstateen1h_we   = 1'b0;                       // Always 0

    mstateen2h_n    = mstateen2h_rdata;            // Read-only
    mstateen2h_we   = 1'b0;                       // Always 0

    mstateen3h_n    = mstateen3_rdata;            // Read-only
    mstateen3h_we   = 1'b0;                       // Always 0

    if (csr_we_int) begin
      case (csr_waddr)

        // jvt: Jump vector table
        CSR_JVT: begin
          if (ZC_EXT) begin
            jvt_we = 1'b1;
          end
        end

        // mstatus
        CSR_MSTATUS: begin
          mstatus_we = 1'b1;
          // CLIC mode is assumed when CLIC = 1
          // For CLIC, a write to mstatus.mpp or mstatus.mpie will write to the
          // corresponding bits in mstatus as well.
          if (CLIC) begin
            mcause_alias_we = 1'b1;
          end
        end

        CSR_MISA: begin
          misa_we = 1'b1;
        end

        // mie: machine interrupt enable
        CSR_MIE: begin
          mie_we = 1'b1;
        end

        // mtvec: machine trap-handler base address
        CSR_MTVEC: begin
          mtvec_we = 1'b1;
        end

        // mcounteren: counter enable
        CSR_MCOUNTEREN: begin
          if (USER) begin
            mcounteren_we = 1'b1;
          end
        end

        // mtvt: machine trap-handler vector table base address
        CSR_MTVT: begin
          if (CLIC) begin
            mtvt_we = 1'b1;
          end
        end

        CSR_MSTATUSH: begin
          mstatush_we = 1'b1;
        end

        // mscratch: machine scratch
        CSR_MSCRATCH: begin
          mscratch_we = 1'b1;
        end

        // mepc: exception program counter
        CSR_MEPC: begin
          mepc_we = 1'b1;
        end

        // mcause
        CSR_MCAUSE: begin
          mcause_we = 1'b1;
          // CLIC mode is assumed when CLIC = 1
          // For CLIC, a write to mcause.mpp or mcause.mpie will write to the
          // corresponding bits in mstatus as well.
          if (CLIC) begin
            mstatus_alias_we = 1'b1;
          end
        end

        CSR_MTVAL: begin
          mtval_we = 1'b1;
        end

        // mip: machine interrupt pending
        CSR_MIP: begin
          mip_we = 1'b1;
        end

        CSR_MNXTI: begin
          if (CLIC) begin
            mnxti_we = 1'b1;

            // Writes to mnxti also writes to mstatus (uses mstatus in the RMW operation)
            // Also writing to mcause to ensure we can assert mstatus_we == mcause_we and similar for mpp/mpie.
            mstatus_we = 1'b1;
            mcause_we  = 1'b1;

            // Writes to mintstatus.mil and mcause depend on the current state of
            // clic interrupts AND the type of CSR instruction used.
            // Mcause is written unconditionally for aliasing purposes, but the mcause_n
            // is modified to reflect the side effects in case mnxti_irq_pending_i i set.
            // Side effects occur when there is an actual write to the mstatus CSR
            // This is already coded into the csr_we_int/mnxti_we
            if (mnxti_irq_pending_i) begin
              mintstatus_we = 1'b1;
            end
          end
        end

        CSR_MINTTHRESH: begin
          if (CLIC) begin
            mintthresh_we = 1'b1;
          end
        end

        CSR_MSCRATCHCSW: begin
          if (CLIC && USER) begin
            // mscratchcsw operates on mscratch
            // Writing only when mstatus.mpp != PRIV_LVL_M
            if (mstatus_rdata.mpp != PRIV_LVL_M) begin
              mscratchcsw_we = 1'b1;
              mscratch_we    = 1'b1;
            end
          end
        end

        CSR_MSCRATCHCSWL: begin
          if (CLIC) begin
            // mscratchcswl operates on mscratch
            if ((mcause_rdata.mpil == '0) != (mintstatus_rdata.mil == '0)) begin
              mscratchcswl_we = 1'b1;
              mscratch_we     = 1'b1;
            end
          end
        end

        CSR_TSELECT: begin
          tselect_we = 1'b1;
        end

        CSR_TDATA1: begin
          if (ctrl_fsm_i.debug_mode) begin
            tdata1_we = 1'b1;
          end
        end

        CSR_TDATA2: begin
          if (ctrl_fsm_i.debug_mode) begin
            tdata2_we = 1'b1;
          end
        end

        CSR_TINFO: begin
          tinfo_we = 1'b1;
        end

        CSR_DCSR: begin
          dcsr_we = 1'b1;
        end

        CSR_DPC: begin
          dpc_we = 1'b1;
        end

        CSR_DSCRATCH0: begin
          dscratch0_we = 1'b1;
        end

        CSR_DSCRATCH1: begin
           dscratch1_we = 1'b1;
        end
        CSR_PMPCFG0,  CSR_PMPCFG1,  CSR_PMPCFG2,  CSR_PMPCFG3,
        CSR_PMPCFG4,  CSR_PMPCFG5,  CSR_PMPCFG6,  CSR_PMPCFG7,
        CSR_PMPCFG8,  CSR_PMPCFG9,  CSR_PMPCFG10, CSR_PMPCFG11,
        CSR_PMPCFG12, CSR_PMPCFG13, CSR_PMPCFG14, CSR_PMPCFG15: begin
          if (PMP) begin
            pmpncfg_we[csr_waddr[3:0]*4+:4] = 4'hF;
          end
        end

        CSR_PMPADDR0,  CSR_PMPADDR1,  CSR_PMPADDR2,  CSR_PMPADDR3,
        CSR_PMPADDR4,  CSR_PMPADDR5,  CSR_PMPADDR6,  CSR_PMPADDR7,
        CSR_PMPADDR8,  CSR_PMPADDR9,  CSR_PMPADDR10, CSR_PMPADDR11,
        CSR_PMPADDR12, CSR_PMPADDR13, CSR_PMPADDR14, CSR_PMPADDR15: begin
          if (PMP) begin
            pmp_addr_we[6'(16*0 + csr_waddr[3:0])] = 1'b1;
          end
        end

        CSR_PMPADDR16, CSR_PMPADDR17, CSR_PMPADDR18, CSR_PMPADDR19,
        CSR_PMPADDR20, CSR_PMPADDR21, CSR_PMPADDR22, CSR_PMPADDR23,
        CSR_PMPADDR24, CSR_PMPADDR25, CSR_PMPADDR26, CSR_PMPADDR27,
        CSR_PMPADDR28, CSR_PMPADDR29, CSR_PMPADDR30, CSR_PMPADDR31: begin
          if (PMP) begin
            pmp_addr_we[6'(16*1 + csr_waddr[3:0])] = 1'b1;
          end
        end

        CSR_PMPADDR32, CSR_PMPADDR33, CSR_PMPADDR34, CSR_PMPADDR35,
        CSR_PMPADDR36, CSR_PMPADDR37, CSR_PMPADDR38, CSR_PMPADDR39,
        CSR_PMPADDR40, CSR_PMPADDR41, CSR_PMPADDR42, CSR_PMPADDR43,
        CSR_PMPADDR44, CSR_PMPADDR45, CSR_PMPADDR46, CSR_PMPADDR47: begin
          if (PMP) begin
            pmp_addr_we[6'(16*2 + csr_waddr[3:0])] = 1'b1;
          end
        end

        CSR_PMPADDR48, CSR_PMPADDR49, CSR_PMPADDR50, CSR_PMPADDR51,
        CSR_PMPADDR52, CSR_PMPADDR53, CSR_PMPADDR54, CSR_PMPADDR55,
        CSR_PMPADDR56, CSR_PMPADDR57, CSR_PMPADDR58, CSR_PMPADDR59,
        CSR_PMPADDR60, CSR_PMPADDR61, CSR_PMPADDR62, CSR_PMPADDR63: begin
          if (PMP) begin
            pmp_addr_we[6'(16*3 + csr_waddr[3:0])] = 1'b1;
          end
        end

        CSR_MSECCFG: begin
          if (PMP) begin
            pmp_mseccfg_we = 1'b1;
          end
        end

        CSR_MSECCFGH: begin
          if (PMP) begin
            pmp_mseccfgh_we = 1'b1;
          end
        end

        CSR_MENVCFG: begin
          if (USER) begin
            menvcfg_we = 1'b1;
          end
        end

        CSR_MENVCFGH: begin
          if (USER) begin
            menvcfgh_we = 1'b1;
          end
        end

        CSR_CPUCTRL: begin
          if (SECURE) begin
            cpuctrl_we = 1'b1;
          end
        end

        CSR_SECURESEED0: begin
          if (SECURE) begin
            secureseed0_we = 1'b1;
          end
        end

        CSR_SECURESEED1: begin
          if (SECURE) begin
            secureseed1_we = 1'b1;
          end
        end

        CSR_SECURESEED2: begin
          if (SECURE) begin
            secureseed2_we = 1'b1;
          end
        end

        CSR_MSTATEEN0: begin
          if (USER) begin
            mstateen0_we = 1'b1;
          end
        end

        CSR_MSTATEEN1: begin
          if (USER) begin
            mstateen1_we = 1'b1;
          end
        end

        CSR_MSTATEEN2: begin
          if (USER) begin
            mstateen2_we = 1'b1;
          end
        end

        CSR_MSTATEEN3: begin
          if (USER) begin
            mstateen3_we = 1'b1;
          end
        end

        CSR_MSTATEEN0H: begin
          if (USER) begin
            mstateen0h_we = 1'b1;
          end
        end

        CSR_MSTATEEN1H: begin
          if (USER) begin
            mstateen1h_we = 1'b1;
          end
        end

        CSR_MSTATEEN2H: begin
          if (USER) begin
            mstateen2h_we = 1'b1;
          end
        end

        CSR_MSTATEEN3H: begin
          if (USER) begin
            mstateen3h_we = 1'b1;
          end
        end
        default:;
      endcase
    end

    // CSR side effects from other CSRs

    // CLIC mode is assumed when CLIC = 1
    if (CLIC) begin
      if (mnxti_we) begin
        // Mstatus is written as part of an mnxti access
        // Make sure we alias the mpp/mpie to mcause
        mcause_n = mcause_rdata;
        mcause_n.mpie = mstatus_n.mpie;
        mcause_n.mpp = mstatus_n.mpp;

        // mintstatus and mcause are updated if an actual mstatus write happens and
        // a higher level non-shv interrupt is pending.
        // This is already decoded into the respective _we signals below.
        if (mintstatus_we) begin
          mintstatus_n.mil = mnxti_irq_level_i;
        end
        if (mnxti_irq_pending_i) begin
          mcause_n.irq = 1'b1;
          mcause_n.exception_code = {1'b0, 10'(mnxti_irq_id_i)};
        end
      end else if (mstatus_alias_we) begin
        // In CLIC mode, writes to mcause.mpp/mpie is aliased to mstatus.mpp/mpie
        // All other mstatus bits are preserved
        mstatus_n      = mstatus_rdata; // Preserve all fields

        // Write mpie and mpp as aliased through mcause
        mstatus_n.mpie = mcause_n.mpie;
        mstatus_n.mpp  = mcause_n.mpp;

        mstatus_we = 1'b1;
      end else if (mcause_alias_we) begin
        // In CLIC mode, writes to mstatus.mpp/mpie is aliased to mcause.mpp/mpie
        // All other mcause bits are preserved
        mcause_n = mcause_rdata;
        mcause_n.mpie = mstatus_n.mpie;
        mcause_n.mpp = mstatus_n.mpp;

        mcause_we = 1'b1;
      end
      // The CLIC pointer address should always be output for an access to MNXTI,
      // but will only contain a nonzero value if a CLIC interrupt is actually pending
      // with a higher level. The valid below will be high also for the cases where
      // no side effects occur.
      clic_pa_valid_o = csr_en_gated && (csr_waddr == CSR_MNXTI);
      clic_pa_o       = mnxti_rdata;
    end else begin
      clic_pa_valid_o = 1'b0;
      clic_pa_o       = '0;
    end

    // Exception controller gets priority over other writes
    unique case (1'b1)
      ctrl_fsm_i.csr_save_cause: begin
        if (ctrl_fsm_i.debug_csr_save) begin
          // All interrupts are masked, don't update mcause, mepc, mtval, dpc and mstatus
          // dcsr.nmip is not a flop, but comes directly from the controller
          dcsr_n         = dcsr_t'{
                                    xdebugver : dcsr_rdata.xdebugver,
                                    ebreakm   : dcsr_rdata.ebreakm,
                                    ebreaku   : dcsr_rdata.ebreaku,
                                    stepie    : dcsr_rdata.stepie,
                                    stopcount : dcsr_rdata.stopcount,
                                    mprven    : dcsr_rdata.mprven,
                                    step      : dcsr_rdata.step,
                                    prv       : priv_lvl_rdata,                 // Privilege level at time of debug entry
                                    cause     : ctrl_fsm_i.debug_cause,
                                    default   : 'd0
                                  };
          dcsr_we        = 1'b1;

          dpc_n          = ctrl_fsm_i.pipe_pc;
          dpc_we         = 1'b1;

          priv_lvl_n     = PRIV_LVL_M;  // Execute with machine mode privilege in debug mode
          priv_lvl_we    = 1'b1;
        end else begin
          priv_lvl_n     = PRIV_LVL_M;  // Trap into machine mode
          priv_lvl_we    = 1'b1;

          mstatus_n      = mstatus_rdata;
          mstatus_n.mie  = 1'b0;
          mstatus_n.mpie = mstatus_rdata.mie;
          mstatus_n.mpp  = priv_lvl_rdata;
          mstatus_we     = 1'b1;

          mepc_n         = ctrl_fsm_i.pipe_pc;
          mepc_we        = 1'b1;

          // Save relevant fields from controller to mcause
          mcause_n.irq            = ctrl_fsm_i.csr_cause.irq;
          mcause_n.exception_code = ctrl_fsm_i.csr_cause.exception_code;


          mcause_we = 1'b1;


          if (CLIC) begin
            // mpil is saved from mintstatus
            mcause_n.mpil = mintstatus_rdata.mil;

            // Save minhv from controller
            mcause_n.minhv          = ctrl_fsm_i.csr_cause.minhv;
            // Save aliased values for mpp and mpie
            mcause_n.mpp            = mstatus_n.mpp;
            mcause_n.mpie           = mstatus_n.mpie;

            // Save new interrupt level to mintstatus
            // Horizontal synchronous exception traps do not change the interrupt level.
            // Vertical synchronous exception traps to higher privilege level use interrupt level 0.
            // All exceptions are taken in PRIV_LVL_M, so checking that we get a different privilege level is sufficient for clearing
            // mintstatus.mil.
            if (ctrl_fsm_i.csr_cause.irq) begin
              mintstatus_n.mil = ctrl_fsm_i.irq_level;
              mintstatus_we = 1'b1;
            end else if ((priv_lvl_rdata != priv_lvl_n)) begin
              mintstatus_n.mil = '0;
              mintstatus_we = 1'b1;
            end
          end else begin
            mcause_n.mpil = '0;
          end
        end
      end //ctrl_fsm_i.csr_save_cause

      ctrl_fsm_i.csr_restore_mret,
      ctrl_fsm_i.csr_restore_mret_ptr: begin // MRET
        priv_lvl_n     = privlvl_t'(mstatus_rdata.mpp);
        priv_lvl_we    = 1'b1;

        mstatus_n      = mstatus_rdata;
        mstatus_n.mie  = mstatus_rdata.mpie;
        mstatus_n.mpie = 1'b1;
        mstatus_n.mpp  = PRIV_LVL_LOWEST;
        mstatus_n.mprv = (privlvl_t'(mstatus_rdata.mpp) == PRIV_LVL_M) ? mstatus_rdata.mprv : 1'b0;
        mstatus_we     = 1'b1;

        if (CLIC) begin
          mintstatus_n.mil = mcause_rdata.mpil;
          mintstatus_we = 1'b1;

          // Save aliased values for mpp and mpie
          mcause_n = mcause_rdata;
          mcause_n.mpp = mstatus_n.mpp;
          mcause_n.mpie = mstatus_n.mpie;
          mcause_we = 1'b1;

          // Mret to lower privilege mode clear mintthresh
          if (priv_lvl_n < PRIV_LVL_M) begin
            mintthresh_n  = 32'h00000000;
            mintthresh_we = 1'b1;
          end
        end
      end //ctrl_fsm_i.csr_restore_mret

      ctrl_fsm_i.csr_restore_dret: begin // DRET
        // Restore to the recorded privilege level
        priv_lvl_n = dcsr_rdata.prv;
        priv_lvl_we = 1'b1;

        // Section 4.6 of debug spec: If the new privilege mode is less privileged than M-mode, MPRV in mstatus is cleared.
        mstatus_n      = mstatus_rdata;
        mstatus_n.mprv = (privlvl_t'(dcsr_rdata.prv) == PRIV_LVL_M) ? mstatus_rdata.mprv : 1'b0;
        mstatus_we     = 1'b1;

        if (CLIC) begin
          // Not really needed, but allows for asserting mstatus_we == mcause_we to check aliasing formally
          mcause_n       = mcause_rdata;
          mcause_we      = 1'b1;

          // Dret to lower privilege mode does not clear mintthresh
        end

      end //ctrl_fsm_i.csr_restore_dret

      default:;
    endcase

  end

  // Mirroring mstatus_n to mnxti_n for RVFI
  assign mnxti_n = mstatus_n;

  // CSR operation logic
  // Using ex_wb_pipe_i.rf_wdata for read-modify-write since CSR was read in EX, written in WB
  always_comb
  begin
    if(!csr_en_gated) begin
      csr_wdata_int = csr_wdata;
      csr_we_int    = 1'b0;
    end else begin
      csr_we_int    = 1'b1;
      csr_wdata_int = csr_wdata;
      case (csr_op)
        CSR_OP_WRITE: csr_wdata_int = csr_wdata;
        CSR_OP_SET:   csr_wdata_int = csr_wdata | ex_wb_pipe_i.rf_wdata;
        CSR_OP_CLEAR: csr_wdata_int = (~csr_wdata) & ex_wb_pipe_i.rf_wdata;

        CSR_OP_READ: begin
          csr_wdata_int = csr_wdata;
          csr_we_int    = 1'b0;
        end
        default:;
      endcase
    end
  end

  ////////////////////////////////////////////////////////////////////////
  //
  // CSR instances

  cv32e40s_csr
  #(
    .LIB        (LIB),
    .WIDTH      (32),
    .MASK       (CSR_MSTATEEN0_MASK),
    .SHADOWCOPY (SECURE),
    .RESETVALUE (MSTATEEN0_RESET_VAL)
  )
  mstateen0_csr_i
  (
    .clk                ( clk                   ),
    .rst_n              ( rst_n                 ),
    .scan_cg_en_i       ( scan_cg_en_i          ),
    .wr_data_i          ( mstateen0_n           ),
    .wr_en_i            ( mstateen0_we          ),
    .rd_data_o          ( mstateen0_q           ),
    .rd_error_o         ( mstateen0_rd_error    )
  );

  cv32e40s_csr
  #(
    .LIB        (LIB),
    .WIDTH      (32),
    .MASK       (CSR_JVT_MASK),
    .SHADOWCOPY (SECURE),
    .RESETVALUE (JVT_RESET_VAL)
  )
  jvt_csr_i
  (
    .clk                ( clk                   ),
    .rst_n              ( rst_n                 ),
    .scan_cg_en_i       ( scan_cg_en_i          ),
    .wr_data_i          ( jvt_n                 ),
    .wr_en_i            ( jvt_we                ),
    .rd_data_o          ( jvt_q                 ),
    .rd_error_o         ( jvt_rd_error          )
  );

  generate
    if (DEBUG) begin : gen_debug_csr
      cv32e40s_csr
      #(
        .LIB        (LIB                ),
        .WIDTH      (32                 ),
        .SHADOWCOPY (1'b0               ),
        .MASK       (CSR_DSCRATCH0_MASK ),
        .RESETVALUE (DSCRATCH0_RESET_VAL)
      )
      dscratch0_csr_i
      (
        .clk                ( clk                   ),
        .rst_n              ( rst_n                 ),
        .scan_cg_en_i       ( scan_cg_en_i          ),
        .wr_data_i          ( dscratch0_n           ),
        .wr_en_i            ( dscratch0_we          ),
        .rd_data_o          ( dscratch0_q           ),
        .rd_error_o         ( dscratch0_rd_error    )
      );

      cv32e40s_csr
      #(
        .LIB        (LIB                ),
        .WIDTH      (32                 ),
        .SHADOWCOPY (1'b0               ),
        .MASK       (CSR_DSCRATCH1_MASK ),
        .RESETVALUE (DSCRATCH1_RESET_VAL)
      )
      dscratch1_csr_i
      (
        .clk                ( clk                   ),
        .rst_n              ( rst_n                 ),
        .scan_cg_en_i       ( scan_cg_en_i          ),
        .wr_data_i          ( dscratch1_n           ),
        .wr_en_i            ( dscratch1_we          ),
        .rd_data_o          ( dscratch1_q           ),
        .rd_error_o         ( dscratch1_rd_error    )
      );

      cv32e40s_csr
      #(
        .LIB        (LIB),
        .WIDTH      (32),
        .MASK       (CSR_DCSR_MASK),
        .SHADOWCOPY (SECURE),
        .RESETVALUE (DCSR_RESET_VAL)
      )
      dcsr_csr_i
      (
        .clk                ( clk                   ),
        .rst_n              ( rst_n                 ),
        .scan_cg_en_i       ( scan_cg_en_i          ),
        .wr_data_i          ( dcsr_n                ),
        .wr_en_i            ( dcsr_we               ),
        .rd_data_o          ( dcsr_q                ),
        .rd_error_o         ( dcsr_rd_error         )
      );

      cv32e40s_csr
      #(
        .LIB        (LIB),
        .WIDTH      (32),
        .MASK       (CSR_DPC_MASK),
        .SHADOWCOPY (1'b0),
        .RESETVALUE (DPC_RESET_VAL)
      )
      dpc_csr_i
      (
        .clk                ( clk                   ),
        .rst_n              ( rst_n                 ),
        .scan_cg_en_i       ( scan_cg_en_i          ),
        .wr_data_i          ( dpc_n                 ),
        .wr_en_i            ( dpc_we                ),
        .rd_data_o          ( dpc_q                 ),
        .rd_error_o         ( dpc_rd_error          )
      );
    end else begin : debug_csr_tieoff
        assign dscratch0_q = 32'h0;
        assign dscratch1_q = 32'h0;
        assign dpc_q       = 32'h0;
        assign dcsr_q      = 32'h0;
        assign dscratch0_rd_error = 1'b0;
        assign dscratch1_rd_error = 1'b0;
        assign dcsr_rd_error      = 1'b0;
        assign dpc_rd_error       = 1'b0;
    end
  endgenerate

  cv32e40s_csr
  #(
    .LIB        (LIB),
    .WIDTH      (32),
    .MASK       (CSR_MEPC_MASK),
    .SHADOWCOPY (SECURE),
    .RESETVALUE (MEPC_RESET_VAL)
  )
  mepc_csr_i
  (
    .clk                ( clk                   ),
    .rst_n              ( rst_n                 ),
    .scan_cg_en_i       ( scan_cg_en_i          ),
    .wr_data_i          ( mepc_n                ),
    .wr_en_i            ( mepc_we               ),
    .rd_data_o          ( mepc_q                ),
    .rd_error_o         ( mepc_rd_error         )
  );

  cv32e40s_csr
  #(
    .LIB        (LIB),
    .WIDTH      (32),
    .MASK       (CSR_MSCRATCH_MASK),
    .SHADOWCOPY (SECURE),
    .RESETVALUE (MSCRATCH_RESET_VAL)
  )
  mscratch_csr_i
  (
    .clk                ( clk                   ),
    .rst_n              ( rst_n                 ),
    .scan_cg_en_i       ( scan_cg_en_i          ),
    .wr_data_i          ( mscratch_n            ),
    .wr_en_i            ( mscratch_we           ),
    .rd_data_o          ( mscratch_q            ),
    .rd_error_o         ( mscratch_rd_error     )
  );

  cv32e40s_csr
  #(
    .LIB        (LIB),
    .WIDTH      (32),
    .MASK       (CSR_MSTATUS_MASK),
    .SHADOWCOPY (SECURE),
    .RESETVALUE (MSTATUS_RESET_VAL)
  )
  mstatus_csr_i
  (
    .clk                ( clk                   ),
    .rst_n              ( rst_n                 ),
    .scan_cg_en_i       ( scan_cg_en_i          ),
    .wr_data_i          ( mstatus_n             ),
    .wr_en_i            ( mstatus_we            ),
    .rd_data_o          ( mstatus_q             ),
    .rd_error_o         ( mstatus_rd_error      )
  );


  generate
    if (CLIC) begin : clic_csrs

      assign mie_q = 32'h0;                                                     // CLIC mode is assumed when CLIC = 1
      assign mie_rd_error = 1'b0;

      cv32e40s_csr
      #(
        .LIB        (LIB                  ),
        .WIDTH      (32                   ),
        .SHADOWCOPY (SECURE               ),
        .MASK       (CSR_CLIC_MCAUSE_MASK ),
        .RESETVALUE (MCAUSE_CLIC_RESET_VAL)
      )
      mcause_csr_i (
        .clk                ( clk                   ),
        .rst_n              ( rst_n                 ),
        .scan_cg_en_i       ( scan_cg_en_i          ),
        .wr_data_i          ( mcause_n              ),
        .wr_en_i            ( mcause_we             ),
        .rd_data_o          ( mcause_q              ),
        .rd_error_o         ( mcause_rd_error       )
      );

      cv32e40s_csr
      #(
        .LIB        (LIB),
        .WIDTH      (32),
        .MASK       (CSR_CLIC_MTVEC_MASK),
        .RESETVALUE (MTVEC_CLIC_RESET_VAL),
        .SHADOWCOPY (SECURE)
      )
      mtvec_csr_i
      (
        .clk            ( clk                   ),
        .rst_n          ( rst_n                 ),
        .scan_cg_en_i   ( scan_cg_en_i          ),
        .wr_data_i      ( mtvec_n               ),
        .wr_en_i        ( mtvec_we              ),
        .rd_data_o      ( mtvec_q               ),
        .rd_error_o     ( mtvec_rd_error        )
      );

      cv32e40s_csr
      #(
        .LIB        (LIB),
        .WIDTH      (32),
        .MASK       (CSR_MTVT_MASK),
        .SHADOWCOPY (SECURE),
        .RESETVALUE (MTVT_RESET_VAL)
      )
      mtvt_csr_i
      (
        .clk            ( clk                   ),
        .rst_n          ( rst_n                 ),
        .scan_cg_en_i   ( scan_cg_en_i          ),
        .wr_data_i      ( mtvt_n                ),
        .wr_en_i        ( mtvt_we               ),
        .rd_data_o      ( mtvt_q                ),
        .rd_error_o     ( mtvt_rd_error         )
      );

      cv32e40s_csr
      #(
        .LIB        (LIB),
        .WIDTH      (32),
        .MASK       (CSR_MINTSTATUS_MASK),
        .SHADOWCOPY (SECURE),
        .RESETVALUE (MINTSTATUS_RESET_VAL)
      )
      mintstatus_csr_i
      (
        .clk            ( clk                   ),
        .rst_n          ( rst_n                 ),
        .scan_cg_en_i   ( scan_cg_en_i          ),
        .wr_data_i      ( mintstatus_n          ),
        .wr_en_i        ( mintstatus_we         ),
        .rd_data_o      ( mintstatus_q          ),
        .rd_error_o     ( mintstatus_rd_error   )
      );

      cv32e40s_csr
      #(
        .LIB        (LIB),
        .WIDTH      (32),
        .MASK       (CSR_MINTTHRESH_MASK),
        .SHADOWCOPY (SECURE),
        .RESETVALUE (MINTTHRESH_RESET_VAL)
      )
      mintthresh_csr_i
      (
        .clk            ( clk                   ),
        .rst_n          ( rst_n                 ),
        .scan_cg_en_i   ( scan_cg_en_i          ),
        .wr_data_i      ( mintthresh_n          ),
        .wr_en_i        ( mintthresh_we         ),
        .rd_data_o      ( mintthresh_q          ),
        .rd_error_o     ( mintthresh_rd_error   )
      );

      logic unused_clic_signals;
      assign unused_clic_signals = mie_we | (|mie_n);

    end else begin : basic_mode_csrs

      cv32e40s_csr
      #(
        .LIB        (LIB                   ),
        .WIDTH      (32                    ),
        .SHADOWCOPY (SECURE                ),
        .MASK       (CSR_BASIC_MCAUSE_MASK ),
        .RESETVALUE (MCAUSE_BASIC_RESET_VAL)
      )
      mcause_csr_i (
        .clk                ( clk                   ),
        .rst_n              ( rst_n                 ),
        .scan_cg_en_i       ( scan_cg_en_i          ),
        .wr_data_i          ( mcause_n              ),
        .wr_en_i            ( mcause_we             ),
        .rd_data_o          ( mcause_q              ),
        .rd_error_o         ( mcause_rd_error       )
      );

      cv32e40s_csr
      #(
        .LIB        (LIB),
        .WIDTH      (32),
        .MASK       (CSR_BASIC_MTVEC_MASK),
        .SHADOWCOPY (SECURE),
        .RESETVALUE (MTVEC_BASIC_RESET_VAL)
      )
      mtvec_csr_i
      (
        .clk            ( clk                   ),
        .rst_n          ( rst_n                 ),
        .scan_cg_en_i   ( scan_cg_en_i          ),
        .wr_data_i      ( mtvec_n               ),
        .wr_en_i        ( mtvec_we              ),
        .rd_data_o      ( mtvec_q               ),
        .rd_error_o     ( mtvec_rd_error        )
      );

      cv32e40s_csr
      #(
        .LIB        (LIB),
        .WIDTH      (32),
        .MASK       (IRQ_MASK),
        .SHADOWCOPY (SECURE),
        .RESETVALUE (MIE_BASIC_RESET_VAL)
      )
      mie_csr_i
      (
        .clk            ( clk                   ),
        .rst_n          ( rst_n                 ),
        .scan_cg_en_i   ( scan_cg_en_i          ),
        .wr_data_i      ( mie_n                 ),
        .wr_en_i        ( mie_we                ),
        .rd_data_o      ( mie_q                 ),
        .rd_error_o     ( mie_rd_error          )
      );

      assign mtvt_q                = 32'h0;
      assign mtvt_rd_error         = 1'b0;

      assign mintstatus_q          = 32'h0;
      assign mintstatus_rd_error   = 1'b0;

      assign mintthresh_q          = 32'h0;
      assign mintthresh_rd_error   = 1'b0;

      assign mscratchcsw_q         = 32'h0;

      assign mscratchcswl_q        = 32'h0;

    end

    if (SECURE) begin : xsecure

      logic [2:0] lfsr_lockup;

      cv32e40s_csr
      #(
        .LIB        (LIB),
        .WIDTH      (32),
        .MASK       (CSR_CPUCTRL_MASK),
        .SHADOWCOPY (SECURE),
        .RESETVALUE (CPUCTRL_RESET_VAL)
      )
      cpuctrl_csr_i
      (
        .clk            ( clk                   ),
        .rst_n          ( rst_n                 ),
        .scan_cg_en_i   ( scan_cg_en_i          ),
        .wr_data_i      ( cpuctrl_n             ),
        .wr_en_i        ( cpuctrl_we            ),
        .rd_data_o      ( cpuctrl_q             ),
        .rd_error_o     ( cpuctrl_rd_error      )
      );


      // Shifting LFSR0 in IF because it controls instruction insertion
      cv32e40s_lfsr
      #(
        .LFSR_CFG     (LFSR0_CFG)
      )
      lfsr0_i
      (
        .clk            ( clk                   ),
        .rst_n          ( rst_n                 ),
        .seed_i         ( csr_wdata_int         ),      // Direct use of csr_wdata_int (secureseed0_n = 0 used by RVFI; resolution on read)
        .seed_we_i      ( secureseed0_we        ),
        .shift_i        ( lfsr_shift_if_i       ),
        .data_o         ( xsecure_ctrl_o.lfsr0  ),
        .lockup_o       ( lfsr_lockup[0]        )
      );

      // Shifting lfsr 1 and 2 in ID because they control the operand values
      cv32e40s_lfsr
      #(
        .LFSR_CFG     (LFSR1_CFG)
      )
      lfsr1_i
      (
        .clk            ( clk                   ),
        .rst_n          ( rst_n                 ),
        .seed_i         ( csr_wdata_int         ),      // Direct use of csr_wdata_int (secureseed1_n = 0 used by RVFI; resolution on read)
        .seed_we_i      ( secureseed1_we        ),
        .shift_i        ( lfsr_shift_id_i       ),
        .data_o         ( xsecure_ctrl_o.lfsr1  ),
        .lockup_o       ( lfsr_lockup[1]        )
      );

      cv32e40s_lfsr
      #(
        .LFSR_CFG     (LFSR2_CFG)
      )
      lfsr2_i
      (
        .clk            ( clk                   ),
        .rst_n          ( rst_n                 ),
        .seed_i         ( csr_wdata_int         ),      // Direct use of csr_wdata_int (secureseed2_n = 0 used by RVFI; resolution on read)
        .seed_we_i      ( secureseed2_we        ),
        .shift_i        ( lfsr_shift_id_i       ),
        .data_o         ( xsecure_ctrl_o.lfsr2  ),
        .lockup_o       ( lfsr_lockup[2]        )
      );

      // Populate xsecure_ctrl
      assign xsecure_ctrl_o.cpuctrl = cpuctrl_t'(cpuctrl_q);

      // Combine lockup singals for alert
      assign lfsr_lockup_o = |lfsr_lockup;

      // Reset dummy instruction counter when writing registers that affect insertion frequency
      // A pipeline flush will also be performed.
      // Cannot include lfsr_lockup here, as that would cause the counter for issued instructions in the dummy module
      //   to reset, possibly violating the dummy instruction frequency by issuing too many instructions between dummies.
      assign xsecure_ctrl_o.cntrst = cpuctrl_we || secureseed0_we;

    end // block: xsecure
    else begin : no_xsecure

      // Tie off
      assign xsecure_ctrl_o.cpuctrl = cpuctrl_t'('0);
      assign xsecure_ctrl_o.lfsr0   = '0;
      assign xsecure_ctrl_o.lfsr1   = '0;
      assign xsecure_ctrl_o.lfsr2   = '0;
      assign cpuctrl_rd_error       = 1'b0;
      assign lfsr_lockup_o          = 1'b0;

    end
  endgenerate

  assign csr_wr_in_wb = ex_wb_pipe_i.csr_en &&
                        ex_wb_pipe_i.instr_valid &&
                        ((csr_op == CSR_OP_WRITE) ||
                         (csr_op == CSR_OP_SET)   ||
                         (csr_op == CSR_OP_CLEAR));

  // xsecure CSRs has impact on pipeline operation. When updated, clear pipeline.
  // div/divu/rem/remu and branch decisions in EX stage depend on cpuctrl.dataindtiming
  // Dummy instruction insertion depend on cpuctrl.dummyen/dummyfreq
  assign xsecure_csr_wr_in_wb   = SECURE &&
                                  csr_wr_in_wb &&
                                  ((csr_waddr == CSR_CPUCTRL)     ||
                                   (csr_waddr == CSR_SECURESEED0) ||
                                   (csr_waddr == CSR_SECURESEED1) ||
                                   (csr_waddr == CSR_SECURESEED2));

  // PMP CSRs affect memory access permissions. When updated, the pipeline must be flushed
  // to ensure succseeding instructions are executed with correct permissions
  assign pmp_csr_wr_in_wb = csr_wr_in_wb &&
                            (|pmpncfg_wr_addr_match ||
                             |pmpaddr_wr_addr_match ||
                             (csr_waddr == CSR_MSECCFG));

  // Detect when a JVT write is in WB
  assign jvt_wr_in_wb = csr_wr_in_wb && (csr_waddr == CSR_JVT);

  assign csr_wr_in_wb_flush_o = xsecure_csr_wr_in_wb || pmp_csr_wr_in_wb || jvt_wr_in_wb;

  if (USER) begin : privlvl_user
  // Privilege level register
  cv32e40s_csr
  #(
    .LIB        (LIB),
    .WIDTH      ($bits(privlvl_t)),
    .MASK       (CSR_PRV_LVL_MASK),
    .SHADOWCOPY (SECURE),
    .RESETVALUE (PRIV_LVL_M)
  )
  priv_lvl_i
  (
    .clk            ( clk                   ),
    .rst_n          ( rst_n                 ),
    .scan_cg_en_i   ( scan_cg_en_i          ),
    .wr_data_i      ( priv_lvl_n            ),
    .wr_en_i        ( priv_lvl_we           ),
    .rd_data_o      ( priv_lvl_q_int        ),
    .rd_error_o     ( priv_lvl_rd_error     )
  );

  assign priv_lvl_q = privlvl_t'(priv_lvl_q_int);

  // Generate priviledge level for the IF stage
  // Since MRET may change the priviledge level and can is taken from ID,
  // the priviledge level for the IF stage needs to be predictive
  always_comb begin
    priv_lvl_if_ctrl_o.priv_lvl     = priv_lvl_rdata;
    priv_lvl_if_ctrl_o.priv_lvl_set = 1'b0;

    if (priv_lvl_we) begin
      // Priviledge level updated by MRET in WB or exception
      priv_lvl_if_ctrl_o.priv_lvl     = priv_lvl_n;
      priv_lvl_if_ctrl_o.priv_lvl_set = 1'b1;
    end
    else if (ctrl_fsm_i.mret_jump_id) begin
      // MRET in ID. Set IF stage priviledge level to mstatus.mpp
      // Using mstatus_rdata.mpp is safe since a write to mstatus.mpp in EX or WB it will cause a stall
      priv_lvl_if_ctrl_o.priv_lvl     = privlvl_t'(mstatus_rdata.mpp);
      priv_lvl_if_ctrl_o.priv_lvl_set = 1'b1;
    end
    else if ((id_ex_pipe_i.sys_en && id_ex_pipe_i.sys_mret_insn && ctrl_fsm_i.kill_ex) ||
             (ex_wb_pipe_i.sys_en && ex_wb_pipe_i.sys_mret_insn && ctrl_fsm_i.kill_wb) ||
             (sys_en_id_i && sys_mret_id_i && ctrl_fsm_i.kill_id)) begin
      // MRET got killed before retiring in the WB stage.
      // This will happen if the pipeline is flushed, e.g. by a fence(i) or certain CSR writes (XSECURE, PMP, JVT) preceding the MRET
      // Restore IF privilege level.
      priv_lvl_if_ctrl_o.priv_lvl     = priv_lvl_rdata;
      priv_lvl_if_ctrl_o.priv_lvl_set = 1'b1;
    end
  end

  // Lookahead for priv_lvl_lsu_o. Updates to MPRV or MPP in WB needs to take effect for load/stores in EX
  always_comb begin
    if (mstatus_we) begin
      priv_lvl_lsu_o = mstatus_n.mprv ? privlvl_t'(mstatus_n.mpp) : id_ex_pipe_i.priv_lvl;
    end
    else begin
      priv_lvl_lsu_o = mstatus_rdata.mprv ? privlvl_t'(mstatus_rdata.mpp) : id_ex_pipe_i.priv_lvl;
    end
  end


  end else begin : no_privlvl_user
    assign priv_lvl_q = PRIV_LVL_M;
    assign priv_lvl_rd_error = 1'b0;

    assign priv_lvl_if_ctrl_o.priv_lvl     = PRIV_LVL_M;
    assign priv_lvl_if_ctrl_o.priv_lvl_set = 1'b0;

    assign priv_lvl_lsu_o = PRIV_LVL_M;
  end


  generate
    if (PMP_NUM_REGIONS > 0) begin: csr_pmp

      for (genvar i=0; i < PMP_MAX_REGIONS; i++) begin: gen_pmp_csr

        if (i < PMP_NUM_REGIONS) begin: pmp_region

          assign pmpncfg_wr_addr_match[i] = (csr_waddr == csr_num_e'(CSR_PMPCFG0 + i));

          assign pmpncfg_n_int[i] = csr_wdata_int[(i%4)*PMPNCFG_W+:PMPNCFG_W];

          // Smepmp spec version 1.0, 4b: When mseccfg.mml==1, M-mode only or locked shared regions with executable privileges is not possible, and such writes are ignored. Exempt when mseccfg.rlb==1
          assign pmpncfg_warl_ignore_wr[i] = pmp_mseccfg_rdata.rlb ? 1'b0 :
                                             pmp_mseccfg_rdata.mml &&
                                             (({pmpncfg_n_int[i].lock, pmpncfg_n_int[i].read, pmpncfg_n_int[i].write, pmpncfg_n_int[i].exec} == 4'b1001) || // Locked region, M-mode: execute,      S/U mode: none
                                              ({pmpncfg_n_int[i].lock, pmpncfg_n_int[i].read, pmpncfg_n_int[i].write, pmpncfg_n_int[i].exec} == 4'b1010) || // Locked region, M-mode: execute,      S/U mode: execute
                                              ({pmpncfg_n_int[i].lock, pmpncfg_n_int[i].read, pmpncfg_n_int[i].write, pmpncfg_n_int[i].exec} == 4'b1011) || // Locked region, M-mode: read/execute, S/U mode: execute
                                              ({pmpncfg_n_int[i].lock, pmpncfg_n_int[i].read, pmpncfg_n_int[i].write, pmpncfg_n_int[i].exec} == 4'b1101));  // Locked region, M-mode: read/execute, S/U mode: none

          // MSECCFG.RLB allows the lock bit to be bypassed
          assign pmpncfg_locked[i] = pmpncfg_rdata[i].lock && !pmp_mseccfg_rdata.rlb;

          // Extract PMPCFGi bits from wdata
          always_comb begin

            if(pmpncfg_locked[i] || pmpncfg_warl_ignore_wr[i]) begin
              // Write is ignored because the PMP region is locked or if the write value is illegal
              pmpncfg_n[i] = pmpncfg_q[i];
            end
            else begin

              pmpncfg_n[i]       = csr_wdata_int[(i%4)*PMPNCFG_W+:PMPNCFG_W];
              pmpncfg_n[i].zero0 = '0;

              // PMPCFG.R/W/X form a collective WARL field, disallowing RW=01. Writing an illegal value will leave RWX unchanged.
              if (!pmpncfg_n[i].read && pmpncfg_n[i].write && !pmp_mseccfg_rdata.mml) begin
                pmpncfg_n[i].read  = pmpncfg_q[i].read;
                pmpncfg_n[i].write = pmpncfg_q[i].write;
                pmpncfg_n[i].exec  = pmpncfg_q[i].exec;
              end

              // NA4 mode is not selectable when G > 0, previous mode will be kept
              unique case (csr_wdata_int[(i%4)*PMPNCFG_W+3+:2])
                PMP_MODE_OFF   : pmpncfg_n[i].mode = PMP_MODE_OFF;
                PMP_MODE_TOR   : pmpncfg_n[i].mode = PMP_MODE_TOR;
                PMP_MODE_NA4   : pmpncfg_n[i].mode = (PMP_GRANULARITY == 0) ? PMP_MODE_NA4 :
                                                     pmpncfg_q[i].mode;
                PMP_MODE_NAPOT : pmpncfg_n[i].mode = PMP_MODE_NAPOT;
                default : pmpncfg_n[i].mode = pmpncfg_q[i].mode;
              endcase
            end
          end

          cv32e40s_csr
          #(
            .LIB        (LIB),
            .WIDTH      ($bits(pmpncfg_t)),
            .MASK       (CSR_PMPNCFG_MASK),
            .SHADOWCOPY (SECURE),
            .RESETVALUE (PMP_PMPNCFG_RV[i])
          )
          pmpncfg_csr_i
          (
            .clk            ( clk                   ),
            .rst_n          ( rst_n                 ),
            .scan_cg_en_i   ( scan_cg_en_i          ),
            .wr_data_i      ( pmpncfg_n[i]          ),
            .wr_en_i        ( pmpncfg_we[i]         ),
            .rd_data_o      ( pmpncfg_q[i]          ),
            .rd_error_o     ( pmpncfg_rd_error[i]   )
          );

          assign csr_pmp_o.cfg[i] = pmpncfg_q[i];

          if (i == PMP_NUM_REGIONS-1) begin: pmp_addr_qual_upper
            assign pmpaddr_locked[i] = pmpncfg_locked[i];
          end else begin: pmp_addr_qual_other
            // If the region at the next index is configured as TOR, this region's address register is locked
            assign pmpaddr_locked[i] = pmpncfg_locked[i] ||
                                       (pmpncfg_locked[i+1] && pmpncfg_q[i+1].mode == PMP_MODE_TOR);
          end

          assign pmpaddr_wr_addr_match[i] = (csr_waddr == csr_num_e'(CSR_PMPADDR0 + i));

          // Keep old data if PMPADDR is locked
          // Bit 0 needs special handling because modification of the read data in TOR and OFF mode could lead to
          // wrong data being used as basis for set/clear operations.
          // For example, if PMP_GRANULARITY=1, pmpcfg.mode=OFF, and PMPADDRn=32'hFFFFFFFF, then PMPADDRn would be read as 32'hFFFFFFFE.
          // A set operation with mask 0 would then result in PMPADDRn = 0 | 32'hFFFFFFFE, which would clear the LSB of PMPADDRn.
          // Using the value from pmp_addr_q directly avoids this issue.
          assign pmp_addr_n[i] = pmpaddr_locked[i] ? pmp_addr_q[i] : {csr_wdata_int[31-:(PMP_ADDR_WIDTH-1)], pmp_addr_bit_0_n[i]};

          cv32e40s_csr
          #(
            .LIB        (LIB),
            .WIDTH      (PMP_ADDR_WIDTH),
            .MASK       (CSR_PMPADDR_MASK[31-:PMP_ADDR_WIDTH]),
            .SHADOWCOPY (SECURE),
            .RESETVALUE (PMP_PMPADDR_RV[i][31-:PMP_ADDR_WIDTH])
          )
          pmp_addr_csr_i
          (
            .clk            ( clk                   ),
            .rst_n          ( rst_n                 ),
            .scan_cg_en_i   ( scan_cg_en_i          ),
            .wr_data_i      ( pmp_addr_n[i]         ),
            .wr_en_i        ( pmp_addr_we[i]        ),
            .rd_data_o      ( pmp_addr_q[i]         ),
            .rd_error_o     ( pmp_addr_rd_error[i]  )
          );

          if (PMP_GRANULARITY == 0) begin: pmp_addr_rdata_g0
            // If G == 0, read data is unmodified
            assign pmp_addr_rdata[i]     = pmp_addr_q[i];
            assign pmp_addr_n_r[i]       = pmp_addr_n[i];
            assign pmp_addr_bit_0_n[i]   = csr_wdata_int[0];
          end else if (PMP_GRANULARITY == 1) begin: pmp_addr_rdata_g1
            // If G == 1, bit [G-1] reads as zero in TOR or OFF mode
            always_comb begin
              pmp_addr_rdata[i] = pmp_addr_q[i];
              pmp_addr_n_r[i]   = pmp_addr_n[i];
              if ((pmpncfg_rdata[i].mode == PMP_MODE_OFF) || (pmpncfg_rdata[i].mode == PMP_MODE_TOR)) begin
                pmp_addr_rdata[i][PMP_GRANULARITY-1:0] = '0;
                pmp_addr_n_r[i][PMP_GRANULARITY-1:0]   = '0;
              end
            end

            assign pmp_addr_bit_0_n[i] = (csr_op == CSR_OP_SET)   ? (pmp_addr_q[i][0] ||  csr_wdata[PMP_GRANULARITY-1]) :
                                         (csr_op == CSR_OP_CLEAR) ? (pmp_addr_q[i][0] && !csr_wdata[PMP_GRANULARITY-1]) :
                                         csr_wdata[PMP_GRANULARITY-1];

          end else begin: pmp_addr_rdata_g2
            // For G >= 2, bits are masked to one or zero depending on the mode
            always_comb begin
              // In NAPOT mode, bits [G-2:0] must read as one
              pmp_addr_rdata[i] = {pmp_addr_q[i], {PMP_GRANULARITY-1{1'b1}}};
              pmp_addr_n_r[i]   = {pmp_addr_n[i], {PMP_GRANULARITY-1{1'b1}}};

              if ((pmpncfg_rdata[i].mode == PMP_MODE_OFF) || (pmpncfg_rdata[i].mode == PMP_MODE_TOR)) begin
                // In TOR or OFF mode, bits [G-1:0] must read as zero
                pmp_addr_rdata[i][PMP_GRANULARITY-1:0] = '0;
                pmp_addr_n_r[i][PMP_GRANULARITY-1:0]   = '0;
              end
            end

            assign pmp_addr_bit_0_n[i] = (csr_op == CSR_OP_SET)   ? (pmp_addr_q[i][0] ||  csr_wdata[PMP_GRANULARITY-1]) :
                                         (csr_op == CSR_OP_CLEAR) ? (pmp_addr_q[i][0] && !csr_wdata[PMP_GRANULARITY-1]) :
                                         csr_wdata[PMP_GRANULARITY-1];
          end

          assign csr_pmp_o.addr[i] = {pmp_addr_rdata[i], 2'b00};

          // pmp_addr_n_r is only used by RVFI. Assign pmp_addr_n_r_unused to ease LINT waiving
          assign pmp_addr_n_r_unused[i] = |pmp_addr_n_r[i];

          assign unused_pmp_region_signals[i] = 1'b0; // PMP region implemented, no signals should be unused.
        end // block: pmp_region
        else begin: no_pmp_region

          // Tie off outputs for unimplemented regions
          assign pmpncfg_locked[i]         = 1'b0;
          assign pmpncfg_n[i]              = pmpncfg_t'('0);
          assign pmpncfg_n_int[i]          = pmpncfg_t'('0);
          assign pmpncfg_q[i]              = pmpncfg_t'('0);
          assign pmpncfg_rd_error[i]       = 1'b0;
          assign pmpncfg_warl_ignore_wr[i] = 1'b0;
          assign pmpncfg_wr_addr_match[i]  = 1'b0;

          assign pmp_addr_q[i]             = '0;
          assign pmp_addr_rdata[i]         = '0;
          assign pmp_addr_n_r[i]           = '0;
          assign pmp_addr_n_r_unused[i]    = '0;
          assign pmp_addr_n[i]             = '0;
          assign pmp_addr_bit_0_n[i]       = 1'b0;
          assign pmpaddr_locked[i]         = 1'b0;
          assign pmp_addr_rd_error[i]      = 1'b0;

          assign pmpaddr_wr_addr_match[i]  = 1'b0;

          assign csr_pmp_o.addr[i]         = '0;
          assign csr_pmp_o.cfg[i]          = pmpncfg_t'('0);

          assign unused_pmp_region_signals[i] = (|pmpncfg_n[i]) | (|pmpncfg_n_int[i]) | pmpncfg_we[i] |
                                                pmpncfg_warl_ignore_wr[i] | pmp_addr_we[i] |
                                                (|pmp_addr_q[i]) | (|pmp_addr_n_r[i]) | (|pmp_addr_n[i]) | pmp_addr_bit_0_n[i] |
                                                pmpaddr_locked[i];
        end
      end // block: gen_pmp_csr

      // MSECCFG.MML/MSECCFG.MMWP cannot be unset once set
      assign pmp_mseccfg_n.mml  = csr_wdata_int[CSR_MSECCFG_MML_BIT]  || pmp_mseccfg_rdata.mml;
      assign pmp_mseccfg_n.mmwp = csr_wdata_int[CSR_MSECCFG_MMWP_BIT] || pmp_mseccfg_rdata.mmwp;

      // MSECCFG.RLB cannot be set if RLB=0 and any PMP region is locked
      assign pmp_mseccfg_n.rlb  = pmp_mseccfg_rdata.rlb ? csr_wdata_int[CSR_MSECCFG_RLB_BIT] :
                                  csr_wdata_int[CSR_MSECCFG_RLB_BIT] && !(|pmpncfg_locked);

      assign pmp_mseccfg_n.zero0 = '0;

      cv32e40s_csr
      #(
        .LIB        (LIB),
        .WIDTH      ($bits(mseccfg_t)),
        .MASK       (CSR_MSECCFG_MASK),
        .SHADOWCOPY (SECURE),
        .RESETVALUE (PMP_MSECCFG_RV)
      )
      pmp_mseccfg_csr_i
      (
        .clk            ( clk                   ),
        .rst_n          ( rst_n                 ),
        .scan_cg_en_i   ( scan_cg_en_i          ),
        .wr_data_i      ( pmp_mseccfg_n         ),
        .wr_en_i        ( pmp_mseccfg_we        ),
        .rd_data_o      ( pmp_mseccfg_q         ),
        .rd_error_o     ( pmp_mseccfg_rd_error  )
      );

      assign csr_pmp_o.mseccfg = pmp_mseccfg_q;

      // Combine read error signals
      assign pmp_rd_error = |pmpncfg_rd_error || |pmp_addr_rd_error || pmp_mseccfg_rd_error;

    end // block: csr_pmp
    else begin: no_csr_pmp


      // Generate tieoffs when PMP is not configured
      for (genvar i = 0; i < PMP_MAX_REGIONS; i++) begin : g_tie_pmp_rdata
        assign pmpncfg_locked[i]         = 1'b0;
        assign pmpncfg_n[i]              = pmpncfg_t'('0);
        assign pmpncfg_n_int[i]          = pmpncfg_t'('0);
        assign pmpncfg_q[i]              = pmpncfg_t'('0);
        assign pmpncfg_rd_error[i]       = 1'b0;
        assign pmpncfg_warl_ignore_wr[i] = 1'b0;
        assign pmpncfg_wr_addr_match[i]  = 1'b0;

        assign pmp_addr_q[i]             = '0;
        assign pmp_addr_rdata[i]         = '0;
        assign pmp_addr_n_r[i]           = '0;
        assign pmp_addr_n_r_unused[i]    = '0;
        assign pmp_addr_n[i]             = '0;
        assign pmp_addr_bit_0_n[i]       = 1'b0;
        assign pmpaddr_locked[i]         = 1'b0;
        assign pmp_addr_rd_error[i]      = 1'b0;

        assign pmpaddr_wr_addr_match[i]  = 1'b0;

        assign csr_pmp_o.addr[i]         = '0;
        assign csr_pmp_o.cfg[i]          = pmpncfg_t'('0);

        assign unused_pmp_region_signals[i] = pmpncfg_locked[i] | (|pmpncfg_n[i]) | (|pmpncfg_n_int[i]) |
                                              pmpncfg_rd_error[i] | pmpncfg_warl_ignore_wr[i] | (|pmpncfg_rdata[i]) |
                                              (|pmp_addr_q[i]) | (|pmp_addr_n_r[i]) | (|pmp_addr_n[i]) | pmp_addr_bit_0_n[i] |
                                              pmpaddr_locked[i] | pmp_addr_rd_error[i];
      end

      assign csr_pmp_o.mseccfg    = mseccfg_t'('0);

      assign pmp_mseccfg_n        = mseccfg_t'('0);
      assign pmp_mseccfg_q        = mseccfg_t'('0);
      assign pmp_mseccfg_rd_error = 1'b0;

      assign pmp_rd_error         = 1'b0;

      logic unused_pmp_signals;
      assign unused_pmp_signals = pmp_mseccfg_rd_error | pmp_mseccfg_we | (|pmp_mseccfg_n) | (|pmp_addr_we) | (|pmpncfg_we);

    end // block: no_csr_pmp
  endgenerate

  ////////////////////////////////////////////////////////////////////////
  //
  // CSR rdata

  assign jvt_rdata          = jvt_q;
  assign dscratch0_rdata    = dscratch0_q;
  assign dscratch1_rdata    = dscratch1_q;
  assign dpc_rdata          = dpc_q;
  assign mepc_rdata         = mepc_q;
  assign mscratch_rdata     = mscratch_q;
  assign mstatus_rdata      = mstatus_q;
  assign mtvec_rdata        = mtvec_q;
  assign mtvt_rdata         = mtvt_q;
  assign mintstatus_rdata   = mintstatus_q;
  assign mie_rdata          = mie_q;

  assign priv_lvl_rdata     = priv_lvl_q;

  assign pmpncfg_rdata      = pmpncfg_q;
  assign pmp_mseccfg_rdata  = pmp_mseccfg_q;
  assign mintthresh_rdata   = mintthresh_q;

  // mnxti_rdata breaks the regular convension for CSRs. The read data used for read-modify-write is the mstatus_rdata,
  // while the value read and written back to the GPR is a pointer address if an interrupt is pending, or zero
  // if no interrupt is pending.
  assign mnxti_rdata        = mnxti_irq_pending_i ? {mtvt_addr_o, mnxti_irq_id, 2'b00} : 32'h00000000;

  // mscratchcsw_rdata breaks the regular convension for CSRs. Read data depends on mstatus.mpp
  // mscratch_rdata is returned if mstatus.mpp differs from PRIV_LVL_M, otherwise rs1 is returned.
  // This signal is only used by RVFI, and has WB timing (rs1 comes from ex_wb_pipe_i.csr_wdata, flopped version of id_ex_pipe.alu_operand_a)
  assign mscratchcsw_rdata  = (mstatus_rdata.mpp != PRIV_LVL_M) ? mscratch_rdata : ex_wb_pipe_i.csr_wdata;

  // mscratchcswl_rdata breaks the regular convension for CSrs. Read data depend on mcause.pil and mintstatus.mil.
  // This signal is only used by RVFI, and has WB timing (rs1 comes from ex_wb_pipe_i.csr_wdata, flopped version of id_ex_pipe.alu_operand_a)
  assign mscratchcswl_rdata = ((mcause_rdata.mpil == '0) != (mintstatus_rdata.mil == 0)) ? mscratch_rdata : ex_wb_pipe_i.csr_wdata;

  assign mip_rdata          = mip_i;
  assign misa_rdata         = MISA_VALUE;
  assign mstatush_rdata     = 32'h0;
  assign mtval_rdata        = 32'h0;
  assign mvendorid_rdata    = {MVENDORID_BANK, MVENDORID_OFFSET};
  assign marchid_rdata      = MARCHID;
  assign mimpid_rdata       = {12'b0, MIMPID_MAJOR, 4'b0, MIMPID_MINOR, 4'b0, mimpid_patch_i};
  assign mhartid_rdata      = mhartid_i;
  assign mconfigptr_rdata   = 32'h0;

  assign pmp_mseccfgh_rdata = 32'h0;
  assign mcounteren_rdata   = 32'h0;
  assign menvcfg_rdata      = 32'h0;
  assign menvcfgh_rdata     = 32'h0;

  assign cpuctrl_rdata      = cpuctrl_q;
  assign secureseed0_rdata  = 32'h0;
  assign secureseed1_rdata  = 32'h0;
  assign secureseed2_rdata  = 32'h0;

  assign mstateen0_rdata    = mstateen0_q;
  assign mstateen1_rdata    = 32'h0;
  assign mstateen2_rdata    = 32'h0;
  assign mstateen3_rdata    = 32'h0;
  assign mstateen0h_rdata   = 32'h0;
  assign mstateen1h_rdata   = 32'h0;
  assign mstateen2h_rdata   = 32'h0;
  assign mstateen3h_rdata   = 32'h0;

  // dcsr_rdata factors in the flop outputs and the nmip bit from the controller
  assign dcsr_rdata = DEBUG ? {dcsr_q[31:4], ctrl_fsm_i.pending_nmi, dcsr_q[2:0]} : 32'h0;


  assign mcause_rdata = mcause_q;


  assign csr_rdata_o = csr_rdata_int;


  // Signal when an interrupt may become enabled due to a CSR write
  generate
    if (CLIC) begin : clic_irq_en
      assign csr_irq_enable_write_o = mstatus_we || priv_lvl_we || mintthresh_we || mintstatus_we;
    end else begin : basic_irq_en
      assign csr_irq_enable_write_o = mie_we || mstatus_we || priv_lvl_we;
    end
  endgenerate

  // Set signals for explicit CSR hazard detection
  // Conservative expl_re_ex, based on flopped instr_valid and not the local version factoring in halt/kill.
  // May cause a false positive while EX stage is either halted or killed. When halted the instruction in EX would
  // not propagate at all, regardless of any hazard raised. When killed the stage is flushed and there is no penalty
  // added from the conservative stall.
  // Avoiding halt/kill also avoids combinatorial lopps via the controller_fsm as a CSR hazard may lead to halt_ex being asserted.
  assign csr_hz_o.expl_re_ex = id_ex_pipe_i.csr_en && id_ex_pipe_i.instr_valid;
  assign csr_hz_o.expl_raddr_ex = csr_raddr;

  // Conservative expl_we_wb, based on flopped instr_valid and not the local version factoring in halt/kill.
  // May cause false positives when a CSR instruction in WB is halted or killed. When WB is halted, the backpressure of the pipeline
  // causes no instructions to propagate down the pipeline. Thus a false positive will not give any cycle penalties.
  // When WB is killed, the full pipeline is also killed and any stalls due to a false positive will not have any effect.
  // Same remark about combinatorial loops as for the expl_re_ex above.
  assign csr_hz_o.expl_we_wb = ex_wb_pipe_i.csr_en && ex_wb_pipe_i.instr_valid && (csr_op != CSR_OP_READ);
  assign csr_hz_o.expl_waddr_wb = csr_waddr;
  ////////////////////////////////////////////////////////////////////////
  //
  // CSR outputs

  assign dcsr_o        = dcsr_rdata;
  assign dpc_o         = dpc_rdata;
  assign jvt_addr_o    = jvt_rdata.base[31:32-JVT_ADDR_WIDTH];
  assign jvt_mode_o    = jvt_rdata.mode;
  assign mcause_o      = mcause_rdata;
  assign mcycle_o      = mhpmcounter_rdata[0];
  assign mepc_o        = mepc_rdata;
  assign mie_o         = mie_rdata;
  assign mintstatus_o  = mintstatus_rdata;
  assign mintthresh_th_o  = mintthresh_rdata[7:0];
  assign mstatus_o     = mstatus_rdata;
  assign mtvec_addr_o  = mtvec_rdata.addr;
  assign mtvec_mode_o  = mtvec_rdata.mode;
  assign mtvt_addr_o   = mtvt_rdata.addr[31:(32-MTVT_ADDR_WIDTH)];

  assign priv_lvl_o    = priv_lvl_rdata;
  assign mstateen0_o   = mstateen0_rdata;

  ////////////////////////////////////////////////////////////////////////
  //  ____       _                   _____     _                        //
  // |  _ \  ___| |__  _   _  __ _  |_   _| __(_) __ _  __ _  ___ _ __  //
  // | | | |/ _ \ '_ \| | | |/ _` |   | || '__| |/ _` |/ _` |/ _ \ '__| //
  // | |_| |  __/ |_) | |_| | (_| |   | || |  | | (_| | (_| |  __/ |    //
  // |____/ \___|_.__/ \__,_|\__, |   |_||_|  |_|\__, |\__, |\___|_|    //
  //                         |___/               |___/ |___/            //
  ////////////////////////////////////////////////////////////////////////

  // When DEBUG==0, DBG_NUM_TRIGGERS is assumed to be 0 as well.
  cv32e40s_debug_triggers
    #(
        .LIB              (LIB             ),
        .DBG_NUM_TRIGGERS (DBG_NUM_TRIGGERS)
    )
    debug_triggers_i
    (
      .clk                 ( clk                   ),
      .rst_n               ( rst_n                 ),
      .scan_cg_en_i        ( scan_cg_en_i          ),

      // CSR inputs write inputs
      .csr_wdata_i         ( csr_wdata_int         ),
      .tselect_we_i        ( tselect_we            ),
      .tdata1_we_i         ( tdata1_we             ),
      .tdata2_we_i         ( tdata2_we             ),
      .tinfo_we_i          ( tinfo_we              ),

      // CSR read data outputs
      .tselect_rdata_o     ( tselect_rdata         ),
      .tdata1_rdata_o      ( tdata1_rdata          ),
      .tdata2_rdata_o      ( tdata2_rdata          ),
      .tinfo_rdata_o       ( tinfo_rdata           ),

      // IF stage inputs
      .pc_if_i             ( pc_if_i               ),
      .ptr_in_if_i         ( ptr_in_if_i           ),
      .priv_lvl_if_i       ( priv_lvl_if_i         ),

      // LSU inputs
      .lsu_valid_ex_i      ( lsu_valid_ex_i        ),
      .lsu_addr_ex_i       ( lsu_addr_ex_i         ),
      .lsu_we_ex_i         ( lsu_we_ex_i           ),
      .lsu_be_ex_i         ( lsu_be_ex_i           ),
      .priv_lvl_ex_i       ( id_ex_pipe_i.priv_lvl ),

      // WB inputs
      .priv_lvl_wb_i       ( ex_wb_pipe_i.priv_lvl ),

      // Controller inputs
      .ctrl_fsm_i          ( ctrl_fsm_i            ),

      // Trigger match outputs
      .trigger_match_if_o  ( trigger_match_if_o    ),
      .trigger_match_ex_o  ( trigger_match_ex_o    ),
      .etrigger_wb_o       ( etrigger_wb_o         )
    );



  /////////////////////////////////////////////////////////////////
  //   ____            __     ____                  _            //
  // |  _ \ ___ _ __ / _|   / ___|___  _   _ _ __ | |_ ___ _ __  //
  // | |_) / _ \ '__| |_   | |   / _ \| | | | '_ \| __/ _ \ '__| //
  // |  __/  __/ |  |  _|  | |__| (_) | |_| | | | | ||  __/ |    //
  // |_|   \___|_|  |_|(_)  \____\___/ \__,_|_| |_|\__\___|_|    //
  //                                                             //
  /////////////////////////////////////////////////////////////////

  // Calculate mask for MHPMCOUNTERS depending on how many that are implemented.
  localparam bit [28:0] MHPMCOUNTERS_MASK = (2 ** NUM_MHPMCOUNTERS) -1;
  // Set mask for mcountinhibit, include always included counters for mcycle and minstret.
  localparam bit [31:0] MCOUNTINHIBIT_MASK = (MHPMCOUNTERS_MASK << 3) | 3'b101;


  logic                 debug_stopcount;

  // dcsr.stopcount == 1: Don’t increment any counters while in Debug Mode.
  // The debug spec states that we should also not increment counters "on ebreak instructions that cause entry into debug mode",
  // but this implementation does not take ebreak instructions into account.
  // This is considered OK since most counter events (except wb_invalid and cycle) will be suppressed (in ctrl_fsm_i.mhpmevent) when we
  // have an ebreak causing debug mode entry in WB.
  assign debug_stopcount = dcsr_rdata.stopcount && ctrl_fsm_i.debug_mode;


  // ------------------------
  // Events to count
  assign hpm_events[0] = 1'b1;                               // Cycle counter
  assign hpm_events[1] = ctrl_fsm_i.mhpmevent.minstret;      // Instruction counter

  // ------------------------
  // address decoder for performance counter registers
  logic mcountinhibit_we;
  logic mhpmevent_we;

  assign mcountinhibit_we = csr_we_int & (  csr_waddr == CSR_MCOUNTINHIBIT);
  assign mhpmevent_we     = csr_we_int & ( (csr_waddr == CSR_MHPMEVENT3  )||
                                           (csr_waddr == CSR_MHPMEVENT4  ) ||
                                           (csr_waddr == CSR_MHPMEVENT5  ) ||
                                           (csr_waddr == CSR_MHPMEVENT6  ) ||
                                           (csr_waddr == CSR_MHPMEVENT7  ) ||
                                           (csr_waddr == CSR_MHPMEVENT8  ) ||
                                           (csr_waddr == CSR_MHPMEVENT9  ) ||
                                           (csr_waddr == CSR_MHPMEVENT10 ) ||
                                           (csr_waddr == CSR_MHPMEVENT11 ) ||
                                           (csr_waddr == CSR_MHPMEVENT12 ) ||
                                           (csr_waddr == CSR_MHPMEVENT13 ) ||
                                           (csr_waddr == CSR_MHPMEVENT14 ) ||
                                           (csr_waddr == CSR_MHPMEVENT15 ) ||
                                           (csr_waddr == CSR_MHPMEVENT16 ) ||
                                           (csr_waddr == CSR_MHPMEVENT17 ) ||
                                           (csr_waddr == CSR_MHPMEVENT18 ) ||
                                           (csr_waddr == CSR_MHPMEVENT19 ) ||
                                           (csr_waddr == CSR_MHPMEVENT20 ) ||
                                           (csr_waddr == CSR_MHPMEVENT21 ) ||
                                           (csr_waddr == CSR_MHPMEVENT22 ) ||
                                           (csr_waddr == CSR_MHPMEVENT23 ) ||
                                           (csr_waddr == CSR_MHPMEVENT24 ) ||
                                           (csr_waddr == CSR_MHPMEVENT25 ) ||
                                           (csr_waddr == CSR_MHPMEVENT26 ) ||
                                           (csr_waddr == CSR_MHPMEVENT27 ) ||
                                           (csr_waddr == CSR_MHPMEVENT28 ) ||
                                           (csr_waddr == CSR_MHPMEVENT29 ) ||
                                           (csr_waddr == CSR_MHPMEVENT30 ) ||
                                           (csr_waddr == CSR_MHPMEVENT31 ) );

  // ------------------------
  // Increment value for performance counters
  genvar incr_gidx;
  generate
    for (incr_gidx=0; incr_gidx<32; incr_gidx++) begin : gen_mhpmcounter_increment
      assign mhpmcounter_increment[incr_gidx] = mhpmcounter_rdata[incr_gidx] + 1;
    end
  endgenerate

  // ------------------------
  // next value for performance counters and control registers
  always_comb
    begin
      mcountinhibit_n = mcountinhibit_rdata;
      mhpmevent_n     = mhpmevent_rdata;


      // Inhibit Control
      if(mcountinhibit_we)
        mcountinhibit_n = csr_wdata_int & MCOUNTINHIBIT_MASK;

      // Event Control
      if(mhpmevent_we)
        mhpmevent_n[csr_waddr[4:0]] = csr_wdata_int;
    end

  genvar wcnt_gidx;
  generate
    for (wcnt_gidx=0; wcnt_gidx<32; wcnt_gidx++) begin : gen_mhpmcounter_write

      // Write lower counter bits
      assign mhpmcounter_write_lower[wcnt_gidx] = csr_we_int && (csr_waddr == (CSR_MCYCLE + wcnt_gidx));

      // Write upper counter bits
      assign mhpmcounter_write_upper[wcnt_gidx] = !mhpmcounter_write_lower[wcnt_gidx] &&
                                                  csr_we_int && (csr_waddr == (CSR_MCYCLEH + wcnt_gidx));

      // Increment counter

      if (wcnt_gidx == 0) begin : gen_mhpmcounter_mcycle
        // mcycle = mhpmcounter[0] : count every cycle (if not inhibited)
        assign mhpmcounter_write_increment[wcnt_gidx] = !mhpmcounter_write_lower[wcnt_gidx] &&
                                                        !mhpmcounter_write_upper[wcnt_gidx] &&
                                                        !mcountinhibit_rdata[wcnt_gidx] &&
                                                        !debug_stopcount;
      end else if (wcnt_gidx == 2) begin : gen_mhpmcounter_minstret
        // minstret = mhpmcounter[2]  : count every retired instruction (if not inhibited)
        assign mhpmcounter_write_increment[wcnt_gidx] = !mhpmcounter_write_lower[wcnt_gidx] &&
                                                        !mhpmcounter_write_upper[wcnt_gidx] &&
                                                        !mcountinhibit_rdata[wcnt_gidx] &&
                                                        !debug_stopcount &&
                                                        hpm_events[1];
      end else if( (wcnt_gidx>2) && (wcnt_gidx<(NUM_MHPMCOUNTERS+3))) begin : gen_mhpmcounter_write_increment
        // add +1 if any event is enabled and active
        assign mhpmcounter_write_increment[wcnt_gidx] = !mhpmcounter_write_lower[wcnt_gidx] &&
                                                        !mhpmcounter_write_upper[wcnt_gidx] &&
                                                        !mcountinhibit_rdata[wcnt_gidx] &&
                                                        !debug_stopcount &&
                                                        |(hpm_events & mhpmevent_rdata[wcnt_gidx][NUM_HPM_EVENTS-1:0]);
      end else begin : gen_mhpmcounter_not_implemented
        assign mhpmcounter_write_increment[wcnt_gidx] = 1'b0;
      end

    end
  endgenerate

  // ------------------------
  // HPM Registers
  // next value
  genvar nxt_gidx;
  generate
    for (nxt_gidx = 0; nxt_gidx < 32; nxt_gidx++) begin : gen_mhpmcounter_nextvalue
      // mcyclce  is located at index 0
      // there is no counter at index 1
      // minstret is located at index 2
      // Programable HPM counters start at index 3
      if( (nxt_gidx == 1) ||
          (nxt_gidx >= (NUM_MHPMCOUNTERS+3) ) )
        begin : gen_non_implemented_nextvalue
          assign mhpmcounter_n[nxt_gidx]  = 'b0;
          assign mhpmcounter_we[nxt_gidx] = 2'b0;
      end
      else begin : gen_implemented_nextvalue
        always_comb begin
          mhpmcounter_we[nxt_gidx] = 2'b0;
          mhpmcounter_n[nxt_gidx]  = mhpmcounter_rdata[nxt_gidx];
          if (mhpmcounter_write_lower[nxt_gidx]) begin
            mhpmcounter_n[nxt_gidx][31:0] = csr_wdata_int;
            mhpmcounter_we[nxt_gidx][0] = 1'b1;
          end else if (mhpmcounter_write_upper[nxt_gidx]) begin
            mhpmcounter_n[nxt_gidx][63:32] = csr_wdata_int;
            mhpmcounter_we[nxt_gidx][1] = 1'b1;
          end else if (mhpmcounter_write_increment[nxt_gidx]) begin
            mhpmcounter_we[nxt_gidx] = 2'b11;
            mhpmcounter_n[nxt_gidx] = mhpmcounter_increment[nxt_gidx];
          end
        end // always_comb
      end
    end
  endgenerate
  //  Counter Registers: mhpcounter_q[]
  genvar cnt_gidx;
  generate
    for (cnt_gidx = 0; cnt_gidx < 32; cnt_gidx++) begin : gen_mhpmcounter
      // mcyclce  is located at index 0
      // there is no counter at index 1
      // minstret is located at index 2
      // Programable HPM counters start at index 3
      if( (cnt_gidx == 1) ||
          (cnt_gidx >= (NUM_MHPMCOUNTERS+3) ) )
        begin : gen_non_implemented_mhpmcounter
        assign mhpmcounter_q[cnt_gidx] = 'b0;
      end
      else begin : gen_implemented_mhpmcounter
        always_ff @(posedge clk, negedge rst_n)
          if (!rst_n) begin
            mhpmcounter_q[cnt_gidx] <= 'b0;
          end else begin
            if (mhpmcounter_we[cnt_gidx][0]) begin
              mhpmcounter_q[cnt_gidx][31:0] <= mhpmcounter_n[cnt_gidx][31:0];
            end
            if (mhpmcounter_we[cnt_gidx][1]) begin
              mhpmcounter_q[cnt_gidx][63:32] <= mhpmcounter_n[cnt_gidx][63:32];
            end
          end
      end
      assign mhpmcounter_rdata[cnt_gidx] = mhpmcounter_q[cnt_gidx];
    end
  endgenerate

  //  Event Register: mhpevent_q[]
  genvar evt_gidx;
  generate
    for (evt_gidx = 0; evt_gidx < 32; evt_gidx++) begin : gen_mhpmevent
      // programable HPM events start at index3
      if( (evt_gidx < 3) ||
          (evt_gidx >= (NUM_MHPMCOUNTERS+3) ) )
        begin : gen_non_implemented_mhpmevent
          assign mhpmevent_q[evt_gidx] = 'b0;

          logic unused_mhpmevent_signals;
          assign unused_mhpmevent_signals = (|mhpmevent_n[evt_gidx]) | (|mhpmevent_q[evt_gidx]) | (|mhpmevent_rdata[evt_gidx]);
      end
      else begin : gen_implemented_mhpmevent
        if (NUM_HPM_EVENTS < 32) begin : gen_tie_off
             assign mhpmevent_q[evt_gidx][31:NUM_HPM_EVENTS] = 'b0;
        end
        always_ff @(posedge clk, negedge rst_n)
            if (!rst_n)
                mhpmevent_q[evt_gidx][NUM_HPM_EVENTS-1:0]  <= 'b0;
            else
                mhpmevent_q[evt_gidx][NUM_HPM_EVENTS-1:0]  <= mhpmevent_n[evt_gidx][NUM_HPM_EVENTS-1:0] ;
      end
      assign mhpmevent_rdata[evt_gidx] = mhpmevent_q[evt_gidx];
    end
  endgenerate

  //  Inhibit Register: mcountinhibit_q
  //  Note: implemented counters are disabled out of reset to save power
  always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n) begin
      mcountinhibit_q <= MCOUNTINHIBIT_MASK; // default disable
    end else begin
      mcountinhibit_q <= mcountinhibit_n;
    end
  end

  assign mcountinhibit_rdata = mcountinhibit_q;

  // Assign values used for setting rmask in RVFI
  assign mscratchcsw_in_wb  = ex_wb_pipe_i.csr_en && (csr_waddr == CSR_MSCRATCHCSW);
  assign mscratchcswl_in_wb = ex_wb_pipe_i.csr_en && (csr_waddr == CSR_MSCRATCHCSWL);
  assign mnxti_in_wb        = ex_wb_pipe_i.csr_en && (csr_waddr == CSR_MNXTI);

  // Some signals are unused on purpose (typically they are used by RVFI code). Use them here for easier LINT waiving.

  assign unused_signals = mstatush_we | misa_we | mip_we | mvendorid_we | marchid_we |
    mimpid_we | mhartid_we | mconfigptr_we | mtval_we | pmp_mseccfgh_we | mcounteren_we | menvcfg_we | menvcfgh_we |
    dpc_rd_error | dscratch0_rd_error | dscratch1_rd_error |
    (|menvcfg_n) | (|menvcfgh_n) | (|mcounteren_n) | (|pmp_mseccfgh_n) |
    (|secureseed0_n) | (|secureseed1_n) | (|secureseed2_n) |
    (|mstateen1_n) | (|mstateen2_n) | (|mstateen3_n) | (|mstateen0h_n) | (|mstateen1h_n) | (|mstateen2h_n) | (|mstateen3h_n) |
    mstateen1_we | mstateen2_we | mstateen3_we | mstateen0h_we | mstateen1h_we | mstateen2h_we |
    mstateen3h_we | (|pmp_addr_n_r_unused) | (|mnxti_n) | mscratchcsw_we | mscratchcswl_we |
    (|mscratchcsw_rdata) | (|mscratchcswl_rdata) | (|mscratchcsw_n) | (|mscratchcswl_n) |
    mscratchcsw_in_wb | mscratchcswl_in_wb | mnxti_in_wb |
    (|mtval_n) | (|mconfigptr_n) | (|mhartid_n) | (|mimpid_n) | (|marchid_n) | (|mvendorid_n) | (|mip_n) | (|misa_n) | (|mstatush_n);

endmodule
