  $ export NO_COLOR=1

--lookup emits a function from filename to contents, next to the bindings:

  $ echo "foo" > foo.txt
  $ mcrunch --file=foo.txt --string --lookup=read
  let d_0 = "\x66\x6f\x6f\x0a"
  
  let read = function
    | "foo.txt" -> Some d_0
    | _ -> None

The function can be given another name:

  $ mcrunch --file=foo.txt --string --lookup=find
  let d_0 = "\x66\x6f\x6f\x0a"
  
  let find = function
    | "foo.txt" -> Some d_0
    | _ -> None

Filenames that cannot be used as an OCaml identifier are rejected without a
lookup function, but are fine with one, as mcrunch names the bindings itself:

  $ echo "yu" > YU.mar
  $ mcrunch --file=YU.mar --string
  mcrunch: YU.mar is not a safe filename for OCaml
  [124]
  $ mcrunch --file=YU.mar --string --lookup=read --format "d%d"
  let d0 = "\x79\x75\x0a"
  
  let read = function
    | "YU.mar" -> Some d0
    | _ -> None

An explicit name is still honoured, and is what the contents are bound to:

  $ mcrunch --file=contents:YU.mar --string --lookup=read
  let contents = "\x79\x75\x0a"
  
  let read = function
    | "YU.mar" -> Some contents
    | _ -> None

The whole point being to reach a crunched directory by path:

  $ mkdir -p charmaps
  $ echo "utf8" > charmaps/UTF-8.mar
  $ echo "latin1" > charmaps/ISO-8859-1.mar
  $ mcrunch --directory=charmaps --ext=mar --string --lookup=read
  let d_0 = "\x6c\x61\x74\x69\x6e\x31\x0a"
  let d_1 = "\x75\x74\x66\x38\x0a"
  
  let read = function
    | "charmaps/ISO-8859-1.mar" -> Some d_0
    | "charmaps/UTF-8.mar" -> Some d_1
    | _ -> None

The same file twice is a duplicate, as the lookup would be ambiguous:

  $ mcrunch --file=foo.txt --file=other:foo.txt --lookup=read
  mcrunch: Found some duplications on filenames
  [124]

A lookup function that is not a valid OCaml identifier is rejected:

  $ mcrunch --file=foo.txt --lookup=Read
  Usage: mcrunch [--help] [OPTION]…
  mcrunch: option '--lookup': Read is not a safe OCaml name
  [124]
