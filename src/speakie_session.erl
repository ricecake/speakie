-module(speakie_session).
-behaviour(gen_fsm).
-define(SERVER, ?MODULE).

%% ------------------------------------------------------------------
%% API Function Exports
%% ------------------------------------------------------------------

-export([
	start_link/1, create/1, bind/2, notify/3, notify/4, inform/3
]).

%% ------------------------------------------------------------------
%% gen_fsm Function Exports
%% ------------------------------------------------------------------

-export([
	init/1, handle_event/3, handle_sync_event/4,
	handle_info/3, terminate/3, code_change/4
]).

-export([
	orphaned/2, orphaned/3,
	connected/2, connected/3
]).

%% ------------------------------------------------------------------
%% API Function Definitions
%% ------------------------------------------------------------------

start_link(Args) ->
	gen_fsm:start_link(?MODULE, Args, []).


create(Meta) ->
	NewSessionId = speakie:getNewId(),
	{ok, Pid}    = speakie_session_sup:create(NewSessionId, Meta),
	{NewSessionId, Pid}.

bind(Pid, Meta) -> gen_fsm:sync_send_event(Pid, {bind, {self(), Meta}}).

notify(Session, Type, Message) ->
	notify(Session, undefined, Type, Message).

notify(Session, undefined, Type, Message) when is_pid(Session) ->
	gen_fsm:send_event(Session, {Type, Message});
notify(Session, From, Type, Message) when is_pid(Session) ->
	gen_fsm:send_event(Session, {Type, From, Message});
notify(Session, From, Type, Message) when is_binary(Session) ->
	{ok, {Session, Pid}} = speakie_storage_srv:findSession(Session),
	notify(Pid, From, Type, Message).

inform(Session, Type, Message) when is_pid(Session) ->
	gen_fsm:sync_send_event(Session, {Type, Message}).

%% ------------------------------------------------------------------
%% gen_fsm Function Definitions
%% ------------------------------------------------------------------

init(#{sockets := [Socket]} = Args) ->
	monitor(process, Socket),
	{ok, State} = storeRow(Args#{ channel => [] }),
	speakie_msg_handler:send(Socket, <<"session.data">>, maps:with([id, meta], State)),
	{ok, connected, State}.

orphaned(timeout, State) ->
	{stop, normal, State};
orphaned(_Event, State) ->
	{next_state, orphaned, State, 60000}.

orphaned({bind, {Socket, Data}}, _From, #{ meta := Meta } = State) ->
	monitor(process, Socket),
	{ok, NewState} = storeRow(State#{ sockets := [Socket], meta := mapMerge(Meta, Data) }),
	speakie_msg_handler:send(Socket, <<"session.data">>, maps:with([id, meta], NewState)),
	{reply, ok, connected, NewState}.


connected({signal, {Type, Data}}, #{ sockets := Sockets } = State) ->
	[speakie_msg_handler:send(Socket, Type, Data) || Socket <- Sockets],
	{next_state, connected, State};
connected({signal, From, {Type, Data}}, #{ sockets := Sockets } = State) ->
	[speakie_msg_handler:send(Socket, Type, Data, #{ from => From }) || Socket <- Sockets],
	{next_state, connected, State};
connected({control, socket_close}, #{ sockets := [], channel := Channel } = State) ->
	speakie_storage_srv:sendChannel(Channel, signal, {<<"channel.disconnected">>, maps:with([id, meta], State)}),
	{next_state, orphaned, State, 60000};
connected({control, socket_close}, State) ->
	{next_state, connected, State};
connected({direct, Recipient, Event}, #{ id := Id } = State) ->
	notify(Recipient, signal, {Id, Event}),
	{next_state, connected, State};
connected({<<"session.data.update">>, MetaData}, #{ meta := Data, sockets := Sockets } = State) ->
	{ok, NewState} = storeRow(State#{ meta := mapMerge(MetaData, Data) }),
	ok = case maps:find(channel, NewState) of
		{ok, Channel} ->
			speakie_storage_srv:sendChannel(Channel, signal, {<<"session.data.changed">>, maps:with([id, meta], NewState)});
		error ->
			[speakie_msg_handler:send(Socket, <<"session.data.changed">>, maps:with([id, meta], NewState)) || Socket <- Sockets]
	end,
	{next_state, connected, NewState};
connected({<<"session.join">>, #{ <<"channel">> := ChannelId }}, #{ sockets := Sockets } = State) ->
	{ok, NewState} = speakie_storage_srv:joinChannel(ChannelId, State),
	speakie_storage_srv:sendChannel(ChannelId, signal, {<<"channel.connected">>, maps:with([id, meta], NewState)}),
	[speakie_msg_handler:send(Socket, <<"channel.roster">>, speakie_storage_srv:channelRoster(ChannelId)) || Socket <- Sockets],
	{next_state, connected, NewState};
connected(Event, #{ channel := Channel, id := Id } = State) ->
	ok = speakie_storage_srv:sendChannel(Channel, Id, signal, Event),
	{next_state, connected, State};
connected(_Event, State) ->
	{next_state, connected, State}.

connected({bind, {Socket, Data}}, _From, #{ meta := Meta, sockets := Sockets } = State) ->
	monitor(process, Socket),
	{ok, NewState} = storeRow(State#{ sockets := lists:umerge([Socket], Sockets), meta := mapMerge(Meta, Data) }),
	speakie_msg_handler:send(Socket, <<"session.data">>, maps:with([id, meta], State)),
	{reply, ok, connected, NewState};
connected(_Event, _From, State) ->
	{reply, ok, connected, State}.

%% ------------------------------------------------------------------
%% All state callbacks
%% ------------------------------------------------------------------

handle_event({Type, Data}, StateName, #{sockets := Sockets } = State) ->
	[speakie_msg_handler:send(Socket, Type, Data) || Socket <- Sockets],
	{next_state, StateName, State};
handle_event(_Event, StateName, State) ->
	{next_state, StateName, State}.

handle_sync_event(_Event, _From, StateName, State) ->
    {reply, ok, StateName, State}.

handle_info({'DOWN', _Ref, _Type, Socket, _Exit}, StateName, #{sockets := Sockets } = State) ->
	notify(self(), control, socket_close),
	{next_state, StateName, State#{ sockets := lists:delete(Socket, Sockets) }};
handle_info(_Info, StateName, State) ->
	{next_state, StateName, State}.

terminate(_Reason, _StateName, #{ id := Id } = State) ->
	ok = case maps:find(channel, State) of
		{ok, Channel} ->
			speakie_storage_srv:sendChannel(Channel, signal, {<<"channel.shutdown">>, #{ sessionid => Id }});
		error -> ok
	end,
	speakie_storage_srv:leaveChannel('_', State),
	speakie_storage_srv:deleteSession(Id).

code_change(_OldVsn, StateName, State, _Extra) ->
    {ok, StateName, State}.

%% ------------------------------------------------------------------
%% Internal Function Definitions
%% ------------------------------------------------------------------

storeRow(#{ id := Id, meta := Meta } = State) ->
	speakie_storage_srv:storeSession(Id, self(), Meta),
	{ok, State}.

mapMerge(A, B) when is_map(A), is_map(B) -> maps:from_list(lists:append(maps:to_list(A), maps:to_list(B))).
