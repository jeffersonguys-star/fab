--[[
	FAB - Aerodromo da base (ModuleScript)

	Pista 18/36 de 3.000 m x 45 m em escala real (1 stud = 0,28 m), com:
	- marcas de cabeceira, designadores, eixo, zona de toque, ponto de visada e bordas
	- areas de escape com chevrons, luzes de borda, de cabeceira e de fim de pista
	- sistema de luzes de aproximacao (ALS) com sequenciais na cabeceira 36 e PAPI nas duas
	- pista de taxi paralela "A", ligacoes B a F com marcas de espera e placas
	- patio de aeronaves com posicoes de estacionamento e torres de iluminacao
	- 5 hangares de esquadrao, abrigos reforcados (HAS) para os cacas
	- torre de controle, secao contra incendio, parque de combustivel, radar
	- cerca patrimonial e via de servico
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local FAB = ReplicatedStorage:WaitForChild("FAB")
local C = require(FAB:WaitForChild("Construtor"))
local MD = require(FAB:WaitForChild("MapaDados"))

local A = {}

local SPM = MD.StudPorMetro
local BRANCO = Color3.fromRGB(245, 245, 242)
local AMARELO = Color3.fromRGB(240, 190, 20)
local ASFALTO = Color3.fromRGB(42, 42, 44)
local ASFALTO_ESCAPE = Color3.fromRGB(58, 56, 52)
local CONCRETO = Color3.fromRGB(176, 174, 166)

-- Faz uma faixa (parte fina) entre z1 e z2 em x, dividindo em pedacos de ate 2000 studs
local function faixaZ(pai, nome, x, z1, z2, largura, y, cor, material, espessura, colide)
	local inicio = math.min(z1, z2)
	local fim = math.max(z1, z2)
	local z = inicio
	while z < fim - 0.01 do
		local comp = math.min(2000, fim - z)
		C.Parte(pai, nome, Vector3.new(largura, espessura or 0.06, comp), CFrame.new(x, y, z + comp / 2), cor, material or Enum.Material.SmoothPlastic,
			{ CanCollide = colide == true })
		z = z + comp
	end
end

local function faixaX(pai, nome, z, x1, x2, largura, y, cor, material, espessura, colide)
	local inicio = math.min(x1, x2)
	local fim = math.max(x1, x2)
	local x = inicio
	while x < fim - 0.01 do
		local comp = math.min(2000, fim - x)
		C.Parte(pai, nome, Vector3.new(comp, espessura or 0.06, largura), CFrame.new(x + comp / 2, y, z), cor, material or Enum.Material.SmoothPlastic,
			{ CanCollide = colide == true })
		x = x + comp
	end
end

-- Desenha um digito de 7 segmentos no chao. cf: centro do digito, com -Z = "cima" do numero.
local SEGMENTOS = {
	["0"] = { "a", "b", "c", "d", "e", "f" }, ["1"] = { "b", "c" }, ["2"] = { "a", "b", "g", "e", "d" },
	["3"] = { "a", "b", "g", "c", "d" }, ["4"] = { "f", "g", "b", "c" }, ["5"] = { "a", "f", "g", "c", "d" },
	["6"] = { "a", "f", "g", "e", "c", "d" }, ["7"] = { "a", "b", "c" }, ["8"] = { "a", "b", "c", "d", "e", "f", "g" },
	["9"] = { "a", "b", "c", "d", "f", "g" },
}
local function digito(pai, cf, d, altura, largura, traco)
	local h, w = altura / 2, largura / 2
	local pos = {
		a = { 0, -h, largura, traco }, g = { 0, 0, largura, traco }, d = { 0, h, largura, traco },
		f = { -w, -h / 2, traco, h }, b = { w, -h / 2, traco, h }, e = { -w, h / 2, traco, h }, c = { w, h / 2, traco, h },
	}
	for _, s in ipairs(SEGMENTOS[d] or {}) do
		local p = pos[s]
		C.Parte(pai, "Designador", Vector3.new(p[3], 0.07, p[4]), cf * CFrame.new(p[1], 0, p[2]), BRANCO, Enum.Material.SmoothPlastic, { CanCollide = false })
	end
end

local function luzPista(pai, pos, cor, tamanho)
	tamanho = tamanho or 0.8
	C.Parte(pai, "BaseLuz", Vector3.new(0.5, 1, 0.5), CFrame.new(pos + Vector3.new(0, 0.5, 0)), Color3.fromRGB(60, 60, 60), Enum.Material.Metal, { CanCollide = false })
	return C.Parte(pai, "Luz", Vector3.new(tamanho, tamanho * 0.6, tamanho), CFrame.new(pos + Vector3.new(0, 1.2, 0)), cor, Enum.Material.Neon, { CanCollide = false })
end

local function placaTaxi(pai, cf, texto, estilo)
	-- estilo "local": letra amarela em fundo preto; "mandatoria": branco em fundo vermelho
	local m = C.Parte(pai, "PlacaTaxi", Vector3.new(4.2 * #texto + 2, 3, 0.6), cf * CFrame.new(0, 2.6, 0), Color3.fromRGB(15, 15, 15), Enum.Material.SmoothPlastic)
	C.Parte(pai, "PePlaca", Vector3.new(0.4, 1.2, 0.4), cf * CFrame.new(-1.5, 0.6, 0), Color3.fromRGB(240, 190, 20), Enum.Material.Metal)
	C.Parte(pai, "PePlaca", Vector3.new(0.4, 1.2, 0.4), cf * CFrame.new(1.5, 0.6, 0), Color3.fromRGB(240, 190, 20), Enum.Material.Metal)
	for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
		local g = C.Tela(m, face, 30)
		local f = Instance.new("Frame")
		f.Size = UDim2.fromScale(1, 1)
		f.BorderSizePixel = 0
		f.BackgroundColor3 = estilo == "mandatoria" and Color3.fromRGB(200, 20, 20) or Color3.fromRGB(10, 10, 10)
		f.Parent = g
		C.Texto(f, texto, { TextColor3 = estilo == "mandatoria" and Color3.new(1, 1, 1) or Color3.fromRGB(250, 200, 20), Font = Enum.Font.GothamBlack })
	end
	return m
end

local function hangar(pai, Mapa, centro, largura, prof, alt, nome, numero)
	local m = Instance.new("Model")
	m.Name = "Hangar" .. numero
	m.Parent = pai
	-- centro: CFrame com -Z apontando para a frente (portas)
	C.Parte(m, "Piso", Vector3.new(largura, 0.6, prof), centro * CFrame.new(0, 0.3, 0), Color3.fromRGB(160, 160, 156), Enum.Material.Concrete)
	local cor = Color3.fromRGB(200, 204, 208)
	local paredeAlt = alt * 0.62
	C.Parte(m, "Fundo", Vector3.new(largura, paredeAlt, 1.5), centro * CFrame.new(0, paredeAlt / 2, prof / 2), cor, Enum.Material.CorrodedMetal)
	C.Parte(m, "LadoE", Vector3.new(1.5, paredeAlt, prof), centro * CFrame.new(-largura / 2, paredeAlt / 2, 0), cor, Enum.Material.CorrodedMetal)
	C.Parte(m, "LadoD", Vector3.new(1.5, paredeAlt, prof), centro * CFrame.new(largura / 2, paredeAlt / 2, 0), cor, Enum.Material.CorrodedMetal)
	-- telhado em arco
	local segs = 12
	local flecha = alt - paredeAlt
	for i = 0, segs - 1 do
		local a1 = math.pi * i / segs
		local a2 = math.pi * (i + 1) / segs
		local r = largura / 2
		local p1 = Vector3.new(-math.cos(a1) * r, paredeAlt + math.sin(a1) * flecha, 0)
		local p2 = Vector3.new(-math.cos(a2) * r, paredeAlt + math.sin(a2) * flecha, 0)
		local meio = (p1 + p2) / 2
		local comp = (p2 - p1).Magnitude
		local ang = math.atan2(p2.Y - p1.Y, p2.X - p1.X)
		C.Parte(m, "Telhado", Vector3.new(comp + 0.6, 1.2, prof + 3), centro * CFrame.new(meio) * CFrame.Angles(0, 0, ang), Color3.fromRGB(175, 180, 184), Enum.Material.CorrodedMetal)
		-- fechamento do arco no fundo
		C.Parte(m, "Oitao", Vector3.new(comp, math.abs(meio.Y - paredeAlt) * 2 + 1, 1.2), centro * CFrame.new(meio.X, paredeAlt, prof / 2), cor, Enum.Material.CorrodedMetal)
	end
	-- frente: viga, oitao frontal e portas deslizantes (parcialmente abertas)
	C.Parte(m, "Viga", Vector3.new(largura, 6, 2), centro * CFrame.new(0, paredeAlt + 1, -prof / 2), Color3.fromRGB(28, 52, 104), Enum.Material.Metal)
	for i = 0, segs - 1 do
		local a1 = math.pi * (i + 0.5) / segs
		local x = -math.cos(a1) * largura / 2
		local h = math.sin(a1) * flecha
		C.Parte(m, "OitaoFrente", Vector3.new(largura / segs + 0.5, h, 1.2), centro * CFrame.new(x, paredeAlt + 4 + h / 2, -prof / 2), cor, Enum.Material.CorrodedMetal)
	end
	local nFolhas = 6
	local folha = largura / nFolhas
	for i = 1, nFolhas do
		local x = -largura / 2 + folha * (i - 0.5)
		-- as duas folhas centrais ficam abertas (empilhadas nas laterais)
		local aberta = (i == 3 or i == 4)
		local dx = 0
		if aberta then dx = (i == 3) and -folha * 1.0 or folha * 1.0 end
		C.Parte(m, "Porta", Vector3.new(folha - 0.4, paredeAlt - 2, 1), centro * CFrame.new(x + dx, (paredeAlt - 2) / 2, -prof / 2 - (aberta and 2.2 or 1)),
			Color3.fromRGB(220, 222, 224), Enum.Material.CorrodedMetal)
	end
	C.Parte(m, "TrilhoPorta", Vector3.new(largura + 30, 0.4, 2), centro * CFrame.new(0, 0.2, -prof / 2 - 1.5), Color3.fromRGB(80, 80, 80), Enum.Material.Metal)
	local letreiro = C.Parte(m, "Letreiro", Vector3.new(largura * 0.8, 9, 0.3), centro * CFrame.new(0, paredeAlt + 1, -prof / 2 - 1.2), Color3.fromRGB(28, 52, 104), Enum.Material.SmoothPlastic)
	local g = C.Tela(letreiro, Enum.NormalId.Front, 10)
	C.Texto(g, nome, { Font = Enum.Font.GothamBlack })
	local num = C.Parte(m, "Numero", Vector3.new(30, 30, 0.3), centro * CFrame.new(largura / 2 - 22, paredeAlt + flecha * 0.55, -prof / 2 - 0.8), Color3.fromRGB(200, 204, 208), Enum.Material.SmoothPlastic, { Transparency = 1 })
	local gn = C.Tela(num, Enum.NormalId.Front, 10)
	C.Texto(gn, tostring(numero), { Font = Enum.Font.GothamBlack, TextColor3 = Color3.fromRGB(28, 52, 104) })
	-- iluminacao interna
	for x = -largura / 2 + 30, largura / 2 - 30, 50 do
		for z = -prof / 2 + 30, prof / 2 - 30, 55 do
			local l = C.Parte(m, "Luminaria", Vector3.new(5, 0.6, 5), centro * CFrame.new(x, paredeAlt + flecha * 0.5, z), Color3.fromRGB(255, 252, 240), Enum.Material.Neon)
			C.Luz(l, "SpotLight", { Face = Enum.NormalId.Bottom, Range = 60, Brightness = 1.6, Angle = 110 })
		end
	end
	-- anexo administrativo na lateral
	Mapa.Predio(m, "Anexo", centro * CFrame.new(largura / 2 + 22, 0, 10) * CFrame.Angles(0, math.rad(90), 0), 60, 36, 13, true)
	return m
end

function A.Construir(N, Mapa, raiz)
	local Y = MD.Plato
	local P = MD.Pista
	local ae = Mapa.Pasta("Aerodromo", raiz)
	local pista = Mapa.Pasta("Pista", ae)
	local yPista = Y + 0.05
	local yMarca = Y + 0.24

	-- pavimento da pista e areas de escape
	faixaZ(pista, "Pavimento", P.X, -P.MeioComp, P.MeioComp, P.Largura, yPista, ASFALTO, Enum.Material.Asphalt, 0.35, true)
	faixaZ(pista, "Acostamento", P.X - P.MeiaLarg - 12, -P.MeioComp, P.MeioComp, 24, yPista - 0.05, Color3.fromRGB(70, 68, 62), Enum.Material.Asphalt, 0.3, true)
	faixaZ(pista, "Acostamento", P.X + P.MeiaLarg + 12, -P.MeioComp, P.MeioComp, 24, yPista - 0.05, Color3.fromRGB(70, 68, 62), Enum.Material.Asphalt, 0.3, true)
	for _, s in ipairs({ -1, 1 }) do
		local z1 = s * P.MeioComp
		local z2 = s * (P.MeioComp + P.Zona)
		faixaZ(pista, "Escape", P.X, z1, z2, P.Largura, yPista, ASFALTO_ESCAPE, Enum.Material.Asphalt, 0.35, true)
		-- chevrons amarelos
		for k = 1, 6 do
			local zc = z1 + s * (k - 0.5) * P.Zona / 6
			for _, lado in ipairs({ -1, 1 }) do
				local cf = CFrame.new(P.X + lado * P.MeiaLarg / 2, yMarca, zc) * CFrame.Angles(0, math.rad(lado * s * 35), 0)
				C.Parte(pista, "Chevron", Vector3.new(P.Largura / 2 * 1.1, 0.06, 3 * SPM), cf, AMARELO, Enum.Material.SmoothPlastic, { CanCollide = false })
			end
		end
	end

	-- marcas de borda (faixas laterais continuas)
	for _, lado in ipairs({ -1, 1 }) do
		faixaZ(pista, "FaixaBorda", P.X + lado * (P.MeiaLarg - 2), -P.MeioComp, P.MeioComp, 0.9 * SPM, yMarca, BRANCO)
	end

	-- cada cabeceira: s = +1 para a 36 (sul, pousa rumo norte), -1 para a 18 (norte)
	for _, cab in ipairs({ { s = 1, n = "36" }, { s = -1, n = "18" } }) do
		local s = cab.s
		local zT = s * P.MeioComp
		local dir = -s -- sentido do pouso em Z
		-- faixa transversal da cabeceira
		C.Parte(pista, "FaixaCabeceira", Vector3.new(P.Largura, 0.06, 1.8 * SPM), CFrame.new(P.X, yMarca, zT + dir * 1.5), BRANCO, Enum.Material.SmoothPlastic, { CanCollide = false })
		-- "piano" (16 faixas)
		local largFaixa = 1.8 * SPM
		local espaco = 1.8 * SPM
		for i = 1, 8 do
			for _, lado in ipairs({ -1, 1 }) do
				local x = P.X + lado * (3 * SPM + (i - 0.5) * (largFaixa + espaco))
				if math.abs(x - P.X) < P.MeiaLarg - 6 then
					C.Parte(pista, "Piano", Vector3.new(largFaixa, 0.06, 30 * SPM), CFrame.new(x, yMarca, zT + dir * (6 * SPM + 15 * SPM)), BRANCO, Enum.Material.SmoothPlastic, { CanCollide = false })
				end
			end
		end
		-- designador (numeros de 7 segmentos, "cima" no sentido do pouso)
		local zNum = zT + dir * (6 * SPM + 30 * SPM + 12 * SPM + 4.5 * SPM)
		local cfNum = CFrame.lookAt(Vector3.new(P.X, yMarca, zNum), Vector3.new(P.X, yMarca, zNum + dir))
		local alturaNum, larguraNum, traco = 9 * SPM, 3.6 * SPM, 1.1 * SPM
		digito(pista, cfNum * CFrame.new(-larguraNum * 0.85, 0, 0), string.sub(cab.n, 1, 1), alturaNum, larguraNum, traco)
		digito(pista, cfNum * CFrame.new(larguraNum * 0.85, 0, 0), string.sub(cab.n, 2, 2), alturaNum, larguraNum, traco)
		-- ponto de visada (400 m)
		for _, lado in ipairs({ -1, 1 }) do
			C.Parte(pista, "PontoVisada", Vector3.new(9 * SPM, 0.06, 50 * SPM), CFrame.new(P.X + lado * 11 * SPM, yMarca, zT + dir * 400 * SPM), BRANCO, Enum.Material.SmoothPlastic, { CanCollide = false })
		end
		-- zona de toque
		local tdz = { { 150, 3 }, { 300, 2 }, { 600, 2 }, { 750, 1 }, { 900, 1 } }
		for _, t in ipairs(tdz) do
			for _, lado in ipairs({ -1, 1 }) do
				for k = 1, t[2] do
					local x = P.X + lado * (9 * SPM + (k - 1) * 3 * SPM)
					C.Parte(pista, "ZonaToque", Vector3.new(1.8 * SPM, 0.06, 22.5 * SPM), CFrame.new(x, yMarca, zT + dir * t[1] * SPM), BRANCO, Enum.Material.SmoothPlastic, { CanCollide = false })
				end
			end
		end
		-- luzes de cabeceira (verde) e de fim de pista (vermelho)
		for x = -P.MeiaLarg + 4, P.MeiaLarg - 4, 3 * SPM do
			luzPista(pista, Vector3.new(P.X + x, Y, zT + s * 3), Color3.fromRGB(40, 255, 80), 0.9)
			luzPista(pista, Vector3.new(P.X + x + 1.5 * SPM, Y, zT + s * 6), Color3.fromRGB(255, 40, 30), 0.9)
		end
		-- PAPI do lado esquerdo de quem pousa (oeste para a 36, leste para a 18), a 300 m
		local papi = Mapa.Pasta("PAPI" .. cab.n, ae)
		local ladoPapi = (s == 1) and -1 or 1
		for i = 1, 4 do
			local x = P.X + ladoPapi * (P.MeiaLarg + 15 * SPM + (i - 1) * 9 * SPM)
			local z = zT + dir * 300 * SPM
			local caixa = C.Parte(papi, "Unidade" .. i, Vector3.new(6, 4, 4), CFrame.new(x, Y + 2.5, z), Color3.fromRGB(240, 120, 20), Enum.Material.Metal)
			local lente = C.Parte(papi, "Lente" .. i, Vector3.new(4.4, 2.2, 0.4), CFrame.new(x, Y + 2.8, z + s * 2.1), (i <= 2) and BRANCO or Color3.fromRGB(255, 30, 20), Enum.Material.Neon, { CanCollide = false })
			lente:SetAttribute("Indice", i)
			C.Parte(papi, "Pes", Vector3.new(5, 0.8, 3), CFrame.new(x, Y + 0.4, z), Color3.fromRGB(80, 80, 80), Enum.Material.Metal)
		end
		-- biruta
		local bx = P.X + ladoPapi * (P.MeiaLarg + 90)
		local bz = zT + dir * 200 * SPM
		C.Tubo(ae, "MastroBiruta", Vector3.new(bx, Y, bz), Vector3.new(bx, Y + 22, bz), 0.6, BRANCO, Enum.Material.Metal)
		C.Cilindro(ae, "Biruta", 3, 10, CFrame.new(bx + 5, Y + 21, bz) * CFrame.Angles(0, 0, math.rad(-6)), Color3.fromRGB(240, 110, 20), Enum.Material.Fabric, { CanCollide = false })
		C.Parte(ae, "CirculoBiruta", Vector3.new(30, 0.08, 30), CFrame.new(bx, Y + 0.08, bz), BRANCO, Enum.Material.SmoothPlastic, { CanCollide = false })
	end

	-- eixo da pista (tracos de 30 m e intervalos de 20 m), fora das areas de numeros
	local inicioEixo = -P.MeioComp + (6 + 30 + 12 + 9 + 12) * SPM
	local z = inicioEixo
	while z < P.MeioComp - (6 + 30 + 12 + 9 + 12) * SPM - 30 * SPM do
		C.Parte(pista, "Eixo", Vector3.new(0.9 * SPM, 0.06, 30 * SPM), CFrame.new(P.X, yMarca, z + 15 * SPM), BRANCO, Enum.Material.SmoothPlastic, { CanCollide = false })
		z = z + 50 * SPM
	end

	-- luzes de borda da pista a cada 60 m
	z = -P.MeioComp
	while z <= P.MeioComp + 0.1 do
		for _, lado in ipairs({ -1, 1 }) do
			-- nos ultimos 600 m as luzes ficam amarelas (aviso de fim de pista)
			local cor = Color3.fromRGB(255, 250, 230)
			luzPista(pista, Vector3.new(P.X + lado * (P.MeiaLarg + 3), Y, z), cor, 0.8)
		end
		z = z + 60 * SPM
	end

	-- sistema de luzes de aproximacao da cabeceira 36 (900 m) com sequenciais
	local als = Mapa.Pasta("LuzesAproximacao36", ae)
	local sequenciais = {}
	for k = 1, 30 do
		local zc = P.MeioComp + k * 30 * SPM
		local h = 1 + k * 0.15
		C.Tubo(als, "Poste", Vector3.new(P.X, Y, zc), Vector3.new(P.X, Y + h, zc), 0.5, Color3.fromRGB(230, 120, 20), Enum.Material.Metal)
		C.Parte(als, "Barra", Vector3.new(4.5 * SPM, 0.5, 0.5), CFrame.new(P.X, Y + h, zc), Color3.fromRGB(60, 60, 60), Enum.Material.Metal)
		for i = -2, 2 do
			C.Parte(als, "Lampada", Vector3.new(1.2, 0.9, 1.2), CFrame.new(P.X + i * 1.1 * SPM, Y + h + 0.6, zc), Color3.fromRGB(255, 250, 235), Enum.Material.Neon, { CanCollide = false })
		end
		if k == 10 then
			for i = -6, 6 do
				if math.abs(i) > 2 then
					C.Parte(als, "BarraCruzada", Vector3.new(1.2, 0.9, 1.2), CFrame.new(P.X + i * 1.1 * SPM * 1.5, Y + h + 0.6, zc), Color3.fromRGB(255, 250, 235), Enum.Material.Neon, { CanCollide = false })
				end
			end
		end
		if k >= 10 then
			local flash = C.Parte(als, "Sequencial", Vector3.new(1.4, 1.4, 1.4), CFrame.new(P.X, Y + h + 1.8, zc), Color3.fromRGB(90, 90, 90), Enum.Material.SmoothPlastic, { CanCollide = false })
			table.insert(sequenciais, 1, flash)
		end
	end
	-- o "coelho": flashes em sequencia em direcao a pista, duas vezes por segundo
	task.spawn(function()
		local corApagada = Color3.fromRGB(90, 90, 90)
		while true do
			for i = #sequenciais, 1, -1 do
				local f = sequenciais[i]
				f.Material = Enum.Material.Neon
				f.Color = Color3.new(1, 1, 1)
				task.wait(0.025)
				f.Material = Enum.Material.SmoothPlastic
				f.Color = corApagada
			end
			task.wait(0.3)
		end
	end)

	-- PISTA DE TAXI, LIGACOES E MARCAS ------------------------------------------
	local taxi = Mapa.Pasta("Taxi", ae)
	faixaZ(taxi, "TaxiA", MD.TaxiX, -P.MeioComp, P.MeioComp, MD.TaxiLargura, yPista, Color3.fromRGB(52, 52, 54), Enum.Material.Asphalt, 0.35, true)
	faixaZ(taxi, "EixoTaxi", MD.TaxiX, -P.MeioComp, P.MeioComp, 0.5 * SPM, yMarca, AMARELO)
	for _, lado in ipairs({ -1, 1 }) do
		faixaZ(taxi, "BordaTaxi", MD.TaxiX + lado * (MD.TaxiLargura / 2 - 1), -P.MeioComp, P.MeioComp, 0.5 * SPM, yMarca, AMARELO)
	end
	-- luzes azuis de borda do taxi
	z = -P.MeioComp
	while z <= P.MeioComp do
		for _, lado in ipairs({ -1, 1 }) do
			luzPista(taxi, Vector3.new(MD.TaxiX + lado * (MD.TaxiLargura / 2 + 2), Y, z), Color3.fromRGB(40, 90, 255), 0.6)
		end
		z = z + 60 * SPM
	end
	local letras = { "B", "C", "D", "E", "F" }
	for i, lz in ipairs(MD.Ligacoes) do
		local x1, x2 = P.MeiaLarg, MD.TaxiX - MD.TaxiLargura / 2
		faixaX(taxi, "Ligacao" .. letras[i], lz, x1, x2 + 2, MD.TaxiLargura, yPista, Color3.fromRGB(52, 52, 54), Enum.Material.Asphalt, 0.35, true)
		faixaX(taxi, "EixoLigacao", lz, x1 + 4, MD.TaxiX, 0.5 * SPM, yMarca, AMARELO)
		-- marca de posicao de espera (2 continuas + 2 tracejadas) a 90 m do eixo da pista
		local xe = P.X + 90 * SPM
		for k = 0, 1 do
			C.Parte(taxi, "EsperaContinua", Vector3.new(0.5 * SPM, 0.06, MD.TaxiLargura), CFrame.new(xe + k * 1.2 * SPM, yMarca, lz), AMARELO, Enum.Material.SmoothPlastic, { CanCollide = false })
			local zz = lz - MD.TaxiLargura / 2 + 4
			while zz < lz + MD.TaxiLargura / 2 - 4 do
				C.Parte(taxi, "EsperaTracejada", Vector3.new(0.5 * SPM, 0.06, 3 * SPM), CFrame.new(xe + (2.4 + k * 1.2) * SPM, yMarca, zz + 1.5 * SPM), AMARELO, Enum.Material.SmoothPlastic, { CanCollide = false })
				zz = zz + 6 * SPM
			end
		end
		placaTaxi(taxi, CFrame.new(xe, Y, lz - MD.TaxiLargura / 2 - 10) * CFrame.Angles(0, math.rad(90), 0), "18-36", "mandatoria")
		placaTaxi(taxi, CFrame.new(MD.TaxiX - MD.TaxiLargura / 2 - 12, Y, lz + MD.TaxiLargura / 2 + 14) * CFrame.Angles(0, math.rad(90), 0), letras[i], "local")
	end

	-- PATIO DE AERONAVES --------------------------------------------------------
	local patio = Mapa.Pasta("PatioAeronaves", ae)
	local pa = MD.Patio
	local xIni = MD.TaxiX + MD.TaxiLargura / 2
	local zMeio = (pa.Z1 + pa.Z2) / 2
	local zComp = pa.Z2 - pa.Z1
	for k = 0, 1 do
		local zc = pa.Z1 + zComp / 4 + k * zComp / 2
		C.Parte(patio, "Concreto", Vector3.new(pa.X2 + 40 - xIni, 0.35, zComp / 2), CFrame.new((xIni + pa.X2 + 40) / 2, yPista, zc), CONCRETO, Enum.Material.Concrete)
	end
	-- juntas do concreto
	for x = xIni + 40, pa.X2, 40 do
		faixaZ(patio, "Junta", x, pa.Z1, pa.Z2, 0.3, yPista + 0.18, Color3.fromRGB(140, 138, 130))
	end
	-- posicoes de estacionamento (linha de entrada e barra de parada)
	local pos = 1
	for zz = pa.Z1 + 300, pa.Z2 - 300, 400 do
		faixaX(patio, "LinhaEntrada", zz, xIni + 30, pa.X2 - 260, 0.5 * SPM, yMarca, AMARELO)
		C.Parte(patio, "BarraParada", Vector3.new(1, 0.06, 30), CFrame.new(pa.X2 - 260, yMarca, zz), AMARELO, Enum.Material.SmoothPlastic, { CanCollide = false })
		local placa = C.Parte(patio, "NumeroPosicao", Vector3.new(16, 0.07, 16), CFrame.new(pa.X2 - 230, yMarca, zz), AMARELO, Enum.Material.SmoothPlastic, { CanCollide = false, Transparency = 1 })
		local g = C.Tela(placa, Enum.NormalId.Top, 10)
		C.Texto(g, string.format("%02d", pos), { TextColor3 = AMARELO, Font = Enum.Font.GothamBlack })
		-- equipamentos de apoio (fonte de energia e calcos)
		C.Parte(patio, "FonteSolo", Vector3.new(6, 5, 10), CFrame.new(pa.X2 - 200, Y + 2.8, zz + 50), Color3.fromRGB(240, 200, 30), Enum.Material.Metal)
		C.Parte(patio, "RodasFonte", Vector3.new(6.4, 1.6, 8), CFrame.new(pa.X2 - 200, Y + 0.9, zz + 50), Color3.fromRGB(20, 20, 20), Enum.Material.Rubber)
		pos = pos + 1
	end
	-- torres de iluminacao do patio
	for zz = pa.Z1 + 150, pa.Z2 - 150, 550 do
		local base = Vector3.new(pa.X2 + 25, Y, zz)
		C.Tubo(patio, "TorreLuz", base, base + Vector3.new(0, 70, 0), 2, Color3.fromRGB(150, 150, 150), Enum.Material.Metal)
		local banco = C.Parte(patio, "Refletores", Vector3.new(4, 4, 14), CFrame.new(base + Vector3.new(-2, 70, 0)), Color3.fromRGB(240, 240, 230), Enum.Material.Neon)
		C.Luz(banco, "SpotLight", { Face = Enum.NormalId.Left, Range = 60, Brightness = 2, Angle = 120 })
	end

	-- HANGARES ------------------------------------------------------------------
	local hangares = Mapa.Pasta("Hangares", ae)
	local nomes = {
		"1º ESQUADRÃO DE INSTRUÇÃO AÉREA", "2º ESQUADRÃO DE INSTRUÇÃO AÉREA", "ESQUADRÃO DE CAÇA",
		"ESQUADRÃO DE TRANSPORTE AÉREO", "ESQUADRÃO DE HELICÓPTEROS",
	}
	local zh = { -1500, -750, 0, 750, 1500 }
	for i = 1, 5 do
		local largura, prof, alt = 214, 178, 60
		local frente = pa.X2 + 40
		local centro = CFrame.new(frente + prof / 2, Y, zh[i]) * CFrame.Angles(0, math.rad(90), 0)
		hangar(hangares, Mapa, centro, largura, prof, alt, nomes[i], i)
	end

	-- ABRIGOS REFORCADOS (HAS) PARA OS CACAS -------------------------------------
	local has = Mapa.Pasta("AbrigosReforcados", ae)
	local zHas = -4200
	faixaX(has, "TaxiHAS", zHas, MD.TaxiX, 2100, 60, yPista, Color3.fromRGB(52, 52, 54), Enum.Material.Asphalt, 0.35, true)
	faixaX(has, "EixoHAS", zHas, MD.TaxiX + 40, 2100, 0.5 * SPM, yMarca, AMARELO)
	for i = 0, 3 do
		local x = 1000 + i * 300
		local cf = CFrame.new(x, Y, zHas - 140) * CFrame.Angles(0, math.rad(180), 0)
		local largura, prof, alt = 90, 140, 40
		C.Parte(has, "PatioHAS", Vector3.new(largura + 20, 0.35, 110), CFrame.new(x, yPista, zHas - 30 - 55 + 30), CONCRETO, Enum.Material.Concrete)
		local segs = 10
		for k = 0, segs - 1 do
			local a1 = math.pi * k / segs
			local a2 = math.pi * (k + 1) / segs
			local r = largura / 2
			local p1 = Vector3.new(-math.cos(a1) * r, math.sin(a1) * alt, 0)
			local p2 = Vector3.new(-math.cos(a2) * r, math.sin(a2) * alt, 0)
			local meio = (p1 + p2) / 2
			local comp = (p2 - p1).Magnitude
			local ang = math.atan2(p2.Y - p1.Y, p2.X - p1.X)
			C.Parte(has, "Abobada", Vector3.new(comp + 1, 5, prof), cf * CFrame.new(meio) * CFrame.Angles(0, 0, ang), Color3.fromRGB(120, 124, 110), Enum.Material.Concrete)
			-- parede do fundo
			C.Parte(has, "FundoHAS", Vector3.new(comp, math.max(1, meio.Y * 2), 4), cf * CFrame.new(meio.X, 0, prof / 2), Color3.fromRGB(110, 114, 100), Enum.Material.Concrete)
		end
		-- porta blindada de duas folhas
		for _, lado in ipairs({ -1, 1 }) do
			C.Parte(has, "PortaBlindada", Vector3.new(largura / 2 - 6, alt * 0.7, 3), cf * CFrame.new(lado * (largura / 4 + 6), alt * 0.35, -prof / 2 - 1.5),
				Color3.fromRGB(80, 84, 76), Enum.Material.DiamondPlate)
		end
		C.Parte(has, "VergaHAS", Vector3.new(largura, alt * 0.35, 6), cf * CFrame.new(0, alt * 0.85, -prof / 2), Color3.fromRGB(110, 114, 100), Enum.Material.Concrete)
		local num = C.Parte(has, "NumeroHAS", Vector3.new(14, 10, 0.2), cf * CFrame.new(0, alt * 0.85, -prof / 2 - 3.2), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, { Transparency = 1 })
		local g = C.Tela(num, Enum.NormalId.Front, 10)
		C.Texto(g, "HAS 0" .. (i + 1), { Font = Enum.Font.GothamBlack, TextColor3 = Color3.fromRGB(240, 240, 230) })
	end

	-- TORRE DE CONTROLE ---------------------------------------------------------
	local torre = Mapa.Pasta("TorreDeControle", ae)
	local tc = CFrame.new(1150, Y, 2350)
	Mapa.Predio(torre, "PredioTorre", tc * CFrame.new(0, 0, 30) * CFrame.Angles(0, math.rad(90), 0), 50, 34, 12, true)
	local alturaFuste = 110
	C.Cilindro(torre, "Fuste", 18, alturaFuste, tc * CFrame.new(0, alturaFuste / 2, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(235, 235, 230), Enum.Material.Concrete)
	for i = 0, 7 do
		C.Parte(torre, "JanelaFuste", Vector3.new(2, 4, 0.3), tc * CFrame.new(0, 20 + i * 11, -9.05), Color3.fromRGB(90, 120, 150), Enum.Material.Glass, { Transparency = 0.3 })
	end
	local yCab = alturaFuste
	C.Cilindro(torre, "BaseCabine", 30, 4, tc * CFrame.new(0, yCab + 2, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(28, 52, 104), Enum.Material.Metal)
	C.Cilindro(torre, "PisoCabine", 28, 1, tc * CFrame.new(0, yCab + 4.5, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(60, 60, 64), Enum.Material.Metal)
	local raioCab = 13
	for i = 0, 7 do
		local a = math.rad(i * 45 + 22.5)
		local cfJ = tc * CFrame.new(math.cos(a) * raioCab, yCab + 11, math.sin(a) * raioCab) * CFrame.Angles(0, -a + math.rad(90), 0) * CFrame.Angles(math.rad(-12), 0, 0)
		C.Parte(torre, "VidroCabine", Vector3.new(10.4, 12, 0.4), cfJ, Color3.fromRGB(80, 120, 140), Enum.Material.Glass, { Transparency = 0.45 })
		C.Parte(torre, "Montante", Vector3.new(0.8, 12, 0.8), tc * CFrame.new(math.cos(a - math.rad(22.5)) * (raioCab + 0.4), yCab + 11, math.sin(a - math.rad(22.5)) * (raioCab + 0.4)), Color3.fromRGB(30, 30, 30), Enum.Material.Metal)
		-- consoles com telas verdes
		local cfC = tc * CFrame.new(math.cos(a) * 9, yCab + 7, math.sin(a) * 9) * CFrame.Angles(0, -a + math.rad(90), 0)
		local console = C.Parte(torre, "Console", Vector3.new(6, 2.5, 2), cfC, Color3.fromRGB(40, 40, 44), Enum.Material.Metal)
		local tela = C.Parte(torre, "TelaConsole", Vector3.new(4, 0.1, 1.4), cfC * CFrame.new(0, 1.3, 0) * CFrame.Angles(math.rad(-25), 0, 0), Color3.fromRGB(40, 200, 90), Enum.Material.Neon)
	end
	C.Cilindro(torre, "TetoCabine", 32, 2, tc * CFrame.new(0, yCab + 18, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(28, 52, 104), Enum.Material.Metal)
	C.Tubo(torre, "Antena", (tc * CFrame.new(4, yCab + 19, 0)).Position, (tc * CFrame.new(4, yCab + 40, 0)).Position, 0.5, Color3.fromRGB(220, 220, 220), Enum.Material.Metal)
	local farolAero = C.Parte(torre, "FarolRotativo", Vector3.new(3, 2, 3), tc * CFrame.new(-4, yCab + 20.5, 0), Color3.fromRGB(255, 255, 255), Enum.Material.Neon)
	local luzFarol = C.Luz(farolAero, "SpotLight", { Face = Enum.NormalId.Front, Range = 60, Brightness = 5, Angle = 20 })
	local placaTorre = C.Parte(torre, "LetreiroTorre", Vector3.new(16, 3.4, 0.3), tc * CFrame.new(0, yCab + 2, -15.2), Color3.fromRGB(28, 52, 104), Enum.Material.SmoothPlastic, { Transparency = 1 })
	C.Texto(C.Tela(placaTorre, Enum.NormalId.Front, 20), "TORRE", { Font = Enum.Font.GothamBlack })
	-- farol de aerodromo alterna branco e verde girando
	task.spawn(function()
		local ang = 0
		local cfBase = farolAero.CFrame
		while true do
			ang = ang + 0.12
			farolAero.CFrame = cfBase * CFrame.Angles(0, ang, 0)
			local verde = math.floor(ang / math.pi) % 2 == 0
			luzFarol.Color = verde and Color3.fromRGB(60, 255, 120) or Color3.new(1, 1, 1)
			farolAero.Color = luzFarol.Color
			task.wait(0.05)
		end
	end)

	-- SECAO CONTRA INCENDIO (SCI) -------------------------------------------------
	local sci = Mapa.Pasta("SecaoContraIncendio", ae)
	local sc = CFrame.new(1150, Y, -2500) * CFrame.Angles(0, math.rad(90), 0)
	Mapa.Predio(sci, "Quartel", sc * CFrame.new(0, 0, 26), 120, 50, 18, false)
	for i = -1, 1 do
		C.Parte(sci, "PortaoVermelho", Vector3.new(28, 16, 0.8), sc * CFrame.new(i * 36, 8.5, 0.6), Color3.fromRGB(200, 30, 30), Enum.Material.Metal)
	end
	local letSci = C.Parte(sci, "Letreiro", Vector3.new(60, 4, 0.3), sc * CFrame.new(0, 18, 0.4), Color3.fromRGB(200, 30, 30), Enum.Material.SmoothPlastic)
	C.Texto(C.Tela(letSci, Enum.NormalId.Front, 20), "SEÇÃO CONTRA INCÊNDIO", { Font = Enum.Font.GothamBlack })
	-- viaturas de combate a incendio
	for i = 0, 1 do
		local v = sc * CFrame.new(-20 + i * 40, 0, -40)
		C.Parte(sci, "Chassi", Vector3.new(11, 3, 34), v * CFrame.new(0, 3.5, 0), Color3.fromRGB(30, 30, 30), Enum.Material.Metal)
		C.Parte(sci, "Carroceria", Vector3.new(10.5, 9, 24), v * CFrame.new(0, 9.5, 4), Color3.fromRGB(205, 25, 25), Enum.Material.SmoothPlastic)
		C.Parte(sci, "Cabine", Vector3.new(10.5, 8, 9), v * CFrame.new(0, 9, -12), Color3.fromRGB(205, 25, 25), Enum.Material.SmoothPlastic)
		C.Parte(sci, "Parabrisa", Vector3.new(9.6, 3.5, 0.3), v * CFrame.new(0, 11, -16.6), Color3.fromRGB(60, 80, 100), Enum.Material.Glass, { Transparency = 0.3 })
		C.Parte(sci, "FaixaRefletiva", Vector3.new(10.7, 0.8, 33), v * CFrame.new(0, 6.5, -0.5), Color3.fromRGB(255, 240, 200), Enum.Material.SmoothPlastic)
		C.Cilindro(sci, "Canhao", 1, 6, v * CFrame.new(0, 14.5, -8) * CFrame.Angles(0, math.rad(90), math.rad(10)), Color3.fromRGB(200, 200, 200), Enum.Material.Metal)
		local barra = C.Parte(sci, "Giroflex", Vector3.new(8, 0.8, 1.2), v * CFrame.new(0, 13.4, -12), Color3.fromRGB(255, 40, 40), Enum.Material.Neon)
		for _, eixo in ipairs({ -10, 0, 10 }) do
			for _, lado in ipairs({ -1, 1 }) do
				C.Cilindro(sci, "Roda", 4.4, 1.8, v * CFrame.new(lado * 5.4, 2.2, eixo), Color3.fromRGB(20, 20, 20), Enum.Material.Rubber)
			end
		end
	end
	Mapa.Via(sci, Vector3.new(MD.TaxiX + 60, Y, -2500), Vector3.new(1110, Y, -2500), 30, true)

	-- PARQUE DE COMBUSTIVEL -------------------------------------------------------
	local pqc = Mapa.Pasta("ParqueCombustivel", ae)
	local pc = CFrame.new(2350, Y, -3000)
	C.Parte(pqc, "Bacia", Vector3.new(260, 0.4, 200), pc * CFrame.new(0, 0.2, 0), Color3.fromRGB(150, 148, 140), Enum.Material.Concrete)
	for _, s in ipairs({ { 0, 100, 260, 2 }, { 0, -100, 260, 2 }, { 130, 0, 2, 200 }, { -130, 0, 2, 200 } }) do
		C.Parte(pqc, "Dique", Vector3.new(s[3], 5, s[4]), pc * CFrame.new(s[1], 2.5, s[2]), Color3.fromRGB(160, 158, 150), Enum.Material.Concrete)
	end
	for i = 0, 3 do
		local t = pc * CFrame.new(-75 + (i % 2) * 150, 0, -45 + math.floor(i / 2) * 90)
		C.Cilindro(pqc, "Tanque", 60, 36, t * CFrame.new(0, 18, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(240, 240, 236), Enum.Material.Metal)
		C.Cilindro(pqc, "TetoTanque", 60.5, 1, t * CFrame.new(0, 36.4, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(200, 200, 196), Enum.Material.Metal)
		C.Parte(pqc, "FaixaTanque", Vector3.new(61, 3, 1), t * CFrame.new(0, 26, -30), Color3.fromRGB(28, 52, 104), Enum.Material.SmoothPlastic)
		C.Tubo(pqc, "Tubulacao", (t * CFrame.new(0, 2, 30)).Position, (pc * CFrame.new(0, 2, 90)).Position, 1.2, Color3.fromRGB(240, 200, 30), Enum.Material.Metal)
	end

	-- RADAR DE VIGILANCIA ---------------------------------------------------------
	local rad = Mapa.Pasta("Radar", ae)
	local rc = CFrame.new(2200, Y, 3300)
	for _, s in ipairs({ { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } }) do
		C.Tubo(rad, "Perna", (rc * CFrame.new(s[1] * 10, 0, s[2] * 10)).Position, (rc * CFrame.new(s[1] * 4, 40, s[2] * 4)).Position, 1.2, Color3.fromRGB(200, 200, 200), Enum.Material.Metal)
	end
	C.Parte(rad, "Plataforma", Vector3.new(12, 2, 12), rc * CFrame.new(0, 41, 0), Color3.fromRGB(180, 180, 180), Enum.Material.Metal)
	local antena = Instance.new("Model")
	antena.Name = "AntenaRadar"
	antena.Parent = rad
	local eixo = C.Cilindro(antena, "Eixo", 2, 4, rc * CFrame.new(0, 44, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(80, 80, 80), Enum.Material.Metal)
	for k = -3, 3 do
		C.Parte(antena, "Refletor", Vector3.new(4.4, 7, 0.6), rc * CFrame.new(k * 4.2, 49, -2 + math.abs(k) * 0.5) * CFrame.Angles(0, math.rad(k * 5), 0), Color3.fromRGB(235, 235, 235), Enum.Material.Metal)
	end
	antena.PrimaryPart = eixo
	local cfAntena = antena:GetPivot()
	local angRadar = 0
	RunService.Heartbeat:Connect(function(dt)
		angRadar = angRadar + dt * 1.6
		antena:PivotTo(cfAntena * CFrame.Angles(angRadar, 0, 0))
	end)
	Mapa.Predio(rad, "AbrigoRadar", rc * CFrame.new(30, 0, 0), 24, 18, 10, true)

	-- VIA DE SERVICO E CERCA PATRIMONIAL -----------------------------------------
	local servico = Mapa.Pasta("ViaServico", ae)
	Mapa.Via(servico, Vector3.new(2060, Y, -3300), Vector3.new(2060, Y, 3300), 16)
	Mapa.Via(servico, Vector3.new(2060, Y, -4200), Vector3.new(2060, Y, -3300), 12, true)
	Mapa.Via(servico, Vector3.new(1150, Y, 2420), Vector3.new(2060, Y, 2420), 12)
	local cerca = Mapa.Pasta("Cerca", ae)
	local x1, x2, z1, z2 = -1100, 2600, -7800, 8800
	local cantos = { Vector3.new(x1, Y, z1), Vector3.new(x2, Y, z1), Vector3.new(x2, Y, z2), Vector3.new(x1, Y, z2), Vector3.new(x1, Y, z1) }
	for i = 1, 4 do
		local a, b = cantos[i], cantos[i + 1]
		local dist = (b - a).Magnitude
		local n = math.ceil(dist / 200)
		for k = 0, n - 1 do
			local p1 = a + (b - a) * (k / n)
			local p2 = a + (b - a) * ((k + 1) / n)
			local sobreVia = (math.abs(p1.Z - 10) < 120 and math.abs(p1.X - x2) < 1) -- passagem da avenida
			if not sobreVia then
				local meio = (p1 + p2) / 2
				C.Parte(cerca, "Tela", Vector3.new(0.2, 8, (p2 - p1).Magnitude), CFrame.lookAt(meio + Vector3.new(0, 4, 0), p2 + Vector3.new(0, 4, 0)) * CFrame.Angles(0, 0, 0),
					Color3.fromRGB(70, 75, 70), Enum.Material.Fabric, { Transparency = 0.55 })
				C.Tubo(cerca, "Mourao", p1, p1 + Vector3.new(0, 9, 0), 0.5, Color3.fromRGB(120, 120, 120), Enum.Material.Metal)
			end
		end
	end
end

return A
