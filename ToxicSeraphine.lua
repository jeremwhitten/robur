--[[
  ToxicSeraphine

  Credits: wxx for using a base of his code to figure this out 
]]

require("common.log")

local Meta = {
  Name = "ToxicSeraphine",
  Version = "1.0.0",
  ChampionName = "Seraphine"
}

module(Meta.Name, package.seeall, log.setup)
clean.module(Meta.Name, package.seeall, log.setup)

local CoreEx = _G.CoreEx
local Libs   = _G.Libs

local Menu = Libs.NewMenu

local Game          = CoreEx.Game
local Input         = CoreEx.Input
local Enums         = CoreEx.Enums
local Renderer      = CoreEx.Renderer
local ObjectManager = CoreEx.ObjectManager
local EventManager  = CoreEx.EventManager
local Vector        = CoreEx.Geometry.Vector

local TargetSelector   = Libs.TargetSelector
local Spell            = Libs.Spell
local Orbwalker        = Libs.Orbwalker
local DamageLib        = Libs.DamageLib
local HealthPrediction = Libs.HealthPred

local Events     = Enums.Events
local SpellSlots = Enums.SpellSlots
local HitChance  = Enums.HitChance

local LocalPlayer = ObjectManager.Player.AsHero

-- Check if we are using the right champion
if LocalPlayer.CharName ~= Meta.ChampionName then return false end

local HitChanceList = { "Collision", "OutOfRange", "VeryLow", "Low", "Medium", "High", "VeryHigh", "Dashing", "Immobile" }

-- UTILS --
local Utils = {}

function Utils.IsGameAvailable()
  -- Is game available to automate stuff
  return not (
    Game.IsChatOpen()  or
    Game.IsMinimized() or
    LocalPlayer.IsDead
  )
end

function Utils.IsInRange(From, To, Min, Max)
  local Distance = From:Distance(To)
  return Distance >= Min and Distance <= Max
end

function Utils.IsValidTarget(Target)
  return Target.IsTargetable and Target.IsAlive
end


function Utils.LoadMenu()
  Menu.RegisterMenu(Meta.Name, Meta.Name, function ()
    
    Menu.NewTree("Q", "[Q] High Note", function()
      Menu.NewTree("ComboQ", "Combo", function()
          Menu.Checkbox("ComboUseQ", "Enabled", true)
      end)      
    end)
    --Menu.NewTree("W", "[W] Surround Sound", function()
    --Menu.NewTree("AutoW", "Auto", function()
    --   Menu.Checkbox("AutoUseWAlly", "Enabled Heal", true)
    --   Menu.Slider("AutoWHealth", "HP %", 50, 0, 100, 1)
    -- end)
    --nd)
    Menu.NewTree("E", "[E] Beat Drop", function()
      Menu.NewTree("ComboE", "Combo", function()
          Menu.Checkbox("ComboUseE", "Enabled", true)
          Menu.Dropdown("ComboHitChanceE", "Hitchance", 6, HitChanceList)
      end)
    end)
    Menu.NewTree("R", "[R] Encore", function()
      Menu.NewTree("ComboR", "Combo", function()
          Menu.Checkbox("ComboUseR", "Enabled", true)
          Menu.Dropdown("ComboHitChanceR", "Hitchance", 6, HitChanceList)
      end)
    end)
  end)
end

-- CHAMPION SPELLS --
local Champion  = {}

Champion.Spells = {}

Champion.Spells.Q = Spell.Skillshot({
  Slot = SpellSlots.Q,
  SlotString = "Q",
  Range = 800,
  Speed = math.huge,
  Radius = 350,
  EffectRadius = 280,
  Delay = 0.25,
  UseHitbox = true,
  Type = "Circular"
})

Champion.Spells.W = Spell.Active({
  Slot = SpellSlots.W,
  Range = 600,
  Delay = 0.25
})

Champion.Spells.E = Spell.Skillshot({
  Slot = SpellSlots.E,
  SlotString = "E",
  Range = 1200,
  Speed = 1200,
  Radius = 70,
  EffectRadius = 70,
  Delay = 0.25,
  UseHitbox = true,
  Type = "Linear"
})

Champion.Spells.R = Spell.Skillshot({
  Slot = SpellSlots.R,
  SlotString = "R",
  Range = 1200,
  Speed = 1600,
  Radius = 160,
  Delay = 0.5,
  UseHitbox = true,
  Type = "Linear",
})

-- CHAMPION LOGICS --
Champion.Logic = {}

function Champion.Logic.Q(Target, Enable)
  local Q = Champion.Spells.Q
  
  if
    Enable and
    Target and
    Q:IsReady() and
    Q:IsInRange(Target)
  then
    return Q:Cast(Target)
  end

  return false
end

function Champion.Logic.W(Target, Enable)
  local W = Champion.Spells.W
  
  if
    Enable and
    Target and
    W:IsReady() and
    W:IsInRange(Target)
  then
    return W:Cast(Target)
  end

  return false
end


function Champion.Logic.E(Target, Hitchance, Enable)
  local E = Champion.Spells.E
  
  if
    Enable and
    Target and
    E:IsReady()
  then
    return E:CastOnHitChance(Target, Hitchance)
  end

  return false
end

function Champion.Logic.R(Target, Hitchance, Enable)
  local R = Champion.Spells.R
  
  if
    Enable and
    Target and
    R:IsReady()
  then
    return R:CastOnHitChance(Target, Hitchance)
  end

  return false
end

function Champion.Logic.Combo()
  if Champion.Logic.E(Champion.Spells.E:GetTarget(), Menu.Get("ComboHitChanceE"), Menu.Get("ComboUseE")) then return true end
  if Champion.Logic.Q(Champion.Spells.Q:GetTarget(), Menu.Get("ComboUseQ")) then return true end
  if Champion.Logic.R(Champion.Spells.R:GetTarget(), Menu.Get("ComboHitChanceR"), Menu.Get("ComboUseR")) then return true end
 
  
  

  return false
end

-- CALLBACKS --
local Callbacks = {}

function Callbacks.OnTick()
  -- Get current orbwalker mode
  local OrbwalkerMode = Orbwalker.GetMode()
  -- Get the right logic func
  local OrbwalkerLogic = Champion.Logic[OrbwalkerMode]
  -- Call it
  if OrbwalkerLogic then
    return OrbwalkerLogic()
  end

  return false
end

-- ENTRYPOINT --
function OnLoad()
  -- Load Menu
  Utils.LoadMenu()
  -- Register callback for func available in champion object
  for EventName, EventId in pairs(Events) do
    if Events[EventName] then
        EventManager.RegisterCallback(EventId, Callbacks[EventName])
    end
  end

  return true
end
