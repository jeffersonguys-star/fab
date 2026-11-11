--[[
	FAB - Area de ensino da base (ModuleScript)

	Fica a leste do patio de aeronaves: portao das armas, comando da base, patio de
	formatura, quadro das esquadrilhas, alojamentos do Corpo de Cadetes, rancho,
	pista de corrida, area de exercicios, sala de instrucao, medicina aeroespacial,
	centro de simulacao, area de salto e, do outro lado da pista, a mata de sobrevivencia.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local FAB = ReplicatedStorage:WaitForChild("FAB")
local C = require(FAB:WaitForChild("Construtor"))
local MD = require(FAB:WaitForChild("MapaDados"))

local E = {}

function E.Construir(N, Mapa, raiz)
	local Y = MD.Plato
	local O = CFrame.new(3500, Y, 0)
	local function L(x, y, z) return O * CFrame.new(x, y, z) end
	local function V(x, y, z) return (O * CFrame.new(x, y, z)).Position end
	local cores = Mapa.Cores
	local BRANCO, AZUL, CINZA, CONCRETO = cores.Branco, cores.Azul, cores.Cinza, cores.Concreto
	local pasta = Mapa.Pasta
	local area = pasta("AreaEnsino", raiz)

	-- Chegada
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Chegada"
	spawn.Anchored = true
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.CFrame = L(0, 0.5, 30)
	spawn.Material = Enum.Material.Concrete
	spawn.Color = CONCRETO
	spawn.Duration = 0
	spawn.Neutral = true
	spawn.Parent = area
	local dec = spawn:FindFirstChildOfClass("Decal")
	if dec then dec:Destroy() end
	N.DefinirLocal("Chegada", L(0, 4, 30))
	C.Parte(area, "PracaChegada", Vector3.new(60, 0.4, 40), L(0, 0.2, 30), Color3.fromRGB(196, 194, 186), Enum.Material.Pavement)

	-- Vias da area de ensino
	local vias = pasta("Vias", area)
	Mapa.Via(vias, V(820, 0, 10), V(-1450, 0, 10), 18)
	Mapa.Via(vias, V(-300, 0, -300), V(-300, 0, 320), 14)
	Mapa.Via(vias, V(120, 0, 10), V(120, 0, -60), 12)
	Mapa.Via(vias, V(60, 0, 18), V(60, 0, 192), 14)
	Mapa.Via(vias, V(300, 0, -300), V(300, 0, 320), 14)

	-- Portao das Armas (entrada da base)
	local portao = pasta("PortaoDasArmas", area)
	local pg = L(780, 0, 10)
	C.Parte(portao, "Guarita", Vector3.new(10, 9, 8), pg * CFrame.new(0, 4.5, -18), BRANCO, Enum.Material.Concrete)
	C.Parte(portao, "JanelaGuarita", Vector3.new(10.2, 3, 6), pg * CFrame.new(0, 5.5, -18), Color3.fromRGB(110, 140, 160), Enum.Material.Glass, { Transparency = 0.4 })
	C.Parte(portao, "TelhadoGuarita", Vector3.new(12, 0.8, 10), pg * CFrame.new(0, 9.4, -18), AZUL, Enum.Material.Metal)
	for _, z in ipairs({ -12, 12 }) do
		C.Parte(portao, "Pilar", Vector3.new(4, 14, 4), pg * CFrame.new(0, 7, z), BRANCO, Enum.Material.Concrete)
	end
	local arco = C.Parte(portao, "Portico", Vector3.new(4, 4, 28), pg * CFrame.new(0, 16, 0), AZUL, Enum.Material.Concrete)
	local gArco = C.Tela(arco, Enum.NormalId.Right, 20)
	C.Texto(gArco, "BASE AÉREA DE INSTRUÇÃO", { Font = Enum.Font.GothamBlack })
	local gArco2 = C.Tela(arco, Enum.NormalId.Left, 20)
	C.Texto(gArco2, "FORÇA AÉREA BRASILEIRA", { Font = Enum.Font.GothamBlack })
	local cancela = C.Parte(portao, "Cancela", Vector3.new(0.5, 0.5, 9), pg * CFrame.new(-6, 3.5, -4.5), Color3.fromRGB(230, 40, 40), Enum.Material.SmoothPlastic)
	Mapa.Bandeira(portao, pg * CFrame.new(10, 0, -24), 24)

	-- Comando da Base
	local cmdCF = L(0, 0, 100)
	local comando = Mapa.Predio(area, "ComandoDaBase", cmdCF, 70, 40, 16, true)
	local letreiro = C.Parte(comando, "Letreiro", Vector3.new(30, 3, 0.3), cmdCF * CFrame.new(0, 14, -20.8), AZUL, Enum.Material.SmoothPlastic)
	local gL = C.Tela(letreiro, Enum.NormalId.Front, 20)
	C.Texto(gL, "COMANDO DA BASE AÉREA", { Font = Enum.Font.GothamBold })
	for i = -1, 1 do
		Mapa.Bandeira(area, cmdCF * CFrame.new(i * 14, 0, -38), 28)
	end

	-- Patio de formatura
	local patio = pasta("PatioFormatura", area)
	C.Parte(patio, "Piso", Vector3.new(110, 1, 76), L(0, 0.5, -60), CONCRETO, Enum.Material.Concrete)
	for x = -50, 50, 10 do
		C.Parte(patio, "Junta", Vector3.new(0.2, 0.05, 76), L(x, 1.02, -60), Color3.fromRGB(140, 138, 130), Enum.Material.Concrete, { CanCollide = false })
	end
	local pal = L(0, 1, -95)
	C.Parte(patio, "Palanque", Vector3.new(24, 3, 10), pal * CFrame.new(0, 1.5, 0), BRANCO, Enum.Material.Concrete)
	C.Parte(patio, "PalanqueFaixa", Vector3.new(24.2, 0.6, 10.2), pal * CFrame.new(0, 2.6, 0), AZUL, Enum.Material.SmoothPlastic)
	C.Escada(patio, pal * CFrame.new(0, 0, 9), 6, 3, 4)
	C.Corrimao(patio, { (pal * CFrame.new(-12, 3, -5)).Position, (pal * CFrame.new(12, 3, -5)).Position }, 3)
	Mapa.Bandeira(patio, L(-30, 1, -97))
	Mapa.Bandeira(patio, L(30, 1, -97))
	N.DefinirLocal("FormaturaInstrutor", L(0, 7, -95) * CFrame.Angles(0, math.rad(180), 0))
	N.DefinirLocal("FormaturaGrade", L(0, 4, -70))
	N.Placas.OrdemUnida = Mapa.Placa(patio, "PlacaOrdemUnida", L(-50, 1, -18), "Ordem Unida", "Entrar em forma")
	for fila = 0, 4 do
		for col = -4, 4 do
			C.Parte(patio, "Marca", Vector3.new(1.2, 0.05, 1.2), L(col * 4.5, 1.03, -70 + fila * 5), Color3.fromRGB(240, 240, 240), Enum.Material.SmoothPlastic, { CanCollide = false })
		end
	end

	-- Quadro das esquadrilhas
	local q = pasta("QuadroEsquadrilhas", area)
	local quadro = C.Parte(q, "Quadro", Vector3.new(16, 9, 0.5), L(50, 6.5, -18), Color3.fromRGB(10, 10, 10), Enum.Material.SmoothPlastic)
	C.Parte(q, "Base", Vector3.new(17, 2, 1.5), L(50, 1, -18), CINZA, Enum.Material.Concrete)
	N.QuadroEsquadrilhas = quadro

	-- Alojamentos do Corpo de Cadetes e rancho
	local alo1 = Mapa.Predio(area, "AlojamentoCadetes1", L(110, 0, -160), 90, 30, 14, true)
	local alo2 = Mapa.Predio(area, "AlojamentoCadetes2", L(210, 0, -160), 90, 30, 14, true)
	for _, a in ipairs({ { alo1, L(110, 0, -160) }, { alo2, L(210, 0, -160) } }) do
		local l = C.Parte(a[1], "Letreiro", Vector3.new(26, 2.4, 0.3), a[2] * CFrame.new(0, 13, -15.8), AZUL, Enum.Material.SmoothPlastic)
		local g = C.Tela(l, Enum.NormalId.Front, 20)
		C.Texto(g, "CORPO DE CADETES DA AERONÁUTICA", { Font = Enum.Font.GothamBold })
	end
	Mapa.Predio(area, "Rancho", L(-110, 0, 100), 60, 40, 12, true)

	-- Pista de corrida (oval) e area de exercicios
	local pc = pasta("PistaCorrida", area)
	local centro = V(-210, 0, -60)
	local raio, reta = 34, 70
	local pontos = {}
	local segs = 40
	local per = 2 * reta + 2 * math.pi * raio
	for i = 0, segs - 1 do
		local d = i / segs * per
		local x, z
		if d < reta then
			x, z = raio, -reta / 2 + d
		elseif d < reta + math.pi * raio then
			local a = (d - reta) / raio
			x, z = raio * math.cos(a), reta / 2 + raio * math.sin(a)
		elseif d < 2 * reta + math.pi * raio then
			x, z = -raio, reta / 2 - (d - reta - math.pi * raio)
		else
			local a = math.pi + (d - 2 * reta - math.pi * raio) / raio
			x, z = raio * math.cos(a), -reta / 2 + raio * math.sin(a)
		end
		table.insert(pontos, centro + Vector3.new(x, 0, z))
	end
	C.Parte(pc, "Gramado", Vector3.new(2 * raio + 30, 0.25, reta + 2 * raio + 30), CFrame.new(centro + Vector3.new(0, 0.12, 0)), Color3.fromRGB(70, 125, 60), Enum.Material.Grass)
	for i = 1, #pontos do
		local a, b = pontos[i], pontos[i % #pontos + 1]
		local meio = (a + b) / 2
		local comp = (b - a).Magnitude + 0.6
		C.Parte(pc, "Pista", Vector3.new(9, 0.3, comp), CFrame.lookAt(meio + Vector3.new(0, 0.28, 0), b + Vector3.new(0, 0.28, 0)),
			Color3.fromRGB(150, 62, 48), Enum.Material.Ground)
	end
	C.Parte(pc, "Largada", Vector3.new(9, 0.06, 0.8), CFrame.new(pontos[1] + Vector3.new(0, 0.46, 0)), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, { CanCollide = false })
	N.PontosCorrida = pontos
	N.Placas.Corrida = Mapa.Placa(pc, "PlacaCorrida", CFrame.new(centro + Vector3.new(raio + 12, 0, -6)) * CFrame.Angles(0, math.rad(90), 0), "TACF - Corrida", "Largada da pista")
	-- arquibancada
	for i = 0, 3 do
		C.Parte(pc, "Arquibancada", Vector3.new(4, 1.2 + i * 1.2, 50), CFrame.new(centro + Vector3.new(-raio - 12 - i * 4, 0.6 + i * 0.6, 0)), Color3.fromRGB(200, 200, 200), Enum.Material.Concrete)
	end
	local ex = pasta("AreaExercicios", area)
	local exCF = L(-120, 0, -60)
	C.Parte(ex, "Piso", Vector3.new(30, 0.6, 24), exCF * CFrame.new(0, 0.3, 0), Color3.fromRGB(70, 110, 70), Enum.Material.Rubber)
	for i = -2, 2 do
		C.Parte(ex, "Colchonete", Vector3.new(3, 0.3, 7), exCF * CFrame.new(i * 5, 0.75, 0), Color3.fromRGB(25, 45, 90), Enum.Material.Fabric)
	end
	-- barras e cobertura
	for _, x in ipairs({ -14, 14 }) do
		C.Tubo(ex, "Coluna", (exCF * CFrame.new(x, 0, -11)).Position, (exCF * CFrame.new(x, 12, -11)).Position, 0.6, CINZA, Enum.Material.Metal)
		C.Tubo(ex, "Coluna", (exCF * CFrame.new(x, 0, 11)).Position, (exCF * CFrame.new(x, 12, 11)).Position, 0.6, CINZA, Enum.Material.Metal)
	end
	C.Parte(ex, "Cobertura", Vector3.new(32, 0.5, 26), exCF * CFrame.new(0, 12.2, 0), Color3.fromRGB(200, 205, 210), Enum.Material.Metal)
	N.DefinirLocal("Exercicios", exCF * CFrame.new(0, 4, 0))
	N.Placas.Exercicios = Mapa.Placa(ex, "PlacaExercicios", exCF * CFrame.new(0, 0, 16), "TACF - Flexões e Abdominais", "Teste de condicionamento")

	-- Sala de instrucao teorica
	local ensino = pasta("Ensino", area)
	local salaCF = L(170, 0, -60) * CFrame.Angles(0, math.rad(90), 0)
	local sala = Mapa.Predio(ensino, "SalaDeAula", salaCF, 44, 36, 14, true)
	for fila = 0, 3 do
		for col = -2, 2 do
			local mesa = salaCF * CFrame.new(col * 7, 0, -12 + fila * 6)
			C.Parte(sala, "Mesa", Vector3.new(4, 0.3, 2), mesa * CFrame.new(0, 3.2, 0), Color3.fromRGB(150, 110, 70), Enum.Material.Wood)
			C.Parte(sala, "PeMesa", Vector3.new(3.6, 2.2, 0.2), mesa * CFrame.new(0, 2, 0.8), CINZA, Enum.Material.Metal)
			C.Parte(sala, "Cadeira", Vector3.new(2, 0.3, 2), mesa * CFrame.new(0, 2.2, -2.2), Color3.fromRGB(30, 30, 34), Enum.Material.Plastic)
			C.Parte(sala, "Encosto", Vector3.new(2, 2, 0.25), mesa * CFrame.new(0, 3.3, -3.1), Color3.fromRGB(30, 30, 34), Enum.Material.Plastic)
		end
	end
	local lousa = C.Parte(sala, "Lousa", Vector3.new(18, 7, 0.3), salaCF * CFrame.new(0, 8, 17.2), Color3.fromRGB(240, 240, 240), Enum.Material.SmoothPlastic)
	local gl = C.Tela(lousa, Enum.NormalId.Front, 30)
	C.Texto(gl, "INSTRUÇÃO TEÓRICA", { TextColor3 = Color3.fromRGB(20, 20, 20), Size = UDim2.fromScale(0.9, 0.2), Position = UDim2.fromScale(0.05, 0.08) })
	C.Texto(gl, "Aerodinâmica  ·  Navegação  ·  Meteorologia  ·  Regulamentos", { TextColor3 = Color3.fromRGB(60, 60, 60), Font = Enum.Font.Gotham,
		Size = UDim2.fromScale(0.9, 0.1), Position = UDim2.fromScale(0.05, 0.34) })
	local mesaInstrutor = C.Parte(sala, "MesaInstrutor", Vector3.new(8, 3.4, 3), salaCF * CFrame.new(0, 2.7, 12), Color3.fromRGB(40, 40, 44), Enum.Material.Wood)
	N.Placas.Teoria = mesaInstrutor
	N.DefinirLocal("SalaAula", salaCF * CFrame.new(0, 4, 4))
	Mapa.Placa(ensino, "PlacaEnsino", salaCF * CFrame.new(10, 0, -24) * CFrame.Angles(0, math.rad(180), 0), "Divisão de Ensino", "Instrução teórica")

	-- Medicina aeroespacial (camara hipobarica e centrifuga)
	local medCF = L(170, 0, 60) * CFrame.Angles(0, math.rad(90), 0)
	local med = Mapa.Predio(ensino, "MedicinaAeroespacial", medCF, 60, 44, 18, true)
	local cam = medCF * CFrame.new(-14, 0, 6)
	C.Cilindro(med, "Camara", 9, 18, cam * CFrame.new(0, 6, 0) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(190, 196, 200), Enum.Material.Metal)
	for i = -1, 1 do
		local v = C.Cilindro(med, "Visor", 1.6, 0.4, cam * CFrame.new(-4.4, 6.5, i * 5), Color3.fromRGB(90, 130, 160), Enum.Material.Glass, { Transparency = 0.3 })
		C.Luz(v, "PointLight", { Range = 6, Brightness = 0.6, Color = Color3.fromRGB(180, 220, 255) })
	end
	C.Parte(med, "PortaCamara", Vector3.new(0.6, 6, 3.6), cam * CFrame.new(-4.6, 4.5, -7), Color3.fromRGB(150, 156, 160), Enum.Material.DiamondPlate)
	local painelCam = C.Parte(med, "PainelCamara", Vector3.new(4, 4, 1), cam * CFrame.new(-7, 3, -9), Color3.fromRGB(30, 30, 32), Enum.Material.Metal)
	local gp = C.Tela(painelCam, Enum.NormalId.Front, 60)
	C.Texto(gp, "ALTITUDE\n25.000 ft", { TextColor3 = Color3.fromRGB(120, 255, 140), Font = Enum.Font.Code })
	N.Placas.Hipoxia = painelCam
	N.DefinirLocal("Hipoxia", cam * CFrame.new(0, 4, 0))
	local cen = medCF * CFrame.new(14, 0, 6)
	C.Cilindro(med, "BaseCentrifuga", 5, 2.5, cen * CFrame.new(0, 2.25, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(60, 62, 66), Enum.Material.Metal)
	local braco = Instance.new("Model")
	braco.Name = "BracoCentrifuga"
	braco.Parent = med
	local eixo = C.Cilindro(braco, "Eixo", 2, 3, cen * CFrame.new(0, 4.5, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(200, 200, 205), Enum.Material.Metal)
	C.Parte(braco, "Braco", Vector3.new(10, 1.2, 1.6), cen * CFrame.new(5, 5.5, 0), Color3.fromRGB(220, 220, 225), Enum.Material.Metal)
	C.Esfera(braco, "Gondola", 4.4, cen * CFrame.new(9.5, 5.5, 0), Color3.fromRGB(235, 235, 235), Enum.Material.SmoothPlastic)
	C.Esfera(braco, "Contrapeso", 2.6, cen * CFrame.new(-2.5, 5.5, 0), Color3.fromRGB(80, 80, 85), Enum.Material.Metal)
	braco.PrimaryPart = eixo
	local painelCen = C.Parte(med, "PainelCentrifuga", Vector3.new(4, 4, 1), medCF * CFrame.new(14, 3, -13), Color3.fromRGB(30, 30, 32), Enum.Material.Metal)
	local gc = C.Tela(painelCen, Enum.NormalId.Front, 60)
	C.Texto(gc, "CENTRÍFUGA\nPERFIL G", { TextColor3 = Color3.fromRGB(120, 255, 140), Font = Enum.Font.Code })
	N.Placas.Centrifuga = painelCen
	N.BracoCentrifuga = braco
	N.DefinirLocal("Centrifuga", medCF * CFrame.new(14, 4, -10))
	local pts = {}
	for i = 0, 16 do
		local a = i / 16 * math.pi * 2
		table.insert(pts, (cen * CFrame.new(math.cos(a) * 13, 1, math.sin(a) * 13)).Position)
	end
	C.Corrimao(med, pts, 3.5, Color3.fromRGB(240, 190, 30))
	Mapa.Placa(ensino, "PlacaMedicina", medCF * CFrame.new(12, 0, -30) * CFrame.Angles(0, math.rad(180), 0), "Medicina Aeroespacial", "Câmara hipobárica e centrífuga")

	-- Centro de simulacao (hangar das maquinas)
	local hg = pasta("CentroSimulacao", area)
	local hCF = L(0, 0, 230)
	local largura, prof, alt = 130, 80, 30
	C.Parte(hg, "Piso", Vector3.new(largura, 1, prof), hCF * CFrame.new(0, 0.5, 0), Color3.fromRGB(150, 150, 146), Enum.Material.Concrete)
	local corParede = Color3.fromRGB(210, 212, 214)
	C.Parte(hg, "ParedeFundo", Vector3.new(largura, alt, 1.5), hCF * CFrame.new(0, alt / 2 + 1, prof / 2), corParede, Enum.Material.CorrodedMetal)
	C.Parte(hg, "ParedeE", Vector3.new(1.5, alt, prof), hCF * CFrame.new(-largura / 2, alt / 2 + 1, 0), corParede, Enum.Material.CorrodedMetal)
	C.Parte(hg, "ParedeD", Vector3.new(1.5, alt, prof), hCF * CFrame.new(largura / 2, alt / 2 + 1, 0), corParede, Enum.Material.CorrodedMetal)
	C.Parte(hg, "FrenteE", Vector3.new(30, alt, 1.5), hCF * CFrame.new(-largura / 2 + 15, alt / 2 + 1, -prof / 2), corParede, Enum.Material.CorrodedMetal)
	C.Parte(hg, "FrenteD", Vector3.new(30, alt, 1.5), hCF * CFrame.new(largura / 2 - 15, alt / 2 + 1, -prof / 2), corParede, Enum.Material.CorrodedMetal)
	C.Parte(hg, "Verga", Vector3.new(largura, 8, 1.5), hCF * CFrame.new(0, alt - 3, -prof / 2), AZUL, Enum.Material.Metal)
	local letSim = C.Parte(hg, "Letreiro", Vector3.new(60, 5, 0.3), hCF * CFrame.new(0, alt - 3, -prof / 2 - 0.9), AZUL, Enum.Material.SmoothPlastic)
	local gLet = C.Tela(letSim, Enum.NormalId.Front, 20)
	C.Texto(gLet, "CENTRO DE SIMULAÇÃO DE VOO", { Font = Enum.Font.GothamBold })
	local segsArco = 10
	for i = 0, segsArco - 1 do
		local a1 = math.pi * i / segsArco
		local a2 = math.pi * (i + 1) / segsArco
		local r = largura / 2
		local p1 = Vector3.new(-math.cos(a1) * r, alt + 1 + math.sin(a1) * 18, 0)
		local p2 = Vector3.new(-math.cos(a2) * r, alt + 1 + math.sin(a2) * 18, 0)
		local meio = (p1 + p2) / 2
		local comp = (p2 - p1).Magnitude
		local ang = math.atan2(p2.Y - p1.Y, p2.X - p1.X)
		C.Parte(hg, "Telhado", Vector3.new(comp + 0.4, 1, prof + 2), hCF * CFrame.new(meio) * CFrame.Angles(0, 0, ang), Color3.fromRGB(180, 184, 188), Enum.Material.CorrodedMetal)
		C.Parte(hg, "Trelica", Vector3.new(comp, 0.8, 0.8), hCF * CFrame.new(meio - Vector3.new(0, 1.2, 0)) * CFrame.Angles(0, 0, ang), Color3.fromRGB(70, 72, 76), Enum.Material.Metal)
	end
	for x = -45, 45, 30 do
		for z = -20, 25, 22 do
			local l = C.Parte(hg, "Luminaria", Vector3.new(3, 0.6, 3), hCF * CFrame.new(x, alt + 4, z), Color3.fromRGB(255, 252, 240), Enum.Material.Neon)
			C.Cilindro(hg, "Refletor", 4.2, 1.2, hCF * CFrame.new(x, alt + 4.8, z) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(60, 60, 64), Enum.Material.Metal)
			C.Luz(l, "SpotLight", { Face = Enum.NormalId.Bottom, Range = 45, Brightness = 2.2, Angle = 100, Shadows = true })
		end
	end
	N.DefinirLocal("Simulador1", hCF * CFrame.new(-30, 1, 8))
	N.DefinirLocal("Simulador2", hCF * CFrame.new(30, 1, 8))
	N.DefinirLocal("HangarSimulador", hCF)

	-- Area de salto
	local sl = pasta("AreaSalto", area)
	local alvo = L(-200, 0, 380)
	C.Cilindro(sl, "AlvoExterno", 60, 0.2, alvo * CFrame.new(0, 0.1, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(240, 240, 240), Enum.Material.Sand, { CanCollide = false })
	C.Cilindro(sl, "AlvoMedio", 36, 0.24, alvo * CFrame.new(0, 0.12, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(230, 120, 30), Enum.Material.Sand, { CanCollide = false })
	C.Cilindro(sl, "AlvoCentro", 12, 0.28, alvo * CFrame.new(0, 0.14, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(240, 240, 240), Enum.Material.Sand, { CanCollide = false })
	local bir = alvo * CFrame.new(40, 0, -30)
	C.Tubo(sl, "MastroBiruta", bir.Position, (bir * CFrame.new(0, 14, 0)).Position, 0.4, Color3.fromRGB(230, 230, 230), Enum.Material.Metal)
	C.Cilindro(sl, "Biruta", 2, 6, bir * CFrame.new(3, 13.6, 0) * CFrame.Angles(0, 0, math.rad(-8)), Color3.fromRGB(240, 110, 20), Enum.Material.Fabric, { CanCollide = false })
	N.DefinirLocal("AlvoSalto", alvo)
	N.Placas.Salto = Mapa.Placa(sl, "PlacaSalto", alvo * CFrame.new(0, 0, -45) * CFrame.Angles(0, math.rad(180), 0), "Salto de Emergência", "Embarque para o lançamento")

	-- Mata de sobrevivencia (a oeste da pista)
	local mata = pasta("Mata", raiz)
	local centroMata = Vector3.new(-2700, Y, -1600)
	local clareira = centroMata + Vector3.new(0, 0, -360)
	math.randomseed(42)
	for i = 1, 420 do
		local a = math.random() * math.pi * 2
		local r = math.sqrt(math.random()) * 480
		local p = centroMata + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
		if (p - clareira).Magnitude > 26 then
			Mapa.Arvore(mata, p, 0.9 + math.random() * 0.9, i % 3 == 0)
		end
	end
	for i = 0, 11 do
		local a = i / 12 * math.pi * 2
		C.Esfera(mata, "Pedra", 2 + math.random(), CFrame.new(clareira + Vector3.new(math.cos(a) * 20, 0.4, math.sin(a) * 20)), Color3.fromRGB(110, 110, 105), Enum.Material.Slate)
	end
	N.DefinirLocal("MataCentro", CFrame.new(centroMata))
	N.DefinirLocal("Clareira", CFrame.new(clareira))
	N.Placas.Sobrevivencia = Mapa.Placa(area, "PlacaSobrevivencia", L(-50, 1, 160) * CFrame.Angles(0, math.rad(180), 0), "Sobrevivência", "Estágio na selva (transporte até a mata)")

	-- Paisagismo: arvores ao longo das vias e da area
	local deco = pasta("Paisagismo", area)
	math.randomseed(7)
	for x = -1420, 760, 60 do
		for _, z in ipairs({ -14, 34 }) do
			if not (x > -330 and x < 330) then Mapa.Arvore(deco, V(x, 0, z), 0.9 + math.random() * 0.4, true) end
		end
	end
	for i = 1, 120 do
		local x = math.random(-600, 700)
		local z = math.random(-450, 520)
		local livre = (math.abs(x) > 320 or math.abs(z) > 300)
		if livre then Mapa.Arvore(deco, V(x, 0, z), 1 + math.random() * 0.6) end
	end
	for x = -1420, 760, 80 do
		local p = V(x, 0, 24)
		C.Tubo(deco, "Poste", p, p + Vector3.new(0, 14, 0), 0.5, CINZA, Enum.Material.Metal)
		C.Parte(deco, "Braco", Vector3.new(0.4, 0.4, 4), CFrame.new(p + Vector3.new(0, 14, -2)), CINZA, Enum.Material.Metal)
		local lamp = C.Parte(deco, "Lampada", Vector3.new(1.2, 0.3, 2), CFrame.new(p + Vector3.new(0, 13.8, -3.6)), Color3.fromRGB(255, 240, 210), Enum.Material.Neon)
		C.Luz(lamp, "SpotLight", { Face = Enum.NormalId.Bottom, Range = 30, Brightness = 1.2, Angle = 120 })
	end

	-- Farol na ponta norte da ilha
	local farol = pasta("Farol", raiz)
	local fp = CFrame.new(700, Y, -9500)
	for i = 0, 7 do
		local cor = (i % 2 == 0) and Color3.fromRGB(240, 240, 240) or Color3.fromRGB(200, 40, 40)
		C.Cilindro(farol, "Torre", 14 - i * 0.8, 8, fp * CFrame.new(0, 4 + i * 8, 0) * CFrame.Angles(0, 0, math.rad(90)), cor, Enum.Material.Concrete)
	end
	local lanterna = C.Cilindro(farol, "Lanterna", 7, 6, fp * CFrame.new(0, 71, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(255, 250, 220), Enum.Material.Neon)
	C.Luz(lanterna, "PointLight", { Range = 60, Brightness = 3, Color = Color3.fromRGB(255, 245, 210) })
	C.Cilindro(farol, "Cupula", 8, 2, fp * CFrame.new(0, 75, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(200, 40, 40), Enum.Material.Metal)
end

return E
