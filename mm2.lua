-- MM2 Multi-Tool | Toker-4.1 | Sheriff Build
-- Silent Aim: Sheriff/Hero → Murderer only
-- Features: Silent Aim, Auto Shoot, ESP (+tracer), Fly, WalkSpeed, JumpPower, Auto Gun, Anti-AFK, Fast Interact

if _G.MM2_LOADED then
    warn("[MM2] already loaded")
    return
end
_G.MM2_LOADED = true

print("[MM2] loading...")

local ok, err = pcall(function()

-- ============================================================
-- LIBRARY
-- ============================================================
local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/PlockScripts/WandUI/refs/heads/main/redz-V5-remake/main.luau"))()
print("[MM2] library ok")

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace        = game:GetService("Workspace")
local VirtualUser      = game:GetService("VirtualUser")
local LocalPlayer      = Players.LocalPlayer
local Camera           = Workspace.CurrentCamera

-- ============================================================
-- CONFIG
-- ============================================================
local Config = {
    SilentAim     = false,
    AutoShoot     = false,
    ShootDelay    = 0.15,
    FOV           = 120,
    TargetPart    = "Head",
    MaxDistance   = 500,

    ESP           = false,
    ESP_Murderer  = true,
    ESP_Sheriff   = true,
    ESP_Hero      = true,
    ESP_Innocent  = true,
    ESP_Names     = true,
    ESP_Distance  = true,
    ESP_Box       = true,
    ESP_Tracer    = false,

    Fly           = false,
    FlySpeed      = 60,

    WalkEnabled   = false,
    WalkSpeed     = 16,

    JumpEnabled   = false,
    JumpPower     = 50,

    AutoGun       = false,
    AntiAFK       = false,
    FastInteract  = false,
}

-- ============================================================
-- STATE
-- ============================================================
local ESP_Store     = {}
local Tracers       = {}
local Fly_State     = {lv=nil, ao=nil, conn=nil, hum=nil, hrp=nil}
local Aim_Conn      = nil
local ESP_Conn      = nil
local Char_Conn     = nil
local Gun_Conn      = nil
local Shoot_Conn    = nil
local AFK_Conn      = nil
local Interact_Conn = nil
local RolesCache    = {}

local Mobile_Move = {x = 0, y = 0, up = false, down = false}

-- ============================================================
-- ROLE HELPERS
-- ============================================================
local function getRoleOf(plr)
    if not plr or not plr.Parent then return nil end
    local char = plr.Character
    if not char then return RolesCache[plr] end

    local ok2, role = pcall(function()
        if char:GetAttribute("Role") then return char:GetAttribute("Role") end
        local rv = plr:FindFirstChild("Role")
        if rv and rv:IsA("StringValue") then return rv.Value end
        if char:FindFirstChild("Knife") then return "Murderer" end
        if char:FindFirstChild("Gun") or char:FindFirstChild("Revolver") then return "Sheriff" end
        local bp = plr:FindFirstChildOfClass("Backpack")
        if bp then
            if bp:FindFirstChild("Knife") then return "Murderer" end
            if bp:FindFirstChild("Gun") or bp:FindFirstChild("Revolver") then return "Sheriff" end
        end
        return nil
    end)

    if ok2 and role then
        RolesCache[plr] = role
        return role
    end
    return RolesCache[plr]
end

local function normalizeRole(role)
    if not role then return "Innocent" end
    local r = string.lower(tostring(role))
    if r:find("murder") then return "Murderer" end
    if r:find("sheriff") then return "Sheriff" end
    if r:find("hero") then return "Hero" end
    return "Innocent"
end

local function isLocalSheriff()
    local r = normalizeRole(getRoleOf(LocalPlayer))
    return r == "Sheriff" or r == "Hero"
end

local function getMurderer()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and normalizeRole(getRoleOf(plr)) == "Murderer" then
            return plr
        end
    end
    return nil
end

local function roleColor(role)
    if role == "Murderer" then return Color3.fromRGB(220, 50, 50) end
    if role == "Sheriff"  then return Color3.fromRGB(60, 130, 255) end
    if role == "Hero"     then return Color3.fromRGB(255, 215, 0) end
    return Color3.fromRGB(90, 220, 120)
end

local function isAlive(plr)
    local c = plr and plr.Character
    if not c then return false end
    local h = c:FindFirstChildOfClass("Humanoid")
    return h and h.Health > 0
end

-- ============================================================
-- SILENT AIM (Sheriff/Hero → Murderer only)
-- ============================================================
local function getTarget()
    if not isLocalSheriff() then return nil end
    local murderer = getMurderer()
    if not murderer or not isAlive(murderer) then return nil end

    local char = murderer.Character
    local part = char:FindFirstChild(Config.TargetPart)
              or char:FindFirstChild("Head")
              or char:FindFirstChild("HumanoidRootPart")
    if not part then return nil end

    local myChar = LocalPlayer.Character
    if not myChar then return nil end
    local myRoot = myChar:FindFirstChild("HumanoidRootPart")
    if not myRoot then return nil end

    local dist = (part.Position - myRoot.Position).Magnitude
    if dist > Config.MaxDistance then return nil end

    local viewport = Camera.ViewportSize
    local sp, onScreen = Camera:WorldToViewportPoint(part.Position)
    if not onScreen then return nil end

    local cx, cy = viewport.X/2, viewport.Y/2
    local sd = (Vector2.new(sp.X, sp.Y) - Vector2.new(cx, cy)).Magnitude
    local fovPx = (math.tan(math.rad(Config.FOV/2)) * (viewport.Y/2)) /
                  math.tan(math.rad(Camera.FieldOfView/2))
    if sd > fovPx then return nil end

    return {plr = murderer, part = part}
end

local function startSilentAim()
    if Aim_Conn then Aim_Conn:Disconnect() end
    Aim_Conn = RunService.RenderStepped:Connect(function()
        if not Config.SilentAim then return end
        local t = getTarget()
        if t then
            pcall(function()
                Camera.CFrame = CFrame.new(Camera.CFrame.Position, t.part.Position)
            end)
        end
    end)
end

local function stopSilentAim()
    if Aim_Conn then Aim_Conn:Disconnect() Aim_Conn = nil end
end

-- ============================================================
-- AUTO SHOOT
-- ============================================================
local function fireGun()
    local char = LocalPlayer.Character
    if not char then return end
    local tool = char:FindFirstChildOfClass("Tool")
    if not tool then return end
    pcall(function() tool:Activate() end)
end

local function startAutoShoot()
    if Shoot_Conn then Shoot_Conn:Disconnect() end
    Shoot_Conn = RunService.Heartbeat:Connect(function()
        if not Config.AutoShoot then return end
        if not isLocalSheriff() then return end
        if getTarget() then
            fireGun()
            task.wait(Config.ShootDelay)
        end
    end)
end

local function stopAutoShoot()
    if Shoot_Conn then Shoot_Conn:Disconnect() Shoot_Conn = nil end
end

-- ============================================================
-- AUTO PICKUP GUN
-- ============================================================
local function tryPickupGun()
    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return end
    if char:FindFirstChild("Gun") or char:FindFirstChild("Revolver") then return end
    if not isLocalSheriff() then return end

    for _, obj in ipairs(Workspace:GetDescendants()) do
        local name = obj.Name
        if name == "Gun" or name == "Revolver" or name == "gun" then
            if obj:IsA("BasePart") or obj:IsA("Model") then
                local target = obj:IsA("Model") and (obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")) or obj
                if target then
                    local dist = (target.Position - hrp.Position).Magnitude
                    if dist <= 8 then
                        pcall(function()
                            firetouchinterest(hrp, target, 0)
                            firetouchinterest(hrp, target, 1)
                        end)
                    end
                end
            end
        end
    end
end

local function startAutoGun()
    if Gun_Conn then Gun_Conn:Disconnect() end
    Gun_Conn = RunService.Heartbeat:Connect(function()
        if not Config.AutoGun then return end
        pcall(tryPickupGun)
    end)
end

local function stopAutoGun()
    if Gun_Conn then Gun_Conn:Disconnect() Gun_Conn = nil end
end

-- ============================================================
-- ESP
-- ============================================================
local function removeTracer(plr)
    if Tracers[plr] then
        pcall(function() Tracers[plr]:Destroy() end)
        Tracers[plr] = nil
    end
end

local function removeESP(plr)
    local data = ESP_Store[plr]
    if not data then return end
    if data.highlight then data.highlight:Destroy() end
    if data.billboard then data.billboard:Destroy() end
    if data.box then data.box:Destroy() end
    removeTracer(plr)
    ESP_Store[plr] = nil
end

local function buildESP(plr)
    if plr == LocalPlayer then return end
    if ESP_Store[plr] then return end
    local char = plr.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local role = normalizeRole(getRoleOf(plr))
    local color = roleColor(role)

    local hl = Instance.new("Highlight")
    hl.Name = "MM2_ESP_HL"
    hl.Adornee = char
    hl.FillColor = color
    hl.OutlineColor = Color3.new(0, 0, 0)
    hl.FillTransparency = 0.6
    hl.OutlineTransparency = 0
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Parent = char

    local box = Instance.new("SelectionBox")
    box.Name = "MM2_ESP_BOX"
    box.Adornee = hrp
    box.LineThickness = 0.05
    box.Color3 = color
    box.Transparency = 0.3
    box.Parent = char

    local bb = Instance.new("BillboardGui")
    bb.Name = "MM2_ESP_BB"
    bb.Adornee = char:FindFirstChild("Head") or hrp
    bb.Size = UDim2.new(0, 220, 0, 60)
    bb.StudsOffset = Vector3.new(0, 3.2, 0)
    bb.AlwaysOnTop = true
    bb.Parent = char

    local nameLbl = Instance.new("TextLabel")
    nameLbl.Name = "NameLbl"
    nameLbl.BackgroundTransparency = 1
    nameLbl.Size = UDim2.new(1, 0, 0.5, 0)
    nameLbl.Font = Enum.Font.GothamBold
    nameLbl.TextSize = 14
    nameLbl.TextColor3 = color
    nameLbl.TextStrokeTransparency = 0
    nameLbl.TextStrokeColor3 = Color3.new(0, 0, 0)
    nameLbl.Text = plr.Name
    nameLbl.Parent = bb

    local infoLbl = Instance.new("TextLabel")
    infoLbl.Name = "InfoLbl"
    infoLbl.BackgroundTransparency = 1
    infoLbl.Position = UDim2.new(0, 0, 0.5, 0)
    infoLbl.Size = UDim2.new(1, 0, 0.5, 0)
    infoLbl.Font = Enum.Font.Gotham
    infoLbl.TextSize = 12
    infoLbl.TextColor3 = Color3.fromRGB(230, 230, 230)
    infoLbl.TextStrokeTransparency = 0
    infoLbl.TextStrokeColor3 = Color3.new(0, 0, 0)
    infoLbl.Text = string.format("[%s] 0m", role)
    infoLbl.Parent = bb

    ESP_Store[plr] = {
        highlight = hl, billboard = bb, box = box,
        nameLbl = nameLbl, infoLbl = infoLbl, role = role,
    }
end

local function updateTracer(plr, hrp, color)
    local myChar = LocalPlayer.Character
    if not myChar then return end
    local myRoot = myChar:FindFirstChild("HumanoidRootPart")
    if not myRoot then return end

    local line = Tracers[plr]
    if not line then
        line = Drawing.new("Line")
        line.Thickness = 1.5
        line.Transparency = 1
        line.Visible = false
        Tracers[plr] = line
    end

    if not Config.ESP or not Config.ESP_Tracer then
        line.Visible = false
        return
    end

    local o, oOn = Camera:WorldToViewportPoint(myRoot.Position)
    local t, tOn = Camera:WorldToViewportPoint(hrp.Position)
    if oOn and tOn then
        line.From = Vector2.new(o.X, o.Y)
        line.To   = Vector2.new(t.X, t.Y)
        line.Color = color
        line.Visible = true
    else
        line.Visible = false
    end
end

local function updateESP()
    local myPos = Camera.CFrame.Position
    for plr, data in pairs(ESP_Store) do
        if not plr.Parent or not plr.Character or not plr.Character.Parent then
            removeESP(plr)
            continue
        end

        local role = normalizeRole(getRoleOf(plr))
        local color = roleColor(role)
        data.role = role

        local visible = false
        if role == "Murderer" and Config.ESP_Murderer then visible = true end
        if role == "Sheriff"  and Config.ESP_Sheriff  then visible = true end
        if role == "Hero"     and Config.ESP_Hero     then visible = true end
        if role == "Innocent" and Config.ESP_Innocent then visible = true end

        if data.highlight then
            data.highlight.Enabled = Config.ESP and visible
            data.highlight.FillColor = color
        end
        if data.box then
            data.box.Visible = Config.ESP and visible and Config.ESP_Box
            data.box.Color3 = color
        end
        if data.billboard then
            data.billboard.Enabled = Config.ESP and visible
        end
        if data.nameLbl then
            data.nameLbl.TextColor3 = color
            data.nameLbl.Text = Config.ESP_Names and plr.Name or ""
            data.nameLbl.Visible = Config.ESP_Names
        end
        if data.infoLbl then
            local hrp = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
            local d = 0
            if hrp then d = math.floor((hrp.Position - myPos).Magnitude) end
            data.infoLbl.Text = string.format("[%s] %dm", role, d)
            data.infoLbl.Visible = Config.ESP_Distance
        end

        local hrp2 = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
        if hrp2 and visible then
            pcall(updateTracer, plr, hrp2, color)
        elseif Tracers[plr] then
            Tracers[plr].Visible = false
        end
    end
end

local function startESP()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then buildESP(plr) end
    end
    if ESP_Conn then ESP_Conn:Disconnect() end
    ESP_Conn = RunService.Heartbeat:Connect(function()
        if not Config.ESP then
            for plr in pairs(ESP_Store) do removeESP(plr) end
            return
        end
        updateESP()
    end)
end

local function stopESP()
    if ESP_Conn then ESP_Conn:Disconnect() ESP_Conn = nil end
    for plr in pairs(ESP_Store) do removeESP(plr) end
end

-- ============================================================
-- FLY
-- ============================================================
local function stopFly()
    if Fly_State.conn then Fly_State.conn:Disconnect() Fly_State.conn = nil end
    if Fly_State.lv then pcall(function() Fly_State.lv:Destroy() end) Fly_State.lv = nil end
    if Fly_State.ao then pcall(function() Fly_State.ao:Destroy() end) Fly_State.ao = nil end
    if Fly_State.hum then
        pcall(function()
            Fly_State.hum.PlatformStand = false
            Fly_State.hum:ChangeState(Enum.HumanoidStateType.GettingUp)
        end)
    end
    Fly_State.hum = nil
    Fly_State.hrp = nil
end

local function getMoveVector()
    local v = Vector3.new(0, 0, 0)
    if UserInputService:IsKeyDown(Enum.KeyCode.W) then v += Vector3.new(0, 0, -1) end
    if UserInputService:IsKeyDown(Enum.KeyCode.S) then v += Vector3.new(0, 0,  1) end
    if UserInputService:IsKeyDown(Enum.KeyCode.A) then v += Vector3.new(-1, 0, 0) end
    if UserInputService:IsKeyDown(Enum.KeyCode.D) then v += Vector3.new( 1, 0, 0) end
    if UserInputService:IsKeyDown(Enum.KeyCode.Space) then v += Vector3.new(0, 1, 0) end
    if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
       or UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
        v += Vector3.new(0, -1, 0)
    end
    if math.abs(Mobile_Move.x) > 0.01 or math.abs(Mobile_Move.y) > 0.01 then
        v += Vector3.new(Mobile_Move.x, 0, Mobile_Move.y)
    end
    if Mobile_Move.up then v += Vector3.new(0, 1, 0) end
    if Mobile_Move.down then v += Vector3.new(0, -1, 0) end
    return v
end

local function startFly()
    stopFly()
    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart") or char:WaitForChild("HumanoidRootPart", 2)
    if not hrp then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end

    Fly_State.hrp = hrp
    Fly_State.hum = hum

    pcall(function()
        hum:SetStateEnabled(Enum.HumanoidStateType.Freefall, false)
        hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
        hum.PlatformStand = true
    end)

    local att = hrp:FindFirstChild("MM2_Fly_Att") or Instance.new("Attachment")
    att.Name = "MM2_Fly_Att"
    att.Parent = hrp

    local lv = Instance.new("LinearVelocity")
    lv.Name = "MM2_Fly_LV"
    lv.Attachment0 = att
    lv.MaxForce = math.huge
    lv.RelativeTo = Enum.ActuatorRelativeTo.World
    lv.VectorVelocity = Vector3.new(0, 0, 0)
    lv.Parent = hrp
    Fly_State.lv = lv

    local ao = Instance.new("AlignOrientation")
    ao.Name = "MM2_Fly_AO"
    ao.Attachment0 = att
    ao.Mode = Enum.OrientationAlignmentMode.OneAttachment
    ao.RigidityEnabled = true
    ao.CFrame = hrp.CFrame
    ao.Parent = hrp
    Fly_State.ao = ao

    Fly_State.conn = RunService.RenderStepped:Connect(function()
        if not Config.Fly then return end
        local c = LocalPlayer.Character
        if not c or c ~= char then return end
        local r = c:FindFirstChild("HumanoidRootPart")
        if not r or not Fly_State.lv then return end

        local cam = Camera.CFrame
        local input = getMoveVector()
        local worldMove = (cam.LookVector * -input.Z) + (cam.RightVector * input.X)
        local vertical   = Vector3.new(0, input.Y, 0)
        local dir = worldMove + vertical
        if dir.Magnitude > 0 then dir = dir.Unit * Config.FlySpeed end

        Fly_State.lv.VectorVelocity = dir
        if Fly_State.ao then
            Fly_State.ao.CFrame = CFrame.new(r.Position, r.Position + cam.LookVector)
        end
    end)
end

-- ============================================================
-- WALK / JUMP
-- ============================================================
local function applyWalk()
    local char = LocalPlayer.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    hum.WalkSpeed = Config.WalkEnabled and Config.WalkSpeed or 16
end

local function applyJump()
    local char = LocalPlayer.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    if Config.JumpEnabled then
        pcall(function() hum.UseJumpPower = true end)
        hum.JumpPower = Config.JumpPower
    else
        pcall(function() hum.UseJumpPower = false end)
        hum.JumpPower = 50
    end
end

-- ============================================================
-- ANTI-AFK / FAST INTERACT
-- ============================================================
local function startAntiAFK()
    if AFK_Conn then AFK_Conn:Disconnect() end
    AFK_Conn = LocalPlayer.Idled:Connect(function()
        if not Config.AntiAFK then return end
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end)
    end)
end

local function startFastInteract()
    if Interact_Conn then Interact_Conn:Disconnect() end
    Interact_Conn = RunService.Heartbeat:Connect(function()
        if not Config.FastInteract then return end
        local char = LocalPlayer.Character
        if not char then return end
        local tool = char:FindFirstChildOfClass("Tool")
        if tool then
            pcall(function()
                if tool:FindFirstChild("Cooldown") then tool.Cooldown.Value = 0 end
                if tool:FindFirstChild("Reload") then tool.Reload.Value = false end
            end)
        end
    end)
end

-- ============================================================
-- CHARACTER / PLAYER HOOKS
-- ============================================================
local function bindCharacter(char)
    char:WaitForChild("Humanoid", 10)

    local function refresh()
        if Config.Fly then
            task.wait(0.4)
            startFly()
        end
        if Config.ESP then
            removeESP(LocalPlayer)
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr ~= LocalPlayer then
                    removeESP(plr)
                    buildESP(plr)
                end
            end
        end
        if Config.WalkEnabled then applyWalk() end
        if Config.JumpEnabled then applyJump() end
    end

    char.AncestryChanged:Connect(function(_, parent)
        if not parent then stopFly() end
    end)

    task.delay(0.5, refresh)
end

if Char_Conn then Char_Conn:Disconnect() end
Char_Conn = LocalPlayer.CharacterAdded:Connect(bindCharacter)
if LocalPlayer.Character then bindCharacter(LocalPlayer.Character) end

Players.PlayerAdded:Connect(function(plr)
    plr.CharacterAdded:Connect(function()
        if Config.ESP then
            task.wait(0.5)
            buildESP(plr)
        end
    end)
end)

Players.PlayerRemoving:Connect(function(plr)
    removeESP(plr)
    RolesCache[plr] = nil
end)

task.spawn(function()
    while task.wait(1) do
        if Config.ESP or Config.SilentAim or Config.AutoGun or Config.AutoShoot then
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr ~= LocalPlayer then getRoleOf(plr) end
            end
        end
    end
end)

-- ============================================================
-- UI
-- ============================================================
local Window = Library:MakeWindow({
    Name = "MM2 | Toker-4.1",
    SubName = "Sheriff Build",
    FolderName = "MM2_Toker41",
})

local Tabs = {
    Aim      = Window:MakeTab({Name = "Aim"}),
    ESP      = Window:MakeTab({Name = "ESP"}),
    Movement = Window:MakeTab({Name = "Movement"}),
    Misc     = Window:MakeTab({Name = "Misc"}),
}

-- AIM
Tabs.Aim:AddSection("Silent Aim — Sheriff → Murderer")

Tabs.Aim:AddToggle({
    Name = "Silent Aim", Default = false, Flag = "sa_enabled",
    Callback = function(v)
        Config.SilentAim = v
        if v then startSilentAim() else stopSilentAim() end
    end,
})

Tabs.Aim:AddParagraph(
    "Только Sheriff/Hero → только Murderer.",
    "Другие цели игнорируются."
)

Tabs.Aim:AddSlider({
    Name = "FOV", Min = 20, Max = 360, Default = 120, Flag = "sa_fov",
    Callback = function(v) Config.FOV = v end,
})

Tabs.Aim:AddDropdown({
    Name = "Target Part",
    Options = {"Head", "HumanoidRootPart", "UpperTorso", "Torso"},
    Default = "Head",
    Flag = "sa_part",
    Callback = function(v) Config.TargetPart = v end,
})

Tabs.Aim:AddSlider({
    Name = "Max Distance", Min = 50, Max = 1500, Default = 500, Flag = "sa_dist",
    Callback = function(v) Config.MaxDistance = v end,
})

Tabs.Aim:AddSection("Auto Shoot")

Tabs.Aim:AddToggle({
    Name = "Auto Shoot", Default = false, Flag = "as_enabled",
    Callback = function(v)
        Config.AutoShoot = v
        if v then startAutoShoot() else stopAutoShoot() end
    end,
})

Tabs.Aim:AddSlider({
    Name = "Shoot Delay", Min = 0.05, Max = 1, Default = 0.15, Flag = "as_delay",
    Callback = function(v) Config.ShootDelay = v end,
})

-- ESP
Tabs.ESP:AddToggle({
    Name = "ESP Master", Default = false, Flag = "esp_enabled",
    Callback = function(v)
        Config.ESP = v
        if v then startESP() else stopESP() end
    end,
})
Tabs.ESP:AddToggle({Name = "Murderer", Default = true,  Flag = "esp_m",     Callback = function(v) Config.ESP_Murderer = v end})
Tabs.ESP:AddToggle({Name = "Sheriff",  Default = true,  Flag = "esp_s",     Callback = function(v) Config.ESP_Sheriff  = v end})
Tabs.ESP:AddToggle({Name = "Hero",     Default = true,  Flag = "esp_h",     Callback = function(v) Config.ESP_Hero     = v end})
Tabs.ESP:AddToggle({Name = "Innocent", Default = true,  Flag = "esp_i",     Callback = function(v) Config.ESP_Innocent = v end})
Tabs.ESP:AddToggle({Name = "Names",    Default = true,  Flag = "esp_names", Callback = function(v) Config.ESP_Names    = v end})
Tabs.ESP:AddToggle({Name = "Distance", Default = true,  Flag = "esp_dist",  Callback = function(v) Config.ESP_Distance = v end})
Tabs.ESP:AddToggle({Name = "Box",      Default = true,  Flag = "esp_box",   Callback = function(v) Config.ESP_Box      = v end})
Tabs.ESP:AddToggle({Name = "Tracer",   Default = false, Flag = "esp_tracer",Callback = function(v) Config.ESP_Tracer   = v end})

-- MOVEMENT
Tabs.Movement:AddSection("Fly")
Tabs.Movement:AddToggle({
    Name = "Fly", Default = false, Flag = "fly_enabled",
    Callback = function(v)
        Config.Fly = v
        if v then startFly() else stopFly() end
    end,
})
Tabs.Movement:AddSlider({
    Name = "Fly Speed", Min = 10, Max = 400, Default = 60, Flag = "fly_speed",
    Callback = function(v) Config.FlySpeed = v end,
})

Tabs.Movement:AddSection("Speed / Jump")
Tabs.Movement:AddToggle({
    Name = "WalkSpeed", Default = false, Flag = "ws_enabled",
    Callback = function(v)
        Config.WalkEnabled = v
        applyWalk()
    end,
})
Tabs.Movement:AddSlider({
    Name = "WalkSpeed Value", Min = 16, Max = 200, Default = 16, Flag = "ws_value",
    Callback = function(v)
        Config.WalkSpeed = v
        if Config.WalkEnabled then applyWalk() end
    end,
})
Tabs.Movement:AddToggle({
    Name = "JumpPower", Default = false, Flag = "jp_enabled",
    Callback = function(v)
        Config.JumpEnabled = v
        applyJump()
    end,
})
Tabs.Movement:AddSlider({
    Name = "JumpPower Value", Min = 50, Max = 300, Default = 50, Flag = "jp_value",
    Callback = function(v)
        Config.JumpPower = v
        if Config.JumpEnabled then applyJump() end
    end,
})

-- MISC
Tabs.Misc:AddToggle({
    Name = "Auto Pickup Gun", Default = false, Flag = "auto_gun",
    Callback = function(v)
        Config.AutoGun = v
        if v then startAutoGun() else stopAutoGun() end
    end,
})
Tabs.Misc:AddButton({
    Name = "Pickup Gun Now",
    Callback = function() pcall(tryPickupGun) end,
})
Tabs.Misc:AddToggle({
    Name = "Anti-AFK", Default = false, Flag = "anti_afk",
    Callback = function(v)
        Config.AntiAFK = v
        if v then startAntiAFK() end
    end,
})
Tabs.Misc:AddToggle({
    Name = "Fast Interact", Default = false, Flag = "fast_interact",
    Callback = function(v)
        Config.FastInteract = v
        if v then startFastInteract() end
    end,
})
Tabs.Misc:AddButton({
    Name = "Rejoin Server",
    Callback = function()
        pcall(function()
            game:GetService("TeleportService"):Teleport(game.PlaceId, LocalPlayer)
        end)
    end,
})
Tabs.Misc:AddButton({
    Name = "Reset Character",
    Callback = function()
        local c = LocalPlayer.Character
        if c then
            local h = c:FindFirstChildOfClass("Humanoid")
            if h then h.Health = 0 end
        end
    end,
})
Tabs.Misc:AddButton({
    Name = "Unload Script",
    Callback = function()
        stopSilentAim(); stopAutoShoot(); stopESP(); stopFly(); stopAutoGun()
        if Char_Conn then Char_Conn:Disconnect() end
        pcall(function() Library:Destroy() end)
        _G.MM2_LOADED =
