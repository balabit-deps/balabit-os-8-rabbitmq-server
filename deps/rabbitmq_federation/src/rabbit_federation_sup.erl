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
%% The Original Code is RabbitMQ Federation.
%%
%% The Initial Developer of the Original Code is GoPivotal, Inc.
%% Copyright (c) 2007-2020 Pivotal Software, Inc.  All rights reserved.
%%

-module(rabbit_federation_sup).

-behaviour(supervisor).

%% Supervises everything. There is just one of these.

-include_lib("rabbit_common/include/rabbit.hrl").
-define(SUPERVISOR, rabbit_federation_sup).

-export([start_link/0, stop/0]).

-export([init/1]).

%% This supervisor needs to be part of the rabbit application since
%% a) it needs to be in place when exchange recovery takes place
%% b) it needs to go up and down with rabbit

-rabbit_boot_step({rabbit_federation_supervisor,
                   [{description, "federation"},
                    {mfa,         {rabbit_sup, start_child, [?MODULE]}},
                    {requires,    kernel_ready},
                    {cleanup,     {?MODULE, stop, []}},
                    {enables,     rabbit_federation_exchange},
                    {enables,     rabbit_federation_queue}]}).

%%----------------------------------------------------------------------------

start_link() ->
    R = supervisor:start_link({local, ?SUPERVISOR}, ?MODULE, []),
    rabbit_federation_event:add_handler(),
    R.

stop() ->
    rabbit_federation_event:remove_handler(),
    ok = supervisor:terminate_child(rabbit_sup, ?MODULE),
    ok = supervisor:delete_child(rabbit_sup, ?MODULE).

%%----------------------------------------------------------------------------

init([]) ->
    Status = {status, {rabbit_federation_status, start_link, []},
              transient, ?WORKER_WAIT, worker,
              [rabbit_federation_status]},
    XLinkSupSup = {x_links,
                   {rabbit_federation_exchange_link_sup_sup, start_link, []},
                   transient, ?SUPERVISOR_WAIT, supervisor,
                   [rabbit_federation_exchange_link_sup_sup]},
    QLinkSupSup = {q_links,
                   {rabbit_federation_queue_link_sup_sup, start_link, []},
                  transient, ?SUPERVISOR_WAIT, supervisor,
                  [rabbit_federation_queue_link_sup_sup]},
    %% with default reconnect-delay of 5 second, this supports up to
    %% 100 links constantly failing and being restarted a minute
    %% (or 200 links if reconnect-delay is 10 seconds, 600 with 30 seconds,
    %% etc: N * (60/reconnect-delay) <= 1200)
    {ok, {{one_for_one, 1200, 60}, [Status, XLinkSupSup, QLinkSupSup]}}.
