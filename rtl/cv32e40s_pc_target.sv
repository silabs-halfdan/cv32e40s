// Copyright 2021 Silicon Labs, Inc.
//   
// This file, and derivatives thereof are licensed under the
// Solderpad License, Version 2.0 (the "License");
// Use of this file means you agree to the terms and conditions
// of the license and are in full compliance with the License.
// You may obtain a copy of the License at
//   
//     https://solderpad.org/licenses/SHL-2.0/
//   
// Unless required by applicable law or agreed to in writing, software
// and hardware implementations thereof
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, EITHER EXPRESSED OR IMPLIED.
// See the License for the specific language governing permissions and
// limitations under the License.

////////////////////////////////////////////////////////////////////////////////
//                                                                            //
// Authors:        Øystein Knauserud - oystein.knauserud@silabs.com           //
//                                                                            //
// Description:    Computes pc target for jumps and branches                  //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////

module cv32e40s_pc_target import cv32e40s_pkg::*;
  (
   input jt_mux_e      ctrl_transfer_target_mux_sel_i,
   input logic [31:0]  pc_id_i,
   input logic [31:0]  imm_uj_type_i,
   input logic [31:0]  imm_sb_type_i,
   input logic [31:0]  imm_i_type_i,
   input logic [31:0]  jalr_fw_i,
   output logic [31:0] bch_target_o,
   output logic [31:0] jmp_target_o
  );

  logic [31:0] pc_target;

  assign bch_target_o = pc_target;
  assign jmp_target_o = pc_target;

  always_comb begin : pc_target_mux
    unique case (ctrl_transfer_target_mux_sel_i)
      JT_JAL:  pc_target = pc_id_i   + imm_uj_type_i;
      JT_COND: pc_target = pc_id_i   + imm_sb_type_i;
      JT_JALR: pc_target = jalr_fw_i + imm_i_type_i;             // JALR: Allowing forward iff WB result comes from ALU/EX stage (NOT from LSU)
      default: pc_target = jalr_fw_i + imm_i_type_i;
    endcase
  end
endmodule