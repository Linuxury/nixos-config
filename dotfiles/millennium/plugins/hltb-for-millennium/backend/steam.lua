--[[
    Steam API Helpers for Lua

    Standalone module for Steam store API queries.
    Requires: http, json modules

    Usage:
        local steam = require("steam")
        local name, err = steam.get_game_name(1234)

    Testing:
        Functions are separated for testability:
        - build_url(app_id) - constructs API URL
        - parse_response(data, app_id) - parses JSON response
        - get_game_name(app_id) - full flow with HTTP

        For mocking HTTP in tests:
        steam._http = mock_http_module
]]

local http = require("http")
local json = require("json")

local M = {}

M.STORE_API_URL = "https://store.steampowered.com/api/appdetails"
M.TIMEOUT = 10

-- Exposed for testing; defaults to real http module
M._http = http

-- Build Steam Store API URL
-- Exported for testing and potential fallback implementations
function M.build_url(app_id)
    return M.STORE_API_URL .. "?appids=" .. app_id .. "&l=english"
end

-- Parse Steam Store API response
-- Returns app data table or nil, error
function M.parse_response(data, app_id)
    if not data then
        return nil, "No data"
    end

    local app_data = data[tostring(app_id)]
    if not app_data then
        return nil, "App not found in response"
    end

    if not app_data.success then
        return nil, "App not found"
    end

    if not app_data.data then
        return nil, "No app data"
    end

    return app_data.data, nil
end

-- Get game details from Steam API
-- Always request English to ensure consistent names for HLTB matching
function M.get_app_details(app_id)
    if not app_id then
        return nil, "app_id is nil"
    end

    local url = M.build_url(app_id)
    local response, err = M._http.get(url, { timeout = M.TIMEOUT })

    if not response then
        return nil, "Request failed: " .. (err or "unknown")
    end

    if response.status ~= 200 then
        return nil, "HTTP " .. response.status
    end

    local success, data = pcall(json.decode, response.body)
    if not success or not data then
        return nil, "Invalid JSON response"
    end

    return M.parse_response(data, app_id)
end

-- Get just the game name
function M.get_game_name(app_id)
    local details, err = M.get_app_details(app_id)
    if not details then
        return nil, err
    end
    return details.name, nil
end

return M
