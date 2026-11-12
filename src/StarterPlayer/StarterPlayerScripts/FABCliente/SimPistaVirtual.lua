--[[
	FAB - Aerodromo virtual do simulador (cliente)

	Cenario ficticio usado no "voo livre": uma ilha de treino afastada do mapa real,
	com pista 18/36 de 3.000 m, luzes, PAPI, taxiway, patio, hangares e torre.
	Existe so no cliente de quem esta no simulador. A fisica consulta Solo(x, z) em metros.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MD = require(ReplicatedStorage:WaitForChild("FAB"):WaitForChild("MapaDados"))

local PV = {}

local E = MD.StudPorMetro
local CX = 9000          -- centro do cenario em X (metros), fora do limite do oceano real
local ELEV = 1.2         -- altura do solo acima do mar (metros)
local COMP = 3000        -- comprimento da pista (m)
local LARG = 45          -- largura da pista (m)
local MEIA = COMP / 2

PV.CentroX = CX
PV.Elevacao = ELEV

local BRANCO = Color3.fromRGB(240, 240, 234)
local ASFALTO = Color3.fromRGB(54, 55, 58)
local CONCRETO = Color3.fromRGB(150, 150, 146)

-- Solo em metros: devolve altura e tipo ("pista", "grama" ou "agua")
function PV.Solo(x, z)
	local dx, dz = x - CX, z
	if math.abs(dx) <= 2000 and math.abs(dz) <= 3000 then
		local naPista = math.abs(dx) <= LARG / 2 + 7 and math.abs(dz) <= MEIA + 60
		local naTaxi = dx >= 25 and dx <= 345 and dz >= 1300 and dz <= 2020
		local naTaxi2 = dx >= 20 and dx <= 345 and math.abs(dz - 1380) <= 12
		if naPista or naTaxi or naTaxi2 then return ELEV, "pista" end
		return ELEV, "grama"
	end
	return 0, "agua"
end

function PV.Inicio(P)
	return { X = CX, Z = MEIA - 35, Y = ELEV + P.AlturaTrem - 0.03, Rumo = 0, Velocidade = 0, Manete = 0, Trem = 1, Flap = 0 }
end

function PV.Criar(pasta)
	local obj = {}
	local raiz = Instance.new("Folder")
	raiz.Name = "AerodromoVirtual"
	raiz.Parent = pasta
	local base = Vector3.new(CX * E, 0, 0)

	local function parte(nome, tam, pos, cor, mat, extra)
		local p = Instance.new("Part")
		p.Name = nome
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Size = Vector3.new(tam.X * E, tam.Y * E, tam.Z * E)
		local rot = extra and extra.Rot or 0
		p.CFrame = CFrame.new(base + Vector3.new(pos.X * E, pos.Y * E, pos.Z * E)) * CFrame.Angles(0, rot, 0)
		p.Color = cor
		p.Material = mat or Enum.Material.SmoothPlastic
		if extra then
			if extra.Forma then p.Shape = extra.Forma end
			if extra.Sombra then p.CastShadow = true end
		end
		p.Parent = raiz
		return p
	end

	-- faixa fina ao longo de Z, dividida em segmentos de ate 1800 studs
	local function faixaZ(nome, x, z1, z2, larg, y, cor, mat, esp)
		local seg = 1800 / E
		local z = z1
		while z < z2 do
			local z3 = math.min(z + seg, z2)
			parte(nome, Vector3.new(larg, esp or 0.05, z3 - z), Vector3.new(x, y, (z + z3) / 2), cor, mat)
			z = z3
		end
	end

	-- ILHA: base de areia e grama por cima --------------------------------------------------
	local passo = 2000 / E
	local function laje(nome, meiaX, meiaZ, y, esp, cor, mat)
		local x = -meiaX
		while x < meiaX do
			local x2 = math.min(x + passo, meiaX)
			local z = -meiaZ
			while z < meiaZ do
				local z2 = math.min(z + passo, meiaZ)
				parte(nome, Vector3.new(x2 - x, esp, z2 - z), Vector3.new((x + x2) / 2, y, (z + z2) / 2), cor, mat)
				z = z2
			end
			x = x2
		end
	end
	laje("Areia", 2150, 3150, ELEV - 0.9, 1.8, Color3.fromRGB(214, 196, 150), Enum.Material.Sand)
	laje("Grama", 1950, 2950, ELEV - 0.06, 0.12, Color3.fromRGB(84, 118, 62), Enum.Material.Grass)

	-- PISTA ---------------------------------------------------------------------------------
	local y0 = ELEV + 0.02
	faixaZ("Acostamento", 0, -MEIA - 60, MEIA + 60, LARG + 14, y0, Color3.fromRGB(78, 79, 82), Enum.Material.Asphalt, 0.04)
	faixaZ("Pista", 0, -MEIA - 60, MEIA + 60, LARG, y0 + 0.03, ASFALTO, Enum.Material.Asphalt, 0.05)
	local ym = y0 + 0.08
	for _, lado in ipairs({ -1, 1 }) do
		faixaZ("LinhaBorda", lado * (LARG / 2 - 1.2), -MEIA, MEIA, 0.9, ym, BRANCO)
	end
	for z = -MEIA + 120, MEIA - 120, 50 do
		parte("Eixo", Vector3.new(1.2, 0.04, 30), Vector3.new(0, ym, z), BRANCO)
	end
	-- cabeceiras: faixas, numeros e zona de toque
	local function cabeceira(sinal, numero)
		local zc = sinal * (MEIA - 6)
		for i = -5, 5 do
			if i ~= 0 then
				parte("Cabeceira", Vector3.new(1.8, 0.04, 30), Vector3.new(i * 3.6, ym, zc - sinal * 15), BRANCO)
			end
		end
		for _, d in ipairs({ 150, 300, 450, 600 }) do
			local largura = (d == 300) and 3 or 2
			for _, lado in ipairs({ -1, 1 }) do
				parte("ZonaToque", Vector3.new(largura, 0.04, d == 300 and 22 or 22), Vector3.new(lado * 9, ym, sinal * (MEIA - d - 12)), BRANCO)
				parte("ZonaToque", Vector3.new(largura, 0.04, 22), Vector3.new(lado * 12.5, ym, sinal * (MEIA - d - 12)), BRANCO)
			end
		end
		-- numero em sete segmentos; "cima" do numero aponta para o centro da pista
		local segs = { ["3"] = "abcdg", ["6"] = "afedcg", ["1"] = "bc", ["8"] = "abcdefg" }
		local function digito(ch, cx)
			local larg, alt, t = 3.4, 9, 1.1
			local s = segs[ch]
			local function seg(u, v, w, h)
				-- u para a direita de quem aproxima, v para a frente (centro da pista)
				parte("Numero", Vector3.new(w, 0.04, h), Vector3.new(sinal * u, ym, zc - sinal * (30 + 4 + v)), BRANCO)
			end
			local ux = cx
			if s:find("a") then seg(ux, alt - t / 2, larg, t) end
			if s:find("d") then seg(ux, t / 2, larg, t) end
			if s:find("g") then seg(ux, alt / 2, larg, t) end
			if s:find("b") then seg(ux + larg / 2 - t / 2, alt * 0.75, t, alt / 2) end
			if s:find("c") then seg(ux + larg / 2 - t / 2, alt * 0.25, t, alt / 2) end
			if s:find("f") then seg(ux - larg / 2 + t / 2, alt * 0.75, t, alt / 2) end
			if s:find("e") then seg(ux - larg / 2 + t / 2, alt * 0.25, t, alt / 2) end
		end
		digito(string.sub(numero, 1, 1), -3)
		digito(string.sub(numero, 2, 2), 3)
	end
	cabeceira(1, "36")
	cabeceira(-1, "18")

	-- LUZES DE PISTA --------------------------------------------------------------------------
	local function luz(nome, x, z, cor, tam)
		local p = parte(nome, Vector3.new(tam or 0.5, 0.35, tam or 0.5), Vector3.new(x, ELEV + 0.17, z), cor, Enum.Material.Neon)
		return p
	end
	for z = -MEIA, MEIA, 60 do
		for _, lado in ipairs({ -1, 1 }) do
			luz("LuzBorda", lado * (LARG / 2 + 2.5), z, Color3.fromRGB(255, 244, 214))
		end
	end
	for i = -6, 6 do
		luz("LuzCabeceira", i * 3.2, MEIA + 1, Color3.fromRGB(40, 255, 90), 0.7)
		luz("LuzCabeceira", i * 3.2, -MEIA - 1, Color3.fromRGB(255, 40, 30), 0.7)
	end
	-- luzes de aproximacao (cabeceira 36, ao sul)
	for d = 30, 420, 30 do
		for i = -2, 2 do
			luz("Aproximacao", i * 1.5, MEIA + 1 + d, Color3.fromRGB(255, 250, 240), 0.6)
		end
		parte("BarraAprox", Vector3.new(18, 0.3, 0.6), Vector3.new(0, ELEV + 0.15, MEIA + 1 + d), Color3.fromRGB(255, 250, 240), Enum.Material.Neon)
	end
	-- PAPI a esquerda da cabeceira 36
	for i = 0, 3 do
		parte("PAPI", Vector3.new(1.4, 1.1, 1.4), Vector3.new(-(LARG / 2 + 16 + i * 9), ELEV + 0.6, MEIA - 300), Color3.fromRGB(255, 255, 245), Enum.Material.Neon)
	end

	-- TAXIWAY E PATIO ---------------------------------------------------------------------------
	parte("Taxiway", Vector3.new(310, 0.1, 23), Vector3.new(175, ELEV + 0.05, MEIA - 120), ASFALTO, Enum.Material.Asphalt)
	parte("LinhaTaxi", Vector3.new(310, 0.04, 0.35), Vector3.new(175, ELEV + 0.12, MEIA - 120), Color3.fromRGB(240, 200, 20))
	parte("Patio", Vector3.new(320, 0.12, 720), Vector3.new(185, ELEV + 0.06, MEIA + 160), CONCRETO, Enum.Material.Concrete)
	for z = MEIA - 160, MEIA + 480, 40 do
		parte("PosicaoAeronave", Vector3.new(0.4, 0.04, 22), Vector3.new(215, ELEV + 0.14, z), Color3.fromRGB(240, 200, 20))
	end

	-- HANGARES, TORRE E WINDSOCK --------------------------------------------------------------
	local function hangar(x, z)
		local larg, comp, alt = 40, 56, 9
		parte("HangarParede", Vector3.new(larg, alt, comp), Vector3.new(x, ELEV + alt / 2, z), Color3.fromRGB(150, 154, 158), Enum.Material.Metal, { Sombra = true })
		parte("HangarTeto", Vector3.new(comp, 14, larg), Vector3.new(x, ELEV + alt, z), Color3.fromRGB(176, 180, 184), Enum.Material.Metal,
			{ Forma = Enum.PartType.Cylinder, Rot = math.rad(90), Sombra = true })
		parte("HangarPorta", Vector3.new(larg - 6, alt - 1, 0.5), Vector3.new(x, ELEV + (alt - 1) / 2, z - comp / 2 - 0.2), Color3.fromRGB(70, 74, 80), Enum.Material.Metal)
		parte("HangarFaixa", Vector3.new(larg + 0.2, 1.2, comp + 0.2), Vector3.new(x, ELEV + 1.2, z), Color3.fromRGB(0, 70, 140), Enum.Material.SmoothPlastic)
	end
	hangar(330, MEIA + 420)
	hangar(330, MEIA + 340)
	hangar(330, MEIA + 260)
	-- torre
	parte("TorreFuste", Vector3.new(7, 22, 7), Vector3.new(120, ELEV + 11, MEIA + 40), Color3.fromRGB(218, 216, 208), Enum.Material.Concrete, { Sombra = true })
	parte("TorreCabine", Vector3.new(13, 4.4, 13), Vector3.new(120, ELEV + 24.2, MEIA + 40), Color3.fromRGB(40, 70, 84), Enum.Material.Glass, { Sombra = true })
	parte("TorreTeto", Vector3.new(15, 0.8, 15), Vector3.new(120, ELEV + 26.8, MEIA + 40), Color3.fromRGB(218, 216, 208), Enum.Material.Concrete)
	-- windsock
	parte("MastroManga", Vector3.new(0.3, 9, 0.3), Vector3.new(-(LARG / 2 + 40), ELEV + 4.5, 0), Color3.fromRGB(220, 220, 220), Enum.Material.Metal)
	for i = 0, 3 do
		parte("Manga", Vector3.new(1.6 - i * 0.2, 1.4 - i * 0.2, 1.6 - i * 0.2), Vector3.new(-(LARG / 2 + 40) + 0.8 + i * 1.6, ELEV + 9, 0),
			(i % 2 == 0) and Color3.fromRGB(255, 110, 20) or BRANCO, Enum.Material.Fabric, { Forma = Enum.PartType.Cylinder })
	end

	-- ARVORES NAS BORDAS ------------------------------------------------------------------------
	local rng = Random.new(41)
	for z = -2800, 2800, 70 do
		for _, lado in ipairs({ -1, 1 }) do
			local x = lado * (260 + rng:NextNumber(0, 700))
			if not (x > 0 and x < 340 and z > 900 and z < 1750) then
				local alt = rng:NextNumber(9, 16)
				parte("Tronco", Vector3.new(0.7, alt * 0.5, 0.7), Vector3.new(x, ELEV + alt * 0.25, z), Color3.fromRGB(92, 66, 44), Enum.Material.Wood)
				parte("Copa", Vector3.new(alt * 0.7, alt * 0.8, alt * 0.7), Vector3.new(x, ELEV + alt * 0.7, z), Color3.fromRGB(44 + rng:NextInteger(0, 20), 92 + rng:NextInteger(0, 30), 46),
					Enum.Material.Grass, { Forma = Enum.PartType.Ball, Sombra = true })
			end
		end
	end

	function obj.Destruir()
		raiz:Destroy()
	end
	return obj
end

return PV
