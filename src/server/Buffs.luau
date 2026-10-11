local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Config = require(game.ReplicatedStorage.Shared.Config)

-- Expiration uses monotonic server time. Only the display timestamp is sent to
-- clients; a client can never extend or select the strength of a buff.
local Buffs = {}
local active = {}
local callbacks = {}
local connections = {}
local random = Random.new()

local function changed(player)
 if callbacks.OnChanged then callbacks.OnChanged(player) end
end

local function stateFor(buff, now)
 local remaining = math.max(0, buff.Deadline - now)
 if remaining <= 0 then return nil end
 local state = {Remaining=remaining, ExpiresAt=buff.ExpiresAt}
 if buff.Multiplier then state.Multiplier = buff.Multiplier end
 if buff.Tiers then state.Tiers = buff.Tiers end
 if buff.Scale then state.Scale = buff.Scale end
 return state
end

function Buffs.GetState(player)
 local result = {}
 local now = os.clock()
 for kind, buff in pairs(active[player] or {}) do
  local state = stateFor(buff, now)
  if state then result[kind] = state end
 end
 return result
end

function Buffs.GetModifiers(player)
 local state = Buffs.GetState(player)
 return {
  Speed=state.Speed and state.Speed.Multiplier or 1,
  Scale=state.Giant and state.Giant.Scale or 1,
  HuntBonus=state.Hunt and state.Hunt.Tiers or 0,
 }
end

function Buffs.Apply(player, kind)
 if kind ~= "Speed" and kind ~= "Hunt" and kind ~= "Giant" then return nil end
 if not player or player.Parent ~= Players then return nil end
 local definition = Config.Buffs
 local duration = definition.Duration
 local buff = {Deadline=os.clock()+duration, ExpiresAt=workspace:GetServerTimeNow()+duration}
 if kind == "Speed" then buff.Multiplier = definition.SpeedMultiplier
 elseif kind == "Hunt" then buff.Tiers = random:NextInteger(definition.HuntMin, definition.HuntMax)
 elseif kind == "Giant" then buff.Scale = definition.GiantScale end
 local previous = active[player] or {}
 previous[kind] = buff
 active[player] = previous
 changed(player)
 return stateFor(buff, os.clock())
end

function Buffs.Start(newCallbacks)
 callbacks = newCallbacks or {}
 for _, connection in ipairs(connections) do connection:Disconnect() end
 table.clear(connections)
 local elapsed = 0
 table.insert(connections, RunService.Heartbeat:Connect(function(dt)
  elapsed += dt
  if elapsed < 0.1 then return end
  elapsed = 0
  local now = os.clock()
  for player, states in pairs(active) do
   local expired = false
   for kind, buff in pairs(states) do
    if buff.Deadline <= now then states[kind] = nil; expired = true end
   end
   if next(states) == nil then active[player] = nil end
   if expired then changed(player) end
  end
 end))
 table.insert(connections, Players.PlayerRemoving:Connect(function(player)
  active[player] = nil
 end))
end

return Buffs
