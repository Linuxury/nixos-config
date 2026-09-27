--!nonstrict
-- nix-updates service: the only entry that runs checks. Publishes
-- { phase, rows, checkedAt, error } as "nix_updates" for the widget and panel,
-- and listens for "nix_updates_request" (a nonce) to check on demand.
--
-- check.sh runs detached because runAsync with a callback is capped at 60s and
-- a cold `nix flake update` can take longer. It writes its result file
-- atomically; this service polls the file's mtime and reloads when it changes,
-- so the last result (and its timestamp) survives a shell restart for free.

local STATE_KEY = "nix_updates"
local REQUEST_KEY = "nix_updates_request"
local POLL_MS = 15000
local STALE_S = 15 * 60 -- give up on a check that never wrote a result

local dataDir = noctalia.pluginDataDir()
local resultPath = dataDir .. "/result"
local script = noctalia.pluginDir() .. "/check.sh"

local lastMtime = nil
local startedAt = nil -- os.time() of a check we launched, until its result lands
local state = { phase = "idle", rows = {}, checkedAt = nil, error = nil }

local function publish()
  noctalia.state.set(STATE_KEY, {
    phase = startedAt and "checking" or state.phase,
    rows = state.rows,
    checkedAt = state.checkedAt,
    error = state.error,
  })
end

local function launch()
  if startedAt then return end
  local dir = noctalia.expandPath(noctalia.getConfig("flake_dir"))
  if noctalia.runAsync({ "sh", script, dir, noctalia.getConfig("host"), resultPath }) then
    startedAt = os.time()
    publish()
  end
end

-- Parse "ok|error <epoch>" + body lines. Returns false if the file is unreadable.
local function load(notify)
  local raw = noctalia.readFile(resultPath)
  if not raw then return false end
  local lines = string.split(raw, "\n")
  local status, epoch = string.match(lines[1] or "", "^(%a+) (%d+)$")
  if not status then return false end

  local prevCount = #state.rows
  state.checkedAt = tonumber(epoch)
  if status == "ok" then
    local rows = {}
    for i = 2, #lines do
      local name, old, new = string.match(lines[i], "^(%S+) (%S+) (%S+)$")
      if name then table.insert(rows, { name = name, old = old, new = new }) end
    end
    state.phase, state.rows, state.error = "idle", rows, nil
    if notify and #rows > 0 and #rows > prevCount then
      local body = {}
      for i = 1, math.min(#rows, 8) do
        table.insert(body, `{rows[i].name}  {rows[i].old} → {rows[i].new}`)
      end
      if #rows > 8 then table.insert(body, noctalia.tr("more", { count = #rows - 8 })) end
      noctalia.notify(noctalia.tr("count", { count = #rows }), table.concat(body, "\n"))
    end
  else
    -- Keep the previous rows so a network blip doesn't hide known updates.
    state.phase = "error"
    state.error = table.concat(lines, "\n", 2)
  end
  return true
end

local function intervalS()
  return (tonumber(noctalia.getConfig("check_interval")) or 0) * 3600
end

noctalia.setUpdateInterval(POLL_MS)

function update()
  local info = noctalia.fileInfo(resultPath)
  if info and info.mtime ~= lastMtime then
    -- A result already on disk at startup is old news: load it silently.
    local notify = lastMtime ~= nil or startedAt ~= nil
    lastMtime = info.mtime
    load(notify)
    startedAt = nil
  elseif startedAt and os.time() - startedAt > STALE_S then
    startedAt = nil
  end

  local interval = intervalS()
  if interval > 0 and (state.checkedAt == nil or os.time() - state.checkedAt >= interval) then
    launch()
  end
  publish()
end

function onConfigChanged()
  -- A different flake or host makes the cached result meaningless.
  state.checkedAt = nil
  launch()
end

noctalia.state.watch(REQUEST_KEY, function()
  launch()
end)
