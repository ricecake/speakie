-module(speakie_session_sup).

-behaviour(supervisor).

%% API
-export([start_link/0, create/2]).

%% Supervisor callbacks
-export([init/1]).

%% Helper macro for declaring children of supervisor
-define(CHILD(I, Type), {I, {I, start_link, []}, transient, 5000, Type, [I]}).

%% ===================================================================
%% API functions
%% ===================================================================

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

create(Id, Meta) ->
	supervisor:start_child(?MODULE, [#{
		id => Id,
		sockets => [self()],
		meta => Meta
	}]).

%% ===================================================================
%% Supervisor callbacks
%% ===================================================================

init([]) ->
	{ok, { {simple_one_for_one, 5, 10}, [
		?CHILD(speakie_session, worker)
	]} }.
