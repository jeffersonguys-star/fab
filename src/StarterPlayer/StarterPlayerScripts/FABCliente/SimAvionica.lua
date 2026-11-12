--[[
	FAB - Avionica do simulador (cliente)

	Desenha as telas e os instrumentos da cabine em SurfaceGuis:
	- PFD: horizonte artificial com escada de arfagem e escala de inclinacao, fitas de
	  velocidade e altitude, variometro, fita de rumo, marcador de trajetoria, G, Mach,
	  angulo de ataque e anunciador de modos.
	- MAPA: mapa movel com rumo para cima, aneis de distancia, rosa dos ventos, pista,
	  prolongamento do eixo, ponto de navegacao e simbolo da aeronave.
	- MOTOR: indicadores de arco (N2 ou torque, temperatura), fluxo e quantidade de
	  combustivel, hidraulico, trem (3 luzes), flape, freio aerodinamico e lista de alertas.
	- WAD: tela panoramica do F-39E dividida em PFD, mapa tatico e motor.
	- ISIS (reserva), UFCP (painel frontal) e painel de anunciadores.
	- Instrumentos analogicos redondos (T-25 e T-27) com mostrador, ponteiros e vidro.
]]

local AV = {}

local PRETO = Color3.fromRGB(4, 5, 7)
local BRANCO = Color3.fromRGB(240, 240, 240)
local CIANO = Color3.fromRGB(0, 220, 255)
local VERDE = Color3.fromRGB(40, 255, 110)
local AMBAR = Color3.fromRGB(255, 186, 0)
local VERMELHO = Color3.fromRGB(255, 45, 40)
local MAGENTA = Color3.fromRGB(255, 60, 230)
local CEU = Color3.fromRGB(0, 104, 214)
local TERRA = Color3.fromRGB(122, 74, 32)
local MONO = Enum.Font.RobotoMono
local SANS = Enum.Font.GothamMedium

local function F(pai, p)
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	f.BackgroundColor3 = BRANCO
	for k, v in pairs(p or {}) do f[k] = v end
	f.Parent = pai
	return f
end

local function T(pai, texto, tam, p)
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Text = texto or ""
	t.TextSize = tam or 20
	t.Font = MONO
	t.TextColor3 = BRANCO
	t.Size = UDim2.fromOffset(tam * 4, tam * 1.2)
	for k, v in pairs(p or {}) do t[k] = v end
	t.Parent = pai
	return t
end

local function canto(f, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = r or UDim.new(1, 0)
	c.Parent = f
	return c
end

local function contorno(f, cor, esp)
	local s = Instance.new("UIStroke")
	s.Color = cor or BRANCO
	s.Thickness = esp or 2
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = f
	return s
end

local function recorte(pai, p)
	local ok, g = pcall(function() return Instance.new("CanvasGroup") end)
	if not ok then g = Instance.new("Frame") g.ClipsDescendants = true end
	g.BorderSizePixel = 0
	for k, v in pairs(p or {}) do g[k] = v end
	g.Parent = pai
	return g
end

-- Arco de tracos em volta de um centro (escalas e faixas coloridas)
local function arco(pai, cx, cy, r, a0, a1, passo, comp, esp, cor)
	local a = a0
	while a <= a1 + 0.01 do
		local rad = math.rad(a)
		F(pai, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(cx + math.sin(rad) * (r - comp / 2), cy - math.cos(rad) * (r - comp / 2)),
			Size = UDim2.fromOffset(esp, comp), Rotation = a, BackgroundColor3 = cor or BRANCO })
		a = a + passo
	end
end

-- PFD -----------------------------------------------------------------------------------
local function pfd(pai, W, H)
	local o = {}
	F(pai, { Size = UDim2.fromOffset(W, H), BackgroundColor3 = PRETO })
	local att = recorte(pai, { Size = UDim2.fromOffset(W, H), BackgroundColor3 = TERRA })
	local pxGrau = H / 50
	local disco = F(att, { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(W * 3, H * 6), BackgroundTransparency = 1 })
	F(disco, { Size = UDim2.fromScale(1, 0.5), BackgroundColor3 = CEU })
	F(disco, { Position = UDim2.fromScale(0, 0.5), Size = UDim2.fromScale(1, 0.5), BackgroundColor3 = TERRA })
	F(disco, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, 0, 0, 2) })
	for k = -18, 18 do
		if k ~= 0 then
			local ang = k * 5
			local maior = k % 2 == 0
			local y = H * 3 - ang * pxGrau
			F(disco, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(W * 1.5, y), Size = UDim2.fromOffset(maior and W * 0.22 or W * 0.1, 2) })
			if maior then
				T(disco, tostring(math.abs(ang)), H * 0.035, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromOffset(W * 1.5 - W * 0.12, y), Size = UDim2.fromOffset(W * 0.06, H * 0.04), TextXAlignment = Enum.TextXAlignment.Right })
				T(disco, tostring(math.abs(ang)), H * 0.035, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromOffset(W * 1.5 + W * 0.12, y), Size = UDim2.fromOffset(W * 0.06, H * 0.04), TextXAlignment = Enum.TextXAlignment.Left })
			end
		end
	end
	-- escala de inclinacao fixa e ponteiro que gira com o horizonte
	local cx, cy, raio = W / 2, H * 0.48, H * 0.36
	for _, a in ipairs({ -60, -45, -30, -20, -10, 0, 10, 20, 30, 45, 60 }) do
		local maior = a % 30 == 0
		arco(att, cx, cy, raio, a, a, 1, maior and H * 0.04 or H * 0.025, 2, BRANCO)
	end
	local girador = F(att, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(cx, cy), Size = UDim2.fromOffset(2, 2), BackgroundTransparency = 1 })
	F(girador, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(1, -raio + H * 0.045), Size = UDim2.fromOffset(H * 0.035, H * 0.03), Rotation = 45, BackgroundColor3 = BRANCO })
	-- simbolo fixo da aeronave (amarelo, como nos PFD reais)
	for _, s in ipairs({ -1, 1 }) do
		F(att, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(cx + s * W * 0.14, cy), Size = UDim2.fromOffset(W * 0.1, H * 0.018), BackgroundColor3 = AMBAR })
		F(att, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(cx + s * W * 0.095, cy), Size = UDim2.fromOffset(H * 0.018, H * 0.035), BackgroundColor3 = AMBAR })
	end
	F(att, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(cx, cy), Size = UDim2.fromOffset(H * 0.02, H * 0.02), BackgroundColor3 = AMBAR })
	-- marcador de trajetoria
	local fpm = F(att, { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(H * 0.04, H * 0.04), BackgroundTransparency = 1 })
	canto(fpm)
	contorno(fpm, VERDE, 2)
	F(fpm, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.fromOffset(H * 0.03, 2), BackgroundColor3 = VERDE })
	F(fpm, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(1, 0.5), Size = UDim2.fromOffset(H * 0.03, 2), BackgroundColor3 = VERDE })
	F(fpm, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromOffset(2, H * 0.02), BackgroundColor3 = VERDE })

	-- fitas
	local function fita(x, larg, faixa, passoRotulo, passoTraco, lado)
		local f = F(pai, { Position = UDim2.fromOffset(x, H * 0.14), Size = UDim2.fromOffset(larg, H * 0.68), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, ClipsDescendants = true })
		local itens = {}
		local n = math.floor(faixa / passoTraco) + 2
		for i = 1, n do
			local traco = F(f, { AnchorPoint = Vector2.new(lado == "esq" and 1 or 0, 0.5), Size = UDim2.fromOffset(larg * 0.18, 2) })
			local rot = T(f, "", H * 0.038, { AnchorPoint = Vector2.new(lado == "esq" and 1 or 0, 0.5), Size = UDim2.fromOffset(larg * 0.75, H * 0.05),
				TextXAlignment = lado == "esq" and Enum.TextXAlignment.Right or Enum.TextXAlignment.Left })
			itens[i] = { traco, rot }
		end
		local caixa = F(pai, { AnchorPoint = Vector2.new(lado == "esq" and 0 or 1, 0.5), Position = UDim2.fromOffset(lado == "esq" and x - 2 or x + larg + 2, H * 0.48),
			Size = UDim2.fromOffset(larg + 4, H * 0.085), BackgroundColor3 = Color3.new(0, 0, 0) })
		contorno(caixa, BRANCO, 2)
		local valor = T(caixa, "", H * 0.06, { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, Font = MONO })
		return function(v)
			local alturaF = H * 0.68
			local px = alturaF / faixa
			local base = math.floor(v / passoTraco) * passoTraco
			for i, it in ipairs(itens) do
				local val = base + (i - math.floor(#itens / 2)) * passoTraco
				local y = alturaF / 2 - (val - v) * px
				it[1].Position = UDim2.fromOffset(lado == "esq" and larg or 0, y)
				it[2].Position = UDim2.fromOffset(lado == "esq" and larg * 0.78 or larg * 0.22, y)
				it[2].Text = (val % passoRotulo == 0 and val >= 0) and tostring(val) or ""
				it[1].Size = UDim2.fromOffset(val % passoRotulo == 0 and larg * 0.18 or larg * 0.1, 2)
			end
			valor.Text = tostring(math.floor(v + 0.5))
		end
	end
	local fitaVel = fita(W * 0.03, W * 0.15, 80, 20, 10, "esq")
	local fitaAlt = fita(W * 0.76, W * 0.17, 800, 200, 100, "dir")
	-- variometro
	local vsi = F(pai, { Position = UDim2.fromOffset(W * 0.945, H * 0.22), Size = UDim2.fromOffset(W * 0.045, H * 0.52), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45 })
	for _, k in ipairs({ -2, -1, 0, 1, 2 }) do
		F(vsi, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, -k * H * 0.12), Size = UDim2.fromOffset(W * 0.015, 2) })
	end
	local vsiP = F(vsi, { AnchorPoint = Vector2.new(0, 0.5), Size = UDim2.fromOffset(W * 0.045, 3), BackgroundColor3 = VERDE })
	-- rumo
	local rumoF = F(pai, { Position = UDim2.fromOffset(W * 0.2, H * 0.885), Size = UDim2.fromOffset(W * 0.56, H * 0.1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, ClipsDescendants = true })
	local rumoItens = {}
	for i = 1, 15 do
		rumoItens[i] = { F(rumoF, { AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.fromOffset(2, H * 0.02) }),
			T(rumoF, "", H * 0.035, { AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.fromOffset(W * 0.06, H * 0.05), TextXAlignment = Enum.TextXAlignment.Center }) }
	end
	local caixaRumo = F(pai, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromOffset(W * 0.48, H * 0.885), Size = UDim2.fromOffset(W * 0.1, H * 0.06), BackgroundColor3 = Color3.new(0, 0, 0) })
	contorno(caixaRumo, BRANCO, 2)
	local txtRumo = T(caixaRumo, "", H * 0.045, { Size = UDim2.fromScale(1, 1) })
	-- dados auxiliares e anunciador de modos
	local info = T(pai, "", H * 0.034, { Position = UDim2.fromOffset(W * 0.03, H * 0.84), Size = UDim2.fromOffset(W * 0.17, H * 0.15), TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top, TextColor3 = BRANCO })
	local fma = F(pai, { Size = UDim2.fromOffset(W, H * 0.07), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.2 })
	local modos = {}
	for i = 1, 4 do
		modos[i] = T(fma, "", H * 0.036, { Position = UDim2.fromOffset((i - 1) * W / 4, 0), Size = UDim2.fromOffset(W / 4, H * 0.07), TextColor3 = VERDE })
		if i > 1 then F(fma, { Position = UDim2.fromOffset((i - 1) * W / 4, H * 0.01), Size = UDim2.fromOffset(1, H * 0.05), BackgroundColor3 = Color3.fromRGB(120, 120, 120) }) end
	end
	local alertaTxt = T(pai, "", H * 0.05, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(W / 2, H * 0.7), Size = UDim2.fromOffset(W * 0.4, H * 0.07), TextColor3 = VERMELHO, Font = MONO })
	local piscar = 0

	function o.Atualizar(s, ctx, dt)
		local kt = (s.IAS or 0) * 1.943844
		local ft = (s.Altitude or 0) * 3.28084
		local fpmv = (s.VS or 0) * 196.85
		local arf, inc = s.Arfagem or 0, s.Inclinacao or 0
		disco.Rotation = -inc
		local r = math.rad(inc)
		local d = arf * pxGrau
		disco.Position = UDim2.fromOffset(cx - math.sin(r) * d, cy + math.cos(r) * d)
		girador.Rotation = -inc
		-- FPM: angulo de trajetoria e deriva em relacao ao nariz
		local gama = math.deg(math.atan2(s.VS or 0, math.max(s.V or 1, 1)))
		local beta = s.BetaGraus or 0
		fpm.Position = UDim2.fromOffset(cx - beta * pxGrau, cy - (gama - arf) * pxGrau)
		fpm.Visible = (s.V or 0) > 15
		fitaVel(kt)
		fitaAlt(ft)
		vsiP.Position = UDim2.new(0, 0, 0.5, -math.clamp(fpmv / 1000, -2.2, 2.2) * H * 0.12)
		local rumo = s.Rumo or 0
		local base = math.floor(rumo / 5) * 5
		local pxG = W * 0.56 / 50
		for i, it in ipairs(rumoItens) do
			local val = base + (i - 8) * 5
			local x = W * 0.28 + (val - rumo) * pxG
			it[1].Position = UDim2.fromOffset(x, 0)
			it[1].Size = UDim2.fromOffset(2, (val % 10 == 0) and H * 0.025 or H * 0.012)
			it[2].Position = UDim2.fromOffset(x, H * 0.028)
			local v = val % 360
			it[2].Text = (val % 30 == 0) and ((v == 0 and "N") or (v == 90 and "L") or (v == 180 and "S") or (v == 270 and "O") or tostring(v / 10)) or ""
		end
		txtRumo.Text = string.format("%03d", math.floor(rumo + 0.5) % 360)
		info.Text = string.format("G  %.1f\nM  %.2f\nα  %.1f", s.Nz or 1, s.Mach or 0, s.AlfaGraus or 0)
		local P = s.P
		modos[1].Text = (P.Tipo == "jato") and (((s.PosCombustor or 0) > 0.5) and "MAX AB" or "MIL/MAN") or "PWR MAN"
		modos[2].Text = s.EmSolo and "SOLO" or "VOO"
		modos[3].Text = (s.Trem or 0) > 0.98 and "TREM DN" or ((s.Trem or 0) < 0.02 and "TREM UP" or "TREM TRS")
		modos[3].TextColor3 = ((s.Trem or 0) > 0.02 and (s.Trem or 0) < 0.98) and AMBAR or VERDE
		modos[4].Text = P.FBW and "FBW NORM" or "MAN"
		piscar = piscar + (dt or 0)
		local agl = (s.AGL or 0) * 3.28084
		local msg = ""
		if s.AvisoEstol then msg = "ESTOL"
		elseif agl < 500 and fpmv < -2500 and not s.EmSolo then msg = "PUXE PARA CIMA" end
		alertaTxt.Text = msg
		alertaTxt.Visible = msg ~= "" and math.floor(piscar * 3) % 2 == 0
	end
	return o
end

-- MAPA ------------------------------------------------------------------------------------
local function mapa(pai, W, H)
	local o = {}
	local fundo = recorte(pai, { Size = UDim2.fromOffset(W, H), BackgroundColor3 = Color3.fromRGB(8, 14, 20) })
	local cx, cy = W / 2, H * 0.74
	local raioMax = H * 0.66
	local alcanceKm = 20
	-- grade do terreno e campos (gira com o rumo)
	local mundo = F(fundo, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(cx, cy), Size = UDim2.fromOffset(4, 4), BackgroundTransparency = 1 })
	local pista = F(mundo, { AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = BRANCO })
	local eixo = F(mundo, { AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = CIANO, BackgroundTransparency = 0.4 })
	local nomeBase = T(mundo, "BASE", H * 0.035, { AnchorPoint = Vector2.new(0, 0.5), TextColor3 = CIANO, Size = UDim2.fromOffset(W * 0.2, H * 0.05), TextXAlignment = Enum.TextXAlignment.Left })
	local linhasGrade = {}
	for i = 1, 14 do
		linhasGrade[i] = F(mundo, { AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = Color3.fromRGB(40, 70, 60), BackgroundTransparency = 0.3 })
	end
	local alvo = F(mundo, { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(H * 0.04, H * 0.04), Rotation = 45, BackgroundTransparency = 1, Visible = false })
	contorno(alvo, MAGENTA, 3)
	local rota = F(fundo, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromOffset(cx, cy), BackgroundColor3 = MAGENTA, Visible = false })
	-- aneis de distancia e rosa dos ventos (gira)
	for _, f in ipairs({ 0.5, 1 }) do
		local anel = F(fundo, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(cx, cy), Size = UDim2.fromOffset(raioMax * 2 * f, raioMax * 2 * f), BackgroundTransparency = 1 })
		canto(anel)
		contorno(anel, Color3.fromRGB(160, 160, 160), f == 1 and 2 or 1)
	end
	local rosa = F(fundo, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(cx, cy), Size = UDim2.fromOffset(2, 2), BackgroundTransparency = 1 })
	for a = 0, 355, 5 do
		local rad = math.rad(a)
		local maior = a % 30 == 0
		F(rosa, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(math.sin(rad) * (raioMax - (maior and 8 or 4)), -math.cos(rad) * (raioMax - (maior and 8 or 4))),
			Size = UDim2.fromOffset(2, maior and 16 or 8), Rotation = a })
		if maior then
			local txt = (a == 0 and "N") or (a == 90 and "L") or (a == 180 and "S") or (a == 270 and "O") or tostring(a / 10)
			T(rosa, txt, H * 0.04, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(math.sin(rad) * (raioMax - 32), -math.cos(rad) * (raioMax - 32)),
				Size = UDim2.fromOffset(H * 0.08, H * 0.05), Rotation = a, TextColor3 = (a == 0) and CIANO or BRANCO })
		end
	end
	-- simbolo da aeronave
	F(fundo, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(cx, cy), Size = UDim2.fromOffset(4, H * 0.07) })
	F(fundo, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(cx, cy - H * 0.008), Size = UDim2.fromOffset(H * 0.07, 4) })
	F(fundo, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(cx, cy + H * 0.03), Size = UDim2.fromOffset(H * 0.035, 3) })
	F(fundo, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromOffset(cx, cy - H * 0.035), Size = UDim2.fromOffset(2, raioMax - H * 0.035), BackgroundTransparency = 0.6 })
	-- textos
	local topo = T(fundo, "", H * 0.045, { Position = UDim2.fromOffset(0, H * 0.01), Size = UDim2.fromOffset(W, H * 0.06), TextColor3 = BRANCO })
	local gs = T(fundo, "", H * 0.036, { Position = UDim2.fromOffset(W * 0.03, H * 0.01), Size = UDim2.fromOffset(W * 0.3, H * 0.06), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = VERDE })
	T(fundo, alcanceKm .. " km", H * 0.034, { Position = UDim2.fromOffset(W * 0.7, H * 0.01), Size = UDim2.fromOffset(W * 0.27, H * 0.06), TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = CIANO })
	local dist = T(fundo, "", H * 0.034, { Position = UDim2.fromOffset(W * 0.6, H * 0.92), Size = UDim2.fromOffset(W * 0.37, H * 0.06), TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = MAGENTA })

	function o.Atualizar(s, ctx)
		local px = raioMax / (alcanceKm * 1000)
		local rumo = s.Rumo or 0
		mundo.Rotation = -rumo
		rosa.Rotation = -rumo
		-- o mundo gira em torno da aeronave: posicoes relativas (x para leste, -z para norte)
		local function rel(x, z)
			return UDim2.fromOffset((x - s.px) * px + 2, (z - s.pz) * px + 2)
		end
		local cab = 1500
		pista.Position = rel(0, 0)
		pista.Size = UDim2.fromOffset(math.max(3, 45 * px * 3), math.max(6, cab * 2 * px))
		eixo.Position = rel(0, cab + 6000)
		eixo.Size = UDim2.fromOffset(1, 12000 * px)
		nomeBase.Position = rel(400, 0)
		local passo = 5000
		local gx = math.floor(s.px / passo) * passo
		local gz = math.floor(s.pz / passo) * passo
		for i = 1, 7 do
			local l = linhasGrade[i]
			l.Position = rel(gx + (i - 4) * passo, s.pz)
			l.Size = UDim2.fromOffset(1, raioMax * 2.4)
			local l2 = linhasGrade[i + 7]
			l2.Position = rel(s.px, gz + (i - 4) * passo)
			l2.Size = UDim2.fromOffset(raioMax * 2.4, 1)
		end
		local a = ctx and ctx.AlvoMapa
		if a then
			alvo.Visible = true
			alvo.Position = rel(a.X, a.Z)
			local dx, dz = a.X - s.px, a.Z - s.pz
			local d = math.sqrt(dx * dx + dz * dz)
			local brg = math.deg(math.atan2(dx, -dz)) % 360
			local relAng = math.rad(brg - rumo)
			local comp = math.min(d * px, raioMax)
			rota.Visible = true
			rota.AnchorPoint = Vector2.new(0.5, 0.5)
			rota.Size = UDim2.fromOffset(2, comp)
			rota.Rotation = brg - rumo
			rota.Position = UDim2.fromOffset(cx + math.sin(relAng) * comp / 2, cy - math.cos(relAng) * comp / 2)
			dist.Text = string.format("WPT %03d° %.1f km", math.floor(brg + 0.5), d / 1000)
		else
			alvo.Visible = false
			rota.Visible = false
			dist.Text = ""
		end
		topo.Text = string.format("RUMO %03d", math.floor(rumo + 0.5) % 360)
		gs.Text = string.format("GS %d", math.floor((s.V or 0) * 1.943844 + 0.5))
	end
	return o
end

-- MOTOR / SISTEMAS -------------------------------------------------------------------------
local function indicadorArco(pai, cx, cy, r, titulo, faixas, maximo)
	-- faixas: { {de, ate, cor} } em fracao 0..1 do arco (210 graus)
	local a0, a1 = -120, 90
	for _, fx in ipairs(faixas) do
		arco(pai, cx, cy, r, a0 + fx[1] * (a1 - a0), a0 + fx[2] * (a1 - a0), 4, r * 0.12, 3, fx[3])
	end
	arco(pai, cx, cy, r * 0.86, a0, a1, (a1 - a0) / 10, r * 0.1, 2, BRANCO)
	local piv = F(pai, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(cx, cy), Size = UDim2.fromOffset(2, 2), BackgroundTransparency = 1 })
	local ponteiro = F(piv, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromOffset(1, 1), Size = UDim2.fromOffset(4, r * 0.9) })
	local caixa = F(pai, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromOffset(cx + r * 0.08, cy + r * 0.35), Size = UDim2.fromOffset(r * 1.05, r * 0.42), BackgroundColor3 = Color3.new(0, 0, 0) })
	contorno(caixa, BRANCO, 2)
	local valor = T(caixa, "", r * 0.32, { Size = UDim2.fromScale(1, 1) })
	T(pai, titulo, r * 0.22, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(cx, cy + r * 0.62), Size = UDim2.fromOffset(r * 2, r * 0.3), TextColor3 = CIANO })
	return function(frac, texto)
		piv.Rotation = a0 + math.clamp(frac, 0, 1.05) * (a1 - a0)
		valor.Text = texto
	end
end

local function motor(pai, W, H)
	local o = {}
	F(pai, { Size = UDim2.fromOffset(W, H), BackgroundColor3 = PRETO })
	local r = math.min(W * 0.2, H * 0.17)
	local ind1, ind2
	o.Iniciado = false
	local tituloEsq, tituloDir
	local col1, col2 = W * 0.27, W * 0.72
	local fluxo = T(pai, "", H * 0.04, { Position = UDim2.fromOffset(W * 0.05, H * 0.42), Size = UDim2.fromOffset(W * 0.9, H * 0.06), TextXAlignment = Enum.TextXAlignment.Left })
	local comb = T(pai, "", H * 0.05, { Position = UDim2.fromOffset(W * 0.05, H * 0.49), Size = UDim2.fromOffset(W * 0.9, H * 0.07), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = BRANCO })
	local barra = F(pai, { Position = UDim2.fromOffset(W * 0.05, H * 0.57), Size = UDim2.fromOffset(W * 0.9, H * 0.02), BackgroundColor3 = Color3.fromRGB(40, 40, 40) })
	local barraV = F(barra, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = VERDE })
	-- trem (3 luzes), flape, freio
	local tremF = F(pai, { Position = UDim2.fromOffset(W * 0.05, H * 0.63), Size = UDim2.fromOffset(W * 0.42, H * 0.2), BackgroundTransparency = 1 })
	T(tremF, "TREM", H * 0.035, { Size = UDim2.fromOffset(W * 0.42, H * 0.05), TextColor3 = CIANO })
	local luzes = {}
	for i, p in ipairs({ { 0.5, 0.35 }, { 0.2, 0.72 }, { 0.8, 0.72 } }) do
		local l = F(tremF, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(p[1], p[2]), Size = UDim2.fromOffset(W * 0.1, H * 0.065), BackgroundColor3 = Color3.new(0, 0, 0) })
		contorno(l, BRANCO, 1)
		luzes[i] = T(l, "", H * 0.035, { Size = UDim2.fromScale(1, 1) })
	end
	local sist = T(pai, "", H * 0.036, { Position = UDim2.fromOffset(W * 0.52, H * 0.63), Size = UDim2.fromOffset(W * 0.45, H * 0.2), TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top, TextColor3 = BRANCO })
	local alertas = F(pai, { Position = UDim2.fromOffset(W * 0.04, H * 0.84), Size = UDim2.fromOffset(W * 0.92, H * 0.14), BackgroundColor3 = Color3.fromRGB(14, 14, 16) })
	contorno(alertas, Color3.fromRGB(80, 80, 80), 1)
	local linhasAlerta = {}
	for i = 1, 3 do
		linhasAlerta[i] = T(alertas, "", H * 0.034, { Position = UDim2.fromOffset(W * 0.03, (i - 1) * H * 0.045), Size = UDim2.fromOffset(W * 0.9, H * 0.045), TextXAlignment = Enum.TextXAlignment.Left })
	end

	function o.Atualizar(s, ctx)
		local P = s.P
		local jato = P.Tipo == "jato"
		if not o.Iniciado then
			o.Iniciado = true
			if jato then
				ind1 = indicadorArco(pai, col1, H * 0.2, r, "N2 %", { { 0, 0.85, Color3.fromRGB(70, 70, 70) }, { 0.85, 0.97, VERDE }, { 0.97, 1, VERMELHO } })
				ind2 = indicadorArco(pai, col2, H * 0.2, r, "T5 °C", { { 0, 0.8, Color3.fromRGB(70, 70, 70) }, { 0.8, 0.92, AMBAR }, { 0.92, 1, VERMELHO } })
			else
				ind1 = indicadorArco(pai, col1, H * 0.2, r, "TQ %", { { 0, 0.9, VERDE }, { 0.9, 1, VERMELHO } })
				ind2 = indicadorArco(pai, col2, H * 0.2, r, "ITT °C", { { 0, 0.82, VERDE }, { 0.82, 0.93, AMBAR }, { 0.93, 1, VERMELHO } })
			end
		end
		local n = s.N or 0
		local carga = jato and n or (s.FracaoMotor or 0)
		local temp = s.MotorLigado and (jato and (420 + carga * 380 + ((s.PosCombustor or 0) > 0.5 and 60 or 0)) or (480 + carga * 280)) or 20
		ind1(carga, string.format("%d", math.floor(carga * 100 + 0.5)))
		ind2(temp / 1000, string.format("%d", math.floor(temp)))
		local ff = s.MotorLigado and (P.Consumo or 0.1) * (0.25 + carga) * 3600 * (((s.PosCombustor or 0) > 0.5) and 2.6 or 1) or 0
		fluxo.Text = string.format("FF %5d kg/h   %s", math.floor(ff), jato and string.format("N1 %d%%", math.floor(n * 96)) or string.format("NP %d", s.MotorLigado and 2000 or 0))
		local frac = math.clamp((s.Combustivel or 0) / (P.Combustivel or 1), 0, 1)
		comb.Text = string.format("COMB %5d kg", math.floor(s.Combustivel or 0))
		barraV.Size = UDim2.fromScale(frac, 1)
		barraV.BackgroundColor3 = frac < 0.15 and AMBAR or VERDE
		local tr = s.Trem or 0
		for i = 1, 3 do
			local l = luzes[i]
			if not P.TremRetratil or tr > 0.98 then
				l.Text = "DN"
				l.TextColor3 = VERDE
			elseif tr < 0.02 then
				l.Text = "UP"
				l.TextColor3 = BRANCO
			else
				l.Text = "TRS"
				l.TextColor3 = AMBAR
			end
		end
		local est = ctx and ctx.Estados or {}
		sist.Text = string.format("FLAPE %d%%\nFREIO AR %s\nHID 1 %s\nGER %s", math.floor((s.Flap or 0) * 100 + 0.5),
			(s.AeroFreio or 0) > 0.5 and "ABERTO" or "FECHADO", est.Bateria and "3000" or "   0", s.MotorLigado and "ON" or "OFF")
		local msgs = {}
		if s.AvisoEstol then table.insert(msgs, { "ESTOL", VERMELHO }) end
		if not s.MotorLigado then table.insert(msgs, { "MOTOR DESLIGADO", AMBAR }) end
		if frac < 0.15 then table.insert(msgs, { "COMBUSTÍVEL BAIXO", AMBAR }) end
		if est.FreioEst then table.insert(msgs, { "FREIO DE ESTACIONAMENTO", BRANCO }) end
		if s.Partindo then table.insert(msgs, { "PARTIDA EM CURSO", BRANCO }) end
		if not est.Bateria then table.insert(msgs, { "BATERIA DESLIGADA", AMBAR }) end
		for i = 1, 3 do
			local m = msgs[i]
			linhasAlerta[i].Text = m and m[1] or ""
			linhasAlerta[i].TextColor3 = m and m[2] or BRANCO
		end
	end
	return o
end

-- ISIS (reserva) ---------------------------------------------------------------------------
local function isis(pai, W, H)
	local o = {}
	F(pai, { Size = UDim2.fromOffset(W, H), BackgroundColor3 = PRETO })
	local att = recorte(pai, { Position = UDim2.fromOffset(W * 0.2, H * 0.15), Size = UDim2.fromOffset(W * 0.6, H * 0.7), BackgroundColor3 = TERRA })
	local disco = F(att, { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(W * 3, H * 6), BackgroundTransparency = 1 })
	F(disco, { Size = UDim2.fromScale(1, 0.5), BackgroundColor3 = CEU })
	F(disco, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, 0, 0, 2) })
	for _, s in ipairs({ -1, 1 }) do
		F(att, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, s * W * 0.12, 0.5, 0), Size = UDim2.fromOffset(W * 0.12, 4), BackgroundColor3 = AMBAR })
	end
	local vel = T(pai, "", H * 0.12, { Position = UDim2.fromOffset(0, H * 0.4), Size = UDim2.fromOffset(W * 0.2, H * 0.15) })
	local alt = T(pai, "", H * 0.1, { Position = UDim2.fromOffset(W * 0.8, H * 0.4), Size = UDim2.fromOffset(W * 0.2, H * 0.15) })
	local rumo = T(pai, "", H * 0.1, { Position = UDim2.fromOffset(W * 0.3, H * 0.86), Size = UDim2.fromOffset(W * 0.4, H * 0.13) })
	function o.Atualizar(s)
		local px = H * 0.7 / 40
		disco.Rotation = -(s.Inclinacao or 0)
		local r = math.rad(s.Inclinacao or 0)
		local d = (s.Arfagem or 0) * px
		disco.Position = UDim2.fromOffset(W * 0.3 - math.sin(r) * d, H * 0.35 + math.cos(r) * d)
		vel.Text = tostring(math.floor((s.IAS or 0) * 1.943844 + 0.5))
		alt.Text = tostring(math.floor((s.Altitude or 0) * 3.28084 / 10 + 0.5) * 10)
		rumo.Text = string.format("%03d", math.floor((s.Rumo or 0) + 0.5) % 360)
	end
	return o
end

local function ufcp(pai, W, H)
	local o = {}
	F(pai, { Size = UDim2.fromOffset(W, H), BackgroundColor3 = Color3.fromRGB(6, 14, 8) })
	local l1 = T(pai, "", H * 0.38, { Position = UDim2.fromOffset(W * 0.02, H * 0.05), Size = UDim2.fromOffset(W * 0.96, H * 0.45), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = VERDE })
	local l2 = T(pai, "", H * 0.38, { Position = UDim2.fromOffset(W * 0.02, H * 0.5), Size = UDim2.fromOffset(W * 0.96, H * 0.45), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = VERDE })
	function o.Atualizar(s)
		l1.Text = string.format("COM1 121.500  NAV 113.20  HDG %03d", math.floor((s.Rumo or 0) + 0.5) % 360)
		l2.Text = string.format("BARO 1013  ALT %05d  CMB %04d", math.floor((s.Altitude or 0) * 3.28084), math.floor(s.Combustivel or 0))
	end
	return o
end

local function anunciadores(pai, W, H)
	local o = {}
	F(pai, { Size = UDim2.fromOffset(W, H), BackgroundColor3 = Color3.fromRGB(16, 16, 18) })
	local nomes = { "ESTOL", "PARTIDA", "BATERIA", "BOMBA", "FLAPE", "TREM", "GERADOR", "COMB BX" }
	local luz = {}
	for i, n in ipairs(nomes) do
		local f = F(pai, { Position = UDim2.fromOffset(W * 0.06, H * 0.02 + (i - 1) * H * 0.122), Size = UDim2.fromOffset(W * 0.88, H * 0.105), BackgroundColor3 = Color3.fromRGB(26, 26, 28) })
		luz[n] = { F = f, T = T(f, n, H * 0.05, { Size = UDim2.fromScale(1, 1), Font = Enum.Font.GothamBold, TextColor3 = Color3.fromRGB(70, 70, 70) }) }
	end
	function o.Atualizar(s, ctx)
		local est = ctx and ctx.Estados or {}
		local function acender(n, ligado, cor)
			local l = luz[n]
			l.F.BackgroundColor3 = ligado and cor or Color3.fromRGB(26, 26, 28)
			l.T.TextColor3 = ligado and Color3.new(0, 0, 0) or Color3.fromRGB(70, 70, 70)
		end
		acender("ESTOL", s.AvisoEstol, VERMELHO)
		acender("PARTIDA", s.Partindo == true, AMBAR)
		acender("BATERIA", est.Bateria, VERDE)
		acender("BOMBA", est.Bomba, VERDE)
		acender("FLAPE", (s.Flap or 0) > 0.05, VERDE)
		acender("TREM", (s.Trem or 0) > 0.98, VERDE)
		acender("GERADOR", not s.MotorLigado, AMBAR)
		acender("COMB BX", (s.Combustivel or 0) / (s.P.Combustivel or 1) < 0.15, AMBAR)
	end
	return o
end

-- WAD do F-39E: tres portais numa tela so
local function wad(pai, W, H)
	local o = {}
	F(pai, { Size = UDim2.fromOffset(W, H), BackgroundColor3 = PRETO })
	local barraH = H * 0.07
	local topo = F(pai, { Size = UDim2.fromOffset(W, barraH), BackgroundColor3 = Color3.fromRGB(14, 16, 20) })
	local rotulos = { "PFD", "TAC", "SYS" }
	local larg = { 0.32, 0.4, 0.28 }
	local x = 0
	local portais = {}
	for i = 1, 3 do
		local w = W * larg[i]
		T(topo, rotulos[i], barraH * 0.6, { Position = UDim2.fromOffset(x, 0), Size = UDim2.fromOffset(w, barraH), TextColor3 = CIANO })
		local p = F(pai, { Position = UDim2.fromOffset(x + 2, barraH + 2), Size = UDim2.fromOffset(w - 4, H - barraH - 4), BackgroundTransparency = 1, ClipsDescendants = true })
		portais[i] = { Quadro = p, W = w - 4, H = H - barraH - 4 }
		if i > 1 then F(pai, { Position = UDim2.fromOffset(x - 1, barraH), Size = UDim2.fromOffset(2, H - barraH), BackgroundColor3 = Color3.fromRGB(60, 60, 60) }) end
		x = x + w
	end
	local relogio = T(topo, "", barraH * 0.55, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromOffset(W - 6, 0), Size = UDim2.fromOffset(W * 0.12, barraH), TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = VERDE })
	local a = pfd(portais[1].Quadro, portais[1].W, portais[1].H)
	local b = mapa(portais[2].Quadro, portais[2].W, portais[2].H)
	local c = motor(portais[3].Quadro, portais[3].W, portais[3].H)
	o.Portal = portais[2]
	function o.Atualizar(s, ctx, dt)
		a.Atualizar(s, ctx, dt)
		b.Atualizar(s, ctx, dt)
		c.Atualizar(s, ctx, dt)
		relogio.Text = os.date("%H:%M:%S")
	end
	return o
end

AV.Paginas = { PFD = pfd, MAPA = mapa, MOTOR = motor, ISIS = isis, UFCP = ufcp, ANUN = anunciadores, WAD = wad }

-- INSTRUMENTOS ANALOGICOS ------------------------------------------------------------------
-- Mostrador redondo: fundo preto fosco, escala branca, numeros, ponteiro com contrapeso.
local function face(pai, S)
	local f = F(pai, { Size = UDim2.fromOffset(S, S), BackgroundColor3 = Color3.fromRGB(14, 14, 15) })
	canto(f)
	return f
end

local function escala(f, S, a0, a1, passoMaior, subdiv, numeros, rotulosFn)
	local cx, cy = S / 2, S / 2
	local r = S * 0.47
	local a = a0
	local k = 0
	local passo = passoMaior / subdiv
	while a <= a1 + 0.01 do
		local maior = k % subdiv == 0
		arco(f, cx, cy, r, a, a, 1, maior and S * 0.08 or S * 0.045, maior and 3 or 2, BRANCO)
		if maior and numeros then
			local txt = rotulosFn and rotulosFn(k / subdiv) or tostring(k / subdiv)
			if txt ~= "" then
				local rad = math.rad(a)
				T(f, txt, S * 0.085, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(cx + math.sin(rad) * r * 0.7, cy - math.cos(rad) * r * 0.7), Size = UDim2.fromOffset(S * 0.2, S * 0.1), Font = Enum.Font.GothamBold })
			end
		end
		a = a + passo
		k = k + 1
	end
end

local function ponteiro(f, S, comp, larg, cor)
	local piv = F(f, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(2, 2), BackgroundTransparency = 1, ZIndex = 4 })
	F(piv, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromOffset(1, 1 + S * 0.08), Size = UDim2.fromOffset(larg, S * comp), BackgroundColor3 = cor or BRANCO, ZIndex = 4 })
	local cubo = F(f, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(S * 0.08, S * 0.08), BackgroundColor3 = Color3.fromRGB(40, 40, 40), ZIndex = 5 })
	canto(cubo)
	return piv
end

local function titulo(f, S, t, y)
	T(f, t, S * 0.07, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(S / 2, S * (y or 0.68)), Size = UDim2.fromOffset(S * 0.5, S * 0.09), Font = SANS, TextColor3 = Color3.fromRGB(200, 200, 200) })
end

local MOSTRADORES = {}

function MOSTRADORES.ASI(pai, S)
	local f = face(pai, S)
	-- 40 a 300 kt em 320 graus
	arco(f, S / 2, S / 2, S * 0.47, 0 + (60 - 40) / 260 * 320, (130 - 40) / 260 * 320, 3, S * 0.03, 3, Color3.fromRGB(255, 255, 255))
	arco(f, S / 2, S / 2, S * 0.45, (75 - 40) / 260 * 320, (230 - 40) / 260 * 320, 3, S * 0.035, 3, VERDE)
	arco(f, S / 2, S / 2, S * 0.45, (230 - 40) / 260 * 320, (270 - 40) / 260 * 320, 3, S * 0.035, 3, AMBAR)
	escala(f, S, 0, 320, 320 / 13 * 2, 2, true, function(i) return tostring(40 + i * 40) end)
	titulo(f, S, "NÓS")
	local p = ponteiro(f, S, 0.44, 5)
	return function(s) p.Rotation = (math.clamp((s.IAS or 0) * 1.943844, 40, 300) - 40) / 260 * 320 end
end

function MOSTRADORES.ALT(pai, S)
	local f = face(pai, S)
	escala(f, S, 0, 360, 36, 5, true, function(i) return i < 10 and tostring(i) or "" end)
	titulo(f, S, "ALT  ft", 0.3)
	local tambor = F(f, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.66), Size = UDim2.fromOffset(S * 0.36, S * 0.11), BackgroundColor3 = Color3.new(0, 0, 0) })
	contorno(tambor, Color3.fromRGB(90, 90, 90), 1)
	local num = T(tambor, "", S * 0.08, { Size = UDim2.fromScale(1, 1) })
	local p10 = ponteiro(f, S, 0.26, 7)
	local p1 = ponteiro(f, S, 0.42, 4)
	return function(s)
		local ft = (s.Altitude or 0) * 3.28084
		p1.Rotation = (ft % 1000) / 1000 * 360
		p10.Rotation = (ft % 10000) / 10000 * 360
		num.Text = string.format("%05d", math.floor(math.max(ft, 0)))
	end
end

function MOSTRADORES.VSI(pai, S)
	local f = face(pai, S)
	escala(f, S, -170, -10, 40, 2, true, function(i) local v = { "20", "10", "5", "0" } return v[i + 1] or "" end)
	escala(f, S, 10, 170, 40, 2, true, function(i) local v = { "", "5", "10", "20", "" } return v[i + 1] or "" end)
	titulo(f, S, "SUBIDA x100", 0.36)
	local p = ponteiro(f, S, 0.42, 5)
	return function(s)
		local fpm = math.clamp((s.VS or 0) * 196.85, -2000, 2000)
		p.Rotation = -90 + fpm / 2000 * 170
	end
end

function MOSTRADORES.Curva(pai, S)
	local f = face(pai, S)
	for _, a in ipairs({ -90, -70, 70, 90 }) do arco(f, S / 2, S / 2, S * 0.47, a, a, 1, S * 0.09, 4, BRANCO) end
	titulo(f, S, "COORD. DE CURVA", 0.3)
	local asas = F(f, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(S * 0.6, 4), ZIndex = 4 })
	F(asas, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromOffset(4, S * 0.07), ZIndex = 4 })
	local tubo = F(f, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.8), Size = UDim2.fromOffset(S * 0.5, S * 0.1), BackgroundColor3 = Color3.fromRGB(30, 30, 30) })
	canto(tubo)
	F(tubo, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, -S * 0.06, 0.5, 0), Size = UDim2.fromOffset(2, S * 0.1) })
	F(tubo, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, S * 0.06, 0.5, 0), Size = UDim2.fromOffset(2, S * 0.1) })
	local bola = F(tubo, { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(S * 0.085, S * 0.085), BackgroundColor3 = Color3.fromRGB(20, 20, 20), ZIndex = 5 })
	canto(bola)
	contorno(bola, BRANCO, 2)
	return function(s)
		local taxa = math.deg(-(s.wy or 0))
		asas.Rotation = math.clamp(taxa / 3 * 20, -40, 40)
		bola.Position = UDim2.fromScale(0.5 + math.clamp((s.BetaGraus or 0) / 15, -0.4, 0.4), 0.5)
	end
end

function MOSTRADORES.HI(pai, S)
	local f = face(pai, S)
	local cartao = F(f, { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 })
	for a = 0, 355, 5 do
		local maior = a % 10 == 0
		local rad = math.rad(a)
		F(cartao, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(S / 2 + math.sin(rad) * S * 0.44, S / 2 - math.cos(rad) * S * 0.44), Size = UDim2.fromOffset(2, maior and S * 0.07 or S * 0.04), Rotation = a })
		if a % 30 == 0 then
			local t = (a == 0 and "N") or (a == 90 and "L") or (a == 180 and "S") or (a == 270 and "O") or tostring(a / 10)
			T(cartao, t, S * 0.09, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(S / 2 + math.sin(rad) * S * 0.32, S / 2 - math.cos(rad) * S * 0.32), Size = UDim2.fromOffset(S * 0.14, S * 0.1), Rotation = a, Font = Enum.Font.GothamBold })
		end
	end
	F(f, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.02), Size = UDim2.fromOffset(4, S * 0.1), BackgroundColor3 = AMBAR, ZIndex = 4 })
	local av = F(f, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(4, S * 0.3), BackgroundColor3 = AMBAR, ZIndex = 4 })
	F(av, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.35), Size = UDim2.fromOffset(S * 0.22, 4), BackgroundColor3 = AMBAR, ZIndex = 4 })
	return function(s) cartao.Rotation = -(s.Rumo or 0) end
end

function MOSTRADORES.Atitude(pai, S)
	local g = recorte(pai, { Size = UDim2.fromOffset(S, S), BackgroundColor3 = TERRA })
	canto(g)
	local px = S / 60
	local disco = F(g, { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(S * 3, S * 3), BackgroundTransparency = 1 })
	F(disco, { Size = UDim2.fromScale(1, 0.5), BackgroundColor3 = CEU })
	F(disco, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, 0, 0, 3) })
	for k = -4, 4 do
		if k ~= 0 then
			F(disco, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, -k * 10 * px), Size = UDim2.fromOffset(S * (k % 2 == 0 and 0.3 or 0.16), 2) })
		end
	end
	local girador = F(g, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(2, 2), BackgroundTransparency = 1 })
	F(girador, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(1, -S * 0.46), Size = UDim2.fromOffset(S * 0.04, S * 0.06), BackgroundColor3 = BRANCO })
	for _, a in ipairs({ -60, -30, -20, -10, 0, 10, 20, 30, 60 }) do arco(g, S / 2, S / 2, S * 0.48, a, a, 1, S * 0.06, 2, BRANCO) end
	for _, s in ipairs({ -1, 1 }) do
		F(g, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, s * S * 0.16, 0.5, 0), Size = UDim2.fromOffset(S * 0.18, S * 0.035), BackgroundColor3 = AMBAR, ZIndex = 4 })
	end
	F(g, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(S * 0.04, S * 0.04), BackgroundColor3 = AMBAR, ZIndex = 4 })
	return function(s)
		local inc, arf = s.Inclinacao or 0, s.Arfagem or 0
		disco.Rotation = -inc
		girador.Rotation = -inc
		local r = math.rad(inc)
		local d = arf * px
		disco.Position = UDim2.fromOffset(S / 2 - math.sin(r) * d, S / 2 + math.cos(r) * d)
	end
end

function MOSTRADORES.RPM(pai, S)
	local f = face(pai, S)
	arco(f, S / 2, S / 2, S * 0.45, -135 + 0.75 * 270, -135 + 0.97 * 270, 3, S * 0.05, 3, VERDE)
	arco(f, S / 2, S / 2, S * 0.45, -135 + 0.97 * 270, 135, 3, S * 0.05, 3, VERMELHO)
	escala(f, S, -135, 135, 27, 2, true, function(i) return (i % 2 == 0) and tostring(i * 10) or "" end)
	titulo(f, S, "RPM %")
	local p = ponteiro(f, S, 0.42, 5)
	return function(s) p.Rotation = -135 + math.clamp(s.N or 0, 0, 1.05) * 270 end
end

function MOSTRADORES.Comb(pai, S)
	local f = face(pai, S)
	arco(f, S / 2, S / 2, S * 0.45, -120, -100, 3, S * 0.05, 3, VERMELHO)
	escala(f, S, -120, 120, 60, 2, true, function(i) local v = { "0", "¼", "½", "¾", "C" } return v[i + 1] or "" end)
	titulo(f, S, "COMB")
	local p = ponteiro(f, S, 0.42, 5)
	return function(s) p.Rotation = -120 + math.clamp((s.Combustivel or 0) / (s.P.Combustivel or 1), 0, 1) * 240 end
end
MOSTRADORES.Combustivel = MOSTRADORES.Comb

function MOSTRADORES.G(pai, S)
	local f = face(pai, S)
	-- -3 a +9 G
	arco(f, S / 2, S / 2, S * 0.45, -150 + (7.3 + 3) / 12 * 300, 150, 3, S * 0.05, 3, VERMELHO)
	escala(f, S, -150, 150, 50, 2, true, function(i) return tostring(-3 + i * 2) end)
	titulo(f, S, "G")
	local pMax = ponteiro(f, S, 0.38, 3, AMBAR)
	local p = ponteiro(f, S, 0.42, 5)
	local maximo = 1
	return function(s)
		local g = s.Nz or 1
		if g > maximo then maximo = g end
		p.Rotation = -150 + (math.clamp(g, -3, 9) + 3) / 12 * 300
		pMax.Rotation = -150 + (math.clamp(maximo, -3, 9) + 3) / 12 * 300
	end
end
MOSTRADORES.Acelerometro = MOSTRADORES.G

function MOSTRADORES.Relogio(pai, S)
	local f = face(pai, S)
	escala(f, S, 0, 330, 30, 5, true, function(i) return tostring(i == 0 and 12 or i) end)
	local ph = ponteiro(f, S, 0.26, 6)
	local pm = ponteiro(f, S, 0.4, 4)
	local ps = ponteiro(f, S, 0.42, 2, VERMELHO)
	return function()
		local t = os.date("*t")
		ph.Rotation = ((t.hour % 12) + t.min / 60) * 30
		pm.Rotation = t.min * 6
		ps.Rotation = t.sec * 6
	end
end

function MOSTRADORES.Temp(pai, S)
	local f = face(pai, S)
	arco(f, S / 2, S / 2, S * 0.45, -120 + 0.3 * 240, -120 + 0.8 * 240, 3, S * 0.05, 3, VERDE)
	arco(f, S / 2, S / 2, S * 0.45, -120 + 0.9 * 240, 120, 3, S * 0.05, 3, VERMELHO)
	escala(f, S, -120, 120, 48, 2, true, function(i) return tostring(i * 2) end)
	titulo(f, S, "ITT x100")
	local p = ponteiro(f, S, 0.42, 5)
	return function(s)
		local carga = s.FracaoMotor or s.N or 0
		local t = s.MotorLigado and (480 + carga * 280) or 20
		p.Rotation = -120 + math.clamp(t / 1000, 0, 1) * 240
	end
end

function MOSTRADORES.ISIS(pai, S)
	local f = face(pai, S)
	local o = isis(f, S, S)
	return function(s) o.Atualizar(s) end
end

AV.Mostradores = MOSTRADORES

return AV
