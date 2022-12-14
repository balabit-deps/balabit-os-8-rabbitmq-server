%% The contents of this file are subject to the Mozilla Public License
%% Version 1.1 (the "License"); you may not use this file except in
%% compliance with the License. You may obtain a copy of the License
%% at https://www.mozilla.org/MPL/
%%
%% Software distributed under the License is distributed on an "AS IS"
%% basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See
%% the License for the specific language governing rights and
%% limitations under the License.
%%
%% The Original Code is RabbitMQ.
%%
%% The Initial Developer of the Original Code is GoPivotal, Inc.
%% Copyright (c) 2007-2017 Pivotal Software, Inc.  All rights reserved.
%%

-module(rabbit_stomp).

-include("rabbit_stomp.hrl").

-behaviour(application).
-export([start/2, stop/1]).
-export([parse_default_user/2]).
-export([connection_info_local/1,
         emit_connection_info_local/3,
         emit_connection_info_all/4,
         list/0]).

-define(DEFAULT_CONFIGURATION,
        #stomp_configuration{
          default_login    = undefined,
          default_passcode = undefined,
          implicit_connect = false,
          ssl_cert_login   = false}).

start(normal, []) ->
    Config = parse_configuration(),
    Listeners = parse_listener_configuration(),
    rabbit_stomp_sup:start_link(Listeners, Config).

stop(_State) ->
    ok.

emit_connection_info_all(Nodes, Items, Ref, AggregatorPid) ->
    Pids = [spawn_link(Node, rabbit_stomp, emit_connection_info_local,
                       [Items, Ref, AggregatorPid])
            || Node <- Nodes],
    rabbit_control_misc:await_emitters_termination(Pids),
    ok.

emit_connection_info_local(Items, Ref, AggregatorPid) ->
    rabbit_control_misc:emitting_map_with_exit_handler(
      AggregatorPid, Ref, fun(Pid) ->
                                  rabbit_stomp_reader:info(Pid, Items)
                          end,
      list()).

connection_info_local(Items) ->
    Connections = list(),
    [rabbit_stomp_reader:info(Pid, Items) || Pid <- Connections].

parse_listener_configuration() ->
    {ok, Listeners} = application:get_env(tcp_listeners),
    {ok, SslListeners} = application:get_env(ssl_listeners),
    {Listeners, SslListeners}.

parse_configuration() ->
    {ok, UserConfig} = application:get_env(default_user),
    Conf0 = parse_default_user(UserConfig, ?DEFAULT_CONFIGURATION),
    {ok, SSLLogin} = application:get_env(ssl_cert_login),
    {ok, ImplicitConnect} = application:get_env(implicit_connect),
    Conf = Conf0#stomp_configuration{ssl_cert_login   = SSLLogin,
                                     implicit_connect = ImplicitConnect},
    report_configuration(Conf),
    Conf.

parse_default_user([], Configuration) ->
    Configuration;
parse_default_user([{login, Login} | Rest], Configuration) ->
    parse_default_user(Rest, Configuration#stomp_configuration{
                               default_login = Login});
parse_default_user([{passcode, Passcode} | Rest], Configuration) ->
    parse_default_user(Rest, Configuration#stomp_configuration{
                               default_passcode = Passcode});
parse_default_user([Unknown | Rest], Configuration) ->
    rabbit_log:warning("rabbit_stomp: ignoring invalid default_user "
                       "configuration option: ~p~n", [Unknown]),
    parse_default_user(Rest, Configuration).

report_configuration(#stomp_configuration{
                        default_login    = Login,
                        implicit_connect = ImplicitConnect,
                        ssl_cert_login   = SSLCertLogin}) ->
    case Login of
        undefined -> ok;
        _         -> rabbit_log:info("rabbit_stomp: default user '~s' "
                                     "enabled~n", [Login])
    end,

    case ImplicitConnect of
        true  -> rabbit_log:info("rabbit_stomp: implicit connect enabled~n");
        false -> ok
    end,

    case SSLCertLogin of
        true  -> rabbit_log:info("rabbit_stomp: ssl_cert_login enabled~n");
        false -> ok
    end,

    ok.

list() ->
    [Client
     || {_, ListSupPid, _, _} <- supervisor2:which_children(rabbit_stomp_sup),
        {_, RanchSup, supervisor, _} <- supervisor2:which_children(ListSupPid),
        {ranch_conns_sup, ConnSup, _, _} <- supervisor:which_children(RanchSup),
        {_, CliSup, _, _} <- supervisor:which_children(ConnSup),
        {rabbit_stomp_reader, Client, _, _} <- supervisor:which_children(CliSup)].
