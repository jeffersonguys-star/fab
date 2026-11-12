--[[
	FAB - Mapa (ModuleScript)

	Monta o mundo inteiro por codigo (o place e gerado a partir do repositorio):
	- oceano e ilha em terreno (plato, praias e serras), conforme MapaDados
	- iluminacao realista
	- base aerea (MapaAerodromo) e area de ensino (MapaEnsino)

	Tambem oferece as ferramentas de construcao usadas pelos dois modulos:
	placas, predios, arvores, bandeiras e vias.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local FAB = ReplicatedStorage:WaitForChild("FAB")
local C = require(FAB:WaitForChild("Construtor"))
local MD = require(FAB:WaitForChild("MapaDados"))

local Mapa = {}

local BRANCO = Color3.fromRGB(236, 233, 224)
local AZUL = Color3.fromRGB(24, 52, 110)
local CINZA = Color3.fromRGB(92, 94, 98)
local ASFALTO = Color3.fromRGB(48, 48, 50)

Mapa.Cores = { Branco = BRANCO, Azul = AZUL, Cinza = CINZA, Asfalto = ASFALTO, Concreto = Color3.fromRGB(170, 168, 160) }
Mapa.Y = MD.Plato

local function pasta(nome, pai)
	local f = Instance.new("Folder")
	f.Name = nome
	f.Parent = pai
	return f
end
Mapa.Pasta = pasta

-- Placa com titulo e subtitulo (estilo preto e branco). Le-se do lado +Z local.
function Mapa.Placa(pai, nome, cf, titulo, subtitulo)
	local m = pasta(nome, pai)
	C.Tubo(m, "Poste", (cf * CFrame.new(-2.2, 0, 0)).Position, (cf * CFrame.new(-2.2, 6, 0)).Position, 0.3, CINZA, Enum.Material.Metal)
	C.Tubo(m, "Poste", (cf * CFrame.new(2.2, 0, 0)).Position, (cf * CFrame.new(2.2, 6, 0)).Position, 0.3, CINZA, Enum.Material.Metal)
	local quadro = C.Parte(m, "Quadro", Vector3.new(5.4, 2.8, 0.25), cf * CFrame.new(0, 5.2, 0), Color3.fromRGB(12, 12, 12), Enum.Material.SmoothPlastic)
	local g = C.Tela(quadro, Enum.NormalId.Back, 60)
	local f = Instance.new("Frame")
	f.Size = UDim2.fromScale(1, 1)
	f.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
	f.BorderSizePixel = 0
	f.Parent = g
	local linha = Instance.new("Frame")
	linha.Size = UDim2.new(0.86, 0, 0, 3)
	linha.Position = UDim2.fromScale(0.07, 0.56)
	linha.BackgroundColor3 = Color3.new(1, 1, 1)
	linha.BorderSizePixel = 0
	linha.Parent = f
	C.Texto(f, string.upper(titulo), { Size = UDim2.fromScale(0.86, 0.36), Position = UDim2.fromScale(0.07, 0.14), TextXAlignment = Enum.TextXAlignment.Left })
	C.Texto(f, subtitulo or "", { Size = UDim2.fromScale(0.86, 0.2), Position = UDim2.fromScale(0.07, 0.66), Font = Enum.Font.Gotham,
		TextColor3 = Color3.fromRGB(190, 190, 190), TextXAlignment = Enum.TextXAlignment.Left })
	return quadro
end

-- Arvore (tronco e copa em camadas)
function Mapa.Arvore(pai, pos, escala, simples)
	escala = escala or 1
	local tronco = C.Cilindro(pai, "Tronco", 1.2 * escala, 9 * escala, CFrame.new(pos + Vector3.new(0, 4.5 * escala, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(92, 66, 44), Enum.Material.Wood)
	local verde = Color3.fromRGB(48 + math.random(0, 25), 88 + math.random(0, 30), 40 + math.random(0, 15))
	C.Esfera(pai, "Copa", 9 * escala, CFrame.new(pos + Vector3.new(0, 10 * escala, 0)), verde, Enum.Material.Grass, { CanCollide = false })
	if not simples then
		C.Esfera(pai, "Copa", 7 * escala, CFrame.new(pos + Vector3.new(1.8 * escala, 12.5 * escala, 1 * escala)), verde, Enum.Material.Grass, { CanCollide = false })
	end
	return tronco
end

-- Predio com janelas, porta na frente (-Z local), laje e luzes internas
function Mapa.Predio(pai, nome, cf, largura, profundidade, altura, comPorta, corParede)
	local m = Instance.new("Model")
	m.Name = nome
	m.Parent = pai
	local parede = corParede or BRANCO
	local esp = 1
	C.Parte(m, "Piso", Vector3.new(largura, 1, profundidade), cf * CFrame.new(0, 0.5, 0), Color3.fromRGB(200, 198, 192), Enum.Material.Marble)
	local function lado(nomeP, comp, cfP, porta)
		local baixo, vidro = 4, 5
		local cima = altura - baixo - vidro
		local function faixa(y, h, cor, mat, transp)
			if porta and y < 10 then
				local larguraPorta = 10
				local lateral = (comp - larguraPorta) / 2
				C.Parte(m, nomeP, Vector3.new(lateral, h, esp), cfP * CFrame.new(-(larguraPorta / 2 + lateral / 2), y + h / 2, 0), cor, mat, { Transparency = transp or 0 })
				C.Parte(m, nomeP, Vector3.new(lateral, h, esp), cfP * CFrame.new((larguraPorta / 2 + lateral / 2), y + h / 2, 0), cor, mat, { Transparency = transp or 0 })
				return
			end
			C.Parte(m, nomeP, Vector3.new(comp, h, esp), cfP * CFrame.new(0, y + h / 2, 0), cor, mat, { Transparency = transp or 0 })
		end
		faixa(1, baixo, parede, Enum.Material.Concrete)
		faixa(1 + baixo, vidro, Color3.fromRGB(120, 150, 170), Enum.Material.Glass, 0.45)
		faixa(1 + baixo + vidro, cima, parede, Enum.Material.Concrete)
		C.Parte(m, "FaixaAzul", Vector3.new(comp + 0.2, 0.8, esp + 0.2), cfP * CFrame.new(0, altura - 1.5, 0), AZUL, Enum.Material.SmoothPlastic)
		C.Parte(m, "Pilar", Vector3.new(1.4, altura, 1.4), cfP * CFrame.new(comp / 2, altura / 2 + 1, 0), parede, Enum.Material.Concrete)
	end
	lado("ParedeFrente", largura, cf * CFrame.new(0, 0, -profundidade / 2), comPorta)
	lado("ParedeFundo", largura, cf * CFrame.new(0, 0, profundidade / 2) * CFrame.Angles(0, math.rad(180), 0), false)
	lado("ParedeEsquerda", profundidade, cf * CFrame.new(-largura / 2, 0, 0) * CFrame.Angles(0, math.rad(90), 0), false)
	lado("ParedeDireita", profundidade, cf * CFrame.new(largura / 2, 0, 0) * CFrame.Angles(0, math.rad(-90), 0), false)
	if comPorta then
		C.Parte(m, "Verga", Vector3.new(10, altura - 10, esp), cf * CFrame.new(0, 10 + (altura - 10) / 2 + 0.5, -profundidade / 2), parede, Enum.Material.Concrete)
		C.Parte(m, "Marquise", Vector3.new(16, 0.6, 6), cf * CFrame.new(0, 11, -profundidade / 2 - 3), parede, Enum.Material.Concrete)
		local lm = C.Parte(m, "LuzMarquise", Vector3.new(4, 0.2, 1), cf * CFrame.new(0, 10.6, -profundidade / 2 - 3), Color3.new(1, 1, 1), Enum.Material.Neon)
		C.Luz(lm, "SpotLight", { Face = Enum.NormalId.Bottom, Range = 18, Brightness = 2, Angle = 110 })
		C.Parte(m, "Calcada", Vector3.new(20, 0.6, 10), cf * CFrame.new(0, 0.3, -profundidade / 2 - 5), Color3.fromRGB(190, 188, 180), Enum.Material.Concrete)
	end
	local laje = C.Parte(m, "Laje", Vector3.new(largura + 2, 1, profundidade + 2), cf * CFrame.new(0, altura + 1.5, 0), Color3.fromRGB(210, 208, 200), Enum.Material.Concrete)
	C.Parte(m, "Platibanda", Vector3.new(largura + 2, 1.6, 0.6), cf * CFrame.new(0, altura + 2.8, -profundidade / 2 - 0.7), parede, Enum.Material.Concrete)
	for x = -largura / 2 + 8, largura / 2 - 8, 14 do
		for z = -profundidade / 2 + 8, profundidade / 2 - 8, 14 do
			local l = C.Parte(m, "Luminaria", Vector3.new(6, 0.2, 1.4), cf * CFrame.new(x, altura + 0.85, z), Color3.fromRGB(255, 255, 250), Enum.Material.Neon)
			C.Luz(l, "SurfaceLight", { Face = Enum.NormalId.Bottom, Range = 16, Brightness = 1.4, Angle = 120 })
		end
	end
	C.Parte(m, "CondensadoraAr", Vector3.new(4, 3, 3), cf * CFrame.new(largura / 4, altura + 3.5, profundidade / 5), Color3.fromRGB(200, 200, 200), Enum.Material.Metal)
	C.Cilindro(m, "CaixaDagua", 5, 5, cf * CFrame.new(-largura / 4, altura + 4.5, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(80, 110, 160), Enum.Material.Plastic)
	return m, laje
end

-- Bandeira do Brasil feita de pecas (sobre mastro)
function Mapa.Bandeira(pai, cf, altura)
	altura = altura or 32
	local m = pasta("Bandeira", pai)
	C.Tubo(m, "Mastro", cf.Position, (cf * CFrame.new(0, altura, 0)).Position, 0.6, Color3.fromRGB(220, 220, 220), Enum.Material.Metal)
	C.Esfera(m, "Topo", 1, cf * CFrame.new(0, altura + 0.3, 0), Color3.fromRGB(230, 190, 60), Enum.Material.Metal)
	local base = cf * CFrame.new(5.6, altura - 4, 0)
	C.Parte(m, "Verde", Vector3.new(10, 7, 0.1), base, Color3.fromRGB(0, 151, 57), Enum.Material.Fabric, { CanCollide = false })
	local amarelo = Color3.fromRGB(254, 221, 0)
	local w, h = 4.2, 2.8
	for _, s in ipairs({ { 1, 1 }, { -1, 1 }, { 1, -1 }, { -1, -1 } }) do
		local sx, sy = s[1], s[2]
		local cw = base * CFrame.new(sx * w / 2, sy * h / 2, 0) * CFrame.Angles(0, sx > 0 and math.rad(-90) or math.rad(90), 0)
		if sy < 0 then cw = cw * CFrame.Angles(0, 0, math.rad(180)) end
		C.Cunha(m, "Losango", Vector3.new(0.12, h, w), cw, amarelo, Enum.Material.Fabric, { CanCollide = false })
	end
	C.Cilindro(m, "Globo", 3.4, 0.16, base * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(0, 39, 118), Enum.Material.Fabric, { CanCollide = false })
	C.Parte(m, "Faixa", Vector3.new(3.5, 0.35, 0.18), base * CFrame.Angles(0, 0, math.rad(-12)), Color3.new(1, 1, 1), Enum.Material.Fabric, { CanCollide = false })
	return m
end

-- Via de asfalto com faixa central e meio-fio
function Mapa.Via(pai, a, b, largura, semFaixa)
	local meio = (a + b) / 2
	local comp = (b - a).Magnitude
	local cf = CFrame.lookAt(meio + Vector3.new(0, 0.1, 0), b + Vector3.new(0, 0.1, 0))
	local p = C.Parte(pai, "Via", Vector3.new(largura, 0.2, comp), cf, ASFALTO, Enum.Material.Asphalt)
	C.Parte(pai, "MeioFio", Vector3.new(0.6, 0.5, comp), cf * CFrame.new(largura / 2 + 0.3, 0.15, 0), Color3.fromRGB(180, 180, 175), Enum.Material.Concrete)
	C.Parte(pai, "MeioFio", Vector3.new(0.6, 0.5, comp), cf * CFrame.new(-largura / 2 - 0.3, 0.15, 0), Color3.fromRGB(180, 180, 175), Enum.Material.Concrete)
	if not semFaixa then
		for d = -comp / 2 + 4, comp / 2 - 4, 12 do
			C.Parte(pai, "Faixa", Vector3.new(0.35, 0.05, 5), cf * CFrame.new(0, 0.12, d), Color3.fromRGB(240, 240, 240), Enum.Material.SmoothPlastic, { CanCollide = false })
		end
	end
	return p
end

local function iluminacao()
	Lighting.ClockTime = 13.5
	Lighting.Brightness = 2.6
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 1
	Lighting.GlobalShadows = true
	Lighting.OutdoorAmbient = Color3.fromRGB(128, 128, 132)
	Lighting.GeographicLatitude = -16
	pcall(function() Lighting.Technology = Enum.Technology.Future end)
	if not Lighting:FindFirstChildOfClass("Atmosphere") then
		local a = Instance.new("Atmosphere")
		a.Density = 0.3
		a.Offset = 0.15
		a.Color = Color3.fromRGB(199, 214, 230)
		a.Decay = Color3.fromRGB(110, 130, 160)
		a.Glare = 0.25
		a.Haze = 1.4
		a.Parent = Lighting
	end
	if not Lighting:FindFirstChildOfClass("Sky") then
		local s = Instance.new("Sky")
		s.SunAngularSize = 14
		s.Parent = Lighting
	end
	if not workspace.Terrain:FindFirstChildOfClass("Clouds") then
		local n = Instance.new("Clouds")
		n.Cover = 0.45
		n.Density = 0.6
		n.Color = Color3.fromRGB(246, 247, 250)
		n.Parent = workspace.Terrain
	end
	if not Lighting:FindFirstChildOfClass("ColorCorrectionEffect") then
		local cc = Instance.new("ColorCorrectionEffect")
		cc.Saturation = 0.08
		cc.Contrast = 0.1
		cc.TintColor = Color3.fromRGB(255, 250, 240)
		cc.Parent = Lighting
	end
	Lighting.ColorShift_Top = Color3.fromRGB(255, 240, 215)
	if not Lighting:FindFirstChildOfClass("BloomEffect") then
		local b = Instance.new("BloomEffect")
		b.Intensity = 0.4
		b.Size = 24
		b.Threshold = 1.6
		b.Parent = Lighting
	end
	if not Lighting:FindFirstChildOfClass("SunRaysEffect") then
		local r = Instance.new("SunRaysEffect")
		r.Intensity = 0.05
		r.Parent = Lighting
	end
	local T = workspace.Terrain
	T.WaterWaveSize = 0.18
	T.WaterWaveSpeed = 12
	T.WaterReflectance = 0.6
	T.WaterTransparency = 0.35
	T.WaterColor = Color3.fromRGB(20, 70, 95)
end

-- Faixas das praias (cunhas de areia dos dois lados de uma faixa de 16 studs)
local function praias(T, zc, passo)
	local esq, dir = MD.Borda(zc)
	if dir - esq <= 1 then return false end
	local larg = MD.LarguraPraia
	local alt = MD.Plato + MD.ProfundidadeMar
	T:FillWedge(CFrame.new(dir + larg / 2, MD.Plato - alt / 2, zc) * CFrame.Angles(0, math.rad(-90), 0),
		Vector3.new(passo, alt, larg), Enum.Material.Sand)
	T:FillWedge(CFrame.new(esq - larg / 2, MD.Plato - alt / 2, zc) * CFrame.Angles(0, math.rad(90), 0),
		Vector3.new(passo, alt, larg), Enum.Material.Sand)
	return true, esq, dir
end

local function pontas(T)
	local larg = MD.LarguraPraia
	local alt = MD.Plato + MD.ProfundidadeMar
	for _, sinal in ipairs({ -1, 1 }) do
		local zc = sinal * (MD.Ilha.RaioZ + larg / 2 - 16)
		T:FillWedge(CFrame.new(0, MD.Plato - alt / 2, zc) * CFrame.Angles(0, sinal > 0 and math.rad(180) or 0, 0),
			Vector3.new(700, alt, larg), Enum.Material.Sand)
	end
end

-- Terreno: ilha (plato, praias, serras) e oceano. Gerado aos poucos para nao travar.
local function gerarTerreno()
	local T = workspace.Terrain
	pcall(function()
		T:SetMaterialColor(Enum.Material.Grass, Color3.fromRGB(96, 124, 62))
		T:SetMaterialColor(Enum.Material.LeafyGrass, Color3.fromRGB(70, 104, 54))
		T:SetMaterialColor(Enum.Material.Ground, Color3.fromRGB(122, 100, 72))
		T:SetMaterialColor(Enum.Material.Mud, Color3.fromRGB(96, 78, 58))
		T:SetMaterialColor(Enum.Material.Sand, Color3.fromRGB(205, 190, 150))
		T:SetMaterialColor(Enum.Material.Rock, Color3.fromRGB(110, 108, 102))
		T:SetMaterialColor(Enum.Material.Water, Color3.fromRGB(34, 96, 120))
	end)
	T.WaterColor = Color3.fromRGB(34, 96, 120)
	T.WaterTransparency = 0.55
	T.WaterWaveSize = 0.35
	T.WaterWaveSpeed = 12
	T.WaterReflectance = 0.6
	local L = MD.Limite
	local prof = MD.ProfundidadeMar
	local passo = 16
	local cont = 0
	-- 1. oceano em blocos (exceto o miolo da ilha)
	local bloco = 2048
	for x = -L, L - 1, bloco do
		for z = -L, L - 1, bloco do
			local cx, cz = x + bloco / 2, z + bloco / 2
			local miolo = math.abs(cx) + bloco / 2 < MD.Ilha.RaioX * 0.55 and math.abs(cz) + bloco / 2 < MD.Ilha.RaioZ * 0.55
			if not miolo then
				T:FillBlock(CFrame.new(cx, -prof / 2, cz), Vector3.new(bloco, prof, bloco), Enum.Material.Water)
			end
			task.wait()
		end
	end
	-- 2. plato e praias (sobrescrevem a agua)
	for z = -MD.Ilha.RaioZ, MD.Ilha.RaioZ, passo do
		local zc = z + passo / 2
		local ok, esq, dir = praias(T, zc, passo)
		if ok then
			T:FillBlock(CFrame.new((esq + dir) / 2, MD.Plato - 8, zc), Vector3.new(dir - esq, 16, passo), Enum.Material.Grass)
		end
		cont = cont + 1
		if cont % 40 == 0 then task.wait() end
	end
	pontas(T)
	-- 3. serras: discos empilhados seguindo h(d) = H (1 - d/R)^2
	for _, m in ipairs(MD.Morros) do
		local y = 0
		while y < m.H do
			local r = m.R * (1 - math.sqrt(y / m.H))
			if r < 8 then break end
			local material = Enum.Material.Grass
			if y > m.H * 0.7 then material = Enum.Material.Rock
			elseif y > m.H * 0.45 then material = Enum.Material.LeafyGrass end
			T:FillCylinder(CFrame.new(m.X, MD.Plato + y + 4, m.Z), 8, r, material)
			y = y + 8
			cont = cont + 1
			if cont % 20 == 0 then task.wait() end
		end
	end
	-- 4. manchas de terra e mato alto no gramado (fora da base), para quebrar a cor uniforme
	local rng = Random.new(2024)
	for _ = 1, 260 do
		local x, z = rng:NextNumber(-4500, 6000), rng:NextNumber(-9500, 9500)
		local dentro = math.abs(x) < 520
			or (x > 560 and x < 2100 and math.abs(z) < 2300)
			or (x > 900 and x < 2000 and z < -3700 and z > -4700)
			or (x > 2000 and x < 4800 and z > -2900 and z < 4000)
		if not dentro and math.abs(x) < MD.Ilha.RaioX * 0.9 and math.abs(z) < MD.Ilha.RaioZ * 0.9 then
			local mat = (rng:NextInteger(1, 3) == 1) and Enum.Material.Ground or ((rng:NextInteger(1, 2) == 1) and Enum.Material.LeafyGrass or Enum.Material.Mud)
			pcall(function()
				T:FillBlock(CFrame.new(x, MD.Plato - 1, z) * CFrame.Angles(0, rng:NextNumber(0, 3.14), 0),
					Vector3.new(rng:NextNumber(40, 160), 4, rng:NextNumber(40, 160)), mat)
			end)
		end
		if _ % 20 == 0 then task.wait() end
	end
	workspace:SetAttribute("TerrenoPronto", true)
end

function Mapa.Construir(N)
	local raiz = pasta("BaseAerea", workspace)
	Mapa.Raiz = raiz
	iluminacao()
	N.Placas = N.Placas or {}
	require(script.Parent:WaitForChild("MapaEnsino")).Construir(N, Mapa, raiz)
	require(script.Parent:WaitForChild("MapaAerodromo")).Construir(N, Mapa, raiz)
	for _, nome in ipairs({ "MapaVila", "MapaVeiculos", "MapaAvioes", "MapaVegetacao" }) do
		local ok, err = pcall(function()
			require(script.Parent:WaitForChild(nome)).Construir(N, Mapa, raiz)
		end)
		if not ok then warn("[FAB] " .. nome .. ": " .. tostring(err)) end
	end
	task.spawn(gerarTerreno)
end

return Mapa
