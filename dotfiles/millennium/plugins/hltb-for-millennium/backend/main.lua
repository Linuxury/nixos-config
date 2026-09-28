--[[
    HLTB for Millennium - Plugin Entry Point

    Displays How Long To Beat completion times on Steam game pages.
]]

local logger = require("logger")
local millennium = require("millennium")
local json = require("json")
local hltb = require("hltb")
local steam = require("steam")
local steamhunters = require("steamhunters")
local utils = require("hltb_utils")
local game_ids = require("game_ids")
local settings = require("settings")
local cache = require("cache")

-- Get game name with optional fallback sources
local function get_game_name(app_id)
    -- 1. Try first-party Steam API
    local name, err = steam.get_game_name(app_id)
    if name then
        return name
    end

    logger:info("Steam API failed for " .. tostring(app_id) .. ": " .. (err or "unknown") .. ". Trying fallback...")

    -- 2. Fall back to SteamHunters
    local sh_name, sh_err = steamhunters.get_game_name(app_id)
    if sh_name then
        logger:info("Fallback successful: Found via SteamHunters")
        return sh_name
    end

    return nil, "All sources failed. Steam: " .. (err or "nil") .. ", SH: " .. (sh_err or "nil")
end

-- Internal fetch (always hits HLTB API, bypasses cache)
local function fetch_fresh(app_id, fallback_name)
    -- Check ID cache for direct lookup
    local hltb_id = cache.get_hltb_id(app_id)
    if hltb_id then
        logger:info("ID cache hit for app_id " .. tostring(app_id) .. " -> hltb_id " .. tostring(hltb_id))
        local match, err = hltb.fetch_game_by_id(hltb_id)
        if match then
            return {
                searched_name = match.game_name or "",
                game_id = match.game_id,
                game_name = match.game_name,
                comp_main = utils.seconds_to_hours(match.comp_main),
                comp_plus = utils.seconds_to_hours(match.comp_plus),
                comp_100 = utils.seconds_to_hours(match.comp_100),
            }
        end
        logger:info("Fetch by ID failed: " .. (err or "unknown") .. ", falling back to name search")
    end

    -- Game ID override: direct HLTB ID lookup
    local fix = game_ids[app_id]
    if fix then
        logger:info("Game ID override (AppID " .. tostring(app_id) .. "): HLTB ID " .. tostring(fix))
        local match, err = hltb.fetch_game_by_id(fix)
        if match then
            return {
                searched_name = match.game_name or "",
                game_id = match.game_id,
                game_name = match.game_name,
                comp_main = utils.seconds_to_hours(match.comp_main),
                comp_plus = utils.seconds_to_hours(match.comp_plus),
                comp_100 = utils.seconds_to_hours(match.comp_100),
            }
        end
        logger:info("Game ID override fetch failed: " .. (err or "unknown") .. ", falling back to name search")
    end

    -- Name-based search path
    local search_name

    do
        local game_name, name_err = get_game_name(app_id)
        if not game_name then
            if fallback_name and fallback_name ~= "" then
                logger:info("Using fallback name from UI: " .. fallback_name)
                game_name = fallback_name
            else
                return nil, "Could not get game name: " .. (name_err or "unknown")
            end
        end

        logger:info("Raw name: " .. game_name)
        search_name = utils.sanitize_game_name(game_name)
        if search_name ~= game_name then
            logger:info("Sanitized: " .. search_name)
        end
    end

    local match = hltb.search_best_match(search_name, app_id)
    if not match then
        logger:info("No HLTB results for: " .. search_name)
        return { searched_name = search_name }
    end

    local similarity = utils.calculate_similarity(search_name, match.game_name)
    logger:info("Found match: " .. (match.game_name or "unknown") .. " (id: " .. tostring(match.game_id) .. ", similarity: " .. tostring(similarity) .. ")")

    return {
        searched_name = search_name,
        game_id = match.game_id,
        game_name = match.game_name,
        comp_main = utils.seconds_to_hours(match.comp_main),
        comp_plus = utils.seconds_to_hours(match.comp_plus),
        comp_100 = utils.seconds_to_hours(match.comp_100),
    }
end

-- Main function called by frontend and webkit
function GetHltbData(app_id, fallback_name, force_refresh)
    local success, result = pcall(function()
        local name_hint = (fallback_name and fallback_name ~= "") and fallback_name or nil
        logger:info("GetHltbData called for app_id: " .. tostring(app_id) .. (name_hint and (" (" .. name_hint .. ")") or ""))

        -- Check result cache (skip if force refresh)
        if not force_refresh then
            local entry, is_stale = cache.get(app_id)
            if entry then
                local cache_name = entry.data and entry.data.game_name or entry.data and entry.data.searched_name or "unknown"
                logger:info("Cache " .. (is_stale and "stale" or "fresh") .. " hit for app_id " .. tostring(app_id) .. ": " .. cache_name)
                return json.encode({
                    success = true,
                    data = entry.data,
                    fromCache = true,
                    isStale = is_stale,
                })
            end
        end

        -- Cache miss or force refresh: fetch from HLTB
        local data, err = fetch_fresh(app_id, fallback_name)
        if not data then
            logger:error("Fetch failed: " .. (err or "unknown"))
            return json.encode({ success = false, error = err or "Unknown error" })
        end

        -- Cache the result
        cache.set(app_id, data)

        return json.encode({
            success = true,
            data = data,
            fromCache = false,
            isStale = false,
        })
    end)

    if not success then
        logger:error("GetHltbData error: " .. tostring(result))
        return json.encode({ success = false, error = tostring(result) })
    end

    return result
end

-- Initialize ID cache from Steam import
function InitIdCache(steam_user_id)
    local success, result = pcall(function()
        logger:info("InitIdCache called for user: " .. tostring(steam_user_id))

        -- Skip if already valid for this user
        if cache.is_id_cache_valid(steam_user_id) then
            logger:info("ID cache already valid for user " .. tostring(steam_user_id))
            return json.encode({ success = true, alreadyValid = true })
        end

        local games, err = hltb.fetch_steam_import(steam_user_id)
        if not games then
            logger:info("Steam import failed: " .. (err or "unknown"))
            return json.encode({ success = false, error = err or "Unknown error" })
        end

        cache.set_id_mappings(games, steam_user_id)
        return json.encode({ success = true })
    end)

    if not success then
        logger:error("InitIdCache error: " .. tostring(result))
        return json.encode({ success = false, error = tostring(result) })
    end

    return result
end

-- Get cache statistics for both caches
function GetCacheStats()
    local success, result = pcall(function()
        local result_stats = cache.stats()
        local id_stats = cache.id_cache_stats()

        return json.encode({
            success = true,
            data = {
                resultCache = result_stats,
                idCache = id_stats,
            },
        })
    end)

    if not success then
        logger:error("GetCacheStats error: " .. tostring(result))
        return json.encode({ success = false, error = tostring(result) })
    end

    return result
end

-- Clear both caches
function ClearCache()
    local success, result = pcall(function()
        cache.clear()
        cache.clear_id_cache()
        return json.encode({ success = true })
    end)

    if not success then
        logger:error("ClearCache error: " .. tostring(result))
        return json.encode({ success = false, error = tostring(result) })
    end

    return result
end

-- Settings management (shared between frontend and webkit)
function GetSettings()
    local success, result = pcall(function()
        local current = settings.load()
        return json.encode({ success = true, data = current })
    end)

    if not success then
        logger:error("GetSettings error: " .. tostring(result))
        return json.encode({ success = false, error = tostring(result) })
    end

    return result
end

function SaveSettings(settings_json)
    local success, result = pcall(function()
        local parsed = json.decode(settings_json)
        if type(parsed) ~= "table" then
            return json.encode({ success = false, error = "Invalid settings" })
        end

        local merged = settings.merge_defaults(parsed)
        local ok = settings.save(merged)
        if not ok then
            return json.encode({ success = false, error = "Failed to write settings file" })
        end

        return json.encode({ success = true })
    end)

    if not success then
        logger:error("SaveSettings error: " .. tostring(result))
        return json.encode({ success = false, error = tostring(result) })
    end

    return result
end

-- Plugin lifecycle
local function on_load()
    logger:info("HLTB plugin loaded, Millennium " .. millennium.version())
    cache.load()
    millennium.ready()
end

local function on_frontend_loaded()
    logger:info("HLTB: Frontend loaded")
end

local function on_unload()
    logger:info("HLTB plugin unloaded")
end

return {
    on_load = on_load,
    on_frontend_loaded = on_frontend_loaded,
    on_unload = on_unload,
    GetHltbData = GetHltbData,
    InitIdCache = InitIdCache,
    GetCacheStats = GetCacheStats,
    ClearCache = ClearCache,
    GetSettings = GetSettings,
    SaveSettings = SaveSettings,
}
