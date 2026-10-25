--!nonstrict
-- nix-updates service: the only entry that runs checks. Publishes
-- { phase, rows, checkedAt, error } as "nix_updates" for the widget and panel
-- (each row: { kind = "nix" | "input" | "flatpak", name, old, new }),
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
local STARTUP_S = 15 -- first scheduling decision after the shell starts
local STARTUP_FRESH_S = 30 * 60 -- at startup, skip if the last check is this recent
local BACKOFF = { 60, 5 * 60, 15 * 60 } -- retry delays after consecutive failures

local loadedAt = os.time()
local startupChecked = false
local failures = 0

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
  -- Settings added later read nil until the shell reloads plugin.toml.
  local flatpak = noctalia.getConfig("include_flatpak") ~= false and "1" or "0"
  if noctalia.runAsync({ "sh", script, dir, noctalia.getConfig("host"), resultPath,
                         noctalia.getConfig("compare") or "upstream", flatpak }) then
    startedAt = os.time()
    publish()
  end
end

local function countKind(rows, kind)
  local n = 0
  for _, r in rows do if r.kind == kind then n += 1 end end
  return n
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
      local f = string.split(lines[i], "\t")
      if #f == 4 then
        table.insert(rows, { kind = f[1], name = f[2], old = f[3], new = f[4] })
      else -- result written before Flatpak support: "name old new"
        local name, old, new = string.match(lines[i], "^(%S+) (%S+) (%S+)$")
        if name then table.insert(rows, { kind = "nix", name = name, old = old, new = new }) end
      end
    end
    state.phase, state.rows, state.error = "idle", rows, nil
    failures = 0
    if notify and #rows > 0 and #rows > prevCount then
      local body = {}
      for i = 1, math.min(#rows, 8) do
        table.insert(body, `{rows[i].name}  {rows[i].old} → {rows[i].new}`)
      end
      if #rows > 8 then table.insert(body, noctalia.tr("more", { count = #rows - 8 })) end
      noctalia.notify(noctalia.tr("count_split", { nix = countKind(rows, "nix"), inputs = countKind(rows, "input"),
        flatpak = countKind(rows, "flatpak") }),
        table.concat(body, "\n"))
    end
  else
    -- Keep the previous rows so a network blip doesn't hide known updates.
    state.phase = "error"
    state.error = table.concat(lines, "\n", 2)
    failures += 1
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

  -- Schedule (interval 0 = manual only): STARTUP_S after the shell starts,
  -- check unless the last check is under STARTUP_FRESH_S old; then every
  -- interval; after failures, back off 1 → 5 → 15 min.
  local interval = intervalS()
  local now = os.time()
  if interval > 0 and now - loadedAt >= STARTUP_S then
    local age = state.checkedAt and now - state.checkedAt or math.huge
    local due
    if state.phase == "error" then
      due = math.min(BACKOFF[math.clamp(failures, 1, #BACKOFF)], interval)
    elseif not startupChecked then
      due = math.min(STARTUP_FRESH_S, interval)
    else
      due = interval
    end
    startupChecked = true
    if age >= due then launch() end
  end
  publish()
end

-- Only settings that change what gets compared invalidate the result.
local function target()
  return `{noctalia.getConfig("flake_dir")}|{noctalia.getConfig("host")}|`
    .. `{noctalia.getConfig("compare")}|{noctalia.getConfig("include_flatpak")}`
end
local lastTarget = target()

function onConfigChanged()
  if target() ~= lastTarget then
    lastTarget = target()
    state.checkedAt = nil
    launch()
  end
end

noctalia.state.watch(REQUEST_KEY, function()
  launch()
end)
