--!strict
--[[
	Signal: a small typed event for module-to-module communication.

		local Died: Signal.Signal<Player, string> = Signal.new()
		local connection = Died:Connect(function(player: Player, cause: string) ... end)
		Died:Fire(player, "Fell")
		connection:Disconnect()

	Fire calls every handler that is connected at the moment of the call, each through task.spawn: the handler
	runs right away (nothing is deferred), and a handler that errors or yields does not stop the others.
	Handlers connected during a Fire wait for the next Fire; handlers disconnected during a Fire are skipped.

	Pure: no require, no `game`, so it also runs under Lune (the test runner provides `task`).
]]

export type Connection = {
	Connected: boolean,
	Disconnect: (self: Connection) -> (),
}

export type Signal<T...> = {
	Connect: (self: Signal<T...>, handler: (T...) -> ()) -> Connection,
	Once: (self: Signal<T...>, handler: (T...) -> ()) -> Connection,
	Wait: (self: Signal<T...>) -> T...,
	Fire: (self: Signal<T...>, T...) -> (),
	DisconnectAll: (self: Signal<T...>) -> (),
}

local ConnectionMethods = {}
ConnectionMethods.__index = ConnectionMethods

function ConnectionMethods.Disconnect(self: any): ()
	if not self.Connected then
		return
	end
	self.Connected = false
	local connections = self._signal._connections
	local index = table.find(connections, self)
	if index then
		table.remove(connections, index)
	end
end

local SignalMethods = {}
SignalMethods.__index = SignalMethods

function SignalMethods.Connect(self: any, handler: (...any) -> ()): any
	assert(type(handler) == "function", "Signal:Connect expects a function")
	local connection = setmetatable({ Connected = true, _signal = self, _handler = handler }, ConnectionMethods)
	table.insert(self._connections, connection)
	return connection
end

function SignalMethods.Once(self: any, handler: (...any) -> ()): any
	assert(type(handler) == "function", "Signal:Once expects a function")
	local connection
	connection = self:Connect(function(...: any)
		connection:Disconnect()
		handler(...)
	end)
	return connection
end

function SignalMethods.Wait(self: any): ...any
	local thread = coroutine.running()
	self:Once(function(...: any)
		-- The waiter may have been cancelled (task.cancel) or resumed elsewhere since: never resume a dead thread.
		if coroutine.status(thread) == "suspended" then
			task.spawn(thread, ...)
		end
	end)
	return coroutine.yield()
end

function SignalMethods.Fire(self: any, ...: any): ()
	-- Iterate a snapshot, so connecting or disconnecting inside a handler cannot skip or repeat anyone.
	for _, connection in table.clone(self._connections) do
		if connection.Connected then
			task.spawn(connection._handler, ...)
		end
	end
end

function SignalMethods.DisconnectAll(self: any): ()
	for _, connection in self._connections do
		connection.Connected = false
	end
	table.clear(self._connections)
end

local Signal = {}

function Signal.new<T...>(): Signal<T...>
	return setmetatable({ _connections = {} }, SignalMethods) :: any
end

return Signal
