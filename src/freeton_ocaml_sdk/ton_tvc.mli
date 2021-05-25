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

val read : string -> Ton_types.state_init

(* returns "None" or base64 encoding of data *)
val data : Ton_types.state_init -> string

(* returns "None" or base64 encoding of code *)
val code : Ton_types.state_init -> string

(* returns hex encoding of code hash *)
val code_hash : Ton_types.state_init -> string
