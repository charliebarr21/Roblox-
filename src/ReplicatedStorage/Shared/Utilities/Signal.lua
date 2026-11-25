-- Signal (ModuleScript). Tiny event class so services don't need BindableEvents.

local Signal = {}
Signal.__index = Signal

function Signal.new()
	return setmetatable({ _handlers = {} }, Signal)
end

function Signal:Connect(fn)
	local handler = { fn = fn }
	table.insert(self._handlers, handler)
	local handlers = self._handlers
	local connection = {}
	function connection.Disconnect()
		local index = table.find(handlers, handler)
		if index then
			table.remove(handlers, index)
		end
	end
	return connection
end

function Signal:Fire(...)
	for _, handler in table.clone(self._handlers) do
		task.spawn(handler.fn, ...)
	end
end

return Signal
