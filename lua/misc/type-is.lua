-- https://github.com/jshttp/type-is/blob/7d19b7aab1ad671f59ba157ae0640cd4b1302ca5/index.js#L196
-- Check if `expected` mime type
-- matches `actual` mime type with
-- wildcard and +suffix support.
local mimeMatch = function(expected, actual)
	local actualPre,   actualSuf   =   actual:match("([^/]+)/([^;/]+)")
	local expectedPre, expectedSuf = expected:match("([^/]+)/([^;/]+)")

	-- invalid format
	if not (actualPre and expectedPre) then
		return false
	end

	-- validate type
	if expectedPre ~= "*" and expectedPre ~= actualPre then
		return false
	end

	-- validate suffix wildcard
	if expectedSuf == "*" then -- #note different from type-is
		return true
	end

	-- validate subtype
	if expectedSuf ~= "*" and expectedSuf ~= actualSuf then
		return false
	end

	return true
end

local typeis = function(value, types)
	if not types then return end

	if type(types) == "string" then
		types = {types}
	end

	if type(value) ~= "string" then return end

	for _, typ in pairs(types) do
		if mimeMatch(typ, value) then
			return typ:find("*", nil, true)
				and value or typ
		end
	end

	return false
end

-- https://github.com/jshttp/type-is/blob/7d19b7aab1ad671f59ba157ae0640cd4b1302ca5/index.js#L92
local hasbody = function(req)
	return req:get("transfer-encoding") or req:get("content-length")
end

local function typeofrequest(req, types)
	if not hasbody(req) then return end

	local req_type = req:get("content-type")
	return typeis(req_type, types)
end

return {
	-- typeis = typeis,
	typeofrequest = typeofrequest,
	-- shouldParse = shouldParse,
	hasbody = hasbody,
}
