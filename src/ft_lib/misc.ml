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

open EzFile.OP
open Types

let verbose i = !Globals.verbosity >= i


let temp_dir = Globals.ft_dir // "tmp"
let tmpfile () = Filename.temp_file ~temp_dir "tmpfile" ".tmp"

let call ?(stdout = Unix.stdout) args =
  if verbose 1 then
    Printf.eprintf "Calling %s\n%!" (String.concat " " args);
  let targs = Array.of_list args in
  let pid = Unix.create_process targs.(0) targs
      Unix.stdin stdout Unix.stderr in
  let rec iter () =
    match Unix.waitpid [] pid with
    | exception Unix.Unix_error (EINTR, _, _) -> iter ()
    | _pid, status -> (
      match status with
      | WEXITED 0 -> ()
      | _ ->
        Error.raise "Command '%s' exited with error code %s"
          (String.concat " " args)
          ( match status with
          | WEXITED n -> string_of_int n
          | WSIGNALED n -> Printf.sprintf "SIGNAL %d" n
          | WSTOPPED n -> Printf.sprintf "STOPPED %d" n ) )
  in
  iter ()

let call_stdout_file ?file args =
  let tmpfile = match file with
    | None -> tmpfile ()
    | Some file -> file in
  let stdout = Unix.openfile tmpfile
      [ Unix.O_CREAT ; Unix.O_WRONLY ; Unix.O_TRUNC ] 0o644 in
  match call ~stdout args with
  | () ->
      Unix.close stdout;
      tmpfile
  | exception exn ->
      let stdout = EzFile.read_file tmpfile in
      Printf.eprintf "Stdout after error:\n%s\n" stdout;
      raise exn

(*
let call_stdout args =
  let file = call_stdout_file args in
  let stdout = EzFile.read_file file in
  Sys.remove file;
  stdout
*)

let call_stdout_lines args =
  let file = call_stdout_file args in
  let stdout = EzFile.read_lines file in
  Sys.remove file;
  let lines = Array.to_list stdout in
  if !Globals.verbosity > 1 then
    Printf.eprintf "stdout:\n%s\n%!"
      (String.concat "\n" lines);
  lines




let read_json_file encoding filename =
  let json = EzFile.read_file filename in
  EzEncoding.destruct encoding json

let write_file file content =
  EzFile.make_dir ~p:true (Filename.dirname file);
  EzFile.write_file file content

let write_json_file encoding filename value =
  let json = EzEncoding.construct ~compact:false encoding value in
  write_file filename json


let check_new_key_exn net name =
  List.iter (fun key ->
      if key.key_name = name then
        Error.raise "Key %S already exists" name
    ) net.net_keys

let find_line ?(succeeded=false) f lines =
  let v = ref None in
  let succes = ref false in
  List.iter (function
      | "Succeeded"
      | "Succeeded." -> succes := true
      | s ->
          match f ( EzString.split s ' ' ) with
          | Some vv -> v := Some vv
          | None -> ()
    ) lines;
  if succeeded && not !succes then
    Error.raise "tonos-cli did not succeed:\n %s"
      (String.concat "\n" lines );
  !v

let find_line_exn ?succeeded f lines =
  match find_line ?succeeded f lines with
  | None ->
      Error.raise "Could not parse output of tonos-cli:\n %s"
        (String.concat "\n" lines )
  | Some v -> v

let find_line_ok f lines =
  find_line_exn ~succeeded:true f lines

let find_network config name =
  let rec iter networks =
    match networks with
    | [] -> None
    | net :: tail ->
        if net.net_name = name then Some net else iter tail
  in
  iter config.networks

let find_network_exn config name =
  match find_network config name with
  | Some net -> net
  | None ->
      Error.raise "Network %S does not exist" name

let find_node net name =
  let rec iter nodes =
    match nodes with
    | [] -> None
    | node :: tail ->
        if node.node_name = name then Some node else iter tail
  in
  iter net.net_nodes

let find_key net name =
  let rec iter keys =
    match keys with
    | [] -> None
    | key :: tail ->
        if key.key_name = name then Some key else iter tail
  in
  iter net.net_keys

let find_key_exn net name =
  match find_key net name with
  | None -> Error.raise "Key %S does not exist in network %s"
              name net.net_name
  | Some key -> key

let get_key_pair_exn key =
  match key.key_pair with
  | None
  | Some { secret = None ; _ } ->
      Error.raise "Account %S does not have a secret key" key.key_name
  | Some key_pair -> key_pair

let get_key_passphrase_exn key =
  match key.key_passphrase with
  | None ->
      Error.raise "Account %S does not have a passphrase" key.key_name
  | Some key_passphrase -> key_passphrase

let get_key_account_exn key =
  match key.key_account with
  | None ->
      Error.raise
        "Key %S has no address yet. Use 'ft account KEY --contract CONTRACT'"
        key.key_name
  | Some acc -> acc

let get_key_address_exn key =
  ( get_key_account_exn key ) . acc_address

let get_key_contract_exn key =
  match ( get_key_account_exn key ) . acc_contract with
  | None ->
      Error.raise
        "Key %S has no contract yet. Use 'ft account KEY --contract CONTRACT'"
        key.key_name
  | Some contract -> contract

let current_network config =
  find_network_exn config config.current_network

let current_node config =
  let net = find_network_exn config config.current_network in
  match find_node net net.current_node with
  | None ->
      Error.raise "Unknown node %S in network %S"
        net.current_node net.net_name
  | Some node -> node

let net_dir config = Globals.ft_dir // config.current_network
let tonoscli_binary _config = Globals.ft_dir // "bin" // "tonos-cli"
let tonoscli_config config = net_dir config // "tonos-cli.config"

let tonoscli config args =
    ( tonoscli_binary config ::
      "--config" ::
      tonoscli_config config ::
      args )

let tonoscli config args =
  let config_file = tonoscli_config config in
  let binary = tonoscli_binary config in
  if not ( Sys.file_exists binary ) then begin
    EzFile.make_dir ~p:true ( Filename.dirname binary );
    Error.raise "You must put a copy of tonos-cli binary in %s\n%!" binary
  end;
  if not ( Sys.file_exists config_file ) then begin
    let node = current_node config in
    call (tonoscli config ["config" ; "--url"; node.node_url ]);

    let src_file = "tonlabs-cli.conf.json" in
    if Sys.file_exists src_file then begin
      Printf.eprintf "mv %s %s\n%!" src_file config_file ;
      let content = EzFile.read_file src_file in
      Sys.remove src_file ;
      EzFile.write_file config_file content
    end
  end;
  tonoscli config args

let string_of_workchain wc =
  match wc with
  | None -> "0"
  | Some n -> string_of_int n


let gen_keyfile key_pair =
  let keypair_file = tmpfile () in
  write_json_file Encoding.keypair keypair_file key_pair;
  keypair_file

let get_contract_tvcfile contract =
  let tvc_name = Printf.sprintf "contracts/%s.tvc" contract in
  let tvc_content =
    match Files.read tvc_name with
    | None ->
        Error.raise "Unknown contract %S" contract
    | Some tvc_content -> tvc_content
  in
  let contract_tvc = Globals.ft_dir // tvc_name in
  write_file contract_tvc tvc_content;
  contract_tvc

let get_contract_abifile contract =

  let abi_name = Printf.sprintf "contracts/%s.abi.json" contract in
  let abi_content = match Files.read abi_name with
    | None -> assert false
    | Some abi_content -> abi_content
  in
  let contract_abi = Globals.ft_dir // abi_name in
  write_file contract_abi abi_content;
  contract_abi

let nanotokens_of_string s =
  let s = String.map (function
      '0'..'9' as c -> c
      | ',' | '_' -> '_'
      | '.' -> '.'
      | _ -> Error.raise "Invalid amount %S" s
    ) s in
  let tons, decimals = EzString.cut_at s '.' in
  let decimals = float_of_string ("0." ^ decimals) in
  let decimals = decimals *. 1_000_000_000. in
  let decimals = Int64.of_float decimals in
  let tons = Int64.of_string tons in
  let tons = Int64.mul tons 1_000_000_000L in
  Int64.add tons decimals

let () =
  assert (nanotokens_of_string "1" = 1_000_000_000L );
  assert (nanotokens_of_string "1_000" = 1_000_000_000_000L );
  assert (nanotokens_of_string "1." = 1_000_000_000L );
  assert (nanotokens_of_string "1.000" = 1_000_000_000L );
  assert (nanotokens_of_string "1.256" = 1_256_000_000L );
  assert (nanotokens_of_string "0.000_001" = 1_000L );

  ()
