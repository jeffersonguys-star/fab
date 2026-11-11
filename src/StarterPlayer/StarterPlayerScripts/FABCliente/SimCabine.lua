--[[
	FAB - Cabine 3D do simulador (cliente)

	Monta a cabine da aeronave em escala real em volta do olho do piloto: fuselagem,
	nariz com helice (ou radome), asas, canopi de vidro, painel com instrumentos
	analogicos (T-25 e T-27) ou telas (A-29, F-5EM e F-39E), manche e manete que se
	movem, e interruptores interativos (toque na tela ou clique para acionar).

	Todas as pecas sao soldadas a uma raiz ancorada; o simulador so move a raiz.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MD = require(ReplicatedStorage:WaitForChild("FAB"):WaitForChild("MapaDados"))

local CAB = {}

local E = MD.StudPorMetro
local PRETO = Color3.fromRGB(18, 18, 20)
local GRAFITE = Color3.fromRGB(42, 44, 48)
local CINZA_PAINEL = Color3.fromRGB(58, 60, 64)

local function v(x, y, z) return Vector3.new(x * E, y * E, z * E) end

local function novaParte(pai, nome, tamanhoM, cfLocal, raizCF, cor, material, extra)
	local p = Instance.new("Part")
	p.Name = nome
	p.Size = tamanhoM * E
	p.CFrame = raizCF * cfLocal
	p.Color = cor or GRAFITE
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if extra then for k, val in pairs(extra) do p[k] = val end end
	p.Parent = pai
	return p
end

-- CFrame local em metros
local function L(x, y, z, rx, ry, rz)
	return CFrame.new(x * E, y * E, z * E) * CFrame.Angles(rx or 0, ry or 0, rz or 0)
end

-- Instrumento analogico (mostrador redondo com ponteiro)
local function mostrador(pai, x, y, tam, titulo, marcas, numeros)
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromOffset(x, y)
	f.Size = UDim2.fromOffset(tam, tam)
	f.BackgroundColor3 = Color3.fromRGB(12, 12, 12)
	f.BorderSizePixel = 0
	f.Parent = pai
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(1, 0)
	c.Parent = f
	local s = Instance.new("UIStroke")
	s.Color = Color3.fromRGB(90, 90, 90)
	s.Thickness = 3
	s.Parent = f
	for i = 0, (marcas or 0) - 1 do
		local ang = (numeros and numeros.Inicio or 0) + i * ((numeros and numeros.Passo) or (360 / marcas))
		local braco = Instance.new("Frame")
		braco.AnchorPoint = Vector2.new(0.5, 1)
		braco.Position = UDim2.fromScale(0.5, 0.5)
		braco.Size = UDim2.new(0, 2, 0.47, 0)
		braco.BackgroundTransparency = 1
		braco.Rotation = ang
		braco.Parent = f
		local traco = Instance.new("Frame")
		traco.Size = UDim2.new(1, 0, 0, (i % 2 == 0) and 9 or 5)
		traco.BackgroundColor3 = Color3.new(1, 1, 1)
		traco.BorderSizePixel = 0
		traco.Parent = braco
	end
	if numeros and numeros.Textos then
		for i, t in ipairs(numeros.Textos) do
			local ang = math.rad(numeros.Inicio + (i - 1) * numeros.PassoTexto)
			local r = 0.32
			local l = Instance.new("TextLabel")
			l.AnchorPoint = Vector2.new(0.5, 0.5)
			l.Position = UDim2.fromScale(0.5 + math.sin(ang) * r, 0.5 - math.cos(ang) * r)
			l.Size = UDim2.fromOffset(tam * 0.2, tam * 0.12)
			l.BackgroundTransparency = 1
			l.Text = t
			l.TextColor3 = Color3.new(1, 1, 1)
			l.Font = Enum.Font.GothamBold
			l.TextScaled = true
			l.Parent = f
		end
	end
	local rot = Instance.new("TextLabel")
	rot.AnchorPoint = Vector2.new(0.5, 0)
	rot.Position = UDim2.fromScale(0.5, 0.62)
	rot.Size = UDim2.fromScale(0.6, 0.12)
	rot.BackgroundTransparency = 1
	rot.Text = titulo
	rot.TextColor3 = Color3.fromRGB(200, 200, 200)
	rot.Font = Enum.Font.Gotham
	rot.TextScaled = true
	rot.Parent = f
	local function ponteiro(comprimento, largura, cor)
		local p = Instance.new("Frame")
		p.AnchorPoint = Vector2.new(0.5, 1)
		p.Position = UDim2.fromScale(0.5, 0.5)
		p.Size = UDim2.new(0, largura or 4, comprimento or 0.42, 0)
		p.BackgroundColor3 = cor or Color3.new(1, 1, 1)
		p.BorderSizePixel = 0
		p.ZIndex = 3
		p.Parent = f
		return p
	end
	local cubo = Instance.new("Frame")
	cubo.AnchorPoint = Vector2.new(0.5, 0.5)
	cubo.Position = UDim2.fromScale(0.5, 0.5)
	cubo.Size = UDim2.fromOffset(10, 10)
	cubo.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	cubo.ZIndex = 4
	cubo.Parent = f
	local cc = Instance.new("UICorner")
	cc.CornerRadius = UDim.new(1, 0)
	cc.Parent = cubo
	return f, ponteiro
end

-- Horizonte artificial (recortado por CanvasGroup)
local function horizonte(pai, x, y, tam, redondo)
	local ok, g = pcall(function() return Instance.new("CanvasGroup") end)
	if not ok then g = Instance.new("Frame") g.ClipsDescendants = true end
	g.AnchorPoint = Vector2.new(0.5, 0.5)
	g.Position = UDim2.fromOffset(x, y)
	g.Size = UDim2.fromOffset(tam, tam)
	g.BackgroundColor3 = Color3.fromRGB(110, 70, 35)
	g.BorderSizePixel = 0
	g.Parent = pai
	if redondo then
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(1, 0)
		c.Parent = g
	end
	local disco = Instance.new("Frame")
	disco.AnchorPoint = Vector2.new(0.5, 0.5)
	disco.Position = UDim2.fromScale(0.5, 0.5)
	disco.Size = UDim2.fromScale(3, 3)
	disco.BackgroundTransparency = 1
	disco.Parent = g
	local ceu = Instance.new("Frame")
	ceu.Size = UDim2.fromScale(1, 0.5)
	ceu.BackgroundColor3 = Color3.fromRGB(40, 120, 210)
	ceu.BorderSizePixel = 0
	ceu.Parent = disco
	local terra = Instance.new("Frame")
	terra.Position = UDim2.fromScale(0, 0.5)
	terra.Size = UDim2.fromScale(1, 0.5)
	terra.BackgroundColor3 = Color3.fromRGB(120, 75, 35)
	terra.BorderSizePixel = 0
	terra.Parent = disco
	local linha = Instance.new("Frame")
	linha.AnchorPoint = Vector2.new(0.5, 0.5)
	linha.Position = UDim2.fromScale(0.5, 0.5)
	linha.Size = UDim2.new(1, 0, 0, 2)
	linha.BackgroundColor3 = Color3.new(1, 1, 1)
	linha.BorderSizePixel = 0
	linha.Parent = disco
	-- escada de arfagem (a cada 10 graus); 1 grau = tam/60 pixels
	local pxGrau = tam / 60
	for k = -6, 6 do
		if k ~= 0 then
			local m = Instance.new("Frame")
			m.AnchorPoint = Vector2.new(0.5, 0.5)
			m.Position = UDim2.new(0.5, 0, 0.5, -k * 10 * pxGrau)
			m.Size = UDim2.fromOffset(tam * (k % 2 == 0 and 0.3 or 0.16), 2)
			m.BackgroundColor3 = Color3.new(1, 1, 1)
			m.BorderSizePixel = 0
			m.Parent = disco
		end
	end
	-- simbolo fixo da aeronave
	for _, s in ipairs({ { -0.22, 0.14 }, { 0.22, 0.14 } }) do
		local a = Instance.new("Frame")
		a.AnchorPoint = Vector2.new(0.5, 0.5)
		a.Position = UDim2.fromScale(0.5 + s[1], 0.5)
		a.Size = UDim2.new(s[2], 0, 0, 4)
		a.BackgroundColor3 = Color3.fromRGB(255, 200, 0)
		a.BorderSizePixel = 0
		a.ZIndex = 5
		a.Parent = g
	end
	local ponto = Instance.new("Frame")
	ponto.AnchorPoint = Vector2.new(0.5, 0.5)
	ponto.Position = UDim2.fromScale(0.5, 0.5)
	ponto.Size = UDim2.fromOffset(6, 6)
	ponto.BackgroundColor3 = Color3.fromRGB(255, 200, 0)
	ponto.ZIndex = 5
	ponto.Parent = g
	return function(arfagem, inclinacao)
		disco.Rotation = -inclinacao
		local rad = math.rad(inclinacao)
		local dy = arfagem * pxGrau
		disco.Position = UDim2.new(0.5, -math.sin(rad) * dy, 0.5, math.cos(rad) * dy)
	end
end

local function rotulo(pai, texto, x, y, w, h, tam, cor, fonte, alinh)
	local t = Instance.new("TextLabel")
	t.Position = UDim2.fromOffset(x, y)
	t.Size = UDim2.fromOffset(w, h)
	t.BackgroundTransparency = 1
	t.Text = texto
	t.TextSize = tam
	t.TextColor3 = cor or Color3.new(1, 1, 1)
	t.Font = fonte or Enum.Font.GothamBold
	t.TextXAlignment = alinh or Enum.TextXAlignment.Center
	t.Parent = pai
	return t
end

function CAB.Criar(P, pastaPai)
	local obj = { Interruptores = {}, Estados = {}, P = P }
	local modelo = Instance.new("Model")
	modelo.Name = "CabineSimulador"
	local raizCF = CFrame.new(0, 50000, 0)
	local raiz = Instance.new("Part")
	raiz.Name = "Raiz"
	raiz.Anchored = true
	raiz.CanCollide = false
	raiz.CanQuery = false
	raiz.CanTouch = false
	raiz.Transparency = 1
	raiz.Size = Vector3.new(0.2, 0.2, 0.2)
	raiz.CFrame = raizCF
	raiz.Parent = modelo
	obj.Raiz = raiz
	obj.Modelo = modelo
	local ox, oy, oz = P.Olho[1], P.Olho[2], P.Olho[3]
	local jato = P.Tipo == "jato"
	local vidro = P.Cabine == "vidro"
	local corFuselagem = jato and Color3.fromRGB(150, 156, 160) or Color3.fromRGB(235, 235, 232)
	if P.Id == "A29" then corFuselagem = Color3.fromRGB(95, 104, 92) end
	if P.Id == "F5" then corFuselagem = Color3.fromRGB(128, 136, 142) end
	if P.Id == "T27" then corFuselagem = Color3.fromRGB(235, 235, 232) end
	local corDetalhe = Color3.fromRGB(28, 52, 104)

	local function parte(nome, tam, cf, cor, mat, extra)
		return novaParte(modelo, nome, tam, cf, raizCF, cor, mat, extra)
	end

	-- FUSELAGEM, NARIZ E ASAS ---------------------------------------------------
	local raioF = jato and 0.75 or 0.68
	local comp = jato and 14 or 9
	local fus = parte("Fuselagem", Vector3.new(comp, raioF * 2, raioF * 2), L(0, 0, 0.5, 0, math.rad(90), 0), corFuselagem, Enum.Material.Metal)
	fus.Shape = Enum.PartType.Cylinder
	-- dorso por tras do canopi
	parte("Dorso", Vector3.new(0.7, 0.5, comp * 0.45), L(0, raioF * 0.75, oz + 1.6 + comp * 0.2), corFuselagem, Enum.Material.Metal)
	-- nariz
	if jato then
		local cone = parte("Radome", Vector3.new(3.2, raioF * 1.6, raioF * 1.6), L(0, -0.1, oz - 3.2, 0, math.rad(90), 0), corFuselagem, Enum.Material.Metal)
		cone.Shape = Enum.PartType.Cylinder
		local ponta = parte("PontaRadome", Vector3.new(raioF * 1.4, raioF * 1.4, raioF * 1.4), L(0, -0.12, oz - 4.8), Color3.fromRGB(90, 96, 100), Enum.Material.SmoothPlastic)
		ponta.Shape = Enum.PartType.Ball
		parte("Pitot", Vector3.new(0.05, 0.05, 1.2), L(0, -0.12, oz - 5.6), Color3.fromRGB(200, 200, 200), Enum.Material.Metal)
		-- entradas de ar laterais
		for _, s in ipairs({ -1, 1 }) do
			parte("EntradaAr", Vector3.new(0.5, 0.9, 2.4), L(s * (raioF + 0.15), -0.25, oz + 1.2), corFuselagem, Enum.Material.Metal)
		end
	else
		local capo = parte("Capo", Vector3.new(2.6, raioF * 1.8, raioF * 1.8), L(0, -0.12, oz - 2.0, 0, math.rad(90), 0), corFuselagem, Enum.Material.Metal)
		capo.Shape = Enum.PartType.Cylinder
		local spinner = parte("Spinner", Vector3.new(0.55, 0.55, 0.55), L(0, -0.15, oz - 3.4), Color3.fromRGB(30, 30, 30), Enum.Material.Metal)
		spinner.Shape = Enum.PartType.Ball
		local escape = parte("Escape", Vector3.new(0.25, 0.25, 0.4), L(raioF * 0.9, -0.3, oz - 1.6), Color3.fromRGB(60, 50, 45), Enum.Material.Metal)
		-- helice: disco translucido + pas que giram
		local disco = parte("DiscoHelice", Vector3.new(0.05, 2.1, 2.1), L(0, -0.15, oz - 3.35, 0, math.rad(90), 0), Color3.fromRGB(200, 200, 200), Enum.Material.Glass, { Transparency = 0.92 })
		disco.Shape = Enum.PartType.Cylinder
		obj.Pas = {}
		for i = 1, (P.Id == "T25" and 2 or 4) do
			local pa = parte("Pa", Vector3.new(0.14, 1.05, 0.04), L(0, -0.15, oz - 3.32), PRETO, Enum.Material.SmoothPlastic)
			pa:SetAttribute("Angulo", (i - 1) * (math.pi * 2 / (P.Id == "T25" and 2 or 4)))
			table.insert(obj.Pas, pa)
		end
	end
	-- asas
	local yAsa = jato and -0.15 or -0.55
	local zAsa = jato and 1.0 or 0.1
	local corda = jato and 3 or 1.7
	for _, s in ipairs({ -1, 1 }) do
		local env = P.Envergadura / 2
		local asa = parte("Asa", Vector3.new(env - raioF, 0.16, corda), L(s * (raioF + (env - raioF) / 2), yAsa, zAsa + oz * 0 , 0, 0, s * math.rad(jato and -2 or 5)),
			corFuselagem, Enum.Material.Metal)
		parte("FaixaAsa", Vector3.new(0.6, 0.17, corda * 0.9), L(s * (env - 0.5), yAsa + (jato and 0 or 0.04), zAsa), corDetalhe, Enum.Material.SmoothPlastic)
		parte("LuzNavegacao", Vector3.new(0.12, 0.12, 0.2), L(s * env, yAsa, zAsa - corda * 0.3), s > 0 and Color3.fromRGB(40, 255, 80) or Color3.fromRGB(255, 40, 30), Enum.Material.Neon)
	end
	if P.Id == "F39" then
		-- canards
		for _, s in ipairs({ -1, 1 }) do
			parte("Canard", Vector3.new(1.6, 0.08, 1.0), L(s * (raioF + 0.75), 0.2, oz + 0.8, 0, 0, s * math.rad(-4)), corFuselagem, Enum.Material.Metal)
		end
	end
	-- leme vertical (visivel olhando para tras)
	parte("Deriva", Vector3.new(0.15, jato and 2.2 or 1.4, 1.5), L(0, raioF + (jato and 1.1 or 0.7), comp / 2 - 0.5, math.rad(-15), 0, 0), corFuselagem, Enum.Material.Metal)

	-- CABINE -------------------------------------------------------------------
	local largCab = (P.Assentos == "lado") and 1.15 or 0.78
	local cxCab = (P.Assentos == "lado") and 0 or ox
	-- bordas da cabine (soleiras)
	for _, s in ipairs({ -1, 1 }) do
		parte("Soleira", Vector3.new(0.12, 0.25, 2.2), L(cxCab + s * largCab / 2, oy - 0.42, oz + 0.2), GRAFITE, Enum.Material.Metal)
		parte("ConsoleLateral", Vector3.new(0.2, 0.08, 1.2), L(cxCab + s * (largCab / 2 - 0.12), oy - 0.55, oz + 0.05), CINZA_PAINEL, Enum.Material.Metal)
	end
	-- painel e para-sol
	local larguraPainel = (P.Assentos == "lado") and 1.1 or 0.74
	local painelCF = L(cxCab, oy - 0.3, oz - 0.72, math.rad(-8), 0, 0)
	local painel = parte("Painel", Vector3.new(larguraPainel, 0.34, 0.04), painelCF, PRETO, Enum.Material.SmoothPlastic)
	parte("ParaSol", Vector3.new(larguraPainel + 0.04, 0.05, 0.28), L(cxCab, oy - 0.11, oz - 0.82), PRETO, Enum.Material.Fabric)
	parte("PainelInferior", Vector3.new(larguraPainel * 0.8, 0.2, 0.04), L(cxCab, oy - 0.56, oz - 0.66, math.rad(-25), 0, 0), PRETO, Enum.Material.SmoothPlastic)
	-- canopi: arcos e vidro
	local alturaCan = 0.55
	for _, z in ipairs({ oz - 0.95, oz + 0.75 }) do
		for k = 0, 6 do
			local a1 = math.pi * k / 7
			local a2 = math.pi * (k + 1) / 7
			local x1, y1 = -math.cos(a1) * largCab / 2, math.sin(a1) * alturaCan
			local x2, y2 = -math.cos(a2) * largCab / 2, math.sin(a2) * alturaCan
			local cx, cy = (x1 + x2) / 2, (y1 + y2) / 2
			local seg = math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2)
			parte("ArcoCanopi", Vector3.new(seg + 0.01, 0.035, 0.05), L(cxCab + cx, oy - 0.3 + cy, z, 0, 0, math.atan2(y2 - y1, x2 - x1)), PRETO, Enum.Material.Metal)
		end
	end
	for k = 0, 6 do
		local a = math.pi * (k + 0.5) / 7
		local x, y = -math.cos(a) * largCab / 2 * 1.02, math.sin(a) * alturaCan * 1.02
		parte("VidroCanopi", Vector3.new(largCab * 0.47, 0.01, 1.75), L(cxCab + x, oy - 0.3 + y, oz - 0.1, 0, 0, a - math.pi / 2),
			Color3.fromRGB(200, 220, 235), Enum.Material.Glass, { Transparency = 0.93 })
	end
	-- para-brisa frontal inclinado
	parte("ParaBrisa", Vector3.new(largCab * 0.95, 0.5, 0.01), L(cxCab, oy - 0.05, oz - 1.05, math.rad(-55), 0, 0), Color3.fromRGB(200, 220, 235), Enum.Material.Glass, { Transparency = 0.94 })

	-- manche e manete (articulados por Weld)
	local function articulada(nome, tam, cfLocal, cor, mat)
		local p = parte(nome, tam, cfLocal, cor, mat)
		local w = Instance.new("Weld")
		w.Part0 = raiz
		w.Part1 = p
		w.C0 = cfLocal
		w.Parent = p
		return p, w, cfLocal
	end
	local baseManche = L(ox, oy - 0.95, oz - 0.38)
	local _, wManche = articulada("Manche", Vector3.new(0.035, 0.42, 0.035), baseManche * L(0, 0.21, 0), PRETO, Enum.Material.Rubber)
	local _, wPunho = articulada("PunhoManche", Vector3.new(0.06, 0.13, 0.06), baseManche * L(0, 0.45, 0), Color3.fromRGB(30, 30, 30), Enum.Material.Rubber)
	obj.Manche = { wManche, wPunho }
	obj.BaseManche = baseManche
	local baseManete = L(ox - 0.33, oy - 0.62, oz - 0.12)
	parte("TrilhoManete", Vector3.new(0.05, 0.03, 0.28), baseManete, CINZA_PAINEL, Enum.Material.Metal)
	local _, wManete = articulada("Manete", Vector3.new(0.05, 0.14, 0.05), baseManete * L(0, 0.08, 0.1), PRETO, Enum.Material.Metal)
	obj.Manete = wManete
	obj.BaseManete = baseManete

	-- INSTRUMENTOS ----------------------------------------------------------------
	local g = Instance.new("SurfaceGui")
	g.Face = Enum.NormalId.Back
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = 900 / (larguraPainel * E)
	g.LightInfluence = 0
	g.Brightness = 1.2
	g.Adornee = painel
	g.Parent = painel
	local fundo = Instance.new("Frame")
	fundo.Size = UDim2.fromScale(1, 1)
	fundo.BackgroundColor3 = PRETO
	fundo.BorderSizePixel = 0
	fundo.Parent = g
	local W = 900
	local H = 900 * 0.34 / larguraPainel
	obj.Instrumentos = {}
	local I = obj.Instrumentos
	if not vidro then
		-- seis basicos + motor (T-25 e T-27)
		local tam = math.min(H * 0.46, W / 7.5)
		local x0 = (P.Assentos == "lado") and (W * 0.08 + tam / 2) or (W * 0.5 - tam * 1.15)
		local dx = tam * 1.12
		local y1, y2 = H * 0.27, H * 0.74
		local _, pASI = mostrador(fundo, x0, y1, tam, "KT", 24, { Inicio = 0, Passo = 15, Textos = { "40", "80", "120", "160", "200", "240" }, PassoTexto = 60 })
		I.ASI = pASI()
		I.Atitude = horizonte(fundo, x0 + dx, y1, tam, true)
		local _, pALT = mostrador(fundo, x0 + dx * 2, y1, tam, "ALT", 50, { Inicio = 0, Passo = 7.2, Textos = { "0", "2", "4", "6", "8" }, PassoTexto = 72 })
		I.Alt100 = pALT(0.42, 4)
		I.Alt1000 = pALT(0.26, 7, Color3.fromRGB(220, 220, 220))
		local fTC, pTC = mostrador(fundo, x0, y2, tam, "CURVA", 0)
		I.Curva = pTC(0.4, 5)
		local bola = Instance.new("Frame")
		bola.AnchorPoint = Vector2.new(0.5, 0.5)
		bola.Position = UDim2.fromScale(0.5, 0.82)
		bola.Size = UDim2.fromOffset(tam * 0.12, tam * 0.12)
		bola.BackgroundColor3 = Color3.new(1, 1, 1)
		bola.ZIndex = 5
		bola.Parent = fTC
		local cb = Instance.new("UICorner")
		cb.CornerRadius = UDim.new(1, 0)
		cb.Parent = bola
		I.Bola = bola
		local fHI = mostrador(fundo, x0 + dx, y2, tam, "", 36)
		local cartao = Instance.new("Frame")
		cartao.Size = UDim2.fromScale(1, 1)
		cartao.BackgroundTransparency = 1
		cartao.Parent = fHI
		for i, t in ipairs({ "N", "3", "6", "L", "12", "15", "S", "21", "24", "O", "30", "33" }) do
			local a = math.rad((i - 1) * 30)
			local l = rotulo(cartao, t, 0, 0, tam * 0.16, tam * 0.12, tam * 0.1)
			l.AnchorPoint = Vector2.new(0.5, 0.5)
			l.Position = UDim2.fromScale(0.5 + math.sin(a) * 0.33, 0.5 - math.cos(a) * 0.33)
			l.Rotation = (i - 1) * 30
		end
		local marcaHI = Instance.new("Frame")
		marcaHI.AnchorPoint = Vector2.new(0.5, 0)
		marcaHI.Position = UDim2.fromScale(0.5, 0.04)
		marcaHI.Size = UDim2.fromOffset(4, tam * 0.12)
		marcaHI.BackgroundColor3 = Color3.fromRGB(255, 170, 0)
		marcaHI.ZIndex = 5
		marcaHI.Parent = fHI
		I.CartaoRumo = cartao
		local _, pVSI = mostrador(fundo, x0 + dx * 2, y2, tam, "VS x100", 20, { Inicio = 180, Passo = 9, Textos = { "20", "10", "0", "10", "20" }, PassoTexto = 45 })
		I.VSI = pVSI()
		-- motor
		local tamM = tam * 0.62
		local xm = x0 + dx * 3 + tam * 0.1
		local _, pRPM = mostrador(fundo, xm, H * 0.22, tamM, "RPM %", 12, { Inicio = 225, Passo = 22.5 })
		I.RPM = pRPM()
		local _, pComb = mostrador(fundo, xm, H * 0.52, tamM, "COMB", 10, { Inicio = 240, Passo = 24 })
		I.Comb = pComb()
		local _, pG = mostrador(fundo, xm, H * 0.82, tamM, "G", 12, { Inicio = 240, Passo = 20 })
		I.G = pG()
		-- anunciadores
		local anun = {}
		for i, nome in ipairs({ "ESTOL", "PARTIDA", "BATERIA", "BOMBA", "FLAPE", "TREM" }) do
			local a = rotulo(fundo, nome, xm + tamM * 0.7, H * 0.06 + (i - 1) * H * 0.15, W * 0.12, H * 0.12, 13, Color3.fromRGB(60, 60, 60))
			a.BackgroundTransparency = 0
			a.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
			anun[nome] = a
		end
		I.Anunciadores = anun
	else
		-- cabine de vidro: PFD + motor/navegacao
		local larg = W * 0.43
		local alt = H * 0.88
		local function tela(x)
			local f = Instance.new("Frame")
			f.Position = UDim2.fromOffset(x, H * 0.06)
			f.Size = UDim2.fromOffset(larg, alt)
			f.BackgroundColor3 = Color3.fromRGB(5, 6, 8)
			f.BorderSizePixel = 0
			f.Parent = fundo
			local s = Instance.new("UIStroke")
			s.Color = Color3.fromRGB(70, 70, 70)
			s.Thickness = 4
			s.Parent = f
			return f
		end
		local pfd = tela(W * 0.05)
		I.Atitude = horizonte(pfd, larg * 0.5, alt * 0.5, alt * 0.72, false)
		I.TxtVel = rotulo(pfd, "", 4, alt * 0.44, larg * 0.2, alt * 0.12, 22, Color3.new(1, 1, 1), Enum.Font.Code)
		I.TxtVel.BackgroundColor3 = Color3.new(0, 0, 0)
		I.TxtVel.BackgroundTransparency = 0.2
		I.TxtAlt = rotulo(pfd, "", larg * 0.78, alt * 0.44, larg * 0.21, alt * 0.12, 22, Color3.new(1, 1, 1), Enum.Font.Code)
		I.TxtAlt.BackgroundColor3 = Color3.new(0, 0, 0)
		I.TxtAlt.BackgroundTransparency = 0.2
		I.TxtRumo = rotulo(pfd, "", larg * 0.35, alt * 0.88, larg * 0.3, alt * 0.1, 20, Color3.new(1, 1, 1), Enum.Font.Code)
		I.TxtInfo = rotulo(pfd, "", 6, 4, larg - 12, alt * 0.1, 15, Color3.fromRGB(120, 255, 150), Enum.Font.Code, Enum.TextXAlignment.Left)
		local mfd = tela(W * 0.52)
		I.TxtMotor = rotulo(mfd, "", 10, 8, larg - 20, alt * 0.55, 17, Color3.fromRGB(120, 255, 150), Enum.Font.Code, Enum.TextXAlignment.Left)
		I.TxtMotor.TextYAlignment = Enum.TextYAlignment.Top
		-- mapa (rumo para cima)
		local mapa = Instance.new("Frame")
		mapa.Position = UDim2.fromOffset(10, alt * 0.58)
		mapa.Size = UDim2.fromOffset(larg - 20, alt * 0.38)
		mapa.BackgroundColor3 = Color3.fromRGB(10, 14, 20)
		mapa.ClipsDescendants = true
		mapa.Parent = mfd
		local pista = Instance.new("Frame")
		pista.AnchorPoint = Vector2.new(0.5, 0.5)
		pista.Size = UDim2.fromOffset(4, 30)
		pista.BackgroundColor3 = Color3.new(1, 1, 1)
		pista.Parent = mapa
		local alvo = Instance.new("Frame")
		alvo.AnchorPoint = Vector2.new(0.5, 0.5)
		alvo.Size = UDim2.fromOffset(10, 10)
		alvo.Rotation = 45
		alvo.BackgroundColor3 = Color3.fromRGB(255, 80, 200)
		alvo.Visible = false
		alvo.Parent = mapa
		local eu = Instance.new("Frame")
		eu.AnchorPoint = Vector2.new(0.5, 0.5)
		eu.Position = UDim2.fromScale(0.5, 0.75)
		eu.Size = UDim2.fromOffset(10, 10)
		eu.BackgroundColor3 = Color3.fromRGB(120, 255, 150)
		eu.Parent = mapa
		I.Mapa = { Quadro = mapa, Pista = pista, Alvo = alvo }
	end

	-- INTERRUPTORES INTERATIVOS -----------------------------------------------------
	local lista = { { "Bateria", "BAT" }, { "Bomba", "BOMBA" } }
	if jato then
		table.insert(lista, { "Ignicao", "IGN" })
	else
		table.insert(lista, { "Mistura", "MIST" })
		table.insert(lista, { "Magnetos", "MAG" })
	end
	table.insert(lista, { "Partida", "PARTIDA" })
	table.insert(lista, { "Luzes", "LUZES" })
	table.insert(lista, { "FreioEst", "FREIO EST" })
	local n = #lista
	local larguraFila = math.min(larguraPainel * 0.9, 0.8)
	for i, item in ipairs(lista) do
		local id, texto = item[1], item[2]
		local x = cxCab - larguraFila / 2 + (i - 0.5) * larguraFila / n
		local cfBase = L(x, oy - 0.58, oz - 0.6, math.rad(-25), 0, 0)
		local base = parte("BaseInterruptor", Vector3.new(0.07, 0.07, 0.02), cfBase, Color3.fromRGB(70, 70, 70), Enum.Material.Metal, { CanQuery = true })
		local alavanca = parte("Alavanca", Vector3.new(0.018, 0.05, 0.018), cfBase * L(0, 0, -0.03), Color3.fromRGB(230, 230, 230), Enum.Material.Metal, { CanQuery = true })
		local wa = Instance.new("Weld")
		wa.Part0 = raiz
		wa.Part1 = alavanca
		wa.C0 = cfBase * L(0, 0, -0.03, math.rad(-35), 0, 0)
		wa.Parent = alavanca
		local etiqueta = Instance.new("SurfaceGui")
		etiqueta.Face = Enum.NormalId.Back
		etiqueta.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
		etiqueta.CanvasSize = Vector2.new(140, 140)
		etiqueta.LightInfluence = 0
		etiqueta.Parent = base
		local et = rotulo(etiqueta, texto, 0, 92, 140, 40, 22, Color3.new(1, 1, 1))
		et.TextScaled = true
		local estadoTxt = rotulo(etiqueta, "OFF", 0, 4, 140, 34, 20, Color3.fromRGB(150, 150, 150))
		for _, peca in ipairs({ base, alavanca }) do peca:SetAttribute("Interruptor", id) end
		obj.Interruptores[id] = { Base = base, Alavanca = alavanca, Weld = wa, CF = cfBase, Texto = estadoTxt }
		obj.Estados[id] = false
	end
	if P.TremRetratil then
		local cfT = L(cxCab + larguraFila / 2 + 0.07, oy - 0.45, oz - 0.68, math.rad(-15), 0, 0)
		local trem = parte("AlavancaTrem", Vector3.new(0.04, 0.12, 0.04), cfT, Color3.fromRGB(240, 240, 240), Enum.Material.SmoothPlastic, { CanQuery = true })
		local roda = parte("RodaAlavanca", Vector3.new(0.06, 0.06, 0.06), cfT * L(0, 0.07, 0), Color3.fromRGB(240, 240, 240), Enum.Material.SmoothPlastic, { CanQuery = true })
		roda.Shape = Enum.PartType.Ball
		trem:SetAttribute("Interruptor", "Trem")
		roda:SetAttribute("Interruptor", "Trem")
		obj.Interruptores.Trem = { Base = trem, Alavanca = roda }
	end
	local cfF = L(ox - 0.33, oy - 0.6, oz + 0.12)
	local flape = parte("AlavancaFlape", Vector3.new(0.03, 0.07, 0.05), cfF, Color3.fromRGB(200, 200, 200), Enum.Material.Metal, { CanQuery = true })
	flape:SetAttribute("Interruptor", "Flape")
	obj.Interruptores.Flape = { Base = flape }

	-- iluminacao interna suave
	local luz = Instance.new("PointLight")
	luz.Range = 3 * E
	luz.Brightness = 0.25
	luz.Color = Color3.fromRGB(255, 240, 220)
	luz.Parent = painel

	modelo.Parent = pastaPai or workspace
	-- a solda e feita depois de tudo posicionado
	for _, p in ipairs(modelo:GetDescendants()) do
		if p:IsA("BasePart") and p ~= raiz and not p:FindFirstChildOfClass("Weld") then
			local w = Instance.new("WeldConstraint")
			w.Part0 = raiz
			w.Part1 = p
			w.Parent = p
		end
	end

	-- PARTES QUE PODEM SER TOCADAS ------------------------------------------------
	obj.PartesInterativas = {}
	for _, p in ipairs(modelo:GetDescendants()) do
		if p:IsA("BasePart") and p:GetAttribute("Interruptor") then table.insert(obj.PartesInterativas, p) end
	end

	-- destaque do proximo item do checklist
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
			it.Weld.C0 = it.CF * L(0, 0, -0.03, math.rad(valor and 35 or -35), 0, 0)
			it.Texto.Text = valor and "ON" or "OFF"
			it.Texto.TextColor3 = valor and Color3.new(1, 1, 1) or Color3.fromRGB(150, 150, 150)
		end
	end

	local anguloHelice = 0
	function obj.Atualizar(cf, s, e, dt)
		raiz.CFrame = cf
		-- manche e manete
		local arf = math.clamp(e.Arfagem or 0, -1, 1)
		local rol = math.clamp(e.Rolagem or 0, -1, 1)
		local inc = L(0, 0, 0, arf * math.rad(18), 0, -rol * math.rad(18))
		obj.Manche[1].C0 = obj.BaseManche * inc * L(0, 0.21, 0)
		obj.Manche[2].C0 = obj.BaseManche * inc * L(0, 0.45, 0)
		local m = math.clamp(e.Manete or 0, 0, 1)
		obj.Manete.C0 = obj.BaseManete * L(0, 0.08, 0.1 - m * 0.2, math.rad(-20 + m * 40), 0, 0)
		-- helice
		if obj.Pas then
			local rpm = s.N or 0
			anguloHelice = anguloHelice + rpm * dt * 55
			for _, pa in ipairs(obj.Pas) do
				local w = pa:FindFirstChildOfClass("WeldConstraint")
				if w then w:Destroy() end
				local wj = pa:FindFirstChildOfClass("Weld")
				if not wj then
					wj = Instance.new("Weld")
					wj.Part0 = raiz
					wj.Part1 = pa
					wj.Parent = pa
				end
				local ang = pa:GetAttribute("Angulo") + anguloHelice
				wj.C0 = L(0, -0.15, s.P.Olho[3] - 3.32, 0, 0, ang) * L(0, 0.5, 0)
				pa.Transparency = rpm > 0.3 and 0.75 or 0
			end
		end
		-- instrumentos
		local I = obj.Instrumentos
		local kt = (s.IAS or 0) * 1.943844
		local ft = (s.Altitude or 0) * 3.28084
		local fpm = (s.VS or 0) * 196.85
		if I.Atitude then I.Atitude(s.Arfagem or 0, s.Inclinacao or 0) end
		if I.ASI then
			I.ASI.Rotation = (math.clamp(kt, 0, 260) - 40) * 1.5
			I.Alt100.Rotation = (ft % 1000) / 1000 * 360
			I.Alt1000.Rotation = (ft % 10000) / 10000 * 360
			I.VSI.Rotation = 270 + math.clamp(fpm, -2000, 2000) / 2000 * 90
			I.CartaoRumo.Rotation = -(s.Rumo or 0)
			local taxa = math.deg(-(s.wy or 0))
			I.Curva.Rotation = math.clamp(taxa / 3 * 20, -40, 40)
			I.Bola.Position = UDim2.fromScale(0.5 + math.clamp((s.BetaGraus or 0) / 15, -0.3, 0.3), 0.82)
			I.RPM.Rotation = 225 + (s.N or 0) * 270
			I.Comb.Rotation = 240 + math.clamp((s.Combustivel or 0) / s.P.Combustivel, 0, 1) * 240
			I.G.Rotation = 240 + math.clamp(((s.Nz or 1) + 2) / 10, 0, 1) * 220
			local A = I.Anunciadores
			local function anun(nome, ligado, cor)
				A[nome].TextColor3 = ligado and Color3.new(0, 0, 0) or Color3.fromRGB(60, 60, 60)
				A[nome].BackgroundColor3 = ligado and (cor or Color3.fromRGB(255, 190, 0)) or Color3.fromRGB(25, 25, 25)
			end
			anun("ESTOL", s.AvisoEstol, Color3.fromRGB(255, 50, 40))
			anun("PARTIDA", s.Partindo == true)
			anun("BATERIA", obj.Estados.Bateria, Color3.fromRGB(80, 255, 120))
			anun("BOMBA", obj.Estados.Bomba, Color3.fromRGB(80, 255, 120))
			anun("FLAPE", (s.Flap or 0) > 0.05, Color3.fromRGB(80, 255, 120))
			anun("TREM", (s.Trem or 0) > 0.98, Color3.fromRGB(80, 255, 120))
		else
			I.TxtVel.Text = string.format("%d", math.floor(kt + 0.5))
			I.TxtAlt.Text = string.format("%d", math.floor(ft / 10 + 0.5) * 10)
			I.TxtRumo.Text = string.format("%03d°", math.floor((s.Rumo or 0) + 0.5) % 360)
			I.TxtInfo.Text = string.format("G %.1f  AOA %.0f  M %.2f  VS %d", s.Nz or 1, s.AlfaGraus or 0, s.Mach or 0, math.floor(fpm))
			local motor = (s.P.Tipo == "jato") and string.format("N2  %3d%%\nPÓS %s", math.floor((s.N or 0) * 100), (s.PosCombustor or 0) > 0.5 and "LIGADO" or "-")
				or string.format("TQ  %3d%%", math.floor((s.FracaoMotor or 0) * 100))
			I.TxtMotor.Text = string.format("%s\nCOMB %d kg\nTREM %s\nFLAPE %d%%\nFREIO AR %s\n%s",
				motor, math.floor(s.Combustivel or 0), (s.Trem or 0) > 0.98 and "EMBAIXO" or ((s.Trem or 0) < 0.02 and "RECOLHIDO" or "EM TRÂNSITO"),
				math.floor((s.Flap or 0) * 100), (s.AeroFreio or 0) > 0.5 and "ABERTO" or "-", s.AvisoEstol and "ALERTA DE ESTOL" or "")
			-- mapa: escala 1 px = 20 m, rumo para cima
			local mp = I.Mapa
			local rumo = math.rad(s.Rumo or 0)
			local function projetar(xm, zm)
				local dx, dz = xm - s.px, zm - s.pz
				-- gira para o referencial com o rumo para cima
				local frente = dx * math.sin(rumo) - dz * math.cos(rumo)
				local direita = dx * math.cos(rumo) + dz * math.sin(rumo)
				return UDim2.new(0.5, direita / 20, 0.75, -frente / 20)
			end
			mp.Pista.Position = projetar(0, 0)
			mp.Pista.Rotation = -(s.Rumo or 0)
			mp.Pista.Size = UDim2.fromOffset(4, 3000 / 20)
			if obj.AlvoMapa then
				mp.Alvo.Visible = true
				mp.Alvo.Position = projetar(obj.AlvoMapa.X, obj.AlvoMapa.Z)
			else
				mp.Alvo.Visible = false
			end
		end
	end

	function obj.Destruir()
		modelo:Destroy()
	end

	return obj
end

return CAB
