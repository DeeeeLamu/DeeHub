-- Depoot10 Carry Hub
-- Versi 1.0.0
-- Fitur: Carry, Anti-Lag, Resize Part, Speed, Toggle UI
local OrionLib = loadstring(game:HttpGet(('https://raw.githubusercontent.com/jensonhirst/Orion/main/source')))()

-- Window
local Window = OrionLib:MakeWindow({
    Name = "Depoot10 Carry Hub",
    HidePremium = false,
    SaveConfig = false,
    ConfigFolder = "Depoot10Carry"
})

-- Tabs
local MainTab = Window:MakeTab({Name = "Carry System", Icon = "rbxassetid://4483345998"})
local PerformanceTab = Window:MakeTab({Name = "Performance", Icon = "rbxassetid://6034509993"})
local UtilityTab = Window:MakeTab({Name = "Utility", Icon = "rbxassetid://4483345998"})

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local Terrain = workspace:FindFirstChildOfClass("Terrain")
local LocalPlayer = Players.LocalPlayer

-- Carry remotes
local CarryReplic = ReplicatedStorage:WaitForChild("CarryReplic")
local CarryRemote = CarryReplic:WaitForChild("CarryRemotes"):WaitForChild("CarryRemote")
local CarryChoices = CarryReplic:WaitForChild("CarryChoices")
local GendongPilihan = CarryChoices:WaitForChild("Gendong Pundak")

--=============================================================
-- Carry System
--=============================================================
local targetName, carryRadius = "", 10
local function GendongPlayer(namaTarget)
    local target = Players:FindFirstChild(namaTarget)
    if target then
        CarryRemote:FireServer({cmd="AskCarry", carrychoicesss=GendongPilihan, targetPlr=target})
        OrionLib:MakeNotification({Name="Carry System", Content="Request gendong ke "..namaTarget, Time=2})
    else
        OrionLib:MakeNotification({Name="Carry System", Content="Player tidak ditemukan: "..tostring(namaTarget), Time=2})
    end
end

local function GendongTerdekat()
    local char = LocalPlayer.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local closest, distMin = nil, math.huge
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
            local d = (plr.Character.HumanoidRootPart.Position - root.Position).Magnitude
            if d < distMin then distMin, closest = d, plr end
        end
    end
    if closest then GendongPlayer(closest.Name)
    else OrionLib:MakeNotification({Name="Carry System", Content="Tidak ada player terdekat.", Time=2}) end
end

local function GendongSemua(radius)
    local char = LocalPlayer.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local hitung = 0
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
            if (plr.Character.HumanoidRootPart.Position - root.Position).Magnitude <= radius then
                GendongPlayer(plr.Name)
                hitung += 1
            end
        end
    end
    OrionLib:MakeNotification({Name="Carry System", Content="Request gendong ke "..hitung.." player.", Time=2})
end

-- UI Carry
MainTab:AddTextbox({Name="Nama Player", Default="", TextDisappear=false, Callback=function(v) targetName=v end})
MainTab:AddButton({Name="Gendong Player (Manual)", Callback=function() if targetName~="" then GendongPlayer(targetName) else OrionLib:MakeNotification({Name="Carry System", Content="Isi nama dulu.", Time=2}) end end})
MainTab:AddButton({Name="Gendong Player Terdekat", Callback=GendongTerdekat})
MainTab:AddSlider({Name="Radius Gendong (10-20)", Min=10, Max=20, Default=10, Increment=1, Callback=function(v) carryRadius=v end})
MainTab:AddButton({Name="Gendong Semua Dalam Radius", Callback=function() GendongSemua(carryRadius) end})

--=============================================================
-- Performance Tab
--=============================================================
local AntiLagEnabled = false
local AntiLagConn
local Saved = {particles={}, decals={}, textures={}, materials={}, lighting=nil, terrain=nil}

local function saveLightingAndDim()
    if Saved.lighting then return end
    Saved.lighting = {GlobalShadows=Lighting.GlobalShadows, Brightness=Lighting.Brightness, FogEnd=Lighting.FogEnd, effects={}}
    for _, ef in ipairs(Lighting:GetChildren()) do
        if ef:IsA("BlurEffect") or ef:IsA("SunRaysEffect") or ef:IsA("ColorCorrectionEffect") or ef:IsA("BloomEffect") or ef:IsA("DepthOfFieldEffect") then
            Saved.lighting.effects[ef]=ef.Enabled
            ef.Enabled=false
        end
    end
    Lighting.GlobalShadows=false
    Lighting.Brightness=1
    Lighting.FogEnd=9e9
end

local function restoreLighting()
    local L=Saved.lighting
    if not L then return end
    Lighting.GlobalShadows=L.GlobalShadows
    Lighting.Brightness=L.Brightness
    Lighting.FogEnd=L.FogEnd
    for ef, was in pairs(L.effects) do if ef and ef.Parent then ef.Enabled=was end end
    Saved.lighting=nil
end

local function saveTerrainAndDim()
    if not Terrain or Saved.terrain then return end
    Saved.terrain={WaterWaveSize=Terrain.WaterWaveSize, WaterWaveSpeed=Terrain.WaterWaveSpeed, WaterReflectance=Terrain.WaterReflectance, WaterTransparency=Terrain.WaterTransparency}
    Terrain.WaterWaveSize=0
    Terrain.WaterWaveSpeed=0
    Terrain.WaterReflectance=0
    Terrain.WaterTransparency=0
end

local function restoreTerrain()
    if not Terrain or not Saved.terrain then return end
    for k,v in pairs(Saved.terrain) do Terrain[k]=v end
    Saved.terrain=nil
end

local function applyAntiLagTo(inst)
    if inst:IsA("ParticleEmitter") or inst:IsA("Trail") or inst:IsA("Smoke") or inst:IsA("Fire") then
        if Saved.particles[inst]==nil then Saved.particles[inst]=inst.Enabled end
        inst.Enabled=false
    elseif inst:IsA("Decal") or inst:IsA("Texture") then
        if Saved.decals[inst]==nil then Saved.decals[inst]=inst.Transparency end
        inst.Transparency=1
    elseif inst:IsA("MeshPart") then
        if Saved.textures[inst]==nil then Saved.textures[inst]=inst.TextureID end
        inst.TextureID=""
        if Saved.materials[inst]==nil then Saved.materials[inst]=inst.Material end
        inst.Material=Enum.Material.Plastic
        inst.Reflectance=0
    elseif inst:IsA("BasePart") then
        if Saved.materials[inst]==nil then Saved.materials[inst]=inst.Material end
        inst.Material=Enum.Material.Plastic
        inst.Reflectance=0
    elseif inst:IsA("Explosion") then
        inst.BlastPressure=0
        inst.BlastRadius=0
    end
end

local function enableAntiLag()
    AntiLagEnabled=true
    settings().Rendering.QualityLevel=Enum.QualityLevel.Level01
    saveLightingAndDim()
    saveTerrainAndDim()
    for _, inst in ipairs(workspace:GetDescendants()) do applyAntiLagTo(inst) end
    AntiLagConn=workspace.DescendantAdded:Connect(applyAntiLagTo)
    OrionLib:MakeNotification({Name="Performance", Content="Anti-Lag ON", Time=2})
end

local function disableAntiLag()
    AntiLagEnabled=false
    if AntiLagConn then AntiLagConn:Disconnect() AntiLagConn=nil end
    for inst, was in pairs(Saved.particles) do if inst and inst.Parent then inst.Enabled=was end end
    for inst, tr in pairs(Saved.decals) do if inst and inst.Parent then inst.Transparency=tr end end
    for inst, tex in pairs(Saved.textures) do if inst and inst.Parent and inst:IsA("MeshPart") then inst.TextureID=tex end end
    for inst, mat in pairs(Saved.materials) do if inst and inst.Parent and inst:IsA("BasePart") then inst.Material=mat end end
    Saved.particles,Saved.decals,Saved.textures,Saved.materials={}, {}, {}, {}
    restoreLighting()
    restoreTerrain()
    settings().Rendering.QualityLevel=Enum.QualityLevel.Automatic
    OrionLib:MakeNotification({Name="Performance", Content="Anti-Lag OFF (aset dipulihkan)", Time=2})
end

local function clearLagOnce()
    local n=0
    for _, inst in ipairs(workspace:GetDescendants()) do
        if inst:IsA("ParticleEmitter") or inst:IsA("Trail") or inst:IsA("Smoke") or inst:IsA("Fire") or inst:IsA("Decal") or inst:IsA("Texture") then
            inst:Destroy()
            n+=1
        end
    end
    for _, ef in ipairs(Lighting:GetChildren()) do
        if ef:IsA("BlurEffect") or ef:IsA("SunRaysEffect") or ef:IsA("ColorCorrectionEffect") or ef:IsA("BloomEffect") or ef:IsA("DepthOfFieldEffect") then
            ef.Enabled=false
        end
    end
    settings().Rendering.QualityLevel=Enum.QualityLevel.Level01
    OrionLib:MakeNotification({Name="Performance", Content="Clear Lag selesai: "..n.." objek dihapus", Time=3})
end

PerformanceTab:AddToggle({Name="Anti-Lag (ON/OFF)", Default=false, Callback=function(v) if v then enableAntiLag() else disable
