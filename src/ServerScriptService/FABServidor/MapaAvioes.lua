--[[
	FAB - Aeronaves estacionadas no patio (ModuleScript)
	Usa as malhas reais (FABMalhas.Aeronave_*) quando carregadas; espera ate 60 s.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local FAB = ReplicatedStorage:WaitForChild("FAB")
local MD = require(FAB:WaitForChild("MapaDados"))
local Aeronaves = require(FAB:WaitForChild("Aeronaves"))
local Malhas = require(script.Parent:WaitForChild("Malhas"))

local AV = {}

local fila = {
	{ "F39", 1500 }, { "F39", 1250 }, { "F39", 1000 }, { "F5", 760 }, { "F5", 520 }, { "F5", 280 },
	{ "A29", 20 }, { "A29", -220 }, { "A29", -460 }, { "T27", -700 }, { "T27", -900 }, { "T27", -1100 },
	{ "T25", -1300 }, { "T25", -1450 }, { "T25", -1600 },
}

function AV.Construir(N, Mapa, raiz)
	local pasta = Mapa.Pasta("AeronavesPatio", raiz)
	local E = MD.StudPorMetro
	for i, item in ipairs(fila) do
		task.spawn(function()
			local id, z = item[1], item[2]
			local fonte = Malhas.Obter("Aeronave_" .. id, 60)
			local perfil = Aeronaves[id]
			if not fonte or not perfil then return end
			local m = fonte:Clone()
			for _, p in ipairs(m:GetDescendants()) do
				if p:IsA("BasePart") then p.Anchored = true; p.CanCollide = false end
			end
			local x = 1260 + ((i % 2) * 60)
			m:PivotTo(CFrame.new(x, MD.Plato + perfil.AlturaTrem * E, z) * CFrame.Angles(0, math.rad(90), 0))
			m.Parent = pasta
			-- colisao simples
			local c = Instance.new("Part")
			c.Name = "Colisao"; c.Anchored = true; c.Transparency = 1
			c.Size = Vector3.new(34 * E / 3, 6 * E / 3, 12 * E / 3)
			c.CFrame = CFrame.new(x, MD.Plato + 4, z)
			c.Parent = m
		end)
	end
end

return AV
