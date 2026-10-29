local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer

local CONFIG = {
    Enabled = false,
    RestoreDelay = 1.0,
    ScanInterval = 0.15,
    MaxDistance = 8,
}

local original = {}
local lastTouch = {}
local elapsed = 0

local function isCharacterPart(part, character)
    return part:IsDescendantOf(character)
end

local function isExcluded(part)
    if not part:IsA("BasePart") then
        return true
    end

    -- Terrain, objek yang sudah tidak ada, dan bagian karakter
    -- tidak diproses sebagai objek yang bisa ditembus.
    if part == Workspace.Terrain then
        return true
    end

    if part:GetAttribute("KeepCollision") == true then
        return true
    end

    return false
end

local function saveOriginal(part)
    if original[part] then
        return
    end

    original[part] = {
        CanCollide = part.CanCollide,
        CanTouch = part.CanTouch,
        CanQuery = part.CanQuery,
        Transparency = part.Transparency,
        LocalTransparencyModifier = part.LocalTransparencyModifier,
    }
end

local function phase(part)
    if isExcluded(part) then
        return
    end

    saveOriginal(part)

    -- Simpan waktu terakhir objek bersentuhan dengan karakter.
    lastTouch[part] = os.clock()

    -- Efek lokal: objek dapat dilewati oleh karakter lokal.
    part.CanCollide = false
    part.LocalTransparencyModifier = 0.35
end

local function restore(part)
    local state = original[part]
    if not state then
        return
    end

    if part.Parent then
        part.CanCollide = state.CanCollide
        part.CanTouch = state.CanTouch
        part.CanQuery = state.CanQuery
        part.Transparency = state.Transparency
        part.LocalTransparencyModifier =
            state.LocalTransparencyModifier
    end

    original[part] = nil
    lastTouch[part] = nil
end

local function getCharacter()
    local character = player.Character
    if not character then
        return nil, nil
    end

    local root = character:FindFirstChild("HumanoidRootPart")
    return character, root
end

local function scan()
    local character, root = getCharacter()
    if not character or not root then
        return
    end

    local params = OverlapParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {character}

    local nearby = Workspace:GetPartBoundsInRadius(
        root.Position,
        CONFIG.MaxDistance,
        params
    )

    for _, part in ipairs(nearby) do
        if not isCharacterPart(part, character) then
            phase(part)
        end
    end
end

local function restoreExpired()
    local now = os.clock()

    for part, touchedAt in pairs(lastTouch) do
        if not part.Parent then
            original[part] = nil
            lastTouch[part] = nil
        elseif now - touchedAt >= CONFIG.RestoreDelay then
            restore(part)
        end
    end
end

RunService.Heartbeat:Connect(function(dt)
    if not CONFIG.Enabled then
        return
    end

    elapsed = elapsed + dt
    if elapsed >= CONFIG.ScanInterval then
        elapsed = 0

        local ok, err = pcall(scan)
        if not ok then
            warn("[TemporaryPhase]", err)
        end

        restoreExpired()
    end
end)

-- Contoh pengaktifan:
-- CONFIG.Enabled = true
--
-- Saat dimatikan, pulihkan semua objek:
local function disablePhase()
    CONFIG.Enabled = false

    for part in pairs(original) do
        restore(part)
    end
end

-- Panggil disablePhase() ketika fitur dimatikan.
