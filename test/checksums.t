  $ echo "foo" > foo
  $ sha256sum foo
  b5bb9d8014a0f9b1d61e21e796d78dccdf1352f23cd32812f4850b878ae4944c  foo
  $ md5sum foo
  d3b07384d113edec49eaa6238ad5ff00  foo
  $ mcrunch --string --file foo --checksums sha256:foo_sha256.ml --checksums md5:foo_md5.ml >/dev/null
  $ cat foo_sha256.ml
  let foo = "\xb5\xbb\x9d\x80\x14\xa0\xf9\xb1\xd6\x1e\x21\xe7\x96\xd7\x8d\xcc\
             \xdf\x13\x52\xf2\x3c\xd3\x28\x12\xf4\x85\x0b\x87\x8a\xe4\x94\x4c"
  $ cat foo_md5.ml
  let foo = "\xd3\xb0\x73\x84\xd1\x13\xed\xec\x49\xea\xa6\x23\x8a\xd5\xff\x00"
