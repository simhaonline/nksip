%% -------------------------------------------------------------------
%%
%% Copyright (c) 2013 Carlos Gonzalez Florido.  All Rights Reserved.
%%
%% This file is provided to you under the Apache License,
%% Version 2.0 (the "License"); you may not use this file
%% except in compliance with the License.  You may obtain
%% a copy of the License at
%%
%%   http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing,
%% software distributed under the License is distributed on an
%% "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
%% KIND, either express or implied.  See the License for the
%% specific language governing permissions and limitations
%% under the License.
%%
%% -------------------------------------------------------------------

%% @doc SipApp plugin callbacks default implementation

-module(nksip_callbacks).
-author('Carlos Gonzalez <carlosj.gf@gmail.com>').

-include("nksip.hrl").
-include("nksip_call.hrl").
-export([app_call/3, app_method/2]).
-export([sipapp_init/2, sipapp_handle_call/4, sipapp_handle_cast/3, 
	     sipapp_handle_info/3, sipapp_terminate/3]).

-type plugins_state() :: [{Plugin::atom(), Value::term()}].



%% @doc This plugin callback function is used to call application-level 
%% SipApp callbacks.
-spec app_call(atom(), list(), nksip:app_id()) ->
	{ok, term()} | error.

app_call(Fun, Args, AppId) ->
	case catch apply(AppId, Fun, Args) of
	    {'EXIT', Error} -> 
	        ?call_error("Error calling callback ~p/~p: ~p", [Fun, length(Args), Error]),
	        error;
	    Reply ->
	    	% ?call_warning("Called ~p/~p (~p): ~p", [Fun, length(Args), Args, Reply]),
	    	% ?call_debug("Called ~p/~p: ~p", [Fun, length(Args), Reply]),
	        {ok, Reply}
	end.


%% @doc This plugin callback is called when a call to one of the method specific
%% application-level SipApp callbacks is needed.
-spec app_method(nksip_call:trans(), nksip_call:call()) ->
	{reply, nksip:sip_reply()} | noreply.


app_method(#trans{method='ACK', request=Req}, #call{app_id=AppId}=Call) ->
	case catch AppId:sip_ack(Req, Call) of
		ok -> ok;
		Error -> ?call_error("Error calling callback ack/1: ~p", [Error])
	end,
	noreply;

app_method(#trans{method=Method, request=Req}, #call{app_id=AppId}=Call) ->
	#sipmsg{to={_, ToTag}} = Req,
	Fun = case Method of
		'INVITE' when ToTag == <<>> -> sip_invite;
		'INVITE' -> sip_reinvite;
		'UPDATE' -> sip_update;
		'BYE' -> sip_bye;
		'OPTIONS' -> sip_options;
		'REGISTER' -> sip_register;
		'PRACK' -> sip_prack;
		'INFO' -> sip_info;
		'MESSAGE' -> sip_message;
		'SUBSCRIBE' when ToTag == <<>> -> sip_subscribe;
		'SUBSCRIBE' -> sip_resubscribe;
		'NOTIFY' -> sip_notify;
		'REFER' -> sip_refer;
		'PUBLISH' -> sip_publish
	end,
	case catch AppId:Fun(Req, Call) of
		{reply, Reply} -> 
			{reply, Reply};
		noreply -> 
			noreply;
		Error -> 
			?call_error("Error calling callback ~p/2: ~p", [Fun, Error]),
			{reply, {internal_error, "SipApp Error"}}
	end.


%% @doc Called after starting the SipApp process and before calling application-level
%% init/1 callback. Can be used to store metadata.
-spec sipapp_init(nksip:app_id(), plugins_state()) ->
	{ok, plugins_state()}.

sipapp_init(_AppId, Proplist) ->
	{ok, Proplist}.


%% @doc Called when the SipApp process receives a handle_call/3.
%% Return {ok, NewPluginState} (should call gen_server:reply/2) or continue.
-spec sipapp_handle_call(nksip:app_id(), term(), from(), plugins_state()) ->
	{ok, plugins_state()} | continue.

sipapp_handle_call(_AppId, _Msg, _From, _PluginState) ->
	continue.


%% @doc Called when the SipApp process receives a handle_cast/3.
%% Return {ok, NewPluginState} or continue.
-spec sipapp_handle_cast(nksip:app_id(), term(), plugins_state()) ->
	{ok, plugins_state()} | continue.

sipapp_handle_cast(_AppId, _Msg, _PluginState) ->
	continue.


%% @doc Called when the SipApp process receives a handle_info/3.
%% Return {ok, NewPluginState} or continue.
-spec sipapp_handle_info(nksip:app_id(), term(), plugins_state()) ->
	{ok, plugins_state()} | continue.

sipapp_handle_info(_AppId, _Msg, _PluginState) ->
	continue.


%% @doc Called when the SipApp process receives a terminate/2.
-spec sipapp_terminate(nksip:app_id(), term(), plugins_state()) ->
	continue.

sipapp_terminate(_AppId, _Reason, _PluginState) ->
	continue.
