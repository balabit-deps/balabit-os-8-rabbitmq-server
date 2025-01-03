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

-module(rabbit_trust_store_sup).
-behaviour(supervisor).
-export([start_link/0]).
-export([init/1]).

-include_lib("rabbit_common/include/rabbit.hrl").


%% ...

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).


%% ...

init([]) ->
    Flags = #{strategy => one_for_one,
              intensity => 10,
              period => 1},
    ChildSpecs = [
        #{
            id => trust_store,
            start => {rabbit_trust_store, start_link, []},
            restart => permanent,
            shutdown => timer:seconds(15),
            type => worker,
            modules => [rabbit_trust_store]
        }
    ],

    {ok, {Flags, ChildSpecs}}.
