-- Security (ModuleScript, server only). Rate limiting + suspicious-activity logging for every remote.
-- Usage in a remote handler:
--   if not Security.RateLimit(player, "BuyItem", 10, 5) then return end

local Players = game:GetService("Players")

local Security = {}

local buckets: { [Player]: { [string]: { count: number, windowStart: number } } } = {}
local flagCounts: { [Player]: number } = {}

-- Allows `maxCalls` calls per `windowSeconds` for the (player, key) pair.
function Security.RateLimit(player: Player, key: string, maxCalls: number, windowSeconds: number): boolean
	local playerBuckets = buckets[player]
	if not playerBuckets then
		playerBuckets = {}
		buckets[player] = playerBuckets
	end
	local now = os.clock()
	local bucket = playerBuckets[key]
	if not bucket or now - bucket.windowStart >= windowSeconds then
		playerBuckets[key] = { count = 1, windowStart = now }
		return true
	end
	bucket.count += 1
	if bucket.count > maxCalls then
		if bucket.count == maxCalls + 1 then
			Security.Flag(player, "RateLimit", key)
		end
		return false
	end
	return true
end

-- Logs suspicious activity. Phase 7 will forward this to analytics/webhooks.
function Security.Flag(player: Player, reason: string, detail: string?)
	flagCounts[player] = (flagCounts[player] or 0) + 1
	warn(("[Security] %s (%d) flagged: %s %s"):format(player.Name, player.UserId, reason, detail or ""))
end

function Security.FlagCount(player: Player): number
	return flagCounts[player] or 0
end

-- Numeric validation helpers for remote arguments.
function Security.IsFiniteNumber(value: any): boolean
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

function Security.IsIntegerInRange(value: any, min: number, max: number): boolean
	return Security.IsFiniteNumber(value) and value == math.floor(value) and value >= min and value <= max
end

Players.PlayerRemoving:Connect(function(player)
	buckets[player] = nil
	flagCounts[player] = nil
end)

return Security
