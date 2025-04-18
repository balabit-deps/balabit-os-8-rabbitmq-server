%%   The contents of this file are subject to the Mozilla Public License
%%   Version 1.1 (the "License"); you may not use this file except in
%%   compliance with the License. You may obtain a copy of the License at
%%   https://www.mozilla.org/MPL/
%%
%%   Software distributed under the License is distributed on an "AS IS"
%%   basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See the
%%   License for the specific language governing rights and limitations
%%   under the License.
%%
%%   The Original Code is RabbitMQ Management Console.
%%
%%   The Initial Developer of the Original Code is GoPivotal, Inc.
%%   Copyright (c) 2007-2020 Pivotal Software, Inc.  All rights reserved.
%%

-module(rabbit_peer_discovery_common_app).

-behaviour(application).
-export([start/2, stop/1]).

start(_Type, _StartArgs) ->
    rabbit_peer_discovery_httpc:maybe_configure_proxy(),
    rabbit_peer_discovery_httpc:maybe_configure_inet6(),
    rabbit_peer_discovery_common_sup:start_link().

stop(_State) ->
    ok.
