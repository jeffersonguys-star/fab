--[[
	FAB - Vila militar (PNR) e equipamentos comunitarios (ModuleScript)

	Fica ao sul da area de ensino: ruas com calcada e iluminacao, casas com telhado de duas
	aguas, varanda, garagem, janelas com moldura, muros e jardins, praca com coreto, quadra,
	capela e clube. Mais ao norte: hospital da base (HABASE) com heliponto e o ginasio.
	1 stud = 0,28 m: casa de 44 x 34 studs = 12 x 9,5 m.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local FAB = ReplicatedStorage:WaitForChild("FAB")
local C = require(FAB:WaitForChild("Construtor"))
local MD = require(FAB:WaitForChild("MapaDados"))

local V = {}

local PALETAS = {
	{ Color3.fromRGB(236, 226, 200), Color3.fromRGB(176, 84, 54) },   -- creme / telha
	{ Color3.fromRGB(240, 240, 234), Color3.fromRGB(150, 70, 48) },   -- branca / telha escura
	{ Color3.fromRGB(226, 214, 168), Color3.fromRGB(120, 60, 46) },   -- amarela clara
	{ Color3.fromRGB(190, 212, 222), Color3.fromRGB(150, 74, 52) },   -- azul claro
	{ Color3.fromRGB(232, 206, 196), Color3.fromRGB(110, 58, 44) },   -- rosada
	{ Color3.fromRGB(206, 212, 190), Color3.fromRGB(160, 78, 52) },   -- verde claro
}
local BRANCO = Color3.fromRGB(244, 244, 240)
local VIDRO = Color3.fromRGB(110, 150, 172)

-- Casa de duas aguas. cf: centro da casa no chao, frente voltada para -Z.
local function casa(pai, cf, rng, comGaragem)
	local m = Instance.new("Model")
	m.Name = "Casa"
	m.Parent = pai
	local L, Pf, A = 44, 34, 12
	local pal = PALETAS[rng:NextInteger(1, #PALETAS)]
	local parede, telha = pal[1], pal[2]
	local function P(nome, tam, off, cor, mat, extra)
		return C.Parte(m, nome, tam, cf * off, cor, mat, extra)
	end
	local CONC, PLAS = Enum.Material.Concrete, Enum.Material.SmoothPlastic

	P("Base", Vector3.new(L + 2, 1.2, Pf + 2), CFrame.new(0, 0.6, 0), Color3.fromRGB(176, 174, 166), CONC)
	-- paredes
	P("ParedeFundo", Vector3.new(L, A, 1), CFrame.new(0, 1.2 + A / 2, Pf / 2 - 0.5), parede, CONC)
	P("ParedeEsq", Vector3.new(1, A, Pf), CFrame.new(-L / 2 + 0.5, 1.2 + A / 2, 0), parede, CONC)
	P("ParedeDir", Vector3.new(1, A, Pf), CFrame.new(L / 2 - 0.5, 1.2 + A / 2, 0), parede, CONC)
	-- frente com vao da porta
	local larguraPorta = 6
	local lateral = (L - larguraPorta) / 2
	P("ParedeFrente", Vector3.new(lateral, A, 1), CFrame.new(-(larguraPorta / 2 + lateral / 2), 1.2 + A / 2, -Pf / 2 + 0.5), parede, CONC)
	P("ParedeFrente", Vector3.new(lateral, A, 1), CFrame.new((larguraPorta / 2 + lateral / 2), 1.2 + A / 2, -Pf / 2 + 0.5), parede, CONC)
	P("VergaPorta", Vector3.new(larguraPorta, A - 9.4, 1), CFrame.new(0, 1.2 + 9.4 + (A - 9.4) / 2, -Pf / 2 + 0.5), parede, CONC)
	-- friso e rodape
	P("Rodape", Vector3.new(L + 0.4, 1.4, Pf + 0.4), CFrame.new(0, 1.9, 0), Color3.fromRGB(150, 146, 138), CONC, { CanCollide = false })

	-- porta e moldura
	P("PortaMoldura", Vector3.new(5.6, 9.6, 0.5), CFrame.new(0, 1.2 + 4.8, -Pf / 2 - 0.1), BRANCO, PLAS, { CanCollide = false })
	P("Porta", Vector3.new(4.6, 9, 0.6), CFrame.new(0, 1.2 + 4.5, -Pf / 2 - 0.2), Color3.fromRGB(104, 70, 46), Enum.Material.Wood, { CanCollide = false })
	P("Macaneta", Vector3.new(0.4, 0.4, 0.4), CFrame.new(1.6, 1.2 + 4.4, -Pf / 2 - 0.65), Color3.fromRGB(210, 190, 90), Enum.Material.Metal, { CanCollide = false })

	-- janelas (moldura, vidro, peitoril e persianas)
	local function janela(x, z, lado, w, h, yc)
		local frente = (lado == "F")
		local rot = frente and CFrame.new() or CFrame.Angles(0, math.rad(90), 0)
		local pos = CFrame.new(x, yc, z) * rot
		local zOff = frente and -0.25 or -0.25
		P("JanelaMoldura", Vector3.new(w + 1, h + 1, 0.4), pos * CFrame.new(0, 0, zOff), BRANCO, PLAS, { CanCollide = false })
		P("JanelaVidro", Vector3.new(w, h, 0.3), pos * CFrame.new(0, 0, zOff - 0.15), VIDRO, Enum.Material.Glass, { Transparency = 0.35, CanCollide = false })
		P("JanelaDivisao", Vector3.new(0.35, h, 0.4), pos * CFrame.new(0, 0, zOff - 0.18), BRANCO, PLAS, { CanCollide = false })
		P("Peitoril", Vector3.new(w + 2, 0.5, 1.2), pos * CFrame.new(0, -(h / 2 + 0.5), zOff - 0.4), Color3.fromRGB(190, 188, 180), CONC, { CanCollide = false })
		P("Persiana", Vector3.new(1.4, h + 0.6, 0.35), pos * CFrame.new(-(w / 2 + 1.5), 0, zOff - 0.1), Color3.fromRGB(70, 96, 78), Enum.Material.Wood, { CanCollide = false })
		P("Persiana", Vector3.new(1.4, h + 0.6, 0.35), pos * CFrame.new((w / 2 + 1.5), 0, zOff - 0.1), Color3.fromRGB(70, 96, 78), Enum.Material.Wood, { CanCollide = false })
	end
	janela(-14, -Pf / 2, "F", 6.5, 5, 7.4)
	janela(14, -Pf / 2, "F", 6.5, 5, 7.4)
	-- laterais: eixo X da parede, olhando para fora
	for _, s in ipairs({ -1, 1 }) do
		local pos = CFrame.new(s * (L / 2), 7.4, -6) * CFrame.Angles(0, math.rad(s > 0 and 90 or -90), 0)
		P("JanelaMoldura", Vector3.new(7.5, 6, 0.4), pos * CFrame.new(0, 0, -0.1), BRANCO, PLAS, { CanCollide = false })
		P("JanelaVidro", Vector3.new(6.5, 5, 0.3), pos * CFrame.new(0, 0, -0.25), VIDRO, Enum.Material.Glass, { Transparency = 0.35, CanCollide = false })
		local pos2 = CFrame.new(s * (L / 2), 7.4, 9) * CFrame.Angles(0, math.rad(s > 0 and 90 or -90), 0)
		P("JanelaMoldura", Vector3.new(7.5, 6, 0.4), pos2 * CFrame.new(0, 0, -0.1), BRANCO, PLAS, { CanCollide = false })
		P("JanelaVidro", Vector3.new(6.5, 5, 0.3), pos2 * CFrame.new(0, 0, -0.25), VIDRO, Enum.Material.Glass, { Transparency = 0.35, CanCollide = false })
	end

	-- telhado de duas aguas (cumeeira ao longo de X), com beiral
	local h = 7
	local meia = Pf / 2 + 2.5
	local ang = math.atan2(h, meia)
	local comp = math.sqrt(h * h + meia * meia)
	for _, s in ipairs({ -1, 1 }) do
		P("Telhado", Vector3.new(L + 5, 0.9, comp), CFrame.new(0, 1.2 + A + h / 2 + 0.3, s * meia / 2) * CFrame.Angles(s * ang, 0, 0), telha, Enum.Material.Slate)
		P("Beiral", Vector3.new(L + 5.2, 0.7, 0.6), CFrame.new(0, 1.2 + A - 0.1 + 0.05, s * (meia + 0.2)) * CFrame.Angles(0, 0, 0), BRANCO, PLAS, { CanCollide = false })
	end
	P("Cumeeira", Vector3.new(L + 5.2, 0.9, 1.4), CFrame.new(0, 1.2 + A + h + 0.55, 0), Color3.fromRGB(140, 66, 46), Enum.Material.Slate)
	-- oitoes (triangulo em degraus)
	for j = 1, 6 do
		local zext = (Pf / 2) * (1 - j / 6)
		local hj = h / 6
		for _, s in ipairs({ -1, 1 }) do
			if zext > 0.2 then
				P("Oitao", Vector3.new(1, hj, zext * 2), CFrame.new(s * (L / 2 - 0.5), 1.2 + A + (j - 0.5) * hj, 0), parede, CONC)
			end
		end
	end
	-- caixa d'agua no telhado e condensadora
	C.Cilindro(m, "CaixaDagua", 5, 5.5, cf * CFrame.new(-10, 1.2 + A + h + 3.2, 3) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(70, 118, 176), Enum.Material.Plastic)
	P("TampaCaixa", Vector3.new(5.2, 0.4, 5.2), CFrame.new(-10, 1.2 + A + h + 6, 3), Color3.fromRGB(52, 90, 140), PLAS, { CanCollide = false })
	m.Parent = pai
	P("Condensadora", Vector3.new(4, 3, 1.6), CFrame.new(L / 2 + 2, 2.7, 9), Color3.fromRGB(214, 214, 210), Enum.Material.Metal)

	-- varanda e pilares
	P("Varanda", Vector3.new(14, 0.8, 7), CFrame.new(0, 1.6, -Pf / 2 - 3.5), Color3.fromRGB(196, 192, 182), CONC)
	P("TetoVaranda", Vector3.new(15, 0.7, 8), CFrame.new(0, 1.2 + 10.6, -Pf / 2 - 3.6), BRANCO, PLAS)
	for _, s in ipairs({ -1, 1 }) do
		P("PilarVaranda", Vector3.new(0.9, 9.4, 0.9), CFrame.new(s * 6.4, 1.2 + 4.7, -Pf / 2 - 6.8), BRANCO, CONC)
	end
	local lum = P("LuzVaranda", Vector3.new(1.2, 0.4, 1.2), CFrame.new(0, 1.2 + 10.1, -Pf / 2 - 1.2), Color3.fromRGB(255, 235, 190), Enum.Material.Neon, nil)

	-- garagem anexa
	if comGaragem then
		local gx = L / 2 + 13
		P("GaragemBase", Vector3.new(26, 1.2, Pf - 8), CFrame.new(gx - 1, 0.6, -2), Color3.fromRGB(176, 174, 166), CONC)
		P("GaragemFundo", Vector3.new(24, 10, 1), CFrame.new(gx, 6.2, Pf / 2 - 4.5), parede, CONC)
		P("GaragemLateral", Vector3.new(1, 10, Pf - 8), CFrame.new(gx + 12, 6.2, -2), parede, CONC)
		P("GaragemFrente", Vector3.new(24, 10, 1), CFrame.new(gx, 6.2, -Pf / 2 + 3.5), parede, CONC)
		P("PortaoGaragem", Vector3.new(16, 8.2, 0.5), CFrame.new(gx, 5.3, -Pf / 2 + 2.9), Color3.fromRGB(210, 210, 206), Enum.Material.Metal)
		for k = -3, 3 do
			P("RipaGaragem", Vector3.new(16, 0.25, 0.3), CFrame.new(gx, 5.3 + k * 1.1, -Pf / 2 + 2.6), Color3.fromRGB(176, 176, 172), Enum.Material.Metal, { CanCollide = false })
		end
		P("TetoGaragem", Vector3.new(27, 0.9, Pf - 7), CFrame.new(gx - 0.5, 11.6, -2), telha, Enum.Material.Slate)
	end

	-- muro baixo com portao, gramado e calcada
	local zMuro = -Pf / 2 - 24
	P("Gramado", Vector3.new(L + 40, 0.3, 30), CFrame.new(6, 0.15, -Pf / 2 - 15), Color3.fromRGB(88, 128, 64), Enum.Material.Grass, { CanCollide = false })
	P("CaminhoEntrada", Vector3.new(6, 0.4, 22), CFrame.new(0, 0.3, -Pf / 2 - 12), Color3.fromRGB(196, 192, 182), CONC, { CanCollide = false })
	for _, s in ipairs({ -1, 1 }) do
		local lado = Vector3.new((L + 36) / 2 - 4, 3.2, 1)
		P("Muro", lado, CFrame.new(s * ((L + 36) / 4 + 2.5) + 6, 1.7, zMuro), Color3.fromRGB(226, 222, 212), CONC)
	end
	P("PilarPortao", Vector3.new(1.6, 4.4, 1.6), CFrame.new(-3.5, 2.2, zMuro), Color3.fromRGB(226, 222, 212), CONC)
	P("PilarPortao", Vector3.new(1.6, 4.4, 1.6), CFrame.new(3.5, 2.2, zMuro), Color3.fromRGB(226, 222, 212), CONC)
	P("Portao", Vector3.new(5.4, 3.4, 0.3), CFrame.new(0, 1.9, zMuro), Color3.fromRGB(60, 62, 66), Enum.Material.Metal, { CanCollide = false })
	-- arbusto e cacto de enfeite
	for k = 1, 3 do
		local x = rng:NextNumber(-L / 2 + 2, L / 2 - 2)
		C.Esfera(m, "Arbusto", rng:NextNumber(3, 4.6), cf * CFrame.new(x, 1.8, -Pf / 2 - 2.2 - rng:NextNumber(0, 1)), Color3.fromRGB(52 + rng:NextInteger(0, 20), 100 + rng:NextInteger(0, 24), 52),
			Enum.Material.Grass, { CanCollide = false })
	end
	return m
end
V.Casa = casa

-- Poste de iluminacao publica
local function poste(pai, pos, voltado)
	local topo = pos + Vector3.new(0, 20, 0)
	C.Tubo(pai, "PostePublico", pos, topo, 0.7, Color3.fromRGB(70, 74, 78), Enum.Material.Metal)
	local braco = topo + Vector3.new(voltado * 4.5, 0.5, 0)
	C.Tubo(pai, "BracoPoste", topo, braco, 0.5, Color3.fromRGB(70, 74, 78), Enum.Material.Metal)
	local l = C.Parte(pai, "Luminaria", Vector3.new(3.4, 0.6, 1.6), CFrame.new(braco + Vector3.new(0, -0.4, 0)), Color3.fromRGB(255, 244, 214), Enum.Material.Neon)
	C.Luz(l, "SpotLight", { Face = Enum.NormalId.Bottom, Range = 40, Brightness = 1.4, Angle = 120 })
end
V.Poste = poste

local function banco(pai, cf)
	C.Parte(pai, "Banco", Vector3.new(7, 0.5, 2), cf * CFrame.new(0, 2, 0), Color3.fromRGB(120, 84, 54), Enum.Material.Wood)
	C.Parte(pai, "EncostoBanco", Vector3.new(7, 1.8, 0.4), cf * CFrame.new(0, 3.1, 0.9), Color3.fromRGB(120, 84, 54), Enum.Material.Wood)
	for _, s in ipairs({ -1, 1 }) do
		C.Parte(pai, "PeBanco", Vector3.new(0.5, 2, 2), cf * CFrame.new(s * 3.1, 1, 0), Color3.fromRGB(60, 62, 66), Enum.Material.Metal)
	end
end

function V.Construir(N, Mapa, raiz)
	local Y = MD.Plato
	local pasta = Mapa.Pasta
	local rng = Random.new(2026)
	local vila = pasta("VilaMilitar", raiz)
	local vias = pasta("Vias", vila)
	local casas = pasta("Casas", vila)
	local mob = pasta("Mobiliario", vila)

	-- gramado base de toda a vila (acima do terreno)
	C.Parte(vila, "GramadoVila", Vector3.new(1500, 0.3, 1400), CFrame.new(3550, Y + 0.15, 3320), Color3.fromRGB(86, 124, 62), Enum.Material.Grass, { CanCollide = false })

	-- avenidas
	local X1, X2 = 2860, 4260
	Mapa.Via(vias, Vector3.new(X1, Y, 1960), Vector3.new(X1, Y, 3720), 24)
	Mapa.Via(vias, Vector3.new(X2, Y, 1960), Vector3.new(X2, Y, 3720), 24)
	Mapa.Via(vias, Vector3.new(X1, Y, 3720), Vector3.new(X2, Y, 3720), 24)
	-- ruas transversais (leste-oeste)
	local zs = { 2700, 2920, 3140 }
	for _, z in ipairs(zs) do
		Mapa.Via(vias, Vector3.new(X1, Y, z), Vector3.new(X2, Y, z), 20)
	end
	-- calcadas e postes
	for _, z in ipairs(zs) do
		for _, s in ipairs({ -1, 1 }) do
			C.Parte(vias, "Calcada", Vector3.new(X2 - X1, 0.4, 5), CFrame.new((X1 + X2) / 2, Y + 0.2, z + s * 14), Color3.fromRGB(190, 188, 180), Enum.Material.Concrete, { CanCollide = false })
		end
		for x = X1 + 40, X2 - 40, 100 do
			poste(mob, Vector3.new(x, Y, z + 16), 1)
		end
	end

	-- casas: cinco fileiras (costas com costas entre as ruas)
	local fileiras = {
		{ zs[1] + 62, false }, { zs[2] - 62, true }, { zs[2] + 62, false }, { zs[3] - 62, true }, { zs[3] + 62, false },
	}
	for _, f in ipairs(fileiras) do
		for x = X1 + 70, X2 - 70, 100 do
			local cf = CFrame.new(x, Y, f[1])
			if f[2] then cf = cf * CFrame.Angles(0, math.rad(180), 0) end
			casa(casas, cf, rng, rng:NextInteger(1, 3) == 1)
		end
	end

	-- praca central com coreto
	local pc = CFrame.new(3560, Y, 3550)
	C.Cilindro(mob, "PracaPiso", 90, 0.5, pc * CFrame.new(0, 0.3, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(196, 190, 176), Enum.Material.Cobblestone, { CanCollide = false })
	local coreto = pasta("Coreto", mob)
	C.Cilindro(coreto, "BaseCoreto", 26, 1.4, pc * CFrame.new(0, 1, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(226, 222, 212), Enum.Material.Concrete)
	for k = 0, 7 do
		local a = k / 8 * math.pi * 2
		C.Tubo(coreto, "ColunaCoreto", (pc * CFrame.new(math.cos(a) * 10, 1.7, math.sin(a) * 10)).Position, (pc * CFrame.new(math.cos(a) * 10, 14, math.sin(a) * 10)).Position, 0.9,
			Color3.fromRGB(244, 244, 240), Enum.Material.Concrete)
	end
	C.Cilindro(coreto, "TetoCoreto", 25, 1, pc * CFrame.new(0, 14.5, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(176, 84, 54), Enum.Material.Slate)
	C.Cilindro(coreto, "TetoCoreto2", 16, 1, pc * CFrame.new(0, 15.5, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(176, 84, 54), Enum.Material.Slate)
	C.Esfera(coreto, "Remate", 2.4, pc * CFrame.new(0, 17, 0), Color3.fromRGB(230, 190, 60), Enum.Material.Metal)
	for k = 0, 5 do
		local a = k / 6 * math.pi * 2 + 0.3
		banco(mob, pc * CFrame.new(math.cos(a) * 34, 0.5, math.sin(a) * 34) * CFrame.Angles(0, -a + math.pi / 2, 0))
	end
	poste(mob, pc.Position + Vector3.new(30, 0, 0), -1)
	poste(mob, pc.Position + Vector3.new(-30, 0, 0), 1)
	Mapa.Bandeira(mob, pc * CFrame.new(0, 0, 18), 36)

	-- quadra poliesportiva
	local q = CFrame.new(3900, Y, 3560)
	C.Parte(mob, "Quadra", Vector3.new(96, 0.4, 56), q * CFrame.new(0, 0.2, 0), Color3.fromRGB(190, 70, 56), Enum.Material.Concrete)
	C.Parte(mob, "QuadraMeio", Vector3.new(0.6, 0.06, 56), q * CFrame.new(0, 0.45, 0), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, { CanCollide = false })
	C.Parte(mob, "QuadraLinhaA", Vector3.new(96, 0.06, 0.6), q * CFrame.new(0, 0.45, 27), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, { CanCollide = false })
	C.Parte(mob, "QuadraLinhaB", Vector3.new(96, 0.06, 0.6), q * CFrame.new(0, 0.45, -27), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, { CanCollide = false })
	C.Cilindro(mob, "CirculoCentral", 18, 0.06, q * CFrame.new(0, 0.46, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, { CanCollide = false, Transparency = 0.2 })
	for _, s in ipairs({ -1, 1 }) do
		C.Tubo(mob, "TraveBase", (q * CFrame.new(s * 46, 0, 0)).Position, (q * CFrame.new(s * 46, 9, 0)).Position, 0.6, Color3.fromRGB(230, 230, 230), Enum.Material.Metal)
		C.Parte(mob, "Tabela", Vector3.new(0.4, 5, 7), q * CFrame.new(s * 45, 10, 0), Color3.fromRGB(236, 236, 232), Enum.Material.SmoothPlastic)
		C.Parte(mob, "Aro", Vector3.new(2.6, 0.3, 2.6), q * CFrame.new(s * 43.2, 8, 0), Color3.fromRGB(240, 110, 30), Enum.Material.Metal, { CanCollide = false })
	end
	-- alambrado
	for k = -1, 1, 2 do
		C.Parte(mob, "Alambrado", Vector3.new(104, 16, 0.3), q * CFrame.new(0, 8, k * 31), Color3.fromRGB(200, 205, 200), Enum.Material.Metal, { Transparency = 0.7 })
	end
	for k = -1, 1, 2 do
		C.Parte(mob, "Alambrado", Vector3.new(0.3, 16, 62), q * CFrame.new(k * 52, 8, 0), Color3.fromRGB(200, 205, 200), Enum.Material.Metal, { Transparency = 0.7 })
	end

	-- capela
	local cap = pasta("Capela", mob)
	local cc = CFrame.new(3220, Y, 3550) * CFrame.Angles(0, math.rad(90), 0)
	C.Parte(cap, "Nave", Vector3.new(34, 24, 56), cc * CFrame.new(0, 12.6, 0), Color3.fromRGB(244, 242, 236), Enum.Material.Concrete)
	C.Parte(cap, "Base", Vector3.new(38, 1.2, 60), cc * CFrame.new(0, 0.6, 0), Color3.fromRGB(190, 186, 178), Enum.Material.Concrete)
	for _, s in ipairs({ -1, 1 }) do
		C.Parte(cap, "Telhado", Vector3.new(24, 1, 58), cc * CFrame.new(s * 9, 27.3, 0) * CFrame.Angles(0, 0, math.rad(-s * 25)), Color3.fromRGB(150, 70, 48), Enum.Material.Slate)
	end
	C.Parte(cap, "Torre", Vector3.new(10, 40, 10), cc * CFrame.new(0, 21, -33), Color3.fromRGB(244, 242, 236), Enum.Material.Concrete)
	C.Parte(cap, "Sineiro", Vector3.new(6, 6, 0.6), cc * CFrame.new(0, 36, -38.3), Color3.fromRGB(30, 30, 32), Enum.Material.SmoothPlastic)
	C.Parte(cap, "CruzV", Vector3.new(1.2, 8, 1.2), cc * CFrame.new(0, 46.5, -33), Color3.fromRGB(230, 190, 60), Enum.Material.Metal)
	C.Parte(cap, "CruzH", Vector3.new(5, 1.2, 1.2), cc * CFrame.new(0, 48, -33), Color3.fromRGB(230, 190, 60), Enum.Material.Metal)
	C.Parte(cap, "Porta", Vector3.new(7, 13, 0.6), cc * CFrame.new(0, 7.7, -28.2), Color3.fromRGB(94, 62, 40), Enum.Material.Wood)
	C.Parte(cap, "Vitral", Vector3.new(0.5, 9, 4), cc * CFrame.new(17.2, 14, 6), Color3.fromRGB(90, 130, 190), Enum.Material.Glass, { Transparency = 0.35 })
	C.Parte(cap, "Vitral", Vector3.new(0.5, 9, 4), cc * CFrame.new(-17.2, 14, 6), Color3.fromRGB(190, 90, 90), Enum.Material.Glass, { Transparency = 0.35 })
	C.Parte(cap, "Vitral", Vector3.new(0.5, 9, 4), cc * CFrame.new(17.2, 14, -8), Color3.fromRGB(230, 190, 70), Enum.Material.Glass, { Transparency = 0.35 })

	-- Clube dos oficiais na entrada da vila
	Mapa.Predio(mob, "ClubeDeOficiais", CFrame.new(3560, Y, 2200) * CFrame.Angles(0, math.rad(180), 0), 130, 56, 24, true, Color3.fromRGB(232, 228, 216))
	Mapa.Placa(mob, "PlacaVila", CFrame.new(3000, Y, 2000) * CFrame.Angles(0, math.rad(180), 0), "Vila Militar", "Próprios Nacionais Residenciais")

	-- arvores nos quintais (entre as fileiras de casas) e ao redor da praca
	if Mapa.Arvore then
		local faixas = { { 2792, 2830 }, { 3012, 3050 }, { 3236, 3330 } }
		for _, f in ipairs(faixas) do
			for x = X1 + 40, X2 - 40, 36 do
				local z = rng:NextNumber(f[1], f[2])
				Mapa.Arvore(mob, Vector3.new(x + rng:NextNumber(-8, 8), Y, z), rng:NextNumber(0.7, 1.1), true)
			end
		end
		for k = 0, 9 do
			local a = k / 10 * math.pi * 2
			Mapa.Arvore(mob, Vector3.new(3560 + math.cos(a) * 52, Y, 3550 + math.sin(a) * 52), rng:NextNumber(0.9, 1.2), false)
		end
	end

	-- HOSPITAL DA BASE (HABASE) E GINASIO, ao norte da area de ensino ---------------------
	local hosp = pasta("Hospital", raiz)
	local hc = CFrame.new(3500, Y, -2600)
	local pred = Mapa.Predio(hosp, "HABASE", hc * CFrame.Angles(0, math.rad(180), 0), 170, 64, 36, true, Color3.fromRGB(240, 240, 236))
	C.Parte(hosp, "CruzVermelhaV", Vector3.new(3, 12, 0.5), hc * CFrame.new(0, 22, 32.5), Color3.fromRGB(200, 30, 30), Enum.Material.SmoothPlastic)
	C.Parte(hosp, "CruzVermelhaH", Vector3.new(12, 3, 0.5), hc * CFrame.new(0, 22, 32.5), Color3.fromRGB(200, 30, 30), Enum.Material.SmoothPlastic)
	local letrHos = C.Parte(hosp, "LetreiroHospital", Vector3.new(70, 6, 0.4), hc * CFrame.new(0, 31, 32.6), Color3.fromRGB(20, 52, 100), Enum.Material.SmoothPlastic)
	C.Texto(C.Tela(letrHos, Enum.NormalId.Back, 20), "HOSPITAL DE AERONÁUTICA", { Font = Enum.Font.GothamBold })
	-- baia de ambulancias
	C.Parte(hosp, "BaiaAmbulancia", Vector3.new(60, 0.5, 26), hc * CFrame.new(-90, 0.25, -50), Color3.fromRGB(70, 70, 72), Enum.Material.Asphalt)
	C.Parte(hosp, "CoberturaBaia", Vector3.new(60, 1, 26), hc * CFrame.new(-90, 18, -50), Color3.fromRGB(232, 232, 228), Enum.Material.Metal)
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			C.Tubo(hosp, "PilarBaia", (hc * CFrame.new(-90 + sx * 28, 0, -50 + sz * 11)).Position, (hc * CFrame.new(-90 + sx * 28, 18, -50 + sz * 11)).Position, 1.2, Color3.fromRGB(230, 230, 226), Enum.Material.Metal)
		end
	end
	-- heliponto
	local hp = hc * CFrame.new(150, 0, -10)
	C.Cilindro(hosp, "Heliponto", 70, 0.6, hp * CFrame.new(0, 0.3, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(70, 72, 74), Enum.Material.Concrete)
	C.Cilindro(hosp, "AnelHeliponto", 62, 0.62, hp * CFrame.new(0, 0.32, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(240, 240, 236), Enum.Material.SmoothPlastic, { CanCollide = false })
	C.Cilindro(hosp, "MiolHeliponto", 58, 0.64, hp * CFrame.new(0, 0.34, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(70, 72, 74), Enum.Material.Concrete, { CanCollide = false })
	C.Parte(hosp, "H1", Vector3.new(4, 0.1, 26), hp * CFrame.new(-7, 0.7, 0), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, { CanCollide = false })
	C.Parte(hosp, "H2", Vector3.new(4, 0.1, 26), hp * CFrame.new(7, 0.7, 0), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, { CanCollide = false })
	C.Parte(hosp, "H3", Vector3.new(14, 0.1, 4), hp * CFrame.new(0, 0.7, 0), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, { CanCollide = false })
	for k = 0, 11 do
		local a = k / 12 * math.pi * 2
		C.Parte(hosp, "LuzHeliponto", Vector3.new(1, 0.6, 1), hp * CFrame.new(math.cos(a) * 33, 0.9, math.sin(a) * 33), Color3.fromRGB(255, 200, 40), Enum.Material.Neon, { CanCollide = false })
	end
	-- estacionamento
	C.Parte(hosp, "Estacionamento", Vector3.new(150, 0.3, 60), hc * CFrame.new(0, 0.15, 90), Color3.fromRGB(58, 58, 60), Enum.Material.Asphalt)
	for x = -70, 70, 10 do
		C.Parte(hosp, "VagaLinha", Vector3.new(0.4, 0.05, 16), hc * CFrame.new(x, 0.35, 92), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, { CanCollide = false })
	end
	Mapa.Via(hosp, hc.Position + Vector3.new(0, 0, 135), hc.Position + Vector3.new(0, 0, 330), 20)

	-- ginasio de esportes
	local gc = CFrame.new(4150, Y, -2600)
	local gin = pasta("Ginasio", raiz)
	C.Parte(gin, "Piso", Vector3.new(120, 1, 90), gc * CFrame.new(0, 0.5, 0), Color3.fromRGB(190, 186, 178), Enum.Material.Concrete)
	for _, s in ipairs({ -1, 1 }) do
		C.Parte(gin, "ParedeLateral", Vector3.new(1.6, 24, 90), gc * CFrame.new(s * 60, 13, 0), Color3.fromRGB(230, 232, 234), Enum.Material.Metal)
		C.Parte(gin, "FaixaAzulGinasio", Vector3.new(1.8, 3, 90), gc * CFrame.new(s * 60, 22, 0), Color3.fromRGB(24, 52, 110), Enum.Material.SmoothPlastic)
	end
	C.Parte(gin, "ParedeFundo", Vector3.new(120, 24, 1.6), gc * CFrame.new(0, 13, 45), Color3.fromRGB(230, 232, 234), Enum.Material.Metal)
	C.Parte(gin, "ParedeFrente", Vector3.new(120, 24, 1.6), gc * CFrame.new(0, 13, -45), Color3.fromRGB(230, 232, 234), Enum.Material.Metal, { Transparency = 0 })
	C.Parte(gin, "JanelaoFrente", Vector3.new(60, 8, 1.8), gc * CFrame.new(0, 14, -45.2), Color3.fromRGB(110, 150, 172), Enum.Material.Glass, { Transparency = 0.4 })
	local seg = 10
	for i = 0, seg - 1 do
		local a1 = math.pi * i / seg
		local a2 = math.pi * (i + 1) / seg
		local r = 60
		local p1 = Vector3.new(-math.cos(a1) * r, 25 + math.sin(a1) * 14, 0)
		local p2 = Vector3.new(-math.cos(a2) * r, 25 + math.sin(a2) * 14, 0)
		local meio = (p1 + p2) / 2
		local comp = (p2 - p1).Magnitude
		local ang = math.atan2(p2.Y - p1.Y, p2.X - p1.X)
		C.Parte(gin, "Telhado", Vector3.new(comp + 0.6, 1, 92), gc * CFrame.new(meio) * CFrame.Angles(0, 0, ang), Color3.fromRGB(196, 200, 204), Enum.Material.Metal)
	end
	local letGin = C.Parte(gin, "LetreiroGinasio", Vector3.new(50, 5, 0.4), gc * CFrame.new(0, 21, -46.1), Color3.fromRGB(24, 52, 110), Enum.Material.SmoothPlastic)
	C.Texto(C.Tela(letGin, Enum.NormalId.Front, 20), "GINÁSIO DE ESPORTES", { Font = Enum.Font.GothamBold })
	Mapa.Via(gin, gc.Position + Vector3.new(0, 0, -70), gc.Position + Vector3.new(0, 0, -330), 20)
end

return V
