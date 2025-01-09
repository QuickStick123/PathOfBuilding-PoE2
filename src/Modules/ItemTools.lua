-- Path of Building
--
-- Module: Item Tools
-- Various functions for dealing with items.
--
local t_insert = table.insert
local t_remove = table.remove
local m_min = math.min
local m_max = math.max
local m_floor = math.floor

itemLib = { }
-- Apply a value scalar to the first n of any numbers present
function itemLib.applyValueScalar(line, valueScalar, baseValueScalar)
	if not (valueScalar and type(valueScalar) == "number") then
		valueScalar = 1
	end
	if valueScalar ~= 1 or (baseValueScalar and baseValueScalar ~= 1) then
		if precision then
			return line:gsub("(%d+%.?%d*)", function(num)
				local power = 10 ^ precision
				local numVal = tonumber(num)
				if baseValueScalar then
					numVal = round(numVal * baseValueScalar * power) / power
				end
				numVal = m_floor(numVal * valueScalar * power) / power
				return tostring(numVal)
			end, numbers)
		else
			return line:gsub("(%d+)([^%.])", function(num, suffix)
				local numVal = tonumber(num)
				if baseValueScalar then
					numVal = round(num * baseValueScalar)
				end
				numVal = m_floor(numVal * valueScalar + 0.001)
				return tostring(numVal)..suffix
			end, numbers)
		end
	end
	return line
end

local antonyms = {
	["increased"] = "reduced",
	["reduced"] = "increased",
	["more"] = "less",
	["less"] = "more",
}

local function antonymFunc(num, word)
	local antonym = antonyms[word]
	return antonym and (num.." "..antonym) or ("-"..num.." "..word)
end

-- Apply range value (0 to 1) to a modifier that has a range: "(x-x)" or "(x-x) to (x-x)"
function itemLib.applyRange(line, range, valueScalar, baseValueScalar)
	-- local precisionSame = true
	
	-- stripLines down to # inplace of any number and store numbers inside values also remove all + signs are kept if value is positive
	local values = { }
	local strippedLine = line:gsub("([%+-]?)%((%-?%d+%.?%d*)%-(%-?%d+%.?%d*)%)", function(sign, min, max)
		local value = min + range * (tonumber(max) - min)
		if sign == "-" then value = value * -1 end
		return (sign == "+" and value > 0 ) and sign..tostring(value) or tostring(value)
	end)
	:gsub("%-(%d+%%) (%a+)", antonymFunc)
	:gsub("(%-?%d+%.?%d*)", function(value)
		t_insert(values, value)
		return "#"
	end)

	local function findScalableLine(line, values)
		for numSubs = 0, #values do -- Iterate over substitution counts
			-- Function to replace a specific occurrence of a pattern
			local function replaceNthInstance(input, pattern, replacement, n)
				local count = 0
				return input:gsub(pattern, function(match)
					count = count + 1
					if count == n then
						return replacement
					else
						return match
					end
				end)
			end
	
			local indices = {} -- Indices of the placeholders to replace
			local function permute(start, replacements)
				replacements = replacements or { }
				if #replacements == numSubs then
					-- Replace placeholders
					local modifiedLine = line
					local subsituted = 0
					for i, replacement in ipairs(replacements) do
						modifiedLine = replaceNthInstance(modifiedLine, "#", replacement, indices[i] - subsituted)
						subsituted = subsituted + 1
					end
	
					-- Check if the modified line matches any scalability data
					local key = modifiedLine:gsub("+#", "#")
					if data.modScalability[key] then
						-- Return modified line and remaining values (those not substituted)
						local remainingValues = {}
						local substitutedSet = {}
						for _, replacement in ipairs(replacements) do
							substitutedSet[replacement] = true
						end
						for _, value in ipairs(values) do
							if not substitutedSet[value] then
								table.insert(remainingValues, value)
							end
						end
						return modifiedLine, remainingValues
					end
					return
				end
	
				-- Continue permuting for all combinations of replacements
				for i = start, #values do
					table.insert(indices, i)
					local newReplacements = { }
					for _, v in ipairs(replacements) do
						table.insert(newReplacements, v)
					end
					table.insert(newReplacements, values[i])
					local modifiedLine, remainingValues = permute(i + 1, newReplacements)
					if modifiedLine then
						return modifiedLine, remainingValues -- Return the first found modified line and the remaining values
					end
					table.remove(indices)
				end
			end
	
			-- Start permutation from index 1
			local modifiedLine, remainingValues = permute(1, {})
			if modifiedLine then
				return modifiedLine, remainingValues -- Return the first found modified line and the remaining values
			end
		end
	end

	local scalableLine, scalableValues = findScalableLine(strippedLine, values)

	for _, scalability in ipairs(data.modScalability[scalableLine:gsub("+#", "#")]) do
		if scalability.isScalable then
			for _, format in ipairs(scalability.formats) do
				if format == ""
					-- if spec.k == "negate" then
					-- 	val[spec.v].max, val[spec.v].min = -val[spec.v].min, -val[spec.v].max
					-- elseif spec.k == "invert_chance" then
					-- 	val[spec.v].max, val[spec.v].min = 100 - val[spec.v].min, 100 - val[spec.v].max
					-- elseif spec.k == "negate_and_double" then
					-- 	val[spec.v].max, val[spec.v].min = -2 * val[spec.v].min, -2 * val[spec.v].max
					-- elseif spec.k == "divide_by_two_0dp" then
					-- 	val[spec.v].min = round(val[spec.v].min / 2)
					-- 	val[spec.v].max = round(val[spec.v].max / 2)
					-- elseif spec.k == "divide_by_three" then
					-- 	val[spec.v].min = val[spec.v].min / 3
					-- 	val[spec.v].max = val[spec.v].max / 3
					-- 	val[spec.v].fmt = "g"
					-- elseif spec.k == "divide_by_four" then
					-- 	val[spec.v].min = val[spec.v].min / 4
					-- 	val[spec.v].max = val[spec.v].max / 4
					-- 	val[spec.v].fmt = "g"
					-- elseif spec.k == "divide_by_five" then
					-- 	val[spec.v].min = val[spec.v].min / 5
					-- 	val[spec.v].max = val[spec.v].max / 5
					-- 	val[spec.v].fmt = "g"
					-- elseif spec.k == "divide_by_six" then
					-- 	val[spec.v].min = val[spec.v].min / 6
					-- 	val[spec.v].max = val[spec.v].max / 6
					-- 	val[spec.v].fmt = "g"
					-- elseif spec.k == "divide_by_ten_0dp" then
					-- 	val[spec.v].min = round(val[spec.v].min / 10)
					-- 	val[spec.v].max = round(val[spec.v].max / 10)
					-- elseif spec.k == "divide_by_ten_1dp" or spec.k == "divide_by_ten_1dp_if_required" then
					-- 	val[spec.v].min = round(val[spec.v].min / 10, 1)
					-- 	val[spec.v].max = round(val[spec.v].max / 10, 1)
					-- 	val[spec.v].fmt = "g"
					-- elseif spec.k == "divide_by_twelve" then
					-- 	val[spec.v].min = val[spec.v].min / 12
					-- 	val[spec.v].max = val[spec.v].max / 12
					-- 	val[spec.v].fmt = "g"
					-- elseif spec.k == "divide_by_fifteen_0dp" then
					-- 	val[spec.v].min = round(val[spec.v].min / 15)
					-- 	val[spec.v].max = round(val[spec.v].max / 15)
					-- elseif spec.k == "divide_by_twenty" then
					-- 	val[spec.v].min = val[spec.v].min / 20
					-- 	val[spec.v].max = val[spec.v].max / 20
					-- 	val[spec.v].fmt = "g"
					-- elseif spec.k == "divide_by_twenty_then_double_0dp" then
					-- 	val[spec.v].min = round(val[spec.v].min / 20) * 2
					-- 	val[spec.v].max = round(val[spec.v].max / 20) * 2
					-- elseif spec.k == "divide_by_fifty" then
					-- 	val[spec.v].min = val[spec.v].min / 50
					-- 	val[spec.v].max = val[spec.v].max / 50
					-- 	val[spec.v].fmt = "g"
					-- elseif spec.k == "divide_by_one_hundred" then
					-- 	val[spec.v].min = val[spec.v].min / 100
					-- 	val[spec.v].max = val[spec.v].max / 100
					-- 	val[spec.v].fmt = "g"
					-- elseif spec.k == "divide_by_one_hundred_0dp" then
					-- 	val[spec.v].min = round(val[spec.v].min / 100)
					-- 	val[spec.v].max = round(val[spec.v].max / 100)
					-- 	val[spec.v].fmt = "g"
					-- elseif spec.k == "divide_by_one_hundred_1dp" then
					-- 	val[spec.v].min = round(val[spec.v].min / 100, 1)
					-- 	val[spec.v].max = round(val[spec.v].max / 100, 1)
					-- 	val[spec.v].fmt = "g"
					-- elseif spec.k == "divide_by_one_hundred_2dp_if_required" or spec.k == "divide_by_one_hundred_2dp" then
					-- 	val[spec.v].min = round(val[spec.v].min / 100, 2)
					-- 	val[spec.v].max = round(val[spec.v].max / 100, 2)
					-- 	val[spec.v].fmt = "g"
					-- elseif spec.k == "divide_by_one_hundred_and_negate" then
					-- 	val[spec.v].min = -val[spec.v].min / 100
					-- 	val[spec.v].max = -val[spec.v].max / 100
					-- 	val[spec.v].fmt = "g"
					-- elseif spec.k == "divide_by_one_thousand" then
					-- 	val[spec.v].min = val[spec.v].min / 1000
					-- 	val[spec.v].max = val[spec.v].max / 1000
					-- 	val[spec.v].fmt = "g"
					-- elseif spec.k == "per_minute_to_per_second" then
					-- 	val[spec.v].min = val[spec.v].min / 60
					-- 	val[spec.v].max = val[spec.v].max / 60
					-- 	val[spec.v].fmt = "g"
					-- elseif spec.k == "per_minute_to_per_second_0dp" then
					-- 	val[spec.v].min = round(val[spec.v].min / 60)
					-- 	val[spec.v].max = round(val[spec.v].max / 60)
					-- elseif spec.k == "per_minute_to_per_second_1dp" then
					-- 	val[spec.v].min = round(val[spec.v].min / 60, 1)
					-- 	val[spec.v].max = round(val[spec.v].max / 60, 1)
					-- 	val[spec.v].fmt = "g"
					-- elseif spec.k == "per_minute_to_per_second_2dp_if_required" or spec.k == "per_minute_to_per_second_2dp" then
					-- 	val[spec.v].min = round(val[spec.v].min / 60, 2)
					-- 	val[spec.v].max = round(val[spec.v].max / 60, 2)
					-- 	val[spec.v].fmt = "g"
					-- elseif spec.k == "milliseconds_to_seconds" then
					-- 	val[spec.v].min = val[spec.v].min / 1000
					-- 	val[spec.v].max = val[spec.v].max / 1000
					-- 	val[spec.v].fmt = "g"
					-- elseif spec.k == "milliseconds_to_seconds_halved" then
					-- 	val[spec.v].min = val[spec.v].min / 1000 / 2
					-- 	val[spec.v].max = val[spec.v].max / 1000 / 2
					-- 	val[spec.v].fmt = "g"
					-- elseif spec.k == "milliseconds_to_seconds_0dp" then
					-- 	val[spec.v].min = round(val[spec.v].min / 1000)
					-- 	val[spec.v].max = round(val[spec.v].max / 1000)
					-- elseif spec.k == "milliseconds_to_seconds_1dp" then
					-- 	val[spec.v].min = round(val[spec.v].min / 1000, 1)
					-- 	val[spec.v].max = round(val[spec.v].max / 1000, 1)
					-- 	val[spec.v].fmt = "g"
					-- elseif spec.k == "milliseconds_to_seconds_2dp" or spec.k == "milliseconds_to_seconds_2dp_if_required" then
					-- 	val[spec.v].min = round(val[spec.v].min / 1000, 2)
					-- 	val[spec.v].max = round(val[spec.v].max / 1000, 2)
					-- 	val[spec.v].fmt = "g"									
					-- elseif spec.k == "deciseconds_to_seconds" then
					-- 	val[spec.v].min = val[spec.v].min / 10
					-- 	val[spec.v].max = val[spec.v].max / 10
					-- 	val[spec.v].fmt = ".2f"
					-- elseif spec.k == "30%_of_value" then
					-- 	val[spec.v].min = val[spec.v].min * 0.3
					-- 	val[spec.v].max = val[spec.v].max * 0.3
					-- elseif spec.k == "60%_of_value" then
					-- 	val[spec.v].min = val[spec.v].min * 0.6
					-- 	val[spec.v].max = val[spec.v].max * 0.6
					-- elseif spec.k == "mod_value_to_item_class" then
					-- 	val[spec.v].min = ItemClasses[val[spec.v].min].Name
					-- 	val[spec.v].max = ItemClasses[val[spec.v].max].Name
					-- 	val[spec.v].fmt = "s"
					-- elseif spec.k == "multiplicative_damage_modifier" then
					-- 	val[spec.v].min = 100 + val[spec.v].min
					-- 	val[spec.v].max = 100 + val[spec.v].max
					-- elseif spec.k == "multiplicative_permyriad_damage_modifier" then
					-- 	val[spec.v].min = 100 + (val[spec.v].min / 100)
					-- 	val[spec.v].max = 100 + (val[spec.v].max / 100)
					-- 	val[spec.v].fmt = "g"
					-- elseif spec.k == "times_one_point_five" then
					-- 	val[spec.v].min = val[spec.v].min * 1.5
					-- 	val[spec.v].max = val[spec.v].max * 1.5
					-- elseif spec.k == "double" then
					-- 	val[spec.v].min = val[spec.v].min * 2
					-- 	val[spec.v].max = val[spec.v].max * 2
					-- elseif spec.k == "multiply_by_four" then
					-- 	val[spec.v].min = val[spec.v].min * 4
					-- 	val[spec.v].max = val[spec.v].max * 4
					-- elseif spec.k == "multiply_by_four_and_negate" then
					-- 	val[spec.v].min = -val[spec.v].min * 4
					-- 	val[spec.v].max = -val[spec.v].max * 4
					-- elseif spec.k == "multiply_by_ten" then
					-- 	val[spec.v].min = val[spec.v].min * 10
					-- 	val[spec.v].max = val[spec.v].max * 10
					-- elseif spec.k == "times_twenty" then
					-- 	val[spec.v].min = val[spec.v].min * 20
					-- 	val[spec.v].max = val[spec.v].max * 20
					-- elseif spec.k == "multiply_by_one_hundred" then
					-- 	val[spec.v].min = val[spec.v].min * 100
					-- 	val[spec.v].max = val[spec.v].max * 100
					-- elseif spec.k == "plus_two_hundred" then
					-- 	val[spec.v].min = val[spec.v].min + 200
					-- 	val[spec.v].max = val[spec.v].max + 200
					-- elseif spec.k == "reminderstring" or spec.k == "canonical_line" or spec.k == "canonical_stat" then
					-- elseif spec.k then
					-- 	ConPrintf("Unknown description function: %s", spec.k)
					-- end
			end
		end
	end

	-- Create a line with ranges removed to check if the mod is a high precision mod.
	-- local testLine = not line:find("-", 1, true) and line or
	-- 	line:gsub("(%+?)%((%-?%d+%.?%d*)%-(%-?%d+%.?%d*)%)",
	-- 	function(plus, min, max)
	-- 		min = tonumber(min)
	-- 		local maxPrecision = min + range * (tonumber(max) - min)
	-- 		local minPrecision = m_floor(maxPrecision + 0.5) -- round towards 0
	-- 		if minPrecision ~= maxPrecision then
	-- 			precisionSame = false
	-- 		end
	-- 		return (minPrecision < 0 and "" or plus) .. tostring(minPrecision)
	-- 	end)

	-- if precisionSame and (not valueScalar or valueScalar == 1) and (not baseValueScalar or baseValueScalar == 1)then
	-- 	return testLine
	-- end

	-- local precision = nil
	-- local modList, extra = modLib.parseMod(testLine)
	-- if modList and not extra then
	-- 	for _, mod in pairs(modList) do
	-- 		local subMod = mod
	-- 		if type(mod.value) == "table" and mod.value.mod then
	-- 			subMod = mod.value.mod
	-- 		end
	-- 		if type(subMod.value) == "number" and data.highPrecisionMods[subMod.name] and data.highPrecisionMods[subMod.name][subMod.type] then
	-- 			precision = data.highPrecisionMods[subMod.name][subMod.type]
	-- 		end
	-- 	end
	-- end
	-- if not precision and line:match("(%d+%.%d*)") then
	-- 	precision = data.defaultHighPrecision
	-- end

	local numbers = 0
	line = line:gsub("(%+?)%((%-?%d+%.?%d*)%-(%-?%d+%.?%d*)%)",
		function(plus, min, max)
			numbers = numbers + 1
			local power = 10 ^ (precision or 0)
			local numVal = m_floor((tonumber(min) + range * (tonumber(max) - tonumber(min))) * power + 0.5) / power
			return (numVal < 0 and "" or plus) .. tostring(numVal)
		end)
		:gsub("%-(%d+%%) (%a+)", antonymFunc)

	if numbers == 0 and line:match("(%d+%.?%d*)%%? ") then --If a mod contains x or x% and is not already a ranged value, then only the first number will be scalable as any following numbers will always be conditions or unscalable values.
		numbers = 1
	end

	return itemLib.applyValueScalar(line, valueScalar, baseValueScalar, numbers, precision)
end

function itemLib.formatModLine(modLine, dbMode)
	local line = (not dbMode and modLine.range and itemLib.applyRange(modLine.line, modLine.range, modLine.valueScalar, modLine.corruptedRange)) or modLine.line
	if line:match("^%+?0%%? ") or (line:match(" %+?0%%? ") and not line:match("0 to [1-9]")) or line:match(" 0%-0 ") or line:match(" 0 to 0 ") then -- Hack to hide 0-value modifiers
		return
	end
	local colorCode
	if modLine.extra then
		colorCode = colorCodes.UNSUPPORTED
		if launch.devModeAlt then
			line = line .. "   ^1'" .. modLine.extra .. "'"
		end
	else
		colorCode = (modLine.enchant and colorCodes.ENCHANTED) or (modLine.custom and colorCodes.CUSTOM) or colorCodes.MAGIC
	end
	return colorCode..line
end

itemLib.wiki = {
	key = "F1",
	openGem = function(gemData)
		local name
		if gemData.name then -- skill
			name = gemData.name
			if gemData.tags.support then
				name = name .. " Support"
			end
		else -- grantedEffect from item/passive
			name = gemData;
		end

		itemLib.wiki.open(name)
	end,
	openItem = function(item)
		local name = item.rarity == "UNIQUE" and item.title or item.baseName

		itemLib.wiki.open(name)
	end,
	open = function(name)
		local route = string.gsub(name, " ", "_")

		OpenURL("https://www.poe2wiki.net/wiki/" .. route)
		itemLib.wiki.triggered = true
	end,
	matchesKey = function(key)
		return key == itemLib.wiki.key
	end,
	triggered = false
}