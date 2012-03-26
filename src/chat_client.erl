-module(chat_client).
-behaviour(gen_server).

%% API
-export([start/1, name/3, send/3, list_names/1, create/2, list_channels/1,
         sign_out/1, shutdown/1, join/2, list_ch_users/2, leave/2,
         send_channel/3]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3]).

%% State
-record(state, {name, pid, server}).

%% ===================================================================== 
%% API
%% ===================================================================== 

%% ---------------------------------------------------------------------   
%% @doc
%% Starts the chat client. Takes one atom as an argument and uses it 
%% as a local name.
%% @end
%% ---------------------------------------------------------------------  
-spec start(atom()) -> ok.
start(RefName) ->
    {ok, Pid} = gen_server:start({local, RefName}, ?MODULE, [], []),
    set_pid(RefName, Pid).

%% ---------------------------------------------------------------------     
%% @doc
%% Signs the user in.
%% @end
%% TODO: change the name into something more appropriate
%% --------------------------------------------------------------------- 
-spec name(atom(), atom(), string()) -> ok.
name(ServerName, RefName, Nick) ->
    gen_server:call(RefName, {sign_in, ServerName, Nick}).

%% --------------------------------------------------------------------- 
%% @doc 
%% Send a message to another user.
%% @end
%% --------------------------------------------------------------------- 
send(RefName, To, Message) ->
    gen_server:call(RefName, {sendmsg, To, Message}).

list_names(RefName) ->
    gen_server:call(RefName, list_names).

%% --------------------------------------------------------------------- 
%% @doc
%% List the available channels
%% @end
%% --------------------------------------------------------------------- 
list_channels(RefName) ->
    gen_server:call(RefName, list_channels).

%% --------------------------------------------------------------------- 
%% @doc
%% Create a new channel
%% @end
%% --------------------------------------------------------------------- 
-spec create(atom(), atom()) -> ok.
create(RefName, Channel) ->
    gen_server:call(RefName, {create, Channel}).

%% --------------------------------------------------------------------- 
%% @doc
%% Join a channel
%% @end
%% --------------------------------------------------------------------- 
-spec join(atom(), atom()) -> ok.
join(RefName, Channel) ->
    gen_server:call(RefName, {join, Channel}).

%% --------------------------------------------------------------------- 
%% @doc
%% List users on a particular channel
%% @end
%% --------------------------------------------------------------------- 
-spec list_ch_users(atom(), atom()) -> list(list(string())).
list_ch_users(RefName, Channel) ->
    gen_server:call(RefName, {list_ch_users, Channel}).

%% --------------------------------------------------------------------- 
%% @doc
%% Leave a channel
%% @end
%% --------------------------------------------------------------------- 
leave(RefName, Channel) ->
    gen_server:call(RefName, {leave, Channel}).

%% --------------------------------------------------------------------- 
%% @doc
%% Send a message to the channel
%% @end
%% --------------------------------------------------------------------- 
send_channel(RefName, Channel, Message) ->
    gen_server:call(RefName, {send_ch, Channel, Message}).

sign_out(RefName) ->
    gen_server:cast(RefName, sign_out).

shutdown(RefName) ->
    gen_server:call(RefName, stop).

%% ===================================================================== 
%% gen_server callbacks 
%% ===================================================================== 

init([]) ->
    {ok, #state{}}.


handle_call({sign_in, Server, Name}, _From, S=#state{pid=Pid}) ->
    case gen_server:call({global, Server}, {sign_in, Name, Pid}) of
        ok -> 
            erlang:monitor(process, Server),
            {reply, ok, S#state{server=Server, name=Name}};
        name_taken -> 
            io:format("~p is taken. Select a different nick.~n", [Name]),
            {reply, name_taken, S};
        already_signed_in ->
            io:format("You are already signed in.~n", []),
            {reply, already_signed_in, S}
    end;

handle_call({sendmsg, To, Message}, _From, S=#state{server=Server, pid=Pid}) ->
    gen_server:call({global, Server}, {sendmsg, Pid, To, Message}),
    {reply, ok, S};

handle_call(list_names, _From, S=#state{server=Server}) ->
    {reply, chat_server:list_names(Server), S};

handle_call(list_channels, _From, S=#state{server=Server}) ->
    {reply, chat_server:list_channels(Server), S};

handle_call({create, Channel}, _From, S=#state{server=Server}) ->
    gen_server:cast({global, Server}, {create, Channel}),
    {reply, ok, S};

handle_call({join, Channel}, _From, S=#state{server=Server, name=Name}) ->
    gen_server:cast({global, Server}, {join, Name, Channel}),
    {reply, ok, S};

handle_call({leave, Channel}, _From, S=#state{server=Server, name=Name}) ->
    gen_server:cast({global, Server}, {leave, Name, Channel}),
    {reply, ok, S};

handle_call({list_ch_users, Channel}, _From, S=#state{server=Server}) ->
    {reply, gen_server:call({global, Server}, {list_ch_users, Channel}), S};

handle_call({send_ch, Channel, Message}, _From, S=#state{server=Server,
                                                         name=Name}) ->
    gen_server:call({global, Server}, {send_ch, Name, Channel, Message}),
    {reply, ok, S};

handle_call(stop, _From, S) ->
    {stop, normal, ok, S};

handle_call(_Request, _From, S) ->
    {reply, ok, S}.


handle_cast(sign_out, S=#state{server=Server, name=Nick}) ->
    gen_server:cast({global, Server}, {sign_out, Nick}),
    {noreply, S};

handle_cast({set_pid, Pid}, S=#state{}) ->
    {noreply, S#state{pid=Pid}};

handle_cast({not_found, To}, S) ->
    io:format("~p - no such user.", [To]),
    {noreply, S};

handle_cast(_Message, S) ->
    {noreply, S}.


handle_info({printmsg, From, Message}, S) ->
    io:format("~p says: ~p~n", [From, Message]),
    {noreply, S};

handle_info({msg, {ch, Name, Ch, Message}}, S) ->
    io:format("#~p[~p]: ~p~n", [Ch, Name, Message]),
    {noreply, S};

handle_info({'DOWN', _, process, {Server, _}, _}, S=#state{server=Server}) ->
    io:format("The server ~p has gone offline.~n", [Server]),
    io:format("Please connect to a server to continue chatting."),
    {noreply, S#state{server=null, name=null}};

handle_info(_Info, S) ->
    {noreply, S}.

terminate(_Reason, _S) ->
    ok.

code_change(_OldVsn, S, _Extra) ->
    {ok, S}.

%% ===================================================================== 
%% Internal functions
%% ===================================================================== 

set_pid(RefName, Pid) ->
    gen_server:cast(RefName, {set_pid, Pid}).
