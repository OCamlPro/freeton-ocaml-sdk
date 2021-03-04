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

open EzCompat (* for StringSet *)
open Ezcmd.V2
open EZCMD.TYPES
open EzFile.OP
(* open Types *)


type todo =
    ListContracts
  | BuildContract of string

let remove_files dirname files =
  List.iter (fun file ->
      if Sys.file_exists file then
        Sys.remove file
    ) ( files @ List.map (fun file -> dirname // file) files)

let check_exists dirname file =
  if Sys.file_exists file then
    file
  else
    let file = dirname // file in
    if Sys.file_exists file then
      file
    else
      Error.raise "File %s was not generated" file

let action ~todo ~force =
  match todo with
  | ListContracts ->
      CommandList.list_contracts ()
  | BuildContract filename ->
      let dirname = Filename.dirname filename in
      let basename = Filename.basename filename in
      let name, ext = EzString.cut_at basename '.' in
      if ext <> "sol" then
        Error.raise "File %s must end with .sol extension" basename;
      let known = CommandList.known_contracts () in
      if not force && StringMap.mem name known then
        Error.raise "Contract %s already exists (use -f to override)" name;
      let solc = Misc.binary_file "solc" in
      let tvm_linker = Misc.binary_file "tvm_linker" in
      let stdlib = Misc.binary_file "stdlib_sol.tvm" in

      let abi_file = name ^ ".abi.json" in
      let code_file = name ^ ".code" in
      let tvm_file = name ^ ".tvm" in
      remove_files dirname [ abi_file ; code_file ; tvm_file ];
      Misc.call [ solc ; filename ];
      let abi_file = check_exists dirname abi_file in
      let code_file = check_exists dirname code_file in
      Misc.call [ tvm_linker ; "compile" ; "-o" ; tvm_file ;
                  code_file ;
                  "--abi-json" ; abi_file ;
                  "--lib" ; stdlib
                ];
      let tvm_file = check_exists dirname tvm_file in

      Misc.call [ "cp" ; "-f" ; filename ; tvm_file ; abi_file ;
                  Globals.contracts_dir ];

      ()

let cmd =
  let set_todo, with_todo = Misc.todo_arg () in
  let force = ref false in
   EZCMD.sub
    "contract"
    (fun () ->
       with_todo (fun todo ->
           action ~todo ~force:!force)
    )
    ~args:
      [
        [ "list" ], Arg.Unit (fun () -> set_todo "--list" ListContracts ),
        EZCMD.info "List known contracts";

        [ "force" ], Arg.Set force,
        EZCMD.info "Override existing contracts";

        [ "build"], Arg.String (fun filename ->
            set_todo "--build" (BuildContract filename)),
        EZCMD.info "Build a contract and remember it";
      ]
    ~doc: "Manage contracts"
