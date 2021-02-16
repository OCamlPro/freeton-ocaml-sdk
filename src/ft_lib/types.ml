(**************************************************************************)
(*                                                                        *)
(*  Copyright (c) 2021 OCamlPro SAS & Origin Labs SAS                     *)
(*                                                                        *)
(*  All rights reserved.                                                  *)
(*  This file is distributed under the terms of the GNU Lesser General    *)
(*  Public License version 2.1, with the special exception on linking     *)
(*  described in the LICENSE.md file in the root directory.               *)
(*                                                                        *)
(*                                                                        *)
(**************************************************************************)

type keypair = {
  public : string ;
  mutable secret : string option ;
} [@@deriving json_encoding]

type account = {
  acc_address : string ;                 [@key "address"]
  mutable acc_contract : string option ; [@key "contract"]
  mutable acc_workchain : int option ;   [@key "workchain"]
} [@@deriving json_encoding]

type key = {
  key_name : string ;                    [@key "name"]
  mutable key_passphrase : string option ;       [@key "passphrase"]
  mutable key_pair : keypair option ;    [@key "pair"]
  mutable key_account : account option ; [@key "account"]
} [@@deriving json_encoding]

type node = {
  node_name : string ; [@key "name"]
  node_url : string ;  [@key "url" ]
} [@@deriving json_encoding]

type network = {
  net_name : string ;                       [@key "name"]
  mutable current_node : string ;           [@key "node"]
  mutable current_account : string option ; [@key "account"]
  mutable net_nodes : node list ;           [@key "nodes"]
  mutable net_keys : key list ;   [@dft []] [@key "keys"]
} [@@deriving json_encoding]

type config = {
  mutable modified : bool ;           [@default true]
  mutable current_network : string ;  [@key "network"]
  networks : network list ;
} [@@deriving json_encoding]
