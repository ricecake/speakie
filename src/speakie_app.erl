-module(speakie_app).

-behaviour(application).

%% Application callbacks
-export([start/2, stop/1]).

%% ===================================================================
%% Application callbacks
%% ===================================================================

start(_StartType, _StartArgs) ->
	case speakie_sup:start_link() of
		{ok, Pid} ->
			Dispatch = cowboy_router:compile([
				{'_', [
					{"/ws/",          speakie_msg_handler, #{}},
					{"/:channel",     speakie_page,        engage},
					{"/",             speakie_page,        index},
					{"/static/[...]", cowboy_static, {priv_dir, speakie, "static/"}}
				]}
			]),
			{ok, _} = cowboy:start_http(http, 25, [{ip, {127,0,0,1}}, {port, 8585}],
							[{env, [{dispatch, Dispatch}]}]),
			{ok, Pid}
	end.

stop(_State) ->
	ok.
