--[[
	FAB - Vegetacao com malhas (ModuleScript)
	Arvores reais (FABMalhas.Arvore_*) em bosques e alamedas; some se as malhas nao existirem.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local FAB = ReplicatedStorage:WaitForChild("FAB")
local MD = require(FAB:WaitForChild("MapaDados"))
local Malhas = require(script.Parent:WaitForChild("Malhas"))

local VG = {}
local nomes = { "Arvore_Frondosa", "Arvore_Frondosa2", "Arvore_Palmeira" }

local function livre(x, z)
	if math.abs(x) < 520 then return false end -- pista e acostamento
	if x > 560 and x < 2000 and math.abs(z) < 2300 then return false end -- taxi, patio, hangares
	if x > 900 and x < 2000 and z < -3700 and z > -4700 then return false end -- HAS
	if x > 2000 and x < 4800 and z > -2900 and z < 4000 then return false end -- ensino, vila
	return true
end

function VG.Construir(N, Mapa, raiz)
	local pasta = Mapa.Pasta("ArvoresMalha", raiz)
	task.spawn(function()
		local modelos = {}
		for _, n in ipairs(nomes) do
			local m = Malhas.Obter(n, 60)
			if m then table.insert(modelos, m) end
		end
		if #modelos == 0 then return end
		local rng = Random.new(1234)
		local cont = 0
		local function plantar(x, z)
			local m = modelos[rng:NextInteger(1, #modelos)]:Clone()
			for _, p in ipairs(m:GetDescendants()) do
				if p:IsA("BasePart") then p.Anchored = true; p.CanCollide = false end
			end
			local y = MD.Altura and MD.Altura(x, z) or MD.Plato
			m:PivotTo(CFrame.new(x, y, z) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0))
			m.Parent = pasta
			cont = cont + 1
			if cont % 25 == 0 then task.wait() end
		end
		-- bosques
		for _ = 1, 700 do
			local x, z = rng:NextNumber(-4500, 6200), rng:NextNumber(-9500, 9500)
			if livre(x, z) and math.abs(x - 600) > 80 then plantar(x, z) end
		end
		-- alameda da avenida da vila e do acesso
		for z = 1960, 3720, 70 do plantar(2830, z); plantar(2890, z); plantar(4230, z); plantar(4290, z) end
	end)
end

return VG
