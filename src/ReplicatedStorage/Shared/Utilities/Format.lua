--!strict
-- Format (ModuleScript). Number/time formatting shared by client and server.

local Format = {}

function Format.Commas(n: number): string
	local sign = if n < 0 then "-" else ""
	local digits = tostring(math.floor(math.abs(n)))
	local out = digits:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	out = out:gsub("^,", "")
	return sign .. out
end

local SUFFIXES = {
	{ 1e15, "Q" },
	{ 1e12, "T" },
	{ 1e9, "B" },
	{ 1e6, "M" },
}

-- "$1,250" below one million, "$1.25M" above.
function Format.Money(n: number): string
	local abs = math.abs(n)
	for _, entry in SUFFIXES do
		if abs >= entry[1] then
			local scaled = string.format("%.2f", n / entry[1])
			scaled = scaled:gsub("%.?0+$", "")
			return "$" .. scaled .. entry[2]
		end
	end
	return (if n < 0 then "-$" else "$") .. Format.Commas(abs)
end

function Format.Clock(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

return Format
