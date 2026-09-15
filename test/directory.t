  $ export NO_COLOR=1

A directory is walked recursively, in a stable order, and the path is used to
infer the OCaml name:

  $ mkdir -p assets/sub
  $ echo "foo" > assets/foo.txt
  $ echo "bar" > assets/sub/bar.txt
  $ echo "skip" > assets/other.bin
  $ mcrunch --directory assets --string
  let assets_foo_txt = "\x66\x6f\x6f\x0a"
  let assets_other_bin = "\x73\x6b\x69\x70\x0a"
  let assets_sub_bar_txt = "\x62\x61\x72\x0a"

Only the files with the given extension are crunched, the leading dot being
optional:

  $ mcrunch --directory assets --ext txt --string
  let assets_foo_txt = "\x66\x6f\x6f\x0a"
  let assets_sub_bar_txt = "\x62\x61\x72\x0a"
  $ mcrunch --directory assets --ext .bin --string
  let assets_other_bin = "\x73\x6b\x69\x70\x0a"

Extensions and directories can be repeated, and mixed with --file:

  $ mkdir other
  $ echo "baz" > other/baz.txt
  $ mcrunch --directory assets --directory other --ext txt --ext bin --string
  let assets_foo_txt = "\x66\x6f\x6f\x0a"
  let assets_other_bin = "\x73\x6b\x69\x70\x0a"
  let assets_sub_bar_txt = "\x62\x61\x72\x0a"
  let other_baz_txt = "\x62\x61\x7a\x0a"

A file reached twice is an error, as it already is with --file:

  $ mcrunch --directory assets --file assets/foo.txt --string
  mcrunch: Found some duplications on names
  [124]

So is a directory that does not exist, or that is not a directory:

  $ mcrunch --directory nope
  Usage: mcrunch [--help] [OPTION]…
  mcrunch: option '--directory': nope is not a directory
  [124]
  $ mcrunch --directory assets/foo.txt
  Usage: mcrunch [--help] [OPTION]…
  mcrunch: option '--directory': assets/foo.txt is not a directory
  [124]
