--[[
	FAB - Cenario do simulador (cliente)

	O simulador voa sobre o mapa real da ilha. Este modulo cuida do que so existe
	para quem esta no simulador:
	- oceano distante alem do limite do mapa (segue a camera)
	- cores do PAPI conforme o angulo de planeio da aeronave
	- marcadores de navegacao
	- aeronaves controladas pelo computador (lider de formacao, alvo, adversario)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MD = require(ReplicatedStorage:WaitForChild("FAB"):WaitForChild("MapaDados"))

local CEN = {}

local E = MD.StudPorMetro
local BLOCO = 2048

function CEN.Criar()
	local obj = {}
	local pasta = Instance.new("Folder")
	pasta.Name = "CenarioSimulador"
	pasta.Parent = workspace
	obj.Pasta = pasta

	-- oceano distante
	local tiles = {}
	for i = 1, 49 do
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Size = Vector3.new(BLOCO, 1, BLOCO)
		p.Color = Color3.fromRGB(22, 64, 88)
		p.Material = Enum.Material.SmoothPlastic
		p.Reflectance = 0.15
		p.Transparency = 1
		p.Parent = pasta
		tiles[i] = p
	end
	local celulaAnterior

	-- PAPI das duas cabeceiras
	local papis = {}
	local aero = workspace:FindFirstChild("BaseAerea") and workspace.BaseAerea:FindFirstChild("Aerodromo")
	if aero then
		for _, n in ipairs({ "36", "18" }) do
			local f = aero:FindFirstChild("PAPI" .. n)
			if f then
				for i = 1, 4 do
					local l = f:FindFirstChild("Lente" .. i)
					if l then table.insert(papis, { Parte = l, Indice = i, Original = l.Color }) end
				end
			end
		end
	end
	local AJUSTE = { 3.5, 3.17, 2.83, 2.5 }

	function obj.Atualizar(camPos)
		-- oceano: grade 7x7 em volta da camera, so fora da area do terreno
		local cx = math.floor(camPos.X / BLOCO + 0.5)
		local cz = math.floor(camPos.Z / BLOCO + 0.5)
		local chave = cx .. ":" .. cz
		if chave ~= celulaAnterior then
			celulaAnterior = chave
			local i = 0
			for dx = -3, 3 do
				for dz = -3, 3 do
					i = i + 1
					local x, z = (cx + dx) * BLOCO, (cz + dz) * BLOCO
					local dentro = math.abs(x) + BLOCO / 2 <= MD.Limite and math.abs(z) + BLOCO / 2 <= MD.Limite
					local t = tiles[i]
					t.CFrame = CFrame.new(x, -1.2, z)
					t.Transparency = 0 -- tambem dentro do mapa: onde o terreno ainda nao carregou, aparece o mar e nao o vazio
				end
			end
		end
		-- PAPI
		for _, p in ipairs(papis) do
			local pos = p.Parte.Position
			local dh = Vector3.new(camPos.X - pos.X, 0, camPos.Z - pos.Z).Magnitude
			local ang = math.deg(math.atan2(camPos.Y - pos.Y, math.max(dh, 1)))
			local branco = ang > AJUSTE[p.Indice]
			p.Parte.Color = branco and Color3.fromRGB(255, 255, 245) or Color3.fromRGB(255, 30, 20)
		end
	end

	-- Marcador de navegacao (coluna de luz). pos em studs.
	function obj.Marcador(pos, cor)
		local m = Instance.new("Model")
		m.Name = "Marcador"
		local coluna = Instance.new("Part")
		coluna.Anchored = true
		coluna.CanCollide = false
		coluna.CanQuery = false
		coluna.CastShadow = false
		coluna.Material = Enum.Material.Neon
		coluna.Color = cor or Color3.fromRGB(255, 80, 200)
		coluna.Transparency = 0.35
		coluna.Shape = Enum.PartType.Cylinder
		coluna.Size = Vector3.new(4000, 40, 40)
		coluna.CFrame = CFrame.new(pos + Vector3.new(0, 2000, 0)) * CFrame.Angles(0, 0, math.rad(90))
		coluna.Parent = m
		m.Parent = pasta
		return m
	end

	-- Aeronave controlada pelo computador (pecas simples em escala real)
	function obj.Aeronave(tipo, cor)
		local m = Instance.new("Model")
		m.Name = "Aeronave_" .. tipo
		local raiz = Instance.new("Part")
		raiz.Name = "Raiz"
		raiz.Anchored = true
		raiz.CanCollide = false
		raiz.CanQuery = false
		raiz.Transparency = 1
		raiz.Size = Vector3.new(1, 1, 1)
		raiz.Parent = m
		m.PrimaryPart = raiz
		local corpo = cor or Color3.fromRGB(140, 146, 150)
		local function peca(tam, cf, c, mat, forma)
			local p = Instance.new("Part")
			p.Anchored = false
			p.CanCollide = false
			p.CanQuery = false
			p.Massless = true
			p.Size = tam * E
			p.CFrame = raiz.CFrame * CFrame.new(cf.Position * E) * (cf - cf.Position)
			p.Color = c or corpo
			p.Material = mat or Enum.Material.Metal
			if forma then p.Shape = forma end
			local w = Instance.new("WeldConstraint")
			w.Part0 = raiz
			w.Part1 = p
			w.Parent = p
			p.Parent = m
			return p
		end
		local jato = tipo ~= "A29"
		local comp = jato and 14 or 11
		peca(Vector3.new(comp, 1.4, 1.4), CFrame.Angles(0, math.rad(90), 0), nil, nil, Enum.PartType.Cylinder)
		peca(Vector3.new(1.3, 1.3, 1.3), CFrame.new(0, 0, -comp / 2), Color3.fromRGB(70, 70, 70), nil, Enum.PartType.Ball)
		peca(Vector3.new(jato and 8.5 or 11, 0.15, jato and 3 or 1.8), CFrame.new(0, jato and 0 or -0.4, jato and 1 or 0), nil)
		peca(Vector3.new(3.4, 0.12, 1.2), CFrame.new(0, 0.2, comp / 2 - 0.8), nil)
		peca(Vector3.new(0.15, 2, 1.6), CFrame.new(0, 1.1, comp / 2 - 1), nil)
		peca(Vector3.new(0.8, 0.5, 1.6), CFrame.new(0, 0.7, -comp / 2 + 3.5), Color3.fromRGB(30, 40, 50), Enum.Material.Glass)
		local luz = peca(Vector3.new(0.3, 0.3, 0.3), CFrame.new(0, -0.7, 0), Color3.fromRGB(255, 40, 30), Enum.Material.Neon)
		local pl = Instance.new("PointLight")
		pl.Color = Color3.fromRGB(255, 60, 40)
		pl.Range = 30
		pl.Brightness = 3
		pl.Parent = luz
		if tipo == "Alvo" then
			-- faixas laranja de alta visibilidade
			peca(Vector3.new(1.5, 0.16, 3.1), CFrame.new(-3.5, 0, 1), Color3.fromRGB(255, 120, 20), Enum.Material.SmoothPlastic)
			peca(Vector3.new(1.5, 0.16, 3.1), CFrame.new(3.5, 0, 1), Color3.fromRGB(255, 120, 20), Enum.Material.SmoothPlastic)
		end
		m.Parent = pasta
		return m
	end

	function obj.Destruir()
		for _, p in ipairs(papis) do
			if p.Parte.Parent then p.Parte.Color = p.Original end
		end
		pasta:Destroy()
	end

	return obj
end

-- Piloto automatico simples para as aeronaves do computador (em metros)
function CEN.NovoVoo(x, y, z, rumo, velocidade)
	return { X = x, Y = y, Z = z, Rumo = rumo, V = velocidade, Inclinacao = 0, Arfagem = 0, VS = 0 }
end

function CEN.Voar(v, dt, inclinacaoAlvo, vsAlvo, velAlvo)
	v.Inclinacao = v.Inclinacao + math.clamp((inclinacaoAlvo or 0) - v.Inclinacao, -45 * dt, 45 * dt)
	v.VS = v.VS + math.clamp((vsAlvo or 0) - v.VS, -10 * dt, 10 * dt)
	if velAlvo then v.V = v.V + math.clamp(velAlvo - v.V, -8 * dt, 8 * dt) end
	local taxa = 9.81 * math.tan(math.rad(v.Inclinacao)) / math.max(v.V, 30)
	v.Rumo = (v.Rumo + math.deg(taxa) * dt) % 360
	local vh = math.sqrt(math.max(v.V * v.V - v.VS * v.VS, 1))
	local r = math.rad(v.Rumo)
	v.X = v.X + math.sin(r) * vh * dt
	v.Z = v.Z - math.cos(r) * vh * dt
	v.Y = v.Y + v.VS * dt
	v.Arfagem = math.deg(math.asin(math.clamp(v.VS / v.V, -1, 1)))
end

function CEN.CFrameVoo(v)
	local pos = Vector3.new(v.X * E, v.Y * E, v.Z * E)
	return CFrame.new(pos) * CFrame.Angles(0, -math.rad(v.Rumo), 0) * CFrame.Angles(math.rad(v.Arfagem), 0, 0) * CFrame.Angles(0, 0, -math.rad(v.Inclinacao))
end

return CEN
