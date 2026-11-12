--[[
	FAB - Carregador das malhas 3D (servidor)

	As malhas (.glb) sao enviadas ao Roblox pelo GitHub Actions e viram modelos com
	MeshParts. Aqui cada modelo e carregado com o InsertService, calibrado pelas tres
	ancoras (origem, frente e cima, a 1 unidade de distancia) para ficar na escala certa
	(metros convertidos em studs) e no referencial certo, e recebe material, cor e
	transparencia lidos do nome de cada peca ("Nome@Material@RRGGBB@transparencia").

	Os modelos prontos ficam em ReplicatedStorage.FABMalhas, com o pivo na origem da
	aeronave/estrutura. Os clientes clonam de la. Se um modelo nao carregar (ainda em
	moderacao, por exemplo), os sistemas usam a construcao por partes.
]]

local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FAB = ReplicatedStorage:WaitForChild("FAB")
local MD = require(FAB:WaitForChild("MapaDados"))

local MALHAS = {}

local pasta = Instance.new("Folder")
pasta.Name = "FABMalhas"
pasta.Parent = ReplicatedStorage

local function hexParaCor(h)
	local r, g, b = tonumber(string.sub(h, 1, 2), 16), tonumber(string.sub(h, 3, 4), 16), tonumber(string.sub(h, 5, 6), 16)
	if not (r and g and b) then return nil end
	return Color3.fromRGB(r, g, b)
end

local function partesNome(nome)
	local t = {}
	for p in string.gmatch(nome, "[^@]+") do table.insert(t, p) end
	return t
end

local function preparar(nome, modelo, escalaAlvo)
	local ancoras = {}
	for _, d in ipairs(modelo:GetDescendants()) do
		if d:IsA("BasePart") then
			local base = partesNome(d.Name)[1] or d.Name
			if base == "Ancora_Origem" or base == "Ancora_Frente" or base == "Ancora_Cima" then
				ancoras[base] = d
			end
		end
	end
	local o, f, c = ancoras.Ancora_Origem, ancoras.Ancora_Frente, ancoras.Ancora_Cima
	if not (o and f and c) then
		warn("[FAB] Malha " .. nome .. " sem ancoras; ignorada")
		return nil
	end
	local unidade = (f.Position - o.Position).Magnitude
	if unidade < 1e-4 then return nil end
	-- referencial das ancoras: -Z para a frente, +Y para cima
	local frente = (f.Position - o.Position).Unit
	local cima = (c.Position - o.Position).Unit
	local cfAnc = CFrame.lookAt(o.Position, o.Position + frente, cima)
	modelo.WorldPivot = cfAnc
	modelo:PivotTo(CFrame.new())
	local fator = escalaAlvo / unidade
	if math.abs(fator - 1) > 1e-3 then
		pcall(function() modelo:ScaleTo(modelo:GetScale() * fator) end)
	end
	o:Destroy()
	f:Destroy()
	c:Destroy()
	for _, d in ipairs(modelo:GetDescendants()) do
		if d:IsA("SurfaceAppearance") or d:IsA("Decal") or d:IsA("Texture") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			local p = partesNome(d.Name)
			d.Name = p[1] or d.Name
			local mat = p[2] and Enum.Material[p[2]]
			local ok = pcall(function() if mat then d.Material = mat end end)
			if not ok then d.Material = Enum.Material.SmoothPlastic end
			local cor = p[3] and hexParaCor(p[3])
			if cor then d.Color = cor end
			if p[4] then d.Transparency = tonumber(p[4]) or 0 end
			if d:IsA("MeshPart") then pcall(function() d.TextureID = "" end) end
			d.Anchored = true
			d.CanCollide = false
			d.CanTouch = false
			d.CanQuery = false
			d.CastShadow = d.Transparency < 0.5
			d.TopSurface = Enum.SurfaceType.Smooth
			d.BottomSurface = Enum.SurfaceType.Smooth
		end
	end
	modelo:SetAttribute("Escala", escalaAlvo)
	return modelo
end

function MALHAS.Iniciar()
	local ok, ids = pcall(function() return require(FAB:WaitForChild("MalhasIds")) end)
	if not ok or type(ids) ~= "table" then return end
	for nome, id in pairs(ids) do
		task.spawn(function()
			local sucesso, conteudo = pcall(function() return InsertService:LoadAsset(id) end)
			if not sucesso or not conteudo then
				warn("[FAB] Malha " .. nome .. " (" .. tostring(id) .. ") nao carregou: " .. tostring(conteudo))
				return
			end
			local modelo = conteudo:FindFirstChildWhichIsA("Model") or conteudo
			-- metros para studs nas aeronaves e cabines; as estruturas ja vem em studs
			local escala = (string.sub(nome, 1, 9) == "Aeronave_" or string.sub(nome, 1, 4) == "Sim_") and MD.StudPorMetro or 1
			local pronto = preparar(nome, modelo, escala)
			if pronto then
				pronto.Name = nome
				pronto.Parent = pasta
			else
				modelo:Destroy()
			end
			if conteudo ~= modelo then conteudo:Destroy() end
		end)
	end
end

-- Espera um modelo por ate "tempo" segundos. Devolve nil se nao houver.
function MALHAS.Obter(nome, tempo)
	return pasta:FindFirstChild(nome) or (tempo and pasta:WaitForChild(nome, tempo))
end

return MALHAS
