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
%% Copyright (c) 2007-2020 Pivotal Software, Inc.  All rights reserved.
%%

-module(rabbit_trust_store_app).
-behaviour(application).
-export([change_SSL_options/0]).
-export([revert_SSL_options/0]).
-export([start/2, stop/1]).

-rabbit_boot_step({rabbit_trust_store, [
    {description, "Overrides TLS options in take RabbitMQ trust store into account"},
    {mfa, {?MODULE, change_SSL_options, []}},
    {cleanup, {?MODULE, revert_SSL_options, []}},
    %% {requires, ...},
    {enables, networking}]}).

change_SSL_options() ->
    After = case application:get_env(rabbit, ssl_options) of
        undefined ->
            Before = [],
            edit(Before);
        {ok, Before} when is_list(Before) ->
            ok = application:set_env(rabbit, initial_SSL_options, Before),
            edit(Before)
    end,
    ok = application:set_env(rabbit,
        ssl_options, After).

revert_SSL_options() ->
    {ok, Cfg} = application:get_env(rabbit, initial_SSL_options),
    ok = application:set_env(rabbit, ssl_options, Cfg).

start(normal, _) ->
    rabbit_trust_store_sup:start_link().

stop(_) ->
    ok.


%% Ancillary & Constants

edit(Options) ->
    case proplists:get_value(verify_fun, Options) of
        undefined ->
            ok;
        Val       ->
            rabbit_log:warning("RabbitMQ trust store plugin is used "
                               "and the verify_fun TLS option is set: ~p. "
                               "It will be overwritten by the plugin.~n", [Val]),
            ok
    end,
    %% Only enter those options neccessary for this application.
    lists:keymerge(1, required_options(),
        [{verify_fun, {delegate(), continue}},
         {partial_chain, fun partial_chain/1} | Options]).

delegate() -> fun rabbit_trust_store:whitelisted/3.

partial_chain(Chain) ->
    % special handling of clients that present a chain rather than just a peer cert.
    case lists:reverse(Chain) of
        [PeerDer, Ca | _] ->
            Peer = public_key:pkix_decode_cert(PeerDer, otp),
            % If the Peer is whitelisted make it's immediate Authority a trusted one.
            % This means the peer will automatically be validated.
            case rabbit_trust_store:is_whitelisted(Peer) of
                true -> {trusted_ca, Ca};
                false -> unknown_ca
            end;
        _ -> unknown_ca
    end.

required_options() ->
    [{verify, verify_peer}, {fail_if_no_peer_cert, true}].
