-module(eake).
-author("Sina Samavati <sina.samv@gmail.com>").

-export([main/1]).


main([]) ->
    compile_eake_tasks(),
    help();
main(Args) ->
    compile_eake_tasks(),
    {Opts, Params} = case getopt:parse(option_spec_list(), Args) of
                         {ok, Result} ->
                             Result;
                         {error, {Reason, Data}} ->
                             help(Reason, Data)
                     end,
    maybe_help(Opts, Params),
    [H|TaskArgs] = Params,
    Task = list_to_atom(H),
    maybe_invalid(Task),
    erlang:apply(eake_tasks, Task, TaskArgs).

%% compile Eakefile
compile_eake_tasks() ->
    {ok, MTs, _} = erl_scan:string("-module(eake_tasks).\n"),
    {ok, MF} = erl_parse:parse_form(MTs),

    {ok, ETs, _} = erl_scan:string("-compile(export_all).\n"),
    {ok, EF} = erl_parse:parse_form(ETs),

    {ok, SourceBin} = file:read_file("Eakefile"),
    Source = binary_to_list(SourceBin),
    STs = tokens(Source),

    %% add describe/1 by checking the description attribute
    {DescribeFunc, STs1} = describe_function(STs, [], []),
    {ok, DTs, _} = erl_scan:string(DescribeFunc),
    {ok, DF} = erl_parse:parse_form(DTs),

    %% parse list of Tokens
    SF = walk_list(STs1, fun erl_parse:parse_form/1, []),

    {ok, eake_tasks, Bin} = compile:forms([MF, EF, DF] ++ SF),
    code:load_binary(eake_tasks, "nofile", Bin),
    eake_tasks:module_info().

%% returns {describe(Task) -> Description, and valid tokens}
describe_function([], Acc, AccTokens) ->
    {binary_to_list(iolist_to_binary(Acc)) ++ "describe(_) -> undefined.\n",
     AccTokens};
describe_function([Tokens|Rest], Acc, AccTokens) ->
    {Src,
     Acc2} = case lists:keyfind(description, 3, Tokens) of
                 {atom, _, description} ->
                     {string, _, Description} = lists:keyfind(string, 1, Tokens),
                     {atom, _, Func} = hd(hd(Rest)),
                     {io_lib:format("describe(~p) -> ~p;\n", [Func, Description]),
                      []};
                 _ ->
                     {"", Tokens}
             end,
    describe_function(Rest, Acc ++ Src, AccTokens ++ [Acc2]).

%% parse source
%% returns [Tokens]
tokens(Source) ->
    tokens(Source, []).

tokens([], Acc) ->
    Acc;
tokens(Source, Acc) ->
    {Rest1, Tokens1} = case erl_scan:tokens([], Source, 1) of
                           {done, {ok, Tokens, _}, Rest} ->
                               {Rest, Tokens};
                           _ ->
                               {[], []}
                       end,
    tokens(Rest1, Acc ++ [Tokens1]).

%% walks [Tokens] and applies Fun on Tokens
walk_list([], _, Acc) ->
    Acc;
walk_list([[]|T], Fun, Acc) ->
    walk_list(T, Fun, Acc);
walk_list([H|T], Fun, Acc) ->
    {ok, Result} = Fun(H),
    walk_list(T, Fun, Acc ++ [Result]).


option_spec_list() ->
    [
     {help, $h, "help", undefined, "Displays this message"}
    ].

%% checks if "-h" or "help" is used
maybe_help(Opts, Params) ->
    Fun = fun(L) ->
                  case lists:member(help, L) of
                      true ->
                          help();
                      false ->
                          ok
                  end
          end,
    Fun(Opts),
    Fun(Params).

%% checks if the Task is valid or not
maybe_invalid(Task) ->
    case lists:keyfind(Task, 1, tasks_list()) of
        {Task, _} ->
            ok;
        _ ->
            help("invalid_task", Task)
    end.

help("invalid_task", Data) ->
    help(io_lib:format("invalid_task \"~s\"", [Data]));
help(Reason, Data) ->
    help(io_lib:format("~s ~p", [Reason, Data])).

help(Msg) ->
    io:format("Error: ~s~n~n", [Msg]),
    help().

help() ->
    io:format("Eake :: A make-like tool for Erlang~n"),
    Params = [
              {"", ""}
             ] ++ tasks(),
    getopt:usage(option_spec_list(), escript:script_name(), "", Params),
    halt().

tasks() ->
    walk_tasks(tasks_list(), []).

tasks_list() ->
    L = [{describe, 1}, {module_info, 0}, {module_info, 1}],
    eake_tasks:module_info(exports) -- L.

walk_tasks([], Acc) ->
    Acc;
walk_tasks([{Name, _}|T], Acc) ->
    walk_tasks(T, Acc ++ [{atom_to_list(Name), eake_tasks:describe(Name)}]).
