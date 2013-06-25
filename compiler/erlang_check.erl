#!/usr/bin/env escript

main([File]) ->
    Dir = filename:dirname(File),
    Defs = [strong_validation,
            warn_export_all,
            warn_export_vars,
            warn_shadow_vars,
            warn_obsolete_guard,
            warn_unused_import,
            report,
            {i, Dir ++ "/include"},
            {i, Dir ++ "/../include"},
            {i, Dir ++ "/../../include"},
            {i, Dir ++ "/../../../include"}],
    RebarOpts = case consult_file("rebar.config") of
        {ok, Terms} ->
            RebarLibDirs = proplists:get_value(lib_dirs, Terms, []),
            %% Add these dirs to the path directly
            [ code:add_pathsa(filelib:wildcard(LibDir ++ "/*/ebin")) || LibDir <- RebarLibDirs ],
            RebarDepsDir = proplists:get_value(deps_dir, Terms, "deps"),
            code:add_pathsa(filelib:wildcard(RebarDepsDir ++ "/*/ebin")),
            proplists:get_value(erl_opts, Terms, []);
        {error, _} ->
            []
    end,
    code:add_patha(filename:absname("ebin")),
    compile:file(File, Defs ++ RebarOpts);
main(_) ->
    io:format("Usage: ~s <file>~n", [escript:script_name()]),
    halt(1).


consult_file(File) ->
    case filename:extension(File) of
        ".script" ->
            consult_and_eval(remove_script_ext(File), File);
        _ ->
            Script = File ++ ".script",
            case filelib:is_regular(Script) of
                true ->
                    consult_and_eval(File, Script);
                false ->
                    file:consult(File)
            end
    end.

consult_and_eval(File, Script) ->
    ConfigData = try_consult(File),
    file:script(Script, bs([{'CONFIG', ConfigData}, {'SCRIPT', Script}])).

try_consult(File) ->
    case file:consult(File) of
        {ok, Terms} ->
            Terms;
        {error, enoent} ->
            [];
        {error, Reason} ->
            io:format("Failed to read config file ~s: ~p~n", [File, Reason])
    end.

bs(Vars) ->
    lists:foldl(fun({K,V}, Bs) ->
                        erl_eval:add_binding(K, V, Bs)
                end, erl_eval:new_bindings(), Vars).

remove_script_ext(F) ->
    "tpircs." ++ Rev = lists:reverse(F),
    lists:reverse(Rev).


