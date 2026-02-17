  $ echo "foo" > foo
  $ mcrunch --file=foo -o foo.ml
  $ cat foo.ml
  let foo = [| "\x66\x6f\x6f\x0a" |]
  $ echo "bar" > bar
  $ mcrunch --file=foo --file=bar -o t.ml --with-comments
  $ cat t.ml
  let foo = [| "\x66\x6f\x6f\x0a" |]                                                 (* foo.             *)
            
  let bar = [| "\x62\x61\x72\x0a" |]                                                 (* bar.             *)
            
  $ rm t.ml
  $ mcrunch --file=foo --file=bar -o t.ml -l
  $ cat t.ml
  let foo = [ "\x66\x6f\x6f\x0a" ]
  let bar = [ "\x62\x61\x72\x0a" ]
  $ rm t.ml
  $ mcrunch --file=foo -o t.ml --string
  $ cat t.ml
  let foo = "\x66\x6f\x6f\x0a"
  $ rm t.ml
  $ mcrunch --file=foo -o t.ml --string --with-comments
  Comments are not supported for string output. Not outputting comments.
  $ cat t.ml
  let foo = "\x66\x6f\x6f\x0a"
