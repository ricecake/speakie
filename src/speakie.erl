-module(speakie).

-export([
	start/0, getNewId/0, timestamp/0
]).

start() -> application:ensure_all_started(speakie).

getNewId() -> erlang:integer_to_binary(binary:decode_unsigned(crypto:rand_bytes(32)), 36).
timestamp() -> {Mega, Secs, Micro} = erlang:now(),  Mega*1000*1000*1000*1000 + Secs * 1000 * 1000 + Micro.
