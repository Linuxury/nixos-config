--[[
    SteamHunters API Helper

    Fallback source for game names when Steam Store API fails (e.g. region locks).
    Requires: http, json modules
]]

local http = require("http")
local json = require("json")

local M = {}

M.API_URL = "https://steamhunters.com/api/apps/"
M.TIMEOUT = 15

-- Headers required to mimic a browser and avoid 403 Forbidden
M.HEADERS = {
    ["Accept"] = "application/json",
    ["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
    ["X-Requested-With"] = "Steam"
}

-- Exposed for testing
M._http = http

-- Build URL for SteamHunters
function M.build_url(app_id)
    return M.API_URL .. app_id
end

-- Parse SteamHunters response
function M.parse_response(data)
    if not data then
        return nil, "No data"
    end

    -- SteamHunters returns a flat JSON object: { "id": 123, "name": "Game" }
    if not data.name then
        return nil, "Name field missing in response"
    end

    return data.name, nil
end

-- Get game name from SteamHunters
function M.get_game_name(app_id)
    if not app_id then
        return nil, "app_id is nil"
    end

    local url = M.build_url(app_id)
    local response, err = M._http.get(url, { 
        timeout = M.TIMEOUT,
        headers = M.HEADERS
    })

    if not response then
        return nil, "Request failed: " .. (err or "unknown")
    end

    if response.status ~= 200 then
        return nil, "HTTP " .. response.status
    end

    local success, data = pcall(json.decode, response.body)
    if not success or type(data) ~= "table" then
        return nil, "Game not found"
    end

    return M.parse_response(data)
end

return M
