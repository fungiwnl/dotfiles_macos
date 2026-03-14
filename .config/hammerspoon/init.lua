local log = hs.logger.new("display-arranger", "info")

DisplayArranger = DisplayArranger or {}

local APPLY_DELAY_SECONDS = 1.5
local MAX_ATTEMPTS = 5

local function stopTimer(timer)
	if timer then
		timer:stop()
	end
end

local function stopWatcher(watcher)
	if watcher then
		watcher:stop()
	end
end

stopTimer(DisplayArranger.debounceTimer)
stopWatcher(DisplayArranger.screenWatcher)
stopWatcher(DisplayArranger.wakeWatcher)

local function round(number)
	if number >= 0 then
		return math.floor(number + 0.5)
	end

	return math.ceil(number - 0.5)
end

local function isBuiltinScreen(screen)
	local name = (screen:name() or ""):lower()
	return name:match("built%-in") ~= nil or name:match("color lcd") ~= nil
end

local function getManagedScreens()
	local builtin
	local externals = {}

	for _, screen in ipairs(hs.screen.allScreens()) do
		if isBuiltinScreen(screen) then
			builtin = screen
		else
			table.insert(externals, screen)
		end
	end

	return builtin, externals
end

local function scheduleApplyLayout(reason, attempt)
	local nextAttempt = attempt or 1

	stopTimer(DisplayArranger.debounceTimer)

	DisplayArranger.debounceTimer = hs.timer.doAfter(APPLY_DELAY_SECONDS, function()
		DisplayArranger.debounceTimer = nil

		local builtin, externals = getManagedScreens()

		if not builtin then
			log.w("Skipping layout: built-in display not found")
			return
		end

		if #externals == 0 then
			log.i("Skipping layout: no external display connected")
			return
		end

		if #externals > 1 then
			log.w("Skipping layout: multiple external displays connected")
			return
		end

		local primary = hs.screen.primaryScreen()
		if not primary or primary:id() ~= builtin:id() then
			log.i("Setting built-in display as primary (" .. reason .. ")")
			builtin:setPrimary()

			if nextAttempt < MAX_ATTEMPTS then
				scheduleApplyLayout("primary-display-retry", nextAttempt + 1)
			end

			return
		end

		builtin = hs.screen.find(builtin:id()) or builtin

		local external = externals[1]
		external = hs.screen.find(external:id()) or external

		local builtinFrame = builtin:fullFrame()
		local externalFrame = external:fullFrame()

		local targetX = round(builtinFrame.x + ((builtinFrame.w - externalFrame.w) / 2))
		local targetY = round(builtinFrame.y - externalFrame.h)

		if round(externalFrame.x) == targetX and round(externalFrame.y) == targetY then
			log.i("Display layout already correct (" .. reason .. ")")
			return
		end

		log.i(string.format("Moving external display to (%d, %d) (%s)", targetX, targetY, reason))
		local moved = external:setOrigin(targetX, targetY)

		if moved then
			return
		end

		log.w("Failed to move external display")

		if nextAttempt < MAX_ATTEMPTS then
			scheduleApplyLayout("move-retry", nextAttempt + 1)
		end
	end)
end

DisplayArranger.screenWatcher = hs.screen.watcher.new(function()
	scheduleApplyLayout("screen-change")
end)

DisplayArranger.screenWatcher:start()

DisplayArranger.wakeWatcher = hs.caffeinate.watcher.new(function(event)
	if event == hs.caffeinate.watcher.screensDidWake or event == hs.caffeinate.watcher.systemDidWake then
		scheduleApplyLayout("wake")
	end
end)

DisplayArranger.wakeWatcher:start()

scheduleApplyLayout("startup")
