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
%% The Original Code is RabbitMQ Sharding Plugin
%%
%% The Initial Developer of the Original Code is GoPivotal, Inc.
%% Copyright (c) 2007-2020 Pivotal Software, Inc.  All rights reserved.
%%

-module(rabbit_sharding_exchange_type_modulus_hash).

-include_lib("rabbit_common/include/rabbit.hrl").

-behaviour(rabbit_exchange_type).

-export([description/0, serialise_events/0, route/2, info/1, info/2]).
-export([validate/1, validate_binding/2,
         create/2, delete/3, policy_changed/2,
         add_binding/3, remove_bindings/3, assert_args_equivalence/2]).

-rabbit_boot_step(
   {rabbit_sharding_exchange_type_modulus_hash_registry,
    [{description, "exchange type x-modulus-hash: registry"},
     {mfa,         {rabbit_registry, register,
                    [exchange, <<"x-modulus-hash">>, ?MODULE]}},
     {cleanup, {rabbit_registry, unregister,
                [exchange, <<"x-modulus-hash">>]}},
     {requires,    rabbit_registry},
     {enables,     kernel_ready}]}).

-define(PHASH2_RANGE, 134217728). %% 2^27

description() ->
    [{description, <<"Modulus Hashing Exchange">>}].

serialise_events() -> false.

route(#exchange{name = Name},
      #delivery{message = #basic_message{routing_keys = Routes}}) ->
    Qs = rabbit_router:match_routing_key(Name, ['_']),
    case length(Qs) of
        0 -> [];
        N -> [lists:nth(hash_mod(Routes, N), Qs)]
    end.

info(_) -> [].

info(_, _) -> [].

validate(_X) -> ok.
validate_binding(_X, _B) -> ok.
create(_Tx, _X) -> ok.
delete(_Tx, _X, _Bs) -> ok.
policy_changed(_X1, _X2) -> ok.
add_binding(_Tx, _X, _B) -> ok.
remove_bindings(_Tx, _X, _Bs) -> ok.
assert_args_equivalence(X, Args) ->
    rabbit_exchange:assert_args_equivalence(X, Args).

hash_mod(Routes, N) ->
    M = erlang:phash2(Routes, ?PHASH2_RANGE) rem N,
    M + 1. %% erlang lists are 1..N indexed.
