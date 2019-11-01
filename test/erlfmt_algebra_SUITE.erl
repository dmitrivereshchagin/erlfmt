%% Copyright (c) Facebook, Inc. and its affiliates.
%%
%% Licensed under the Apache License, Version 2.0 (the "License");
%% you may not use this file except in compliance with the License.
%% You may obtain a copy of the License at
%%
%%     http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing, software
%% distributed under the License is distributed on an "AS IS" BASIS,
%% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%% See the License for the specific language governing permissions and
%% limitations under the License.
-module(erlfmt_algebra_SUITE).

-include_lib("common_test/include/ct.hrl").
-include_lib("stdlib/include/assert.hrl").
-include_lib("proper/include/proper.hrl").

%% Test server callbacks
-export([
    suite/0,
    all/0,
    groups/0,
    init_per_suite/1, end_per_suite/1,
    init_per_group/2, end_per_group/2,
    init_per_testcase/2, end_per_testcase/2
]).

%% Test cases
-export([
    string_append_case/1,
    string_spaces_case/1,
    lines_combine_case/1,
    lines_unit/1,
    metric_combine_case/1,
    metric_unit/1
]).

-define(alg, erlfmt_algebra).

suite() ->
    [{timetrap, {seconds, 10}}].

init_per_suite(Config) ->
    Config.

end_per_suite(_Config) ->
    ok.

init_per_group(_GroupName, Config) ->
    Config.

end_per_group(_GroupName, _Config) ->
    ok.

init_per_testcase(_TestCase, Config) ->
    Config.

end_per_testcase(_TestCase, _Config) ->
    ok.

groups() ->
    [
        {string_api, [parallel], [string_append_case, string_spaces_case]},
        {lines_api, [parallel], [lines_combine_case, lines_unit]},
        {metric_api, [parallel], [metric_combine_case, metric_unit]}
    ].

all() ->
    [{group, string_api}, {group, lines_api}, {group, metric_api}].

%%--------------------------------------------------------------------
%% TEST CASESS

string_append_equal_prop() ->
    ?FORALL({Left, Right}, {str(), str()}, begin
        Appended = ?alg:string_append(Left, Right),
        string:equal(?alg:string_text(Appended), [?alg:string_text(Left) | ?alg:string_text(Right)])
    end).

string_append_length_prop() ->
    ?FORALL({Left, Right}, {str(), str()}, begin
        Appended = ?alg:string_append(Left, Right),
        ?alg:string_length(Appended) =:= string:length(?alg:string_text(Appended))
    end).

string_append_case(Config) when is_list(Config) ->
    ct_proper:quickcheck(string_append_equal_prop()),
    ct_proper:quickcheck(string_append_length_prop()).

string_spaces_prop() ->
    ?FORALL(Count, non_neg_integer(), begin
        string:length(?alg:string_text(?alg:string_spaces(Count))) =:= Count
    end).

string_spaces_case(Config) when is_list(Config) ->
    ct_proper:quickcheck(string_spaces_prop()).

-record(layout, {new, flush, combine, render}).

combine_assoc_prop(#layout{combine = Combine, render = Render} = Layout) ->
    Gen = layout(Layout),
    ?FORALL({L1, L2, L3}, {Gen, Gen, Gen}, begin
        Combined1 = Combine(L1, Combine(L2, L3)),
        Combined2 = Combine(Combine(L1, L2), L3),
        string:equal(Render(Combined1), Render(Combined2))
    end).

combine_flush_prop(#layout{combine = Combine, render = Render, flush = Flush} = Layout) ->
    Gen = layout(Layout),
    ?FORALL({L1, L2}, {Gen, Gen}, begin
        Combined1 = Combine(Flush(L1), Flush(L2)),
        Combined2 = Flush(Combine(Flush(L1), L2)),
        string:equal(Render(Combined1), Render(Combined2))
    end).

lines_combine_case(Config) when is_list(Config) ->
    Lines = lines_layout(),
    ct_proper:quickcheck(combine_assoc_prop(Lines)),
    ct_proper:quickcheck(combine_flush_prop(Lines)).

lines_unit(Config) when is_list(Config) ->
    % xxxxxxxx      yyyyyyyy     xxxxxxxx
    % xxx       <>  yyyy      =  xxx
    % xxxxxxx                    xxxxxxx
    % xxxxx                      xxxxxyyyyyyyy
    %                                 yyyy
    New = fun (Text) -> ?alg:lines_new(?alg:string_new(Text)) end,
    #layout{flush = Flush, combine = Combine, render = Render} = lines_layout(),

    Left = Combine(
        Flush(New("xxxxxxxx")),
        Combine(Flush(New("xxx")), Combine(Flush(New("xxxxxxx")), New("xxxxx")))
    ),
    ?assertEqual(
        "xxxxxxxx\n"
        "xxx\n"
        "xxxxxxx\n"
        "xxxxx",
        unicode:characters_to_list(Render(Left))
    ),

    Right = Combine(Flush(New("yyyyyyyy")), New("yyyy")),
    ?assertEqual(
        "yyyyyyyy\n"
        "yyyy",
        unicode:characters_to_list(Render(Right))
    ),

    Combined = Combine(Left, Right),
    ?assertEqual(
        "xxxxxxxx\n"
        "xxx\n"
        "xxxxxxx\n"
        "xxxxxyyyyyyyy\n"
        "     yyyy",
        unicode:characters_to_list(Render(Combined))
    ).

metric_combine_case(Config) when is_list(Config) ->
    Metric = metric_layout(),
    ct_proper:quickcheck(combine_assoc_prop(Metric)),
    ct_proper:quickcheck(combine_flush_prop(Metric)).

metric_unit(Config) when is_list(Config) ->
    % xxxxxxxx      yyyyyyyy     xxxxxxxxxxxxx
    % xxx       <>  yyyy      =  xxxxxxxxxxxxx
    % xxxxxxx                    xxxxxxxxxxxxx
    % xxxxx                      xxxxxxxxxxxxx
    %                            xxxxxxxxx
    New = fun (Text) -> ?alg:metric_new(?alg:string_new(Text)) end,
    #layout{flush = Flush, combine = Combine, render = Render} = metric_layout(),

    Left = Combine(
        Flush(New("xxxxxxxx")),
        Combine(Flush(New("xxx")), Combine(Flush(New("xxxxxxx")), New("xxxxx")))
    ),
    ?assertEqual(
        "xxxxxxxx\n"
        "xxxxxxxx\n"
        "xxxxxxxx\n"
        "xxxxx",
        unicode:characters_to_list(Render(Left))
    ),

    Right = Combine(Flush(New("yyyyyyyy")), New("yyyy")),
    ?assertEqual(
        "xxxxxxxx\n"
        "xxxx",
        unicode:characters_to_list(Render(Right))
    ),

    Combined = Combine(Left, Right),
    ?assertEqual(
        "xxxxxxxxxxxxx\n"
        "xxxxxxxxxxxxx\n"
        "xxxxxxxxxxxxx\n"
        "xxxxxxxxxxxxx\n"
        "xxxxxxxxx",
        unicode:characters_to_list(Render(Combined))
    ).

lines_layout() ->
    #layout{
        new = fun ?alg:lines_new/1,
        flush = fun ?alg:lines_flush/1,
        combine = fun ?alg:lines_combine/2,
        render = fun ?alg:lines_render/1
    }.

metric_layout() ->
    #layout{
        new = fun ?alg:metric_new/1,
        flush = fun ?alg:metric_flush/1,
        combine = fun ?alg:metric_combine/2,
        render = fun ?alg:metric_render/1
    }.

%% It's possible for the utf8 generator to produce strings that start or end with
%% a decomposed accent or something else like this - this means that when appended
%% it composes into one grapheme with the other string and lengths are off.
str() ->
    ClosedUTF8 = ?SUCHTHAT(Str, utf8(), begin
        Length = string:length(Str),
        string:length([" " | Str]) =/= Length andalso string:length([Str | " "]) =/= Length
    end),
    ?LET(Str, ClosedUTF8, ?alg:string_new(string:replace(Str, [<<"\n">>, <<"\r">>], <<>>))).

layout(Layout) ->
    ?SIZED(Size, limited_layout(Size, Layout)).

limited_layout(Size, #layout{new = New}) when Size =< 1 ->
    ?LET(Str, str(), New(Str));
limited_layout(Size, #layout{new = New, flush = Flush, combine = Combine} = Layout) ->
    Self = ?LAZY(limited_layout(Size - 1, Layout)),
    union([
        ?LET(Str, str(), New(Str)),
        ?LET(Lines, Self, Flush(Lines)),
        ?LET({Left, Right}, {Self, Self}, Combine(Left, Right))
    ]).