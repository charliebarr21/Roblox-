-- ClientMain (LocalScript). Boots client controllers in order. Each controller is a ModuleScript with Init().

local controllers = script.Parent:WaitForChild("Controllers")

local ORDER = {
	"StateController",
	"UIController",
}

for _, name in ORDER do
	local ok, controller = pcall(require, controllers:WaitForChild(name))
	if not ok then
		warn(("[ClientMain] Failed to load %s: %s"):format(name, tostring(controller)))
	elseif type(controller) == "table" and controller.Init then
		local initOk, err = pcall(controller.Init)
		if not initOk then
			warn(("[ClientMain] %s.Init failed: %s"):format(name, tostring(err)))
		end
	end
end
