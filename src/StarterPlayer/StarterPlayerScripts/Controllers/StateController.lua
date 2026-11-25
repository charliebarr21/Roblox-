-- StateController (ModuleScript, client). Read-only mirror of the server's player state.
-- The server is authoritative: this module never sends values to the server.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Signal = require(Shared.Utilities.Signal)
local RemoteRegistry = require(Shared.Utilities.RemoteRegistry)

local StateController = {}
StateController.State = {} :: { [string]: any }
StateController.Loaded = false
StateController.Changed = Signal.new() -- (key, value)
StateController.LoadedSignal = Signal.new() -- fires once, after the first snapshot

local function apply(changes: { [string]: any })
	for key, value in changes do
		StateController.State[key] = value
		StateController.Changed:Fire(key, value)
	end
end

function StateController.Init()
	local stateChanged = RemoteRegistry.Event("StateChanged")
	local getState = RemoteRegistry.Function("GetState")

	stateChanged.OnClientEvent:Connect(function(changes)
		if type(changes) == "table" then
			apply(changes)
		end
	end)

	task.spawn(function()
		for _ = 1, 6 do
			local ok, snapshot = pcall(function()
				return getState:InvokeServer()
			end)
			if ok and type(snapshot) == "table" then
				apply(snapshot)
				StateController.Loaded = true
				StateController.LoadedSignal:Fire()
				return
			end
			task.wait(2)
		end
		warn("[StateController] Could not load player state from the server")
	end)
end

return StateController
