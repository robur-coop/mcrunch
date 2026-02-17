# mcrunch

`mcrunch` is a command-line tool that embeds files into OCaml source code. It
reads one or more files and produces an OCaml module where each file's contents
are encoded as a hexadecimal string array (or list or a single string). The
generated module can be statically linked into an OCaml program, giving it
access to the file contents at runtime without any I/O operations.

This is useful for embedding static assets (configuration files, templates,
certificates, binary data) directly into an OCaml binary.

## Installation

```bash
$ opam install mcrunch
```

## Usage

The simplest invocation takes a file and writes an OCaml module to stdout:
```bash
$ mcrunch -f foo.txt
let foo_txt = [| "\x66\x6f\x6f\x0a" |]
```

The OCaml binding name is derived from the filename, with characters like `.`
and `%` replaced by underscores. You can also specify the binding name
explicitly using the `name:filename` syntax:
```bash
$ mcrunch -f contents:foo.txt
let contents = [| "\x66\x6f\x6f\x0a" |]
```

Multiple files can be crunched into a single module:
```bash
$ mcrunch -f foo.txt -f bar.txt -o assets.ml
```

If a filename contains the character `:`, use the prefix `-:` to let `mcrunch`
infer the name automatically:
```bash
$ mcrunch -f -:path:to:file
```

## Options

* `-f`, `--file [NAME|-:]FILENAME` specifies a file to crunch. This option can
  be repeated to include multiple files. An optional name can be given before
  the filename, separated by `:`.
* `-o`, `--output FILENAME` writes the output to the given file instead of
  stdout. The file must not already exist. Use `-` for stdout (the default).
* `-a`, `--array` serializes each file's contents as an array of strings. This
  is the default.
* `-l`, `--list` serializes each file's contents as a list of strings instead of
  an array.
* `-s`, `--string` serializes each file's contents as a single string instead
  of an array of strings.
* `-c`, `--cols COLS` sets the number of octets per line in the hex output.
  Default is 16, maximum is 256.
* `-u` uses uppercase hex letters instead of the default lowercase.
* `--with-comments` appends a human-readable ASCII representation of each line
  as an OCaml comment:

```bash
$ mcrunch -f foo.txt --with-comments
let foo_txt = [| "\x66\x6f\x6f\x0a" |]                                                 (* foo.             *)
```

Note that comments are not supported for `--string` output. A warning is printed on stderr:

```shell
mcrunch --string --with-comments -f foo.txt
$ Comments are not supported for string output. Not outputting comments.
let foo_txt = "\x66\x6f\x6f\x0a"
```

## Example

Given two files `index.html` and `style.css`, you can generate an OCaml module
that embeds both:

```
$ mcrunch -f index.html -f style.css -o static.ml
```

The resulting `static.ml` contains two bindings, `index_html` and `style_css`,
each holding the full file contents as a string array. You can then reference
these values from your OCaml program and reconstruct the original content with
`String.concat ""` (for arrays, `Array.to_list` first).
