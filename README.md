# Eake

A make-like tool for Erlang.

## Why?

Because invoking shell commands from Erlang is sometimes better than invoking Erlang several times from a Makefile.

## Installation

Clone it and just run `make` then put the `eake` file in your `$PATH`.

## Usage

Writing a task is like a function definition, moreover, Eake lets you describe what a task does.

Just touch a file with the name `Eakefile`, and use `-description :: "context...".` above the task to describe what it deos.

Example:
```erlang
%% Eakefile

-description :: "Prints 'Hello, World!'".
'hello-world'() ->
    io:format("Hello, World!~n").

-description :: "Echos an argument".
echo(Arg) ->
    io:format("~s~n", [Arg]).
```

```
$ eake
Eake :: A make-like tool for Erlang

Usage: ./eake [-h]

  -h, --help   Displays this message

  hello-world  Prints 'Hello, World!'
  echo         Echos an argument

###

$ eake hello-world
Hello, World!

$ eake echo "hello everybody"
hello everybody
```

## License

MIT, see LICENSE file for more details.
