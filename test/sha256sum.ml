#!/usr/bin/env ocaml

#use "topfind";;
#require "digestif.c";;

module Hash = Digestif.SHA256

let hash ic =
  let buf = Bytes.create 0x7ff in
  let rec go ctx = match input ic buf 0 (Bytes.length buf) with
    | 0 | exception _ -> Hash.get ctx
    | len ->
      let ctx = Hash.feed_bytes ctx buf ~off:0 ~len in
      go ctx in
  go Hash.empty
;;

let () = match Sys.argv with
  | [| _; filename |] when Sys.file_exists filename && Sys.is_regular_file filename ->
    let ic = open_in_bin filename in
    let finally () = close_in ic in
    Fun.protect ~finally @@ fun () ->
    let hash = hash ic in
    Format.printf "%a %s\n%!" Hash.pp hash filename
  | [| _ |] ->
    let hash = hash stdin in
    Format.printf "%a -\n%!" Hash.pp hash
  | _ -> Format.eprintf "%s [<filename>]\n%!" Sys.argv.(0)
;;
