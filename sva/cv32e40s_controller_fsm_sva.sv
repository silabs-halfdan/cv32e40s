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
//                                                                            //
// Authors:        Matthias Baer - baermatt@student.ethz.ch                   //
//                 Igor Loi - igor.loi@unibo.it                               //
//                 Andreas Traber - atraber@student.ethz.ch                   //
//                 Sven Stucki - svstucki@student.ethz.ch                     //
//                 Michael Gautschi - gautschi@iis.ee.ethz.ch                 //
//                 Davide Schiavone - pschiavo@iis.ee.ethz.ch                 //
//                 Robert Balas - balasr@iis.ee.ethz.ch                       //
//                 Andrea Bettati - andrea.bettati@studenti.unipr.it          //
//                 Halfdan Bechmann - halfdan.bechmann@silabs.com             //
//                 Øystein Knauserud - oystein.knauserud@silabs.com           //
//                                                                            //
// Description:    RTL assertions for the controller module                   //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////

module cv32e40s_controller_fsm_sva
  import uvm_pkg::*;
  import cv32e40s_pkg::*;
  #(  parameter bit          DEBUG         = 1'b0,
      parameter bit          CLIC          = 1'b0,
      parameter int unsigned CLIC_ID_WIDTH = 5,
      parameter rv32_e       RV32          = RV32I
  )
(
  input logic           clk,
  input logic           rst_n,
  input logic           debug_mode_q,
  input ctrl_fsm_t      ctrl_fsm_o,
  input ctrl_byp_t      ctrl_byp_i,
  input logic           jump_taken_id,
  input logic           branch_in_ex,
  input logic           branch_taken_ex,
  input logic           branch_taken_q,
  input logic           branch_decision_ex_i,
  input ctrl_state_e    ctrl_fsm_cs,
  input ctrl_state_e    ctrl_fsm_ns,
  input logic [1:0]     lsu_outstanding_cnt,
  input mpu_status_e    mpu_status_wb_i,
  input logic           if_valid_i,
  input logic           id_valid_i,
  input if_id_pipe_t    if_id_pipe_i,
  input id_ex_pipe_t    id_ex_pipe_i,
  input ex_wb_pipe_t    ex_wb_pipe_i,
  input logic           ex_valid_i,
  input logic           wb_ready_i,
  input logic           mret_in_wb,
  input logic           exception_in_wb,
  input logic [10:0]    exception_cause_wb,
  input logic           rf_we_wb_i,
  input logic           csr_we_i,
  input logic           csr_illegal_i,
  input logic           pending_single_step,
  input logic           trigger_match_in_wb,
  input lsu_err_wb_t    lsu_err_wb_i,
  input logic           wb_valid_i,
  input logic           fencei_in_wb,
  input logic           fencei_flush_req_o,
  input logic           fencei_flush_ack_i,
  input logic           fencei_req_and_ack_q,
  input logic           pending_async_debug,
  input logic           pending_sync_debug,
  input logic           async_debug_allowed,
  input logic           sync_debug_allowed,
  input logic           pending_interrupt,
  input logic           interrupt_allowed,
  input logic           pending_nmi,
  input logic           nmi_allowed,
  input privlvl_t       priv_lvl_i,
  input privlvl_t       priv_lvl_n,
  input logic           sys_en_id_i,
  input logic           sys_wfi_insn_id_i,
  input logic           sys_wfe_insn_id_i,
  input logic           sys_mret_insn_id_i,
  input logic           lsu_busy_i,
  input logic           nmi_is_store_q,
  input logic           nmi_pending_q,
  input dcsr_t          dcsr_i,
  input logic           last_sec_op_id_i,
  input logic           sys_mret_id_i,
  input logic           lsu_trans_valid,
  input logic           irq_clic_shv_i,
  input logic           last_op_wb_i,
  input logic           abort_op_wb_i,
  input logic           csr_wr_in_wb_flush_i,
  input logic [2:0]     debug_cause_q,
  input logic           first_op_if_i,
  input logic           first_op_id_i,
  input logic           first_op_ex_i,
  input logic           last_op_id_i,
  input logic           ex_ready_i,
  input logic           id_ready_i,
  input logic           sequence_interruptible,
  input logic           sequence_in_progress_wb,
  input logic           id_stage_haltable,
  input logic           prefetch_valid_if_i,
  input logic           prefetch_is_tbljmp_ptr_if_i,
  input logic           prefetch_is_mret_ptr_if_i,
  input logic           prefetch_is_clic_ptr_if_i,
  input logic           abort_op_id_i,
  input mcause_t        mcause_i,
  input logic           lsu_trans_valid_i,
  input logic           irq_wu_ctrl_i,
  input logic           wu_wfe_i,
  input logic           wb_counter_event,
  input logic           mret_ptr_in_wb,
  input logic           clic_ptr_in_wb,
  input logic           csr_en_id_i,
  input logic           clic_ptr_in_progress_id_set,
  input logic           clic_ptr_in_progress_id,
  input pipe_pc_mux_e   pipe_pc_mux_ctrl,
  input logic           ptr_in_if_i,
  input logic           etrigger_in_wb,
  input logic           etrigger_wb_i,
  input logic [31:0]    wpt_match_wb_i,
  input logic           debug_req_i,
  input logic           fetch_enable_i,
  input logic           instr_req_o,
  input logic           instr_dbg_o,
  input logic           wfe_in_wb,
  input mstatus_t       mstatus_i,
  input logic           woke_to_interrupt_q,
  input logic           woke_to_debug_q,
  input logic           ebreak_in_wb,
  input mintstatus_t    mintstatus_i,
  input logic           exception_allowed,
  input logic           wfi_in_wb,
  input logic           fence_in_wb,
  input logic           dret_in_wb,
  input logic           csr_flush_ack_q,
  input logic           clic_ptr_in_id,
  input logic           mret_ptr_in_id,
  input logic           alu_jmpr_id_i,
  input logic [31:0]    jalr_fw_id_i,
  input logic [REGFILE_WORD_WIDTH-1:0] rf_mem_i [(RV32 == RV32I) ? 32 : 16],
  input logic [1:0]     response_filter_bus_cnt_q_i,
  input logic           non_shv_irq_ack
);


  // Back-to-back branch should not be possible due to kill of IF/ID stages after branch
  a_no_back_to_back_branch :
    assert property (@(posedge clk) disable iff (!rst_n)
                     (ctrl_fsm_o.pc_set && (ctrl_fsm_o.pc_mux == PC_BRANCH)) |=>
                    !(ctrl_fsm_o.pc_set && (ctrl_fsm_o.pc_mux == PC_BRANCH)))
      else `uvm_error("controller", "Two branches back-to-back are taken")


  // Helper signal
  logic jump_taken;
  assign jump_taken = (ctrl_fsm_o.pc_set && (ctrl_fsm_o.pc_mux == PC_JUMP)) ||
                      (ctrl_fsm_o.pc_set && (ctrl_fsm_o.pc_mux == PC_MRET));

  // Back-to-back jump should not be possible due to kill of IF stage after branch
  a_no_back_to_back_jump :
    assert property (@(posedge clk) disable iff (!rst_n)
                     jump_taken |=> !jump_taken)
      else `uvm_error("controller", "Two jumps back-to-back are taken")

  // Check that a jump is taken only when ID is not killed
  a_valid_jump :
    assert property (@(posedge clk)
                     jump_taken |-> if_id_pipe_i.instr_valid && !ctrl_fsm_o.kill_id)
      else `uvm_error("controller", "Jump taken while ID is killed")

  // Check that register used for JALR target calculation is stable from the jump is taken from ID until the JALR retires from WB.
  // Secure jumps write the link register twice, only checking when the first half (!ex_wb_pipe_i.last_sec_op) is in WB.
  // Excluding rs == x0, as dummies and hints implement actual flops (rf_mem_i[0] would give non-zero value).
  property p_jalr_stable_target;
    logic [4:0] jalr_rs_id;
    logic [31:0] rf_at_jump_id;
    @(posedge clk) disable iff (!rst_n)
      ((jump_taken && alu_jmpr_id_i && (|if_id_pipe_i.instr.bus_resp.rdata[19:15]),                                                               // When JALR is taken from ID,
        rf_at_jump_id = jalr_fw_id_i,                                                                                                            // Store (possibly forwarded) RF value used for target calculation
        jalr_rs_id = if_id_pipe_i.instr.bus_resp.rdata[19:15])                                                                                   // Store RS from JALR instruction
        ##1 (!(ctrl_fsm_o.kill_ex || ctrl_fsm_o.kill_wb) throughout (ex_wb_pipe_i.alu_jmp_qual && wb_valid_i && !ex_wb_pipe_i.last_sec_op)[->1]) // Wait for JALR to retire from WB (while not being killed)
        |-> rf_mem_i[jalr_rs_id][31:0] == rf_at_jump_id);                                                                 // Check that RF value is consistent with the value used for jump target calculation
  endproperty : p_jalr_stable_target

  a_jalr_stable_target: assert property(p_jalr_stable_target) else `uvm_error("controller", "Assertion a_jalr_stable_target failed");

  // Check that a JALR instruction which reads x0 gets zero as result on jalr_fw_id_i.
  property p_jalr_target_x0;
    logic [4:0] jalr_rs_id;
    logic [31:0] rf_at_jump_id;
    @(posedge clk) disable iff (!rst_n)
      (jump_taken && alu_jmpr_id_i && !(|if_id_pipe_i.instr.bus_resp.rdata[19:15])
      |->
      jalr_fw_id_i == 32'd0);

  endproperty : p_jalr_target_x0

  a_jalr_target_x0: assert property(p_jalr_target_x0) else `uvm_error("controller", "Assertion a_jalr_target_x0 failed");

  // Check that xret does not coincide with CSR write (to avoid using wrong return address)
  // This check is more strict than really needed; a CSR instruction would be allowed in EX as long
  // as its write action happens before the xret CSR usage
  property p_xret_csr;
    @(posedge clk) disable iff (!rst_n)
      (ctrl_fsm_o.pc_set && ((ctrl_fsm_o.pc_mux == PC_MRET) || (ctrl_fsm_o.pc_mux == PC_DRET))) |->
                                (!(ex_wb_pipe_i.instr_valid && ex_wb_pipe_i.csr_en && csr_we_i));
  endproperty

  a_xret_csr : assert property(p_xret_csr) else `uvm_error("controller", "Assertion a_xret_csr failed")

  // Ensure that debug state outputs are one-hot
  a_debug_state_onehot :
    assert property (@(posedge clk) disable iff (!rst_n)
                     $onehot({ctrl_fsm_o.debug_havereset, ctrl_fsm_o.debug_running, ctrl_fsm_o.debug_halted}))
      else `uvm_error("controller", "Assertion a_debug_state_onehot failed")

  // Ensure that debug_halted_o equals debug_mode_q
  a_debug_halted_equals_debug_mode :
    assert property (@(posedge clk) disable iff (!rst_n)
                     (1'b1) |-> (debug_mode_q == ctrl_fsm_o.debug_halted))
      else `uvm_error("controller", "Assertion a_debug_halted_equals_debug_mode failed")

  // Ensure no interrupt is taken if LSU has outstanding transactions
  a_no_irq_on_outstanding_obi :
    assert property (@(posedge clk) disable iff (!rst_n)
                      (ctrl_fsm_o.irq_ack) |-> (lsu_outstanding_cnt == 2'b00) )
      else `uvm_error("controller", "Interrupt taken while oustanding transactions are pending")

  // Ensure <stage>.instr_valid is zero following a kill_<prev_stage>

  // Support logic to indicate that IF has been killed, and not yet received a new instruction from the prefetcher
  logic kill_if_no_prefetch_valid;
  always_ff @(posedge clk, negedge rst_n) begin
    if(!rst_n) begin
      kill_if_no_prefetch_valid <= 1'b0;
    end
    else begin
      if (ctrl_fsm_o.kill_if) begin
        kill_if_no_prefetch_valid <= 1'b1;
      end
      else if (prefetch_valid_if_i) begin
        kill_if_no_prefetch_valid <= 1'b0;
      end
    end
  end

  // If IF is killed and ID is ready before a new instruction arrives, if_id_pipe_i.instr_valid must be 0
  a_kill_if :
  assert property (@(posedge clk) disable iff (!rst_n)
                    kill_if_no_prefetch_valid && $past(id_ready_i) |-> (if_id_pipe_i.instr_valid == 1'b0) )
    else `uvm_error("controller", "if_id_pipe_i.instr_valid not zero after kill_if")

  // If ID is killed, id_ex_pipe_i.instr_valid must be 0 following the next ex_ready_i
  a_kill_id :
  assert property (@(posedge clk) disable iff (!rst_n)
                    ctrl_fsm_o.kill_id ##0 ex_ready_i[->1] |=> (id_ex_pipe_i.instr_valid == 1'b0) )
    else `uvm_error("controller", "id_ex_pipe.instr_valid not zero after kill_id")

  a_kill_ex :
  assert property (@(posedge clk) disable iff (!rst_n)
                    (ctrl_fsm_o.kill_ex && !ctrl_fsm_o.halt_wb) |=> (ex_wb_pipe_i.instr_valid == 1'b0) )
    else `uvm_error("controller", "ex_wb_pipe.instr_valid not zero after kill_ex")

  a_kill_wb_rf :
  assert property (@(posedge clk) disable iff (!rst_n)
                    (ctrl_fsm_o.kill_wb) |-> (rf_we_wb_i == 1'b0) )
    else `uvm_error("controller", "regfile written when kill_wb is asserted")

  a_kill_wb_csr :
  assert property (@(posedge clk) disable iff (!rst_n)
                    (ctrl_fsm_o.kill_wb) |-> (!csr_we_i) )
    else `uvm_error("controller", "csr written while kill_wb is asserted")

  // Check that no stages have valid instructions using RESET
  a_reset_if_csr :
    assert property (@(posedge clk) disable iff (!rst_n)
            ((ctrl_fsm_cs == RESET)) |-> (!if_valid_i && !if_id_pipe_i.instr_valid && !id_ex_pipe_i.instr_valid && !ex_wb_pipe_i.instr_valid) )
      else `uvm_error("controller", "Instruction valid during RESET")

  // Check that no LSU insn can be in EX when there is a WFI or WFE in WB
  a_wfi_wfe_lsu_csr :
  assert property (@(posedge clk) disable iff (!rst_n)
          (ex_wb_pipe_i.sys_en && (ex_wb_pipe_i.sys_wfi_insn || ex_wb_pipe_i.sys_wfe_insn) && ex_wb_pipe_i.instr_valid) |-> !(id_ex_pipe_i.lsu_en) )
    else `uvm_error("controller", "LSU instruction follows WFI or WFE")

  // Check that lsu_err_wb_i==2'b01 (load error) can only be true when an LSU instruction is valid in WB
  // Not using wb_valid, as that is only active for the second half of misaligned.
  // bus error may also be active on the first half, thus checking only for active LSU in WB.
  a_lsu_load_err_wb :
    assert property (@(posedge clk) disable iff (!rst_n)
            (lsu_err_wb_i.bus_err &&                                 // Upon LSU error
             !lsu_err_wb_i.store)                                    // Which is not a store
            |-> ex_wb_pipe_i.instr_valid && ex_wb_pipe_i.lsu_en)  // There must be a valid LSU instruction in WB
      else `uvm_error("controller", "LSU load error in WB with no valid LSU instruction")

  // Check that lsu_err_wb_i==2'b11 (store error) can only be true when an LSU instruction is valid in WB, or there's an outstanding OBI transfer
  a_lsu_store_err_wb :
    assert property (@(posedge clk) disable iff (!rst_n)
            (lsu_err_wb_i.bus_err &&                                 // Upon LSU error on store
             lsu_err_wb_i.store)                                     // Which is a store
            |-> (ex_wb_pipe_i.instr_valid && ex_wb_pipe_i.lsu_en) // There must be a valid LSU instruction in WB
            ||  (response_filter_bus_cnt_q_i != '0))              // Or an outstanding transfer on the bus (taking buffered writes into account)
      else `uvm_error("controller", "LSU store error in WB with no valid LSU instruction or outstanding transfers on the bus")

  // Check that fencei handshake is only exercised when there is a fencei in the writeback stage
  a_fencei_hndshk_fencei_wb :
    assert property (@(posedge clk) disable iff (!rst_n)
           fencei_flush_req_o |-> fencei_in_wb)
      else `uvm_error("controller", "Fencei request when no fencei in writeback")

  // Assert that the fencei request is set the cycle after fencei instruction enters WB (if lsu_busy_i=0 and there are no higher priority events)
  // Only check when no higher priority event is pending (nmi, async debug or interrupts) and WB stage is not killed
  a_fencei_hndshk_req_when_fencei_wb :
    assert property (@(posedge clk) disable iff (!rst_n)
           $rose(fencei_in_wb && !lsu_busy_i) && !ctrl_fsm_o.kill_wb && !(pending_nmi || (pending_async_debug && async_debug_allowed) || (pending_interrupt && interrupt_allowed))
                     |=> $rose(fencei_flush_req_o))
      else `uvm_error("controller", "Fencei in WB did not result in fencei_flush_req_o")

  // Only clear fencei request when acknowledged
  //  ##1 is added to prevent $fell from triggering in cycle 1
  a_fencei_hndshk_ack_b4_req_clear :
    assert property (@(posedge clk) disable iff (!rst_n)
           ##1 $fell(fencei_flush_req_o) |-> $past(fencei_flush_ack_i))
      else `uvm_error("controller", "Fencei request cleared before ack")

  // Clearing of fencei_flush_req_o is always followed by wb_valid (meaning that the fence.i fully completed)
  //  ##1 is added to prevent $fell from triggering in cycle 1
  a_fencei_wb_valid :
    assert property (@(posedge clk) disable iff (!rst_n)
           ##1 $fell(fencei_flush_req_o) |-> wb_valid_i)
      else `uvm_error("controller", "Fencei handshake completion not followed by wb_valid")

  // assert that fencei_flush_req_o goes low the cycle after req&&ack
  a_fencei_clear_req :
    assert property (@(posedge clk) disable iff (!rst_n)
                     fencei_flush_req_o && fencei_flush_ack_i |=> !fencei_flush_req_o)
      else `uvm_error("controller", "fencei_flush_req_o not cleared after req&&ack")

  // assert no lingering fencei handshake when a fencei instruction enters WB.
  a_fencei_lingering_req :
    assert property (@(posedge clk) disable iff (!rst_n)
                     $rose(fencei_in_wb) |-> !(fencei_flush_req_o || fencei_req_and_ack_q))
      else `uvm_error("controller", "Fencei handshake not idle when fencei instruction entered writeback")

  // assert that the lsu_busy_i signal (i.e. write buffer empty) is always cleared when fencei handshake is active
  a_fencei_lsu_busy :
    assert property (@(posedge clk) disable iff (!rst_n)
                     fencei_flush_req_o |-> !lsu_busy_i)
      else `uvm_error("controller", "Fencei handshake active while lsu_busy_o = 1")

  // Check that mret in debug mode results in illegal instruction exception
  a_mret_dbg_mode_illegal :
    assert property (@(posedge clk) disable iff (!rst_n)
                     // Disregard higher priority exceptions and trigger match
                      !((ex_wb_pipe_i.instr.mpu_status != MPU_OK) || ex_wb_pipe_i.instr.bus_resp.err || trigger_match_in_wb) &&
                      // Check for mret in instruction word and debug mode
                      ((ex_wb_pipe_i.instr.bus_resp.rdata == 32'h30200073) && debug_mode_q && wb_valid_i)
                      |-> exception_in_wb && (exception_cause_wb == EXC_CAUSE_ILLEGAL_INSN))
      else `uvm_error("controller", "mret in debug mode not flagged as illegal")

  // Helper logic to make assertion look cleaner
  // Same logic as in the bypass module, but duplicated here to catch any changes in bypass
  // that could lead to undetected errors
  logic csrw_ex_wb;
  assign csrw_ex_wb = (
                        ((id_ex_pipe_i.csr_en || (id_ex_pipe_i.sys_en && id_ex_pipe_i.sys_mret_insn)) && id_ex_pipe_i.instr_valid) ||
                        ((ex_wb_pipe_i.csr_en || (ex_wb_pipe_i.sys_en && ex_wb_pipe_i.sys_mret_insn)) && ex_wb_pipe_i.instr_valid)
                      );

  // Detect if the last part of a secure mret is in ID while the first part is in EX or WB
  logic mret_self_stall;
  assign mret_self_stall = (sys_en_id_i && sys_mret_id_i && last_sec_op_id_i) && // MRET 2/2 in ID
                      ((id_ex_pipe_i.sys_en && id_ex_pipe_i.sys_mret_insn && !id_ex_pipe_i.last_op) || // mret 1/2 in EX
                       (ex_wb_pipe_i.sys_en && ex_wb_pipe_i.sys_mret_insn && !ex_wb_pipe_i.last_op));      // mret 1/2 in WB

  // Check that WFI is stalled in ID if CSR writes (explicit and implicit)
  // are present in EX or WB
  a_wfi_id_halt :
    assert property (@(posedge clk) disable iff (!rst_n)
                      ((sys_en_id_i && sys_wfi_insn_id_i) && if_id_pipe_i.instr_valid && csrw_ex_wb)
                      |-> (!id_valid_i && ctrl_fsm_o.halt_id))
      else `uvm_error("controller", "WFI not halted in ID when CSR write is present in EX or WB")

  // Check that WFE is stalled in ID if CSR writes (explicit and implicit)
  // are present in EX or WB
  a_wfe_id_halt :
  assert property (@(posedge clk) disable iff (!rst_n)
                    ((sys_en_id_i && sys_wfe_insn_id_i) && if_id_pipe_i.instr_valid && csrw_ex_wb)
                    |-> (!id_valid_i && ctrl_fsm_o.halt_id))
    else `uvm_error("controller", "WFI not halted in ID when CSR write is present in EX or WB")

  // Check that mret is stalled in ID if CSR writes (explicit and implicit)
  // are present in EX or WB. Exluding the case where the second part of an mret is in ID while the first part
  // is in either EX or WB.
  a_mret_id_halt :
    assert property (@(posedge clk) disable iff (!rst_n)
                      ((sys_en_id_i && sys_mret_insn_id_i) && if_id_pipe_i.instr_valid && (csrw_ex_wb && !mret_self_stall))
                      |-> (!id_valid_i && ctrl_fsm_o.halt_id))
      else `uvm_error("controller", "mret not halted in ID when CSR write is present in EX or WB")


  // mret_jump_id is used to update the priviledge level for the IF stage to mstatus.mpp, this check asserts
  // that there are no updates to mstatus.mpp (or any other CSR) in EX or WB
  a_mret_jump_id_csrw :
   assert property (@(posedge clk) disable iff (!rst_n)
                    ctrl_fsm_o.mret_jump_id |-> !(csrw_ex_wb && !mret_self_stall))
     else `uvm_error("controller", "Priviledge level updated by MRET in ID while CSR write is present in EX or WB")

  // mret in User mode must result in illegal instruction
  a_mret_umode :
    assert property (@(posedge clk) disable iff (!rst_n)
                      // Disregard higher priority exceptions and trigger match
                      !(((ex_wb_pipe_i.instr.mpu_status != MPU_OK) || ex_wb_pipe_i.instr.bus_resp.err || trigger_match_in_wb) && ex_wb_pipe_i.instr_valid) &&
                      // Check for mret in instruction word and user mode
                      ((ex_wb_pipe_i.instr.bus_resp.rdata == 32'h30200073) && ex_wb_pipe_i.instr_valid && (priv_lvl_i == PRIV_LVL_U))
                      |-> (exception_in_wb && (exception_cause_wb == EXC_CAUSE_ILLEGAL_INSN) && !(ex_wb_pipe_i.sys_en && ex_wb_pipe_i.sys_mret_insn)))
      else `uvm_error("controller", "mret in U-mode not flagged as illegal")

  // mret in machine mode must not result in illegal instruction, unless in debug mode where it is treated as an illegal instruction.
  // Disregarding all cases of earlier exceptions, trigger match or when WB contains a clic pointer (which may have the same encoding as an mret instruction)
  a_mret_mmode :
    assert property (@(posedge clk) disable iff (!rst_n)
                      // Disregard higher priority exceptions and trigger match
                      !(((ex_wb_pipe_i.instr.mpu_status != MPU_OK) || ex_wb_pipe_i.instr.bus_resp.err || trigger_match_in_wb) && ex_wb_pipe_i.instr_valid) &&
                      !(ex_wb_pipe_i.instr_meta.clic_ptr || ex_wb_pipe_i.instr_meta.mret_ptr) && !ctrl_fsm_o.debug_mode &&
                      // Check for mret in instruction word and user mode
                      ((ex_wb_pipe_i.instr.bus_resp.rdata == 32'h30200073) && ex_wb_pipe_i.instr_valid && (priv_lvl_i == PRIV_LVL_M))
                      |-> (!exception_in_wb && (ex_wb_pipe_i.sys_en && ex_wb_pipe_i.sys_mret_insn)))
      else `uvm_error("controller", "mret in M-mode flagged as illegal")

  // WFI in User mode with mstatus.tw==1 must result in illegal instruction
  a_wfi_tw_set_umode :
    assert property (@(posedge clk) disable iff (!rst_n)
                      // Disregard higher priority exceptions and trigger match
                      !(((ex_wb_pipe_i.instr.mpu_status != MPU_OK) || ex_wb_pipe_i.instr.bus_resp.err || trigger_match_in_wb) && ex_wb_pipe_i.instr_valid) &&
                      // Check for wfi in instruction word and user mode
                      ((ex_wb_pipe_i.instr.bus_resp.rdata == 32'h10500073) && ex_wb_pipe_i.instr_valid && (priv_lvl_i == PRIV_LVL_U) && mstatus_i.tw)
                      |-> (exception_in_wb && (exception_cause_wb == EXC_CAUSE_ILLEGAL_INSN) && !(ex_wb_pipe_i.sys_en && ex_wb_pipe_i.sys_wfi_insn)))
      else `uvm_error("controller", "WFI in U-mode with mstatus.tw set not flagged as illegal")

  // WFI in User mode with mstatus.tw==0 must not result in illegal instruction
  a_wfi_tw_clear_umode :
    assert property (@(posedge clk) disable iff (!rst_n)
                      // Disregard higher priority exceptions and trigger match, and debug as WFI masked during debug
                      !(((ex_wb_pipe_i.instr.mpu_status != MPU_OK) || ex_wb_pipe_i.instr.bus_resp.err || trigger_match_in_wb) && ex_wb_pipe_i.instr_valid) &&
                      !ctrl_fsm_o.debug_no_sleep &&
                      // Check for wfi in instruction word and user mode
                      ((ex_wb_pipe_i.instr.bus_resp.rdata == 32'h10500073) && ex_wb_pipe_i.instr_valid && (priv_lvl_i == PRIV_LVL_U) && !mstatus_i.tw)
                      |-> (!exception_in_wb && (ex_wb_pipe_i.sys_en && ex_wb_pipe_i.sys_wfi_insn)))
      else `uvm_error("controller", "WFI in U-mode with mstatus.tw set not flagged as illegal")

  // assert that NMI's are not reported on irq_ack
  // Exception for the case where the core wakes from SLEEP due to an interrupt
  //   - in that case the interrupt is honored while there may be a pending nmi.
  a_irq_ack_no_nmi :
    assert property (@(posedge clk) disable iff (!rst_n)
                     ctrl_fsm_o.irq_ack |-> !(pending_nmi && !woke_to_interrupt_q))
      else `uvm_error("controller", "irq_ack set while there's a pending NMI")


  // Assert that interrupts are not allowed when WB stage has an LSU
  // instruction (cnt_q != 0)
  a_block_interrupts:
    assert property (@(posedge clk) disable iff (!rst_n)
                     (ex_wb_pipe_i.instr_valid && ex_wb_pipe_i.lsu_en) |-> !interrupt_allowed)
      else `uvm_error("controller", "interrupt_allowed high while LSU is in WB")

  // Assert that debug is not allowed when WB stage has an LSU
  // instruction (cnt_q != 0) with no watchpoint match attached to it.

  a_block_debug:
    assert property (@(posedge clk) disable iff (!rst_n)
                     (ex_wb_pipe_i.instr_valid && ex_wb_pipe_i.lsu_en) && (ctrl_fsm_cs == FUNCTIONAL)
                     |->
                     !async_debug_allowed)
      else `uvm_error("controller", "debug_allowed high while LSU is in WB")

  // Assert that branches (that are not already taken) are always taken in the first cycle of EX, unless EX is killed or halted
  // What we really want to check with this assertion is that a branch taken always results
  // in a pc_set to PC_BRANCH.
  // If the branch is not taken in the first cycle of EX, caution must be taken to avoid e.g. a jump in
  // ID taking presedence over the branch in EX.

  a_branch_in_ex_taken_first_cycle:
    assert property (@(posedge clk) disable iff (!rst_n)
                     ($rose(branch_in_ex && branch_decision_ex_i) && !branch_taken_q && !(ctrl_fsm_o.halt_ex || ctrl_fsm_o.kill_ex) |->
                      ctrl_fsm_o.pc_set && (ctrl_fsm_o.pc_mux == PC_BRANCH) &&
                      ctrl_fsm_o.kill_if &&
                      (SECURE ? 1'b1 : ctrl_fsm_o.kill_id))); // For SECURE=1, branch instructions are bot in ID and EX when branch is taken, do not kill ID.

  // When flushing the pipeline due to CSR updates in WB, make sure there we don't initiate transactions on the data interface
  // and that there are no outstanding transactions from the LSU point of view.
  // There might still be outstanding transactions in the write buffer, which is why we can't check that data_req_o==0
  a_csr_wr_in_wb_flush_no_obi:
    assert property (@(posedge clk) disable iff (!rst_n)
                     (csr_wr_in_wb_flush_i) |-> (lsu_outstanding_cnt == 2'b00) && !lsu_trans_valid)
      else `uvm_error("controller", "Flushing pipeline when the LSU have outstanding transactions")

  // Assert that we don't count dummy instruction retirements
  // Events caused by the dummy instruction shoud be suppressed
  a_not_counting_dummy_instr :
    assert property (@(posedge clk) disable iff (!rst_n)
                     (ex_wb_pipe_i.instr_meta.dummy |-> !(ctrl_fsm_o.mhpmevent.minstret)))
                     else `uvm_error("controller", "Dummy instruction retirement counted")

  // Assert that we count hint instruction retirements
  // Events caused by the hint instruction should not be suppressed
  a_counting_hint_instr :
    assert property (@(posedge clk) disable iff (!rst_n)
                    (ex_wb_pipe_i.instr_meta.hint && ex_wb_pipe_i.last_op && ex_wb_pipe_i.instr_valid) |-> wb_counter_event)
                    else `uvm_error("controller", "Hint instruction retirement not counted")

  // Dummy instructions should never have synchronous exceptions
  a_no_sync_exception_on_dummy_inst:
    assert property (@(posedge clk) disable iff (!rst_n)
                     (ex_wb_pipe_i.instr_meta.dummy |-> !exception_in_wb))
      else `uvm_error("wb_stage", "Dummy instructions had synchronous exception")


  // Ensure bubble in EX while in SLEEP mode.
  // WFI or WFE instruction will be in WB
  // Bubble is needed to avoid any LSU instructions to go on the bus while handling the WFI, as this
  // could cause the pipeline not to be interruptible when we wake up to an interrupt that should be taken.
  a_wfi_wfe_bubbles:
    assert property (@(posedge clk) disable iff (!rst_n)
                      (ctrl_fsm_cs == SLEEP)
                      |->
                      !(id_ex_pipe_i.instr_valid) && ((ex_wb_pipe_i.sys_en && ex_wb_pipe_i.instr_valid && (ex_wb_pipe_i.sys_wfi_insn || ex_wb_pipe_i.sys_wfe_insn))))
      else `uvm_error("controller", "EX stage not empty while in SLEEP state")

  // When halt_limited_wb is asserted, there can only be WFI instruction in WB
  a_halt_limited_wfi:
    assert property (@(posedge clk) disable iff (!rst_n)
                      (ctrl_fsm_o.halt_limited_wb) |-> (ex_wb_pipe_i.sys_en && (ex_wb_pipe_i.sys_wfi_insn || ex_wb_pipe_i.sys_wfe_insn) && ex_wb_pipe_i.instr_valid))
      else `uvm_error("controller", "No WFI or WFE in WB while halt_limited_wb is asserted")

  // Check that the pipeline is interruptible when we wake up from SLEEP
  a_wakeup_interruptible:
    assert property (@(posedge clk) disable iff (!rst_n)
                      (ctrl_fsm_cs == SLEEP) && (ctrl_fsm_ns == FUNCTIONAL)
                      |=>
                      interrupt_allowed)
      else `uvm_error("controller", "Pipeline not interruptible after waking from SLEEP")

  // When entering or in SLEEP mode, no LSU should perform a request.
  a_enter_sleep_no_lsu:
    assert property (@(posedge clk) disable iff (!rst_n)
                      (ctrl_fsm_cs == SLEEP) || (ctrl_fsm_ns == SLEEP)
                      |=>
                      !lsu_trans_valid_i)
      else `uvm_error("controller", "LSU trans_valid high when entering or in SLEEP")


  // WFI cannot wake up to wu_wfe_i pin
  // Disregarding debug related reasons to wake up
  a_no_wfi_wakeup_on_wfe:
  assert property (@(posedge clk) disable iff (!rst_n)
                    (ctrl_fsm_cs == SLEEP) && ex_wb_pipe_i.instr_valid && ex_wb_pipe_i.sys_en && ex_wb_pipe_i.sys_wfi_insn &&
                    !(irq_wu_ctrl_i || pending_nmi) && wu_wfe_i && !pending_async_debug
                    |=>
                    (ctrl_fsm_cs == SLEEP))
    else `uvm_error("controller", "WFI instruction woke up to wu_wfe_i")

  // WFE wakes up to either interrupts (including NMI) or wu_wfe_i
  // Disregarding debug related reasons to wake up
  a_wfe_wakeup:
  assert property (@(posedge clk) disable iff (!rst_n)
                    (ctrl_fsm_cs == SLEEP) && ex_wb_pipe_i.instr_valid && ex_wb_pipe_i.sys_en && ex_wb_pipe_i.sys_wfe_insn &&
                    (irq_wu_ctrl_i || wu_wfe_i || pending_nmi) && !pending_async_debug
                    |->
                    (ctrl_fsm_ns == FUNCTIONAL))
    else `uvm_error("controller", "WFE must wake up to interuppts or wu_wfe_i")

  // Assert correct exception cause for mpu load faults (checks default of cause mux)
  a_mpu_re_cause_mux:
    assert property (@(posedge clk) disable iff (!rst_n)
                      (mpu_status_wb_i == MPU_RE_FAULT) |-> (exception_cause_wb == EXC_CAUSE_LOAD_FAULT))
      else `uvm_error("controller", "Wrong exception cause for MPU read fault")


  // Helper logic to track first occuring bus error
  // Note: Supports max two outstanding transactions
  logic [1:0] outstanding_type;
  logic [1:0] outstanding_count;
  logic bus_error_is_write;
  logic bus_error_latched;
  logic retire_at_error; // 1 if wb_valid_i is high when the bus error is active
  always_ff @(posedge clk, negedge rst_n) begin
    if (rst_n == 1'b0) begin
      outstanding_type <= 2'b00;
      outstanding_count <= 2'b00;
      bus_error_latched <= 1'b0;
      bus_error_is_write <= 1'b0;
      retire_at_error <= 1'b0;
    end else begin
      // Req, no rvalid
      if (m_c_obi_data_if.s_req.req && m_c_obi_data_if.s_gnt.gnt && !m_c_obi_data_if.s_rvalid.rvalid) begin
        // Increase outstanding counter
        outstanding_count <= outstanding_count + 2'b01;

        if (outstanding_count == 2'b00) begin
          // No outstanding, assign first entry
          outstanding_type[0] <= m_c_obi_data_if.req_payload.we;
        end else begin
          // One outstanding, shift and assign first entry
          outstanding_type[1] <= outstanding_type[0];
          outstanding_type[0] <= m_c_obi_data_if.req_payload.we;
        end

      // rvalid, no req
      end else if (!(m_c_obi_data_if.s_req.req && m_c_obi_data_if.s_gnt.gnt) && m_c_obi_data_if.s_rvalid.rvalid) begin
        // Decrease outstanding counter
        outstanding_count <= outstanding_count - 2'b01;

      // req and rvalid
      end else if ((m_c_obi_data_if.s_req.req && m_c_obi_data_if.s_gnt.gnt) && m_c_obi_data_if.s_rvalid.rvalid) begin
        if (outstanding_count == 2'b10) begin
          // Two outstanding, shift and replace index 0
          outstanding_type[1] <= outstanding_type[0];
          outstanding_type[0] <= m_c_obi_data_if.req_payload.we;
        end else begin
          // One outstanding, replate index 0
          outstanding_type[0] <= m_c_obi_data_if.req_payload.we;
        end
      end


      if (m_c_obi_data_if.s_rvalid.rvalid && m_c_obi_data_if.resp_payload.err && !bus_error_latched) begin
        bus_error_is_write <= outstanding_count == 2'b01 ? outstanding_type[0] : outstanding_type[1];
        bus_error_latched <= 1'b1;
        retire_at_error <= wb_valid_i;
      end else begin
        if (ctrl_fsm_o.pc_set && ctrl_fsm_o.pc_mux == PC_TRAP_NMI) begin
          bus_error_latched <= 1'b0;
        end
      end
    end
  end

  // Check that controller latches correct type for bus error
  a_latched_bus_error:
    assert property (@(posedge clk) disable iff (!rst_n)
                      (m_c_obi_data_if.s_rvalid.rvalid && m_c_obi_data_if.resp_payload.err && !bus_error_latched)
                      |=> (nmi_is_store_q == bus_error_is_write) &&
                          (nmi_pending_q == bus_error_latched) && bus_error_latched)
      else `uvm_error("controller", "Wrong type for LSU bus error")



  // Helper logic. Counting number of retired instructions while an NMI is pending outside of debug mode or single stepping.
  logic [1:0] valid_cnt;
  always_ff @(posedge clk, negedge rst_n) begin
    if (rst_n == 1'b0) begin
      valid_cnt <= '0;
    end else begin
      if (bus_error_latched) begin
        if (wb_valid_i && (last_op_wb_i || abort_op_wb_i) && !ctrl_fsm_o.debug_mode && !(dcsr_i.step && !dcsr_i.stepie)) begin
          valid_cnt <= valid_cnt + 1'b1;
        end
      end else begin
        valid_cnt <= '0;
      end
    end
  end

  // valid_cnt will start counting one cycle after the LSU bus error has
  // become visible to the core. If an instruction was retired (wb_valid=1)
  // when the bus error arrived, we will allow one more instruction to retire
  // before the NMI is taken (counter < 2). If we didn't retire at the same time as the bus
  // error, we allow two instructions to retire (counter < 3). In any case, max two
  // instructions will retire after the bus error has become visible to the
  // core.
  a_nmi_handler_max_retire:
    assert property (@(posedge clk) disable iff (!rst_n)
                    (valid_cnt < (retire_at_error ? 2'b10 : 2'b11)))
    else `uvm_error("controller", "NMI handler not taken within two instruction retirements")

if (CLIC) begin

  // After a pc_set to PC_TRAP_CLICV, only the following jump targets are allowed:
  // PC_POINTER : Normal execution, the pointer target is being fetched
  // PC_TRAP_EXC: The pointer fetch has a synchronous exception
  // PC_TRAP_NMI: A buffered write may receive a data_err_i long after the instruction has left WB.
  a_clicv_next_pc_set:
  assert property (@(posedge clk) disable iff (!rst_n)
                  (ctrl_fsm_o.pc_set && (ctrl_fsm_o.pc_mux == PC_TRAP_CLICV))
                  |=> !ctrl_fsm_o.pc_set until (ctrl_fsm_o.pc_set && ((ctrl_fsm_o.pc_mux == PC_POINTER)        ||
                                                                      (ctrl_fsm_o.pc_mux == PC_TRAP_EXC)       ||
                                                                      (ctrl_fsm_o.pc_mux == PC_TRAP_NMI))))
    else `uvm_error("controller", "Illegal pc_mux after pointer fetch")


  a_clic_ptr_functional_only:
  assert property (@(posedge clk) disable iff (!rst_n)
                  ((ctrl_fsm_cs != FUNCTIONAL)
                  |->
                  !(mret_ptr_in_wb || clic_ptr_in_wb)))
    else `uvm_error("controller", "clic_ptr_in_wb or mret_ptr_in_wb while not in FUNCTIONAL state.")

  // Killing the ID stage should never happen if the ID stage is waiting for a CLIC pointer
  a_clic_ptr_in_progress_no_kill:
  assert property (@(posedge clk) disable iff (!rst_n)
                  clic_ptr_in_progress_id
                  |->
                  !ctrl_fsm_o.kill_id)
    else `uvm_error("controller", "ID stage killed while clic_ptr_in_progress_id is high")

  a_nmi_irq_level_stable:
  assert property (@(posedge clk) disable iff (!rst_n)
                  (ctrl_fsm_o.pc_set && (ctrl_fsm_o.pc_mux == PC_TRAP_NMI))
                  |=>
                  $stable(mintstatus_i))
    else `uvm_error("controller", "mintstatus changed after taking an NMI")

  // Check that unused bits of ctrl_fsm.mtvt_pc_mux is zero
  if (CLIC_ID_WIDTH < 10) begin
    a_unused_mtvt_bits:
    assert property (@(posedge clk) disable iff (!rst_n)
                    |ctrl_fsm_o.mtvt_pc_mux[9:CLIC_ID_WIDTH] == 1'b0)
      else `uvm_error("controller", "Unused bits of ctrl_fsm_o.mtvt_pc_mux is not zero")
  end

end else begin // CLIC
  // Check that CLIC related signals are inactive when CLIC is not configured.
  a_clic_inactive:
  assert property (@(posedge clk) disable iff (!rst_n)
                  1'b1
                  |->
                  (clic_ptr_in_progress_id_set != 1'b1)     &&
                  !ctrl_fsm_o.csr_cause.minhv       &&
                  !mcause_i.minhv                   &&
                  !if_id_pipe_i.instr_meta.clic_ptr &&
                  !id_ex_pipe_i.instr_meta.clic_ptr &&
                  !ex_wb_pipe_i.instr_meta.clic_ptr &&
                  !if_id_pipe_i.instr_meta.mret_ptr &&
                  !id_ex_pipe_i.instr_meta.mret_ptr &&
                  !ex_wb_pipe_i.instr_meta.mret_ptr &&
                  !ctrl_fsm_o.pc_set_clicv          &&
                  !(|ctrl_fsm_o.irq_level)          &&
                  !ctrl_fsm_o.irq_shv               &&
                  !(|ctrl_fsm_o.irq_priv) )
    else `uvm_error("controller", "CLIC signals active when CLIC is not configured.")
end



  // Detect if we are in the middle of a multi operation sequence
  // Basically check if the oldest instruction in the pipeline is a 'first_op'
  // - if not, we have an unfinished sequence and cannot interrupt it.
  // Used to determine if we are allowed to take debug or interrupts
  logic sequence_interruptible_alt;
  always_comb begin
    // Excluding the case of the current state being DEBUG_TAKEN. In this state, we may have a
    // lsu instruction in WB with !first_op if this instruction caused a watchpoint trigger.
    // The controller will reset the flop based flag when this is detected and the code below
    // would not match if not detecting the same case.
    if (ex_wb_pipe_i.instr_valid && (ctrl_fsm_cs == DEBUG_TAKEN)) begin
      sequence_interruptible_alt = 1'b1;
    end else if (ex_wb_pipe_i.instr_valid) begin
      sequence_interruptible_alt = ex_wb_pipe_i.first_op;
    end else if (id_ex_pipe_i.instr_valid) begin
      sequence_interruptible_alt = first_op_ex_i;
    end else if (if_id_pipe_i.instr_valid) begin
      sequence_interruptible_alt = first_op_id_i;
    end else if (prefetch_valid_if_i) begin
      sequence_interruptible_alt = first_op_if_i;
    end else begin
      // If no instruction is ready in the whole pipeline (including IF), then there are nothing in progress
      // and we should safely be able to interrupt unless the IF stage is waiting for a table jump pointer or
      // a CLIC pointer that is a side effect of an mret.
      sequence_interruptible_alt = !(prefetch_is_tbljmp_ptr_if_i || prefetch_is_mret_ptr_if_i);
    end
  end

  // Check if we are allowed to halt the ID stage.
  // If ID stage contains a non-first, non-aborted operation, we cannot halt ID as that
  // could cause a deadlock because a sequence cannot finish through ID.
  logic id_stage_haltable_alt;
  always_comb begin
    if (if_id_pipe_i.instr_valid) begin
      id_stage_haltable_alt = first_op_id_i || if_id_pipe_i.abort_op;
    end else begin
      // If no instruction is ready in ID, then there is nothing in progress
      // and we should safely be able to halt ID unless the IF stage is waiting for a table jump pointer,
      // mret pointer or CLIC pointer
      id_stage_haltable_alt = !(prefetch_is_tbljmp_ptr_if_i || prefetch_is_mret_ptr_if_i || prefetch_is_clic_ptr_if_i);
    end
  end

  a_no_sequence_interrupt:
  assert property (@(posedge clk) disable iff (!rst_n)
                    (!sequence_interruptible |-> !ctrl_fsm_o.irq_ack))
    else `uvm_error("controller", "Sequence broken by interrupt")

  a_interruptible_equivalency:
  assert property (@(posedge clk) disable iff (!rst_n)
                    (sequence_interruptible_alt == sequence_interruptible))
    else `uvm_error("controller", "first_op_done_wb not matching !sequence_interruptible")

  a_no_sequence_nmi:
  assert property (@(posedge clk) disable iff (!rst_n)
                    (!sequence_interruptible |-> !(ctrl_fsm_o.pc_set && (ctrl_fsm_o.pc_mux == PC_TRAP_NMI))))
    else `uvm_error("controller", "Sequence broken by NMI")

  // A sequence that is in progress with no exception on the operation currently in WB can only enter debug mode
  // due to finishing the instruction if single stepped, or a watchpoint trigger fired on the operation in WB.
  a_no_exc_no_sequence_debug:
  assert property (@(posedge clk) disable iff (!rst_n)
                    sequence_in_progress_wb && // Sequence is in progress (first_op done in WB)
                    !exception_in_wb           // Operation in WB has no exception
                    |=>
                    !ctrl_fsm_o.dbg_ack ||    // Cannot take debug
                    (((debug_cause_q == DBG_CAUSE_TRIGGER) && |wpt_match_wb_i && !sequence_in_progress_wb) || // Unless we have a watchpoint trigger
                     ((debug_cause_q == DBG_CAUSE_STEP) && $past(last_op_wb_i) && !sequence_in_progress_wb))) // Or we finished single stepping the instruction
    else `uvm_error("controller", "Sequence broken by non-watchpoint debug when no exception occurred")

  // A sequence that is in progress and the operation currently in WB has an exception can only enter debug because
  // of an exception trigger fired or the instruction is being stepped and the exception caused debug reentry.
  a_exc_no_sequence_debug:
  assert property (@(posedge clk) disable iff (!rst_n)
                    sequence_in_progress_wb && // Sequence is in progress (first_op done in WB)
                    exception_in_wb            // Operation in WB has an exception
                    |=>
                    !ctrl_fsm_o.dbg_ack ||    // Cannot take debug
                    (((debug_cause_q == DBG_CAUSE_TRIGGER) && $past(etrigger_wb_i) && !sequence_in_progress_wb) || // Unless we took an exception trigger
                     ((debug_cause_q == DBG_CAUSE_STEP) && $past(abort_op_wb_i) && !sequence_in_progress_wb)))     // Or a stepped instruction finished due to the exception
    else `uvm_error("controller", "Sequence broken by debug entry when exception occurred.")

  a_no_sequence_wb_kill:
  assert property (@(posedge clk) disable iff (!rst_n)
                    (sequence_in_progress_wb |-> !ctrl_fsm_o.kill_wb))
    else `uvm_error("controller", "WB killed while sequence was in progress")

  // Check that we do not allow ID stage to be halted for pending interrupts/debug if a sequence is not done
  // in the ID stage.
  a_id_stage_haltable:
  assert property (@(posedge clk) disable iff (!rst_n)
                    (id_stage_haltable |-> id_stage_haltable_alt))
    else `uvm_error("controller", "id_stage_haltable not correct")

  // Assert that we have no pc_set in the same cycle as a CSR write in WB requires flushing of the pipeline
  a_csr_wr_in_wb_no_fetch:
  assert property (@(posedge clk) disable iff (!rst_n)
                    (csr_wr_in_wb_flush_i && !ctrl_fsm_o.kill_wb) |-> (!ctrl_fsm_o.pc_set))
    else `uvm_error("controller", "Fetching new instruction before CSR values are updated")

  // Check that id stage is haltable after passing through an operation with abort_op=1
  a_id_halt_abort:
  assert property (@(posedge clk) disable iff (!rst_n)
                    (id_valid_i && ex_ready_i && abort_op_id_i)
                    |=>
                    id_stage_haltable)
    else `uvm_error("controller", "ID stage not haltable after a deasserted operation")

  // Check that wb stage is interruptible after passing through an operation with exception_in_wb
  a_wb_interruptible_abort:
  assert property (@(posedge clk) disable iff (!rst_n)
                    (wb_valid_i && abort_op_wb_i)
                    |=>
                    sequence_interruptible)
    else `uvm_error("controller", "sequence_interruptible should be 1 after an exception has been taken.")


  // Check that id stage is haltable after passing through an operation with abort_op=1
  a_id_halt_last:
  assert property (@(posedge clk) disable iff (!rst_n)
                    (id_valid_i && ex_ready_i && last_op_id_i)
                    |=>
                    id_stage_haltable)
    else `uvm_error("controller", "ID stage not haltable after a deasserted operation")

  // Check that wb stage is interruptible after passing through an operation with exception_in_wb
  a_wb_interruptible_last:
  assert property (@(posedge clk) disable iff (!rst_n)
                    (wb_valid_i && last_op_wb_i)
                    |=>
                    sequence_interruptible)
    else `uvm_error("controller", "sequence_interruptible should be 1 after an exception has been taken.")

  // No new exception may occur in WB unless wb was ready the cycle before
  a_wb_ready_exception:
  assert property (@(posedge clk) disable iff (!rst_n)
                    (!wb_ready_i)
                    |=>
                    $stable(exception_in_wb))
    else `uvm_error("controller", "New exception in WB without WB being ready.")


  // MRET in WB always results in cst_restore_mret being set
  a_mret_in_wb_csr_restore_mret:
  assert property (@(posedge clk) disable iff (!rst_n)
                    (mret_in_wb && wb_valid_i) |-> ctrl_fsm_o.csr_restore_mret)
    else `uvm_error("controller", "MRET in WB did not result in csr_restore_mret.")


  // No CSR should be updated during sleep, and hence no irq_enable_stall should be active.
  a_no_irq_write_during_sleep:
  assert property (@(posedge clk) disable iff (!rst_n)
                    (ctrl_fsm_cs == SLEEP) |-> !ctrl_byp_i.irq_enable_stall)
    else `uvm_error("controller", "irq_enable_stall while SLEEPING should not happen.")

  // Handling of mret in ID requires mcause.minhv to be stable
  // This assertion checks that both operations of secure mrets in ID see the same mcause.minhv.
  a_mret_id_ex_minhv_stable:
  assert property (@(posedge clk) disable iff (!rst_n)
                    (id_valid_i && ex_ready_i && sys_en_id_i && sys_mret_id_i)
                    |=>
                    $stable(mcause_i.minhv))
    else `uvm_error("controller", "mcause.minhv not stable when mret goes from ID to EX")

  a_mret_ex_wb_minhv_stable:
  assert property (@(posedge clk) disable iff (!rst_n)
                    (ex_valid_i && wb_ready_i && id_ex_pipe_i.sys_en && id_ex_pipe_i.sys_mret_insn)
                    |=>
                    $stable(mcause_i.minhv))
    else `uvm_error("controller", "mcause.minhv not stable when mret goes from EX to WB")


  //  mret CSR restores are done in parallell with other events in the controller except for nmi/interrupt/debug entries.
  // Check that CSR restores for mret cannot happen while the WB stage is halted.
  a_mret_restore_halt:
  assert property (@(posedge clk) disable iff (!rst_n)
                  ctrl_fsm_o.csr_restore_mret
                  |->
                  !ctrl_fsm_o.halt_wb)
  else `uvm_error("controller", "csr_restore_mret when WB is halted")



  // When interrupts or debug is taken, the PC stored to dpc or mepc cannot come from a pointer
  a_no_context_from_pointer:
  assert property (@(posedge clk) disable iff (!rst_n)
                  (ctrl_fsm_o.dbg_ack || ctrl_fsm_o.irq_ack || (ctrl_fsm_o.pc_set && (ctrl_fsm_o.pc_mux == PC_TRAP_NMI)))
                  |->
                  !(((pipe_pc_mux_ctrl == PC_WB) && (ex_wb_pipe_i.instr_meta.clic_ptr || ex_wb_pipe_i.instr_meta.mret_ptr || (ex_wb_pipe_i.instr_meta.tbljmp && ex_wb_pipe_i.last_op))) ||
                    ((pipe_pc_mux_ctrl == PC_EX) && (id_ex_pipe_i.instr_meta.clic_ptr || id_ex_pipe_i.instr_meta.mret_ptr || (id_ex_pipe_i.instr_meta.tbljmp && id_ex_pipe_i.last_op))) ||
                    ((pipe_pc_mux_ctrl == PC_ID) && (if_id_pipe_i.instr_meta.clic_ptr || if_id_pipe_i.instr_meta.mret_ptr || (if_id_pipe_i.instr_meta.tbljmp && last_op_id_i))) ||
                    ((pipe_pc_mux_ctrl == PC_IF) && ptr_in_if_i)))
  else `uvm_error("controller", "Pointer used for context storage")


  // Ensure interrupt is taken if woken up by an interrupt (unless a higher priority NMI or debug request woke up the core)
  a_sleep_to_irq:
  assert property (@(posedge clk) disable iff (!rst_n)
                  (ctrl_fsm_cs == SLEEP) &&
                  (ctrl_fsm_ns == FUNCTIONAL) &&
                  irq_wu_ctrl_i &&
                  !(pending_nmi || debug_req_i) &&
                  mstatus_i.mie
                  |=>
                  (ctrl_fsm_o.pc_mux == PC_TRAP_IRQ) || (ctrl_fsm_o.pc_mux == PC_TRAP_CLICV))
    else `uvm_error("controller", "Woke from sleep due to irq but irq not taken")

  // Ensure NMI is taken if woken up by an NMI
  a_sleep_to_nmi:
  assert property (@(posedge clk) disable iff (!rst_n)
                  (ctrl_fsm_cs == SLEEP) &&
                  (ctrl_fsm_ns == FUNCTIONAL) &&
                  pending_nmi
                  |=>
                  (ctrl_fsm_o.pc_mux == PC_TRAP_NMI))
    else `uvm_error("controller", "Woke from sleep due to NMI but NMI not taken")

  // woke_to_interrupt_q shall only be high for a single cycle
  a_woke_to_interrupt_single_cycle:
  assert property (@(posedge clk) disable iff (!rst_n)
                  woke_to_interrupt_q
                  |=>
                  !woke_to_interrupt_q)
    else `uvm_error("controller", "woke_to_interrupt_q asserted for more than one cycle")

  // Make sure no synchronous events are missed during RESET state
  a_no_event_during_reset:
  assert property (@(posedge clk) disable iff (!rst_n)
                  (ctrl_fsm_cs == RESET)
                  |->
                  !((pending_sync_debug && sync_debug_allowed)                  ||
                    (exception_in_wb && exception_allowed)                      ||
                    (wfi_in_wb || wfe_in_wb)                                    ||
                    (fence_in_wb || fencei_in_wb)                               ||
                    (dret_in_wb)                                                ||
                    (csr_wr_in_wb_flush_i)                                      ||
                    (csr_flush_ack_q)                                           ||
                    (branch_taken_ex)                                           ||
                    (jump_taken_id)                                             ||
                    (clic_ptr_in_id || mret_ptr_in_id)                          ||
                    (mret_in_wb || mret_ptr_in_wb)                              ||
                    (clic_ptr_in_wb)                                            ||
                    (pending_single_step || etrigger_in_wb)                     ||
                    (clic_ptr_in_id && id_valid_i && ex_ready_i)                ||
                    (mret_in_wb && !ctrl_fsm_o.kill_wb)                         ||
                    (mret_ptr_in_wb && !ctrl_fsm_o.kill_wb && !exception_in_wb) ||
                    (clic_ptr_in_wb && !ctrl_fsm_o.kill_wb && !exception_in_wb)))
    else `uvm_error("controller", "Synchronous event during RESET")

  // Make sure no synchronous events are missed during SLEEP state
  // During SLEEP, either a WFE of WFI instruction must be in WB
  // jump_taken_id is excluded below on purpose. This event may be true
  // while in sleep (condition was true at the time of WFI/WFE in WB and will be kept true
  // until SLEEP is exited).
  a_no_event_during_sleep:
  assert property (@(posedge clk) disable iff (!rst_n)
                  (ctrl_fsm_cs == SLEEP)
                  |->
                  (wfi_in_wb || wfe_in_wb) &&
                  !((pending_sync_debug && sync_debug_allowed)                  ||
                    (exception_in_wb && exception_allowed)                      ||
                    (fence_in_wb || fencei_in_wb)                               ||
                    (dret_in_wb)                                                ||
                    (csr_wr_in_wb_flush_i)                                      ||
                    (csr_flush_ack_q)                                           ||
                    (branch_taken_ex)                                           ||
                  //(jump_taken_id)                                             || // Left in on purpose, see a_stable_id_sleep
                    (clic_ptr_in_id || mret_ptr_in_id)                          ||
                    (mret_in_wb || mret_ptr_in_wb)                              ||
                    (clic_ptr_in_wb)                                            ||
                    (pending_single_step || etrigger_in_wb)                     ||
                    (clic_ptr_in_id && id_valid_i && ex_ready_i)                ||
                    (mret_in_wb && !ctrl_fsm_o.kill_wb)                         ||
                    (mret_ptr_in_wb && !ctrl_fsm_o.kill_wb && !exception_in_wb) ||
                    (clic_ptr_in_wb && !ctrl_fsm_o.kill_wb && !exception_in_wb)))
    else `uvm_error("controller", "Synchronous event during SLEEP")

  // Check that the if_id_pipe and jump_taken_id are stable when the FSM
  // is in the SLEEP state, just went from FUNCTIONAL to SLEEP or just went from
  // SLEEP to FUNCTIONAL.
  a_stable_id_sleep:
  assert property (@(posedge clk) disable iff (!rst_n)
                  ((ctrl_fsm_cs == SLEEP) ||
                   ((ctrl_fsm_cs == SLEEP) && ($past(ctrl_fsm_cs) == FUNCTIONAL)) ||
                   ((ctrl_fsm_cs == FUNCTIONAL) && ($past(ctrl_fsm_cs) == SLEEP)))
                   |->
                   $stable(if_id_pipe_i) && $stable(jump_taken_id))
    else `uvm_error("controller", "if_id_pipe or jump_taken_id not stable during SLEEP or transition to/from SLEEP")



  // Make sure no synchronous events are missed during DEBUG_TAKEN state caused by non-single-step
  // The following events may be active, and must be killed during DEBUG_TAKEN
  //   - Exceptions will be killed, unless they raised an ETRIGGER (RVFI needs the rvfi_valid)
  //   - WFI/WFE will be killed
  //   - fence[i] will be killed
  //   - CSR instructions requiring pipeline flush will be killed
  //   - Branches in EX will be killed
  //   - Jumps in ID will be killed
  //   - mret pointers in ID will be killed (unless the mret instruction itself finished in WB, then debug will not be allowed at all.)
  //   - mret instructions in WB will be killed.

  // The following events cannot be active during DEBUG_TAKEN:
  //   - dret instructions cannot be in WB while in DEBUG_TAKEN (will be an illegal instruction exception instead)
  //   - csr_flush_ack_q - Handshake flag one cycle after csr_wr_in_wb_flush_i.
  //   - CLIC pointer in ID: When a CLIC pointer is in the pipeline, debug is not allowed
  //   - mret or CLIC pointers in WB, debug is not allowed when these events are active.

  // pending_single step may be true for the following conditions, but will not affect the debug cause (debug cause was decided during the previous cycle)
  //   - An NMI occured (may happen at any time, and may assert pending_single_step even though we're currently handling another debug entry)
  //   - WB is not killed during DEBUG_TAKEN. This will only happen for entries due to trigger match or ebreak

  // pending_sync_debug and etrigger may be active as they may be the cause of debug entry and kept stable due to halting when going into DEBUG_TAKEN.
  a_no_event_during_debug_taken_nonstep:
  assert property (@(posedge clk) disable iff (!rst_n)
                  (ctrl_fsm_cs == DEBUG_TAKEN) &&
                  (debug_cause_q != DBG_CAUSE_STEP)
                  |->
                  !(//(pending_sync_debug && sync_debug_allowed)                    || // Left in on purpose, see comment above
                    (exception_in_wb && exception_allowed && !ctrl_fsm_o.kill_wb &&
                     (debug_cause_q != DBG_CAUSE_TRIGGER))                          ||
                    ((wfi_in_wb || wfe_in_wb) && !ctrl_fsm_o.kill_wb)               ||
                    ((fence_in_wb || fencei_in_wb) && !ctrl_fsm_o.kill_wb)          ||
                    (dret_in_wb)                                                    ||
                    (csr_wr_in_wb_flush_i && !ctrl_fsm_o.kill_wb)                   ||
                    (csr_flush_ack_q)                                               ||
                    (branch_taken_ex && !ctrl_fsm_o.kill_ex)                        ||
                    (jump_taken_id && !ctrl_fsm_o.kill_id)                          ||
                    (clic_ptr_in_id)                                                ||
                    (mret_ptr_in_id && !ctrl_fsm_o.kill_id)                         ||
                    (mret_in_wb && !ctrl_fsm_o.kill_wb)                             ||
                    (mret_ptr_in_wb)                                                ||
                    (clic_ptr_in_wb)                                                ||
                    (pending_single_step && !pending_nmi && !(debug_cause_q == DBG_CAUSE_TRIGGER) && !(debug_cause_q == DBG_CAUSE_EBREAK)) // NMI can come at any time
                    /*(etrigger_in_wb)*/                                            || // Left in on purpose, see comment above
                    (clic_ptr_in_id && id_valid_i && ex_ready_i)                    ||
                    (mret_in_wb && !ctrl_fsm_o.kill_wb)                             ||
                    (mret_ptr_in_wb && !ctrl_fsm_o.kill_wb && !exception_in_wb)     ||
                    (clic_ptr_in_wb && !ctrl_fsm_o.kill_wb && !exception_in_wb)))
    else `uvm_error("controller", "Synchronous event during DEBUG_TAKEN(not single step)")


    // Make sure no synchronous events are missed during DEBUG_TAKEN state caused by single stepping
    // If the stepped instruction was a CSR write requiring pipeline flushing, the event
    // csr_flush_ack_q (flush due to CSR can be done) will be active during DEBUG_TAKEN due to completing the instruction requiring flushing.
    // In single step mode, there are no other instructions in the pipeline once an instruction completes, and
    // execution is redirected to the debug module. This is effectively the same as a pipeline flush, and thus
    // ignoring csr_flush_ack_q is ok.
    a_no_event_during_debug_taken_step:
    assert property (@(posedge clk) disable iff (!rst_n)
                    (ctrl_fsm_cs == DEBUG_TAKEN) &&
                    (debug_cause_q == DBG_CAUSE_STEP)
                    |->
                    !((pending_sync_debug && sync_debug_allowed)                  ||
                      (exception_in_wb && exception_allowed)                      ||
                      ((wfi_in_wb || wfe_in_wb))                                  ||
                      ((fence_in_wb || fencei_in_wb))                             ||
                      (dret_in_wb)                                                ||
                      (csr_wr_in_wb_flush_i)                                      ||
                      //(csr_flush_ack_q)                                         || // Left in on purpose, see coment above
                      (branch_taken_ex)                                           ||
                      (jump_taken_id)                                             ||
                      (clic_ptr_in_id)                                            ||
                      (mret_ptr_in_id)                                            ||
                      (mret_in_wb)                                                ||
                      (mret_ptr_in_wb)                                            ||
                      (clic_ptr_in_wb)                                            ||
                      (pending_single_step && !pending_nmi)                       ||
                      (etrigger_in_wb)                                            ||
                      (clic_ptr_in_id && id_valid_i && ex_ready_i)                ||
                      (mret_in_wb && !ctrl_fsm_o.kill_wb)                         ||
                      (mret_ptr_in_wb && !ctrl_fsm_o.kill_wb && !exception_in_wb) ||
                      (clic_ptr_in_wb && !ctrl_fsm_o.kill_wb && !exception_in_wb)))
      else `uvm_error("controller", "Synchronous event during DEBUG_TAKEN(single stepping)")

generate
  if (DEBUG) begin
    // Check that no new instructions (first_op=1) are valid in ID or EX when a single step is taken
    // In case of interrupt (including NMI) during step, the instruction being stepped could be in any stage, and will get killed.
    // Aborted instructions may cause early termination of sequences. Either we jump to the exception handler before debug entry,
    // or straight to debug in case of a trigger match.
    a_single_step_pipecheck :
      assert property (@(posedge clk) disable iff (!rst_n)
              (pending_single_step && (ctrl_fsm_ns == DEBUG_TAKEN)
              |-> ((!(id_ex_pipe_i.instr_valid && first_op_ex_i) && !(if_id_pipe_i.instr_valid && if_id_pipe_i.first_op))) ||
                  ((ctrl_fsm_o.irq_ack || (pending_nmi && nmi_allowed)) && ctrl_fsm_o.kill_if && ctrl_fsm_o.kill_id && ctrl_fsm_o.kill_ex && ctrl_fsm_o.kill_wb)))

        else `uvm_error("controller", "ID and EX not empty when when single step is taken")

     // Check trigger match never happens during debug_mode
    a_trigger_match_in_debug :
      assert property (@(posedge clk) disable iff (!rst_n)
              ctrl_fsm_o.debug_mode |-> !trigger_match_in_wb)
        else `uvm_error("controller", "Trigger match during debug mode")

    a_lsu_wp_debug:
      assert property (@(posedge clk) disable iff (!rst_n)
                      (ctrl_fsm_cs == DEBUG_TAKEN) && (ex_wb_pipe_i.lsu_en && ex_wb_pipe_i.instr_valid)
                      |->
                      $past(|wpt_match_wb_i))
        else `uvm_error("conroller", "LSU active in WB during DEBUG_TAKEN with no preceeding watchpoint trigger")

    // MRET in WB shall not update CSRs if WB stage is halted (debug entry)
    a_mret_in_wb_halt_csr_restore_mret:
      assert property (@(posedge clk) disable iff (!rst_n)
                        (mret_in_wb && ctrl_fsm_o.halt_wb) |-> !ctrl_fsm_o.csr_restore_mret)
        else `uvm_error("controller", "MRET in WB restored CSRs when WB was halted.")

    // etrigger_in_wb shall only be set when there is an exception in wb
    a_etrig_exception:
      assert property (@(posedge clk) disable iff (!rst_n)
                        etrigger_in_wb |-> exception_in_wb)
        else `uvm_error("controller", "etrigger_in_wb when there is no exception in WB")

    a_no_etrig_on_halt_or_kill:
      assert property (@(posedge clk) disable iff (!rst_n)
                        (ctrl_fsm_o.halt_wb || ctrl_fsm_o.kill_wb)
                        |->
                        !etrigger_in_wb)
        else `uvm_error("controller", "etrigger_in_wb when WB is halted or killed")

    a_no_step_on_halt_or_kill:
      assert property (@(posedge clk) disable iff (!rst_n)
                        (ctrl_fsm_o.halt_wb || ctrl_fsm_o.kill_wb) // WB is halted or killed
                        |->
                        !pending_single_step                       // No single step should be pending
                        or
                        non_shv_irq_ack                            // Unless we ack an non-shv interrupt (kills WB)
                        or
                        (pending_nmi && nmi_allowed))              // or we take an NMI (kills WB)
        else `uvm_error("controller", "pending single step when WB is halted or killed")

     // Only halt LSU instruction in WB for watchpoint trigger matches
    a_halt_lsu_wb:
      assert property (@(posedge clk) disable iff (!rst_n)
                      (ex_wb_pipe_i.instr_valid && ex_wb_pipe_i.lsu_en) && ctrl_fsm_o.halt_wb
                      |->
                      |wpt_match_wb_i)
        else `uvm_error("controller", "LSU in WB halted without watchpoint trigger match")
    // Check that debug is always taken when a watchpoint trigger is arrives in WB
    // The watchpoint is halted during its first cycle in WB, thus checking during FUNCTIONAL state only,
    // as the watchpoint will also be valid during DEBUG_TAKEN, but then the decision already has been made and
    // the controller will go back to FUNCTIONAL.
    a_wpt_debug_entry:
      assert property (@(posedge clk) disable iff (!rst_n)
                      (ex_wb_pipe_i.instr_valid && |wpt_match_wb_i) && (ctrl_fsm_cs == FUNCTIONAL)
                      |->
                      (abort_op_wb_i && (ctrl_fsm_ns == DEBUG_TAKEN)))
        else `uvm_error("controller", "Debug not entered on a WPT match")

    // Ensure debug mode is entered if woken up by a debug request (unless a higher priority NMI woke up the core)
    a_sleep_to_debug:
      assert property (@(posedge clk) disable iff (!rst_n)
                      (ctrl_fsm_cs == SLEEP) &&
                      (ctrl_fsm_ns == FUNCTIONAL) &&
                      debug_req_i &&
                      !pending_nmi
                      |=>
                      (ctrl_fsm_ns == DEBUG_TAKEN))
        else `uvm_error("controller", "Woke from sleep due to debug_req but debug mode not entered")

    // woke_to_debug_q shall only be high for a single cycle
    a_woke_to_debug_single_cycle:
      assert property (@(posedge clk) disable iff (!rst_n)
                      woke_to_debug_q
                      |=>
                      !woke_to_debug_q)
        else `uvm_error("controller", "woke_to_debug_q asserted for more than one cycle")

    // The register file shall never be written during DEBUG_TAKEN state
    // Instructions in WB are generally killed during this state, with the exception of
    // ebreak and triggers. Ebreak and triggers shall never write to the RF anyway.
    a_debug_taken_rf_write:
      assert property (@(posedge clk) disable iff (!rst_n)
                      (ctrl_fsm_cs == DEBUG_TAKEN)
                      |->
                      !rf_we_wb_i)
      else `uvm_error("controller", "Register file written during DEBUG_TAKEN state")

    // Debug cause shall be set to 'step' if an interrupt is taken during stepping
    // Interrupt will kill any potential synchronous debug cause that is present in the WB stage.
    a_irq_step_noetrig_debug_cause:
      assert property (@(posedge clk) disable iff (!rst_n)
                      (ctrl_fsm_cs == FUNCTIONAL) &&
                      dcsr_i.step &&               // single stepping enabled in dcsr
                      !ctrl_fsm_o.debug_mode &&    // Not in debug mode
                      pending_single_step    &&    // Single step is pending
                      !etrigger_in_wb        &&    // No exception trigger (would get higher priority cause 'trigger')
                      ((ctrl_fsm_o.pc_set && (ctrl_fsm_o.pc_mux == PC_TRAP_IRQ)) ||      // Step caused by taking a non-SHV interrupt
                      (clic_ptr_in_wb && ex_wb_pipe_i.instr_valid))                     // or step caused by a CLIC pointer finishing taking a CLIC interrupt
                      |=>
                      (ctrl_fsm_cs == DEBUG_TAKEN) &&
                      (debug_cause_q == DBG_CAUSE_STEP))
        else `uvm_error("controller", "Wrong debug cause when taking an interrupt during single stepping")

    a_no_sleep_during_debug:
      assert property (@(posedge clk) disable iff (!rst_n)
                      (ctrl_fsm_cs == SLEEP)
                      |->
                      !debug_mode_q)
      else `uvm_error("controller", "Debug mode during SLEEP not allowed")

if (CLIC) begin
    // While single stepping, debug cause shall be set to 'trigger' if a pointer for a SHV CLIC interrupt arrives in WB
    // with an exception and an exception trigger that matches the exception has been configured. (trigger > step)
    a_irq_step_etrig_debug_cause:
      assert property (@(posedge clk) disable iff (!rst_n)
                      (ctrl_fsm_cs == FUNCTIONAL) &&
                      dcsr_i.step &&               // single stepping enabled in dcsr
                      !ctrl_fsm_o.debug_mode &&    // Not in debug mode
                      pending_single_step    &&    // Single step is pending
                      etrigger_in_wb         &&    // Exception trigger in CLIC pointer fetch
                      (clic_ptr_in_wb && ex_wb_pipe_i.instr_valid)  // Step caused by an excepted CLIC pointer finishing taking a CLIC interrupt
                      |=>
                      (ctrl_fsm_cs == DEBUG_TAKEN) &&
                      (debug_cause_q == DBG_CAUSE_TRIGGER))
        else `uvm_error("controller", "Wrong debug cause when taking a SHV interrupt with exception trigger on the pointer fetch")
end

    // Debug cause shall be set to 'step' if an NMI is taken during stepping
    // Taking an NMI has priority above async debug, so in case of a debug_req_i at the same cycle debug_cause should be 'step' and not 'haltreq'.
    a_nmi_step_debug_cause:
      assert property (@(posedge clk) disable iff (!rst_n)
                      (ctrl_fsm_cs == FUNCTIONAL) &&
                      dcsr_i.step &&               // single stepping enabled in dcsr
                      !ctrl_fsm_o.debug_mode &&    // Not in debug mode
                      pending_single_step    &&    // Single step is pending
                      (ctrl_fsm_o.pc_set && (ctrl_fsm_o.pc_mux == PC_TRAP_NMI))  // Step caused by taking an NMI
                      |=>
                      (ctrl_fsm_cs == DEBUG_TAKEN) &&
                      (debug_cause_q == DBG_CAUSE_STEP))
        else `uvm_error("controller", "Wrong debug cause when taking an NMI during single stepping")

    // Single stepping an ebreak (that is not killed) with dcsr.ebreakm==0 shall result in either debug cause being step or
    // trigger, depending on if an exception trigger was configured or not.
    a_irq_step_ebreak_debug_cause:
      assert property (@(posedge clk) disable iff (!rst_n)
                      (ctrl_fsm_cs == FUNCTIONAL) &&
                      dcsr_i.step &&                      // single stepping enabled in dcsr
                      !ctrl_fsm_o.debug_mode &&           // Not in debug mode
                      pending_single_step    &&           // Single step is pending
                      ebreak_in_wb && !dcsr_i.ebreakm &&  // Ebreak exception in WB
                      !ctrl_fsm_o.kill_wb                 // Ebreak instruction not killed (by NMI or interrupt)
                      |=>
                      (ctrl_fsm_cs == DEBUG_TAKEN) &&
                      (debug_cause_q == ($past(etrigger_in_wb) ? DBG_CAUSE_TRIGGER : DBG_CAUSE_STEP)))
        else `uvm_error("controller", "Wrong debug cause when single stepping an ebreak without dcsr.ebreakm set")

    // Any synchronous debug entry cause has priority over single step
    // If a pending_sync_debug is allowed to be taken at the same time as a pending_single_step, it must be because an interupt or NMI
    // caused the step, and thus wb_valid must not be 1.
    a_step_vs_sync_debug_cause:
      assert property (@(posedge clk) disable iff (!rst_n)
                      (pending_sync_debug && sync_debug_allowed) &&
                      (ctrl_fsm_cs == FUNCTIONAL)
                      |->
                      !(pending_single_step && wb_valid_i))
        else `uvm_error("controller", "Flagging single step pending while there is a pending synchronous debug reason")

    // Any asynchronous debug entry cause has priority over single step
    // If a pending_async_debug is allowed to be taken at the same time as a pending_single_step, it must be because an interupt or NMI
    // caused the step, and thus wb_valid must not be 1.
    a_step_vs_async_debug_cause:
      assert property (@(posedge clk) disable iff (!rst_n)
                      (pending_async_debug && async_debug_allowed) &&
                      (ctrl_fsm_cs == FUNCTIONAL)
                      |->
                      !(pending_single_step && wb_valid_i))
        else `uvm_error("controller", "Flagging single step pending while there is a pending asynchronous debug reason")


  end // DEBUG
endgenerate

  // Ensure that exception codes 4 and 6 never occur (only supported on CV32E40X)
  a_never_exc_4_6:
  assert property (@(posedge clk) disable iff (!rst_n)
                  exception_in_wb
                  |->
                  (exception_cause_wb != 11'd4) && (exception_cause_wb != 11'd6))
    else `uvm_error("controller", "Unsupported exception code 4 or 6.")


endmodule

