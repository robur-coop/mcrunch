let error_msgf fmt = Fmt.kstr (fun msg -> Error (`Msg msg)) fmt
let to_underscore = function '.' | '%' | '!' | '?' | ':' -> true | _ -> false

let no_colon str =
  String.exists (function '-' -> true | _ -> false) str |> Bool.not

let filename_to_name filename =
  let tmp = Bytes.create (String.length filename) in
  for idx = 0 to String.length filename - 1 do
    if to_underscore filename.[idx] then Bytes.set tmp idx '_'
    else Bytes.set tmp idx filename.[idx]
  done;
  Bytes.unsafe_to_string tmp

module Sched = Hxd.Make (struct type +'a t = 'a end)

let sched = { Hxd.bind= (fun x fn -> fn (Sched.prj x)); return= Sched.inj }
let lseek = { Hxd.lseek= (fun _ _ _ -> Sched.inj (Ok 0)) }

let pp cfg ppf filename =
  let ic = open_in_bin filename in
  let finally () = close_in ic in
  Fun.protect ~finally @@ fun () ->
  let max = in_channel_length ic in
  if max > 0xffff (* 65535 *)
  then
    let pp ppf () =
      let recv (ic, pos) buf ~off ~len =
        let len = Int.min (max - !pos) len in
        let len = input ic buf off len in
        pos := !pos + len;
        Sched.inj (Ok len) in
      let send _ _ ~off:_ ~len = Sched.inj (Ok len) in
      let seek = `Relative 0 in
      let v = Hxd.generate cfg sched recv send (ic, ref 0) () lseek seek ppf in
      match Sched.prj v with
      | Ok () -> ()
      | Error _ -> () in
    Fmt.pf ppf "@[<hov>%a@]" pp ()
  else
    let tmp = Bytes.create 0x7ff in
    let buf = Buffer.create max in
    let rec go () =
      match input ic tmp 0 (Bytes.length tmp) with
      | 0 -> Buffer.contents buf
      | len ->
          Buffer.add_subbytes buf tmp 0 len;
          go ()
      | exception End_of_file -> Buffer.contents buf
    in
    let str = go () in
    Fmt.pf ppf "@[<hov>%a@]" (Hxd_string.pp cfg) str

let run _quiet cfg filenames output =
  let ppf, finally =
    match output with
    | None -> (Fmt.stdout, ignore)
    | Some filename ->
        let oc = open_out_bin filename in
        let ppf = Format.formatter_of_out_channel oc in
        let finally () = close_out oc in
        (ppf, finally)
  in
  Fun.protect ~finally @@ fun () ->
  let fn (filename, name) =
    match name with
    | None ->
        let name = filename_to_name filename in
        Fmt.pf ppf "let %s = @[<hov>%a@]\n%!" name (pp cfg) filename
    | Some name ->
        Fmt.pf ppf "let %s = @[<hov>%a@]\n%!" name (pp cfg) filename
  in
  List.iter fn filenames

let existing_filename filename =
  if Sys.is_regular_file filename then Ok ()
  else error_msgf "%s does not exist" filename

let non_existing_filename filename =
  if Sys.file_exists filename then error_msgf "%s already exists" filename
  else Ok ()

let safe_filename_as_name filename =
  let fn0 = function 'a' .. 'z' | '_' -> true | _ -> false in
  let fn1 = function
    | 'A' .. 'Z' | '0' .. '9' | '\'' -> true
    | chr -> fn0 chr || to_underscore chr
  in
  if
    String.length filename > 0
    && fn0 filename.[0]
    && String.for_all fn1 filename
  then Ok ()
  else error_msgf "%s is not a safe filename" filename

let safe_name name =
  let fn0 = function 'a' .. 'z' | '_' -> true | _ -> false in
  let fn1 = function
    | 'A' .. 'Z' | '0' .. '9' | '\'' -> true
    | chr -> fn0 chr
  in
  if String.length name > 0 && fn0 name.[0] && String.for_all fn1 name then
    Ok ()
  else error_msgf "%s is not a safe name" name

open Cmdliner

let parser_of_arg str =
  let ( let* ) = Result.bind in
  match String.split_on_char ':' str with
  | [] -> assert false
  | [ filename ] ->
      let* () = existing_filename filename in
      let* () = safe_filename_as_name filename in
      Ok (filename, None)
  | "-" :: filename ->
      let filename = String.concat ":" filename in
      let* () = existing_filename filename in
      let* () = safe_filename_as_name filename in
      Ok (filename, None)
  | name :: filename ->
      let filename = String.concat ":" filename in
      let* () = existing_filename filename in
      let* () = safe_name name in
      Ok (filename, Some name)

let pp_of_arg ppf = function
  | filename, None ->
      if no_colon filename then Fmt.string ppf filename
      else Fmt.pf ppf "-:%s" filename
  | filename, Some name -> Fmt.pf ppf "%s:%s" name filename

let setup_filenames filenames =
  let fn = function
    | _, Some name -> name
    | filename, None -> filename_to_name filename
  in
  let names = List.map fn filenames in
  let rec has_duplicate = function
    | [] -> false
    | x :: r -> List.mem x r || has_duplicate r
  in
  if has_duplicate names then error_msgf "Found some duplications on names"
  else if List.is_empty names then error_msgf "No file specified to crunch"
  else Ok filenames

let filenames =
  let doc =
    "The file to $(i,crunch) into the OCaml output file. The user can specify \
     the OCaml name to obtain the contents of the file using the separator \
     $(i,:) (with the name on the left and the file on the right). If the \
     filename contains the character $(i,:) and the user would like to let \
     $(tname) infer the OCaml name, the user can specify $(i,-:filename)."
  in
  let open Arg in
  value
  & opt_all (conv (parser_of_arg, pp_of_arg)) []
  & info [ "f"; "file" ] ~doc ~docv:"[NAME|-:]FILENAME"

let setup_filenames =
  let open Term in
  term_result ~usage:false (const setup_filenames $ filenames)

let output_options = "OUTPUT OPTIONS"

let verbosity =
  let env = Cmd.Env.info "CRUNCH_LOGS" in
  Logs_cli.level ~docs:output_options ~env ()

let renderer =
  let env = Cmd.Env.info "CRUNCH_FMT" in
  Fmt_cli.style_renderer ~docs:output_options ~env ()

let utf_8 =
  let doc = "Allow binaries to emit UTF-8 characters." in
  let env = Cmd.Env.info "CRUNCH_UTF_8" in
  Arg.(value & opt bool true & info [ "with-utf-8" ] ~doc ~env)

let reporter ppf =
  let report src level ~over k msgf =
    let k _ =
      over ();
      k ()
    in
    let with_metadata header _tags k ppf fmt =
      Fmt.kpf k ppf
        ("[%a]%a[%a]: " ^^ fmt ^^ "\n%!")
        Fmt.(styled `Cyan int)
        (Stdlib.Domain.self () :> int)
        Logs_fmt.pp_header (level, header)
        Fmt.(styled `Magenta string)
        (Logs.Src.name src)
    in
    msgf @@ fun ?header ?tags fmt -> with_metadata header tags k ppf fmt
  in
  { Logs.report }

let setup_logs utf_8 style_renderer level =
  Fmt_tty.setup_std_outputs ~utf_8 ?style_renderer ();
  Logs.set_level level;
  Logs.set_reporter (reporter Fmt.stderr);
  Option.is_none level

let setup_logs = Term.(const setup_logs $ utf_8 $ renderer $ verbosity)
let docs_hexdump = "HEX OUTPUT"

let with_comments =
  let doc =
    "Print a human-readable view of each line of the contents as a comment."
  in
  let open Arg in
  value & flag & info [ "with-comments" ] ~doc ~docs:docs_hexdump

let cols =
  let doc = "Format $(i,COLS) octets per line. Default 16. Max 256." in
  let parser str =
    match int_of_string str with
    | n when n < 1 || n > 256 ->
        error_msgf "Invalid COLS value (must <= 256 && > 0): %d" n
    | n -> Ok n
    | exception _ -> error_msgf "Invalid COLS value: %S" str
  in
  let open Arg in
  let cols = conv (parser, Fmt.int) in
  value
  & opt (some cols) None
  & info [ "c"; "cols" ] ~doc ~docv:"COLS" ~docs:docs_hexdump

let kind =
  let open Arg in
  let array =
    info [ "a"; "array" ] ~doc:"Serialize the contents to an array of strings."
  in
  let list =
    info [ "l"; "list" ] ~doc:"Serialize the contents to a list of strings."
  in
  value & vflag `Array [ (`Array, array); (`List, list) ]

let uppercase =
  let doc = "Use upper case hex letters. Default is lower case." in
  let open Arg in
  value & flag & info [ "u" ] ~doc ~docs:docs_hexdump

let setup_hxd with_comments cols uppercase kind =
  Hxd.caml ~with_comments ?cols ~uppercase kind

let setup_hxd =
  let open Term in
  const setup_hxd $ with_comments $ cols $ uppercase $ kind

let output =
  let ( let* ) = Result.bind in
  let doc = "The OCaml output file." in
  let parser = function
    | "-" -> Ok None
    | filename ->
        let* _ = Fpath.of_string filename in
        let* () = non_existing_filename filename in
        Ok (Some filename)
  in
  let pp ppf = function
    | None -> Fmt.string ppf "-"
    | Some filename -> Fmt.string ppf filename
  in
  let open Arg in
  value
  & opt (conv (parser, pp)) None
  & info [ "o"; "output" ] ~doc ~docv:"FILENAME"

let term =
  let open Term in
  const run $ setup_logs $ setup_hxd $ setup_filenames $ output

let cmd =
  let doc =
    "Crunch some files into an OCaml file which can be statically linked with \
     an OCaml program. The OCaml program is able to obtain the contents of \
     these files then without I/O operations."
  in
  let info = Cmd.info "mcrunch" ~doc in
  Cmd.v info term

let () = Cmd.(exit @@ eval cmd)
