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

open Ezcmd.V2
open EZCMD.TYPES
open Ez_subst.V1

(* open Types *)

let rec date_now now rem =
  match rem with
  | [] -> now
  | "plus" :: num :: ( "day" | "days" ) :: rem ->
      let now = now + int_of_string num * 86400 in
      date_now now rem
  | _ ->
      Error.raise "Bad substitution 'now:%s'"
        (String.concat ":" rem)

let get_code filename =
  let tvm_linker = Misc.binary_file "tvm_linker" in
  let lines =
    Misc.call_stdout_lines [ tvm_linker ; "decode" ; "--tvc" ; filename ] in
  let code = ref None in
  List.iter (fun line ->
      match EzString.split line ' ' with
      | [ "" ; "code:" ; base64 ] -> code := Some base64
      | _ -> ()
    ) lines;
  match !code with
  | None -> Error.raise "Code not found in file %S" filename
  | Some code -> code

let subst_string config =
  let net = Config.current_network config in
  let files = ref [] in
  let brace () s =

    let rec iter = function
      | [ "env" ; var ] -> begin
          match Sys.getenv var with
          | exception Not_found ->
              Error.raise "Env variable %S is not defined" var
          | s -> s
        end

      (* Accounts substitutions: *)
      | [ "addr" ; "zero" ] ->
          "0:0000000000000000000000000000000000000000000000000000000000000000"

      (* Account substitutions *)
      | [ "account" ; "addr" ; account ]
      | [ "account" ; "address" ; account ]
        ->
          let key = Misc.find_key_exn net account in
          Misc.get_key_address_exn key
      | [ "account" ; "wc" ; account ] ->
          let key = Misc.find_key_exn net account in
          let acc = Misc.get_key_account_exn key in
          Misc.string_of_workchain acc.acc_workchain
      | [ "account" ; "pubkey" ; account ] ->
          let key = Misc.find_key_exn net account in
          let key_pair = Misc.get_key_pair_exn key in
          key_pair.public
      | [ "account" ; "passphrase" ; account ] ->
          let key = Misc.find_key_exn net account in
          Misc.get_key_passphrase_exn key
      | [ "account" ; "keyfile" ; account ] ->
          let key = Misc.find_key_exn net account in
          let key_pair = Misc.get_key_pair_exn key in
          let file = Misc.gen_keyfile key_pair in
          files := file :: !files;
          file
      | [ "account" ; "contract" ; account ] ->
          let key = Misc.find_key_exn net account in
          let contract = Misc.get_key_contract_exn key in
          contract
      | [ "account" ; "contract" ; "tvc" ; account ] ->
          let key = Misc.find_key_exn net account in
          let contract = Misc.get_key_contract_exn key in
          Misc.get_contract_tvcfile contract
      | [ "account" ; "contract" ; "abi" ; account ] ->
          let key = Misc.find_key_exn net account in
          let contract = Misc.get_key_contract_exn key in
          Misc.get_contract_abifile contract
      | "account" :: "payload" :: account :: meth :: rem ->
          let key = Misc.find_key_exn net account in
          let contract = Misc.get_key_contract_exn key in
          let params = match rem with
            | [] -> "{}"
            | _ -> String.concat ":" rem in
          let abi_file = Misc.get_contract_abifile contract in
          let abi = EzFile.read_file abi_file in
          Base64.encode_string (
            Ton_sdk.ABI.encode_body ~abi ~meth ~params
          )

      (* Contracts substitutions *)
      | [ "contract" ; "tvc" ; contract ] ->
          Misc.get_contract_tvcfile contract
      | [ "contract" ; "abi" ; contract ] ->
          Misc.get_contract_abifile contract
      | "contract" :: "payload" :: contract :: meth :: rem ->
          let params = match rem with
            | [] -> "{}"
            | _ -> String.concat ":" rem in
          let abi_file = Misc.get_contract_abifile contract in
          let abi = EzFile.read_file abi_file in
          Base64.encode_string (
            Ton_sdk.ABI.encode_body ~abi ~meth ~params
          )

      (* Node substitutions *)
      | [ "node" ; "url" ] ->
          let node = Config.current_node config in
          node.node_url

      | [ "ton" ; n ] ->
          Int64.to_string ( Misc.nanotokens_of_string n )
      | [ "file" ; file ] ->
          String.trim ( EzFile.read_file file )

      | "string" :: rem -> String.concat ":" rem

      | "now" :: rem ->
          string_of_int (
            date_now (int_of_float (Unix.gettimeofday ())) rem )


      (* encoders *)
      | "read" :: rem -> EzFile.read_file ( iter rem )
      | "hex" :: rem ->
          let `Hex s = Hex.of_string ( iter rem ) in s
      | "base64" :: rem ->
          Base64.encode_string ( iter rem )
      | "get-code" :: rem ->
          get_code ( iter rem )


      (* deprecated *)
      | [ account ; "addr" ]
      | [ "addr" ; account ] ->
          let key = Misc.find_key_exn net account in
          Misc.get_key_address_exn key
      | [ account ; "wc" ]
      | [ "wc" ; account ] ->
          let key = Misc.find_key_exn net account in
          let acc = Misc.get_key_account_exn key in
          Misc.string_of_workchain acc.acc_workchain
      | [ account ; "pubkey" ]
      | [ "pubkey" ; account ]->
          let key = Misc.find_key_exn net account in
          let key_pair = Misc.get_key_pair_exn key in
          key_pair.public
      | [ account ; "passphrase" ]
      | [ "passphrase" ; account ] ->
          let key = Misc.find_key_exn net account in
          Misc.get_key_passphrase_exn key
      | [ account ; "keyfile" ]
      | [ "keyfile" ; account ] ->
          let key = Misc.find_key_exn net account in
          let key_pair = Misc.get_key_pair_exn key in
          let file = Misc.gen_keyfile key_pair in
          files := file :: !files;
          file
      | [ account ; "contract"; "tvc" ]
      | [ "account-tvc" ; account ] ->
          let key = Misc.find_key_exn net account in
          let contract = Misc.get_key_contract_exn key in
          Misc.get_contract_tvcfile contract
      | [ account ; "contract" ; "abi" ]
      | [ "account-abi" ; account ] ->
          let key = Misc.find_key_exn net account in
          let contract = Misc.get_key_contract_exn key in
          Misc.get_contract_abifile contract

      (* Contracts substitutions *)
      | [ contract ; "tvc" ]
      | [ "tvc" ; contract ]->
          Misc.get_contract_tvcfile contract
      | [ contract ; "abi" ]
      | [ "abi" ; contract ] ->
          Misc.get_contract_abifile contract

      | [ n ; "ton" ] -> Int64.to_string ( Misc.nanotokens_of_string n )


      | _ ->
          Error.raise "Cannot substitute %S" s
    in
    iter ( EzString.split s ':' )
  in
  (fun s -> EZ_SUBST.string ~sep:'%' ~brace ~ctxt:() s), files

let list_substitutions () =
  let content =
{|
Substitutions are written as %{SUBST}, and can be recursive (substitutions
are allowed within SUBST itself).
Here is a list of allowed expressions within SUBST:

* env:VARIABLE    Environemnt variable
* addr:zero     For 0:0000000000000000000000000000000000000000000000000000000000000000"

On wallet accounts:
* account:address:ACCOUNT
* account:wc:ACCOUNT
* account:pubkey:ACCOUNT      Pubkey of account (without 0x)
* account:passphrase:ACCOUNT
* account:keyfile:ACCOUNT     Name of a keyfile generated in $HOME/.ft/tmp/
* account:contract:ACCOUNT    Name of recorded contract of account in wallet
* account:contract:tvc:ACCOUNT    Contract tvc file for account
* account:contract:abi:ACCOUNT    Contract abi file for account
* account:payload:ACCOUNT:METH:PARAMS Output payload base64

On contracts:
* contract:tvc:CONTRACT
* contract:abi:CONTRACT
* contract:payload:CONTRACT:METH:PARAMS Output payload base64

Misc:
* node:url         Current node URL
* ton:NUMBER       Convert NUMBER of tons to nanotons
* file:FILENAME    Read content of filename
* string:SUBST     Take remaining SUBST without substituting, just as a string
* now              Current date
* now:PLUS         Current date plus some delay ( "plus:NDAYS:days" )

Encoders, working on the rest of the substitution:
* read:SUBST       Do SUBST, then read it as a filename
* hex:SUBST        Do SUBST, then convert to hex
* base64:SUBST     Do SUBST, then convert to base64

|}
  in
  Printf.printf "%s\n%!" content

let with_substituted config params f =
  let (subst, files) = subst_string config in
  let clean () = List.iter Sys.remove !files in
  let params = subst params in
  match
    f params
  with
  | res -> clean (); res
  | exception exn -> clean () ; raise exn

let action ~stdout ~file ~string ~keyfile ~addr =
  let config = Config.config () in
  let subst, _files = subst_string config in
  let content =
    match file, string with
    | Some file, None ->
        subst ( EzFile.read_file file )
    | None, Some s ->
        subst s
    | Some _, Some _ ->
        Error.raise "Cannot use both --file and --string"
    | None, None ->
        match keyfile with
        | Some account ->
            let net = Config.current_network config in
            let key = Misc.find_key_exn net account in
            let key_pair = Misc.get_key_pair_exn key in
            EzEncoding.construct ~compact:false Encoding.keypair key_pair
        | None ->
            match addr with
            | Some account ->
                let net = Config.current_network config in
                let key = Misc.find_key_exn net account in
                let acc = Misc.get_key_account_exn key in
                acc.acc_address
            | None ->
                Error.raise "Use one of the arguments"
  in
  match stdout with
  | None -> Printf.printf "%s\n%!" content
  | Some stdout ->
      EzFile.write_file stdout content

let cmd =
  let stdout = ref None in
  let file = ref None in
  let string = ref None in
  let keyfile = ref None in
  let addr = ref None in
  EZCMD.sub
    "output"
    (fun () ->
       action
         ~stdout:!stdout
         ~file:!file
         ~string:!string
         ~keyfile:!keyfile
         ~addr:!addr
    )
    ~args:
      [
        [ "o" ], Arg.String (fun s -> stdout := Some s),
        EZCMD.info "FILE Save command stdout to file";

        [ "file" ], Arg.String (fun s -> file := Some s),
        EZCMD.info "FILE Output content of file after substitution";

        [ "string" ], Arg.String (fun s -> string := Some s),
        EZCMD.info "FILE Output string after substitution";

        [ "keyfile" ], Arg.String (fun s -> keyfile := Some s ),
        EZCMD.info "ACCOUNT Output key file of account";

        [ "addr" ], Arg.String (fun s -> addr := Some s),
        EZCMD.info "ACCOUNT Output address of account";

        [ "list-subst" ], Arg.Unit (fun () ->
              list_substitutions (); exit 0),
          EZCMD.info "List all substitutions";
      ]
    ~doc: "Call tonos-cli, use -- to separate arguments"
