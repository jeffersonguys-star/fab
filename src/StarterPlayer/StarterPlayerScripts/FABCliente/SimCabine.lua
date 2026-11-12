--[[
	FAB - Cabine 3D do simulador (cliente)

	A geometria vem da malha "Sim_<aeronave>" (ReplicatedStorage.FABMalhas): exterior
	completo (fuselagem, asas, nariz, helice, trem e canopi) e uma cabine detalhada com
	assento ejetavel, cintos, consoles cheios de placas e comandos, painel com molduras
	de MFD ou aros de instrumentos, para-sol, HUD, manche, manete, pedais e espelhos.

	Por cima da malha este modulo monta as partes vivas, nas posicoes de CabineLayout:
	telas com aviônica real (SimAvionica), instrumentos analogicos, interruptores que
	funcionam, alavanca do trem com as 3 luzes, alavanca do flape, luzes de alerta,
	vidro combinador do HUD e a prancheta de joelho (escolha de missao).

	Se a malha ainda nao estiver disponivel, monta uma cabine simplificada por partes.
	Tudo e soldado a uma raiz ancorada; o simulador so move a raiz.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local FAB = ReplicatedStorage:WaitForChild("FAB")
local MD = require(FAB:WaitForChild("MapaDados"))
local LAYOUT = require(FAB:WaitForChild("CabineLayout"))
local AV = require(script.Parent:WaitForChild("SimAvionica"))

local CAB = {}

local E = MD.StudPorMetro
local GRAFITE = Color3.fromRGB(44, 46, 50)
local PRETO = Color3.fromRGB(14, 14, 15)

local function cfItem(it, dx, dy, dz)
	local p, r = it.P, it.R or { 0, 0, 0 }
	return CFrame.new(p[1] * E, p[2] * E, p[3] * E) * CFrame.Angles(math.rad(r[1]), math.rad(r[2]), math.rad(r[3]))
		* CFrame.new((dx or 0) * E, (dy or 0) * E, (dz or 0) * E)
end

local function parte(pai, nome, tamM, cf, cor, mat, extra)
	local p = Instance.new("Part")
	p.Name = nome
	p.Size = tamM * E
	p.CFrame = cf
	p.Color = cor or GRAFITE
	p.Material = mat or Enum.Material.SmoothPlastic
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if extra then for k, v in pairs(extra) do p[k] = v end end
	p.Parent = pai
	return p
end

local function superficie(adorno, face, canvas, nome)
	local g = Instance.new("SurfaceGui")
	g.Name = nome or "Tela"
	g.Face = face
	g.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	g.CanvasSize = canvas
	g.LightInfluence = 0
	g.Brightness = 1.6
	g.ZOffset = 1
	g.ResetOnSpawn = false
	g.Adornee = adorno
	g.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	return g
end

-- Cabine simplificada por partes (enquanto a malha nao carrega)
local function construirSimples(modelo, P, lay)
	local ox, oy, oz = lay.Olho[1], lay.Olho[2], lay.Olho[3]
	local function L(x, y, z) return CFrame.new(x * E, y * E, z * E) end
	local larg = (P.Assentos == "lado") and 1.2 or 0.82
	local piso = oy - 1.42
	local cx = (P.Assentos == "lado") and 0 or ox
	parte(modelo, "Piso", Vector3.new(larg, 0.03, 1.9), L(cx, piso, oz), GRAFITE, Enum.Material.DiamondPlate)
	for _, s in ipairs({ -1, 1 }) do
		parte(modelo, "Parede", Vector3.new(0.03, 1.0, 1.9), L(cx + s * larg / 2, piso + 0.5, oz), GRAFITE, Enum.Material.Metal)
		parte(modelo, "Console", Vector3.new(0.17, 0.78, 0.95), L(cx + s * (larg / 2 - 0.1), piso + 0.39, oz), Color3.fromRGB(48, 51, 55), Enum.Material.Metal)
	end
	parte(modelo, "Painel", Vector3.new(larg * 0.9, 0.46, 0.04), L(cx, oy - 0.47, oz - 0.71) * CFrame.Angles(math.rad(-10), 0, 0), GRAFITE)
	parte(modelo, "ParaSol", Vector3.new(larg * 0.95, 0.06, 0.4), L(cx, oy - 0.21, oz - 0.82), PRETO, Enum.Material.Fabric)
	parte(modelo, "Assento", Vector3.new(0.48, 0.1, 0.46), L(ox, oy - 0.86, oz + 0.05), Color3.fromRGB(62, 70, 54), Enum.Material.Fabric)
	parte(modelo, "Encosto", Vector3.new(0.46, 0.8, 0.14), L(ox, oy - 0.42, oz + 0.38) * CFrame.Angles(math.rad(-14), 0, 0), Color3.fromRGB(62, 70, 54), Enum.Material.Fabric)
	parte(modelo, "Manche", Vector3.new(0.035, 0.42, 0.035), L(ox, piso + 0.39, oz - 0.36), PRETO)
	parte(modelo, "Manete", Vector3.new(0.05, 0.13, 0.08), L(lay.Manete.Pivo[1], lay.Manete.Pivo[2] + 0.07, lay.Manete.Pivo[3]), PRETO)
end

function CAB.Criar(P, pastaPai)
	local lay = LAYOUT[P.Id]
	local obj = { Interruptores = {}, Estados = {}, P = P, Guis = {}, Telas = {}, Instrumentos = {} }
	local modelo = Instance.new("Model")
	modelo.Name = "CabineSimulador"
	local raiz = Instance.new("Part")
	raiz.Name = "Raiz"
	raiz.Anchored = true
	raiz.CanCollide = false
	raiz.CanQuery = false
	raiz.CanTouch = false
	raiz.Transparency = 1
	raiz.Size = Vector3.new(0.2, 0.2, 0.2)
	raiz.CFrame = CFrame.new()
	raiz.Parent = modelo
	obj.Raiz = raiz
	obj.Modelo = modelo
	local ox, oy, oz = lay.Olho[1], lay.Olho[2], lay.Olho[3]

	-- MALHA ---------------------------------------------------------------------------------
	local pastaMalhas = ReplicatedStorage:FindFirstChild("FABMalhas")
	local malha = pastaMalhas and pastaMalhas:FindFirstChild("Sim_" .. P.Id)
	obj.Diag = malha and "malha ja estava no cliente" or "malha ausente, pedindo ao servidor"
	if not malha and pastaMalhas then
		local ped = ReplicatedStorage:FindFirstChild("FABPedirCabine")
		if ped then
			ped:FireServer(P.Id)
			malha = pastaMalhas:WaitForChild("Sim_" .. P.Id, 30)
			obj.Diag = malha and "malha recebida do servidor" or "servidor NAO enviou a malha em 30 s"
		else
			obj.Diag = "FABPedirCabine inexistente"
		end
	elseif not pastaMalhas then
		obj.Diag = "pasta FABMalhas inexistente"
	end
	if malha then
		-- espera as malhas terminarem de baixar para a cabine nao aparecer pela metade
		pcall(function() game:GetService("ContentProvider"):PreloadAsync(malha:GetDescendants()) end)
	end
	obj.Animadas = {}
	obj.Trem = {}
	local nPartes = 0
	if malha then
		for _, d in ipairs(malha:GetDescendants()) do
			if d:IsA("BasePart") then
				local c = d:Clone()
				for _, filho in ipairs(c:GetChildren()) do
					if filho:IsA("JointInstance") or filho:IsA("WeldConstraint") then filho:Destroy() end
				end
				c.Anchored = false
				c.Massless = true
				c.CanCollide = false
				c.CanQuery = false
				c.CanTouch = false
				-- sombras so nas pecas grandes da cabine (evita custo excessivo)
				c.CastShadow = c.Transparency < 0.5 and (c.Size.Magnitude > 2)
				c.Parent = modelo
				nPartes = nPartes + 1
				if c.Name == "Manche" or c.Name == "MancheBotoes" or c.Name == "Manete" or c.Name == "Helice" then
					table.insert(obj.Animadas, c)
				elseif c.Name == "Trem" or c.Name == "TremPneus" then
					table.insert(obj.Trem, c)
				end
			end
		end
		if nPartes == 0 then
			obj.Diag = "malha vazia (0 pecas)"
			construirSimples(modelo, P, lay)
		else
			obj.Diag = "malha OK: " .. nPartes .. " pecas"
		end
	else
		construirSimples(modelo, P, lay)
	end

	warn("[FAB] Cabine " .. tostring(P.Id) .. ": " .. tostring(obj.Diag))
	-- TELAS ----------------------------------------------------------------------------------
	for _, t in ipairs(lay.Telas) do
		local w, h = t.Tam[1], t.Tam[2]
		local tela = parte(modelo, "Tela_" .. t.Nome, Vector3.new(w, h, 0.004), cfItem(t), Color3.fromRGB(6, 8, 10), Enum.Material.Glass,
			{ Reflectance = 0.04, CanQuery = true })
		tela:SetAttribute("Tela", t.Nome)
		local base = (w > 0.3) and 1400 or 700
		local cw = (w >= h) and base or math.floor(base * w / h)
		local ch = (w >= h) and math.floor(base * h / w) or base
		local g = superficie(tela, Enum.NormalId.Back, Vector2.new(cw, ch), "FAB_" .. t.Nome)
		table.insert(obj.Guis, g)
		local quadro = Instance.new("Frame")
		quadro.Size = UDim2.fromScale(1, 1)
		quadro.BackgroundColor3 = Color3.new(0, 0, 0)
		quadro.BorderSizePixel = 0
		quadro.ClipsDescendants = true
		quadro.Parent = g
		local construtor = AV.Paginas[t.Pagina]
		local pagina = construtor and construtor(quadro, cw, ch)
		table.insert(obj.Telas, { Nome = t.Nome, Parte = tela, Gui = g, Quadro = quadro, Pagina = pagina, W = cw, H = ch })
	end

	-- INSTRUMENTOS ANALOGICOS -------------------------------------------------------------------
	for _, m in ipairs(lay.Mostradores) do
		local d = m.Diam
		local suporte = parte(modelo, "Instrumento_" .. m.Nome, Vector3.new(d, d, 0.003), cfItem(m), Color3.fromRGB(14, 14, 15), Enum.Material.SmoothPlastic)
		local g = superficie(suporte, Enum.NormalId.Back, Vector2.new(400, 400), "FAB_" .. m.Nome)
		g.Brightness = 1.1
		table.insert(obj.Guis, g)
		local construtor = AV.Mostradores[m.Nome]
		if construtor then
			table.insert(obj.Instrumentos, construtor(g, 400))
		end
		-- vidro do instrumento
		local vidro = parte(modelo, "Vidro", Vector3.new(0.002, d, d), cfItem(m, 0, 0, 0.008) * CFrame.Angles(0, math.rad(90), 0),
			Color3.fromRGB(200, 215, 225), Enum.Material.Glass, { Transparency = 0.88, Shape = Enum.PartType.Cylinder, Reflectance = 0.08 })
		vidro.Name = "VidroInstrumento"
	end

	-- INTERRUPTORES ---------------------------------------------------------------------------
	local ROTULOS = { Bateria = "BAT", Bomba = "BOMBA", Ignicao = "IGNIÇÃO", Mistura = "MISTURA", Magnetos = "MAGNETOS",
		Partida = "PARTIDA", Luzes = "LUZES", FreioEst = "FREIO EST" }
	for _, it in ipairs(lay.Interruptores) do
		local id = it.Id
		local cfBase = cfItem(it)
		local base = parte(modelo, "BaseInterruptor", Vector3.new(0.045, 0.06, 0.008), cfBase * CFrame.new(0, 0, 0.004 * E), Color3.fromRGB(34, 35, 38),
			Enum.Material.Metal, { CanQuery = true })
		local cfAlav = cfBase * CFrame.new(0, 0, 0.008 * E)
		local alavanca = parte(modelo, "Alavanca", Vector3.new(0.008, 0.008, 0.03), cfAlav, Color3.fromRGB(205, 208, 212), Enum.Material.Metal, { CanQuery = true })
		local w = Instance.new("Weld")
		w.Part0 = raiz
		w.Part1 = alavanca
		w.Parent = alavanca
		local etiqueta = parte(modelo, "Etiqueta", Vector3.new(0.06, 0.016, 0.002), cfBase * CFrame.new(0, 0.042 * E, 0.002 * E), Color3.fromRGB(28, 28, 30))
		local g = superficie(etiqueta, Enum.NormalId.Back, Vector2.new(240, 64), "FAB_Etiqueta")
		g.Brightness = 1
		table.insert(obj.Guis, g)
		local txt = Instance.new("TextLabel")
		txt.Size = UDim2.fromScale(1, 1)
		txt.BackgroundTransparency = 1
		txt.Text = ROTULOS[id] or id
		txt.TextColor3 = Color3.fromRGB(230, 230, 225)
		txt.Font = Enum.Font.GothamBold
		txt.TextScaled = true
		txt.Parent = g
		local luz = parte(modelo, "LuzInterruptor", Vector3.new(0.008, 0.008, 0.004), cfBase * CFrame.new(0, -0.024 * E, 0.006 * E), Color3.fromRGB(30, 30, 30), Enum.Material.SmoothPlastic)
		for _, peca in ipairs({ base, alavanca }) do peca:SetAttribute("Interruptor", id) end
		obj.Interruptores[id] = { Base = base, Alavanca = alavanca, Weld = w, CF = cfAlav, Luz = luz }
		obj.Estados[id] = false
	end
	if P.TremRetratil and lay.Trem then
		local cfT = cfItem(lay.Trem)
		local haste = parte(modelo, "AlavancaTrem", Vector3.new(0.014, 0.09, 0.014), cfT, Color3.fromRGB(220, 220, 220), Enum.Material.Metal, { CanQuery = true })
		local roda = parte(modelo, "RodaAlavanca", Vector3.new(0.022, 0.05, 0.05), cfT, Color3.fromRGB(235, 235, 230), Enum.Material.SmoothPlastic,
			{ CanQuery = true, Shape = Enum.PartType.Cylinder })
		local wH = Instance.new("Weld")
		wH.Part0 = raiz
		wH.Part1 = haste
		wH.Parent = haste
		local wR = Instance.new("Weld")
		wR.Part0 = raiz
		wR.Part1 = roda
		wR.Parent = roda
		haste:SetAttribute("Interruptor", "Trem")
		roda:SetAttribute("Interruptor", "Trem")
		local luzes = {}
		for i, dx in ipairs({ 0, -0.016, 0.016 }) do
			luzes[i] = parte(modelo, "LuzTrem", Vector3.new(0.012, 0.012, 0.004), cfT * CFrame.new((0.055 + dx) * E, (i == 1 and 0.02 or -0.005) * E, 0.004 * E),
				Color3.fromRGB(20, 40, 20), Enum.Material.SmoothPlastic)
		end
		obj.Interruptores.Trem = { Base = haste, Alavanca = roda, WH = wH, WR = wR, CF = cfT, Luzes = luzes }
	end
	if lay.Flape then
		local cfF = cfItem(lay.Flape)
		local flape = parte(modelo, "AlavancaFlape", Vector3.new(0.02, 0.05, 0.03), cfF * CFrame.new(0, 0.025 * E, 0), Color3.fromRGB(200, 200, 200),
			Enum.Material.Metal, { CanQuery = true })
		flape:SetAttribute("Interruptor", "Flape")
		obj.Interruptores.Flape = { Base = flape }
	end
	obj.LuzesAlerta = {}
	for _, l in ipairs(lay.Luzes or {}) do
		table.insert(obj.LuzesAlerta, parte(modelo, "AlertaMestre", Vector3.new(l.Tam[1], l.Tam[2], 0.004), cfItem(l), Color3.fromRGB(60, 40, 10), Enum.Material.SmoothPlastic))
	end

	-- HUD: vidro combinador ------------------------------------------------------------------------
	if P.HUD and lay.HUD then
		local h = lay.HUD
		obj.HUDParte = parte(modelo, "VidroHUD", Vector3.new(h.Tam[1], h.Tam[2], 0.003), cfItem(h), Color3.fromRGB(170, 215, 195), Enum.Material.Glass,
			{ Transparency = 0.86, Reflectance = 0.06 })
	end

	-- PRANCHETA DE JOELHO (escolha de missao) -----------------------------------------------------
	local centroPr = Vector3.new((ox + 0.13) * E, (oy - 0.66) * E, (oz - 0.22) * E)
	local olho = Vector3.new(ox * E, oy * E, oz * E)
	local cfPr = CFrame.lookAt(centroPr, olho) * CFrame.Angles(0, 0, 0)
	local prancheta = parte(modelo, "Prancheta", Vector3.new(0.17, 0.23, 0.008), cfPr, Color3.fromRGB(36, 38, 40), Enum.Material.SmoothPlastic)
	parte(modelo, "Presilha", Vector3.new(0.08, 0.02, 0.012), cfPr * CFrame.new(0, 0.11 * E, -0.004 * E), Color3.fromRGB(170, 172, 176), Enum.Material.Metal)
	local gPr = superficie(prancheta, Enum.NormalId.Front, Vector2.new(520, 700), "FAB_Prancheta")
	gPr.Brightness = 1.3
	table.insert(obj.Guis, gPr)
	local folha = Instance.new("Frame")
	folha.Size = UDim2.new(1, -16, 1, -16)
	folha.Position = UDim2.fromOffset(8, 8)
	folha.BackgroundColor3 = Color3.fromRGB(238, 236, 228)
	folha.BorderSizePixel = 0
	folha.Parent = gPr
	obj.Prancheta = { Parte = prancheta, Gui = gPr, Folha = folha, CF = cfPr }

	-- ILUMINACAO DA CABINE ------------------------------------------------------------------------
	local luzPainel = parte(modelo, "LuzPainel", Vector3.new(0.02, 0.02, 0.02), CFrame.new(ox * E, (oy - 0.2) * E, (oz - 0.45) * E), PRETO, nil, { Transparency = 1 })
	local pl = Instance.new("PointLight")
	pl.Range = 1.6 * E
	pl.Brightness = 0.35
	pl.Color = Color3.fromRGB(255, 236, 214)
	pl.Shadows = false
	pl.Parent = luzPainel

	-- SOLDA -----------------------------------------------------------------------------------------
	obj.Pivos = {}
	for _, p in ipairs(modelo:GetDescendants()) do
		if p:IsA("BasePart") and p ~= raiz then
			local w = p:FindFirstChildOfClass("Weld")
			if not w then
				w = Instance.new("Weld")
				w.Part0 = raiz
				w.Part1 = p
				w.Parent = p
			end
			w.C0 = p.CFrame
			p:SetAttribute("C0", p.CFrame)
			obj.Pivos[p] = w
		end
	end
	raiz.CFrame = CFrame.new(0, 5000, 0)
	modelo.Parent = pastaPai or workspace

	obj.PartesInterativas = {}
	for _, p in ipairs(modelo:GetDescendants()) do
		if p:IsA("BasePart") and (p:GetAttribute("Interruptor") or p:GetAttribute("Tela")) then table.insert(obj.PartesInterativas, p) end
	end

	local destaque = Instance.new("Highlight")
	destaque.FillTransparency = 1
	destaque.OutlineColor = Color3.new(1, 1, 1)
	destaque.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	destaque.Enabled = false
	destaque.Parent = modelo
	function obj.Destacar(id)
		local it = id and obj.Interruptores[id]
		if it then
			destaque.Adornee = it.Base
			destaque.Enabled = true
		else
			destaque.Enabled = false
		end
	end

	function obj.DefinirInterruptor(id, valor)
		obj.Estados[id] = valor
		local it = obj.Interruptores[id]
		if it and it.Weld then
			it.Weld.C0 = it.CF * CFrame.Angles(math.rad(valor and -32 or 32), 0, 0) * CFrame.new(0, 0, 0.012 * E)
			it.Luz.Color = valor and Color3.fromRGB(80, 255, 120) or Color3.fromRGB(30, 30, 30)
			it.Luz.Material = valor and Enum.Material.Neon or Enum.Material.SmoothPlastic
		end
	end
	for id in pairs(obj.Interruptores) do
		if obj.Interruptores[id].Weld then obj.DefinirInterruptor(id, false) end
	end

	-- pivos em studs no referencial da aeronave
	local function pivo(t) return t and Vector3.new(t.Pivo[1] * E, t.Pivo[2] * E, t.Pivo[3] * E) end
	local pManche = pivo(lay.Manche)
	local pManete = pivo(lay.Manete)
	local pHelice = pivo(lay.Helice)
	local anguloHelice = 0
	local acumulado = 0

	function obj.Atualizar(cf, s, e, dt)
		raiz.CFrame = cf
		local arf = math.clamp(e.Arfagem or 0, -1, 1)
		local rol = math.clamp(e.Rolagem or 0, -1, 1)
		local m = math.clamp(e.Manete or 0, 0, 1)
		local rpm = s.N or 0
		anguloHelice = anguloHelice + rpm * dt * 60
		for _, p in ipairs(obj.Animadas) do
			local w = obj.Pivos[p]
			local c0 = p:GetAttribute("C0")
			if w and c0 then
				if (p.Name == "Manche" or p.Name == "MancheBotoes") and pManche then
					w.C0 = CFrame.new(pManche) * CFrame.Angles(arf * math.rad(14), 0, -rol * math.rad(14)) * CFrame.new(-pManche) * c0
				elseif p.Name == "Manete" and pManete then
					w.C0 = CFrame.new(0, 0, -(m - 0.4) * 0.16 * E) * c0
				elseif p.Name == "Helice" and pHelice then
					w.C0 = CFrame.new(pHelice) * CFrame.Angles(0, 0, anguloHelice) * CFrame.new(-pHelice) * c0
				end
			end
		end
		local tremEmbaixo = (s.Trem or 1) > 0.5
		for _, p in ipairs(obj.Trem) do p.LocalTransparencyModifier = tremEmbaixo and 0 or 1 end
		local tr = obj.Interruptores.Trem
		if tr and tr.WH then
			local alvo = e.Trem and -1 or 1
			local cfAlav = tr.CF * CFrame.Angles(math.rad(alvo * 25), 0, 0)
			tr.WH.C0 = cfAlav * CFrame.new(0, 0.045 * E, 0.01 * E)
			tr.WR.C0 = cfAlav * CFrame.new(0, 0.09 * E, 0.014 * E) * CFrame.Angles(0, math.rad(90), 0)
			local t = s.Trem or 0
			for _, l in ipairs(tr.Luzes) do
				local cor = t > 0.98 and Color3.fromRGB(60, 255, 100) or (t > 0.02 and Color3.fromRGB(255, 50, 40) or Color3.fromRGB(20, 30, 20))
				l.Color = cor
				l.Material = (t > 0.02) and Enum.Material.Neon or Enum.Material.SmoothPlastic
			end
		end
		local alerta = s.AvisoEstol or ((s.Combustivel or 1) / (s.P.Combustivel or 1) < 0.15)
		for _, l in ipairs(obj.LuzesAlerta) do
			local pisca = alerta and (os.clock() % 0.6 < 0.3)
			l.Color = pisca and Color3.fromRGB(255, 170, 20) or Color3.fromRGB(60, 40, 10)
			l.Material = pisca and Enum.Material.Neon or Enum.Material.SmoothPlastic
		end
		-- telas e instrumentos a 20 quadros por segundo
		acumulado = acumulado + dt
		if acumulado >= 0.05 then
			local ctx = { Estados = obj.Estados, AlvoMapa = obj.AlvoMapa }
			for _, t in ipairs(obj.Telas) do
				if t.Pagina and not t.Coberta then t.Pagina.Atualizar(s, ctx, acumulado) end
			end
			for _, f in ipairs(obj.Instrumentos) do f(s, ctx) end
			acumulado = 0
		end
	end

	function obj.Destruir()
		for _, g in ipairs(obj.Guis) do g:Destroy() end
		modelo:Destroy()
	end

	return obj
end

return CAB
