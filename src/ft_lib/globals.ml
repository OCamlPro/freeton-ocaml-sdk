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

open EzFile.OP

let verbosity = ref 1
let command = "ft"
let about = "ft COMMAND COMMAND-OPTIONS"


let homedir = Sys.getenv "HOME"

let ft_dir = homedir // ".ft"
let config_file = ft_dir // "config.json"

let contracts_dir = ft_dir // "contracts"
