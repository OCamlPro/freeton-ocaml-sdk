(**************************************************************************)
(*                                                                        *)
(*  Copyright (c) 2021 OCamlPro SAS                                       *)
(*                                                                        *)
(*  All rights reserved.                                                  *)
(*  This file is distributed under the terms of the GNU Lesser General    *)
(*  Public License version 2.1, with the special exception on linking     *)
(*  described in the LICENSE.md file in the root directory.               *)
(*                                                                        *)
(*                                                                        *)
(**************************************************************************)

open Ton_types

module SendMessage = struct

  type params = {
    message: string ;
    abi: Abi.t option ; [@opt None]
    send_events: bool ;
  }
  [@@deriving json_encoding]

  type result = {
    shard_block_id: string ;
    sending_endpoints: string list ;
  }
  [@@deriving json_encoding]

  let f = Tc.request_sync "send_message" ~params_enc ~result_enc

end

module WaitForTransaction = struct
  type params = {
    abi: Abi.t option ; [@opt None]
    message: string ;
    shard_block_id: string ;
    send_events: bool ;
    sending_endpoints: string list option; [@opt None]
  }
  [@@deriving json_encoding]

  type result = {
    transaction: Json_repr.ezjsonm ;
    out_messages: string list ;
    decoded: DecodedOutput.t option ; [@opt None]
    fees: TransactionFees.t ;
  }
  [@@deriving json_encoding]

  let f = Tc.request_sync "wait_for_transaction" ~params_enc ~result_enc
end

module ProcessMessage = struct
  type params = {
    message_encode_params: Mod_abi.EncodeMessage.params ;
    send_events: bool ;
  }
  [@@deriving json_encoding]

  type result = {
    transaction: Json_repr.ezjsonm ;
    out_messages: string list ;
    decoded: DecodedOutput.t option ; [@opt None]
    fees: TransactionFees.t ;
  }
  [@@deriving json_encoding]

  let f = Tc.request_sync "process_message" ~params_enc ~result_enc
end

let send_message = SendMessage.f
let wait_for_transaction = WaitForTransaction.f
let process_message = ProcessMessage.f
