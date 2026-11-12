--[[
	FAB - Maquina do simulador de voo (servidor)

	Simulador de movimento completo (full motion) com plataforma Stewart de 6 atuadores
	hidraulicos, cabine fechada com cupula de projecao, ponte de acesso basculante,
	porta deslizante, giroflex, unidade hidraulica, cabos e mangueiras, corrimao de
	seguranca e estacao do instrutor (IOS) com 3 monitores de telemetria ao vivo.

	Enquanto o cadete voa, o cliente envia a atitude da aeronave e a plataforma
	reproduz arfagem, rolagem e acelerações (dentro dos limites da maquina).
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FAB = ReplicatedStorage:WaitForChild("FAB")
local C = require(FAB:WaitForChild("Construtor"))
local Aeronaves = require(FAB:WaitForChild("Aeronaves"))

local MAQ = {}

local BRANCO = Color3.fromRGB(238, 238, 236)
local GRAFITE = Color3.fromRGB(38, 40, 44)
local ACO = Color3.fromRGB(150, 154, 160)
local CROMO = Color3.fromRGB(215, 220, 226)
local AMARELO = Color3.fromRGB(245, 195, 20)
local AZUL = Color3.fromRGB(24, 52, 110)

local ALTURA = 7        -- altura neutra do centro da plataforma superior
local RAIO_BAIXO = 8.2
local RAIO_CIMA = 5.4
local LIMITE_ANG = math.rad(14)

local function soldar(raiz, pasta)
	for _, p in ipairs(pasta:GetDescendants()) do
		if p:IsA("BasePart") and p ~= raiz then
			p.Anchored = false
			p.Massless = true
			local w = Instance.new("WeldConstraint")
			w.Part0 = raiz
			w.Part1 = p
			w.Parent = p
		end
	end
end

-- Monta uma maquina completa. lado = 1 ou -1 (lado da estacao do instrutor)
local function construir(nome, base, lado, numero)
	local m = Instance.new("Model")
	m.Name = nome
	m.Parent = workspace

	local fixo = Instance.new("Folder")
	fixo.Name = "Fixo"
	fixo.Parent = m

	-- base de aco com faixa zebrada
	C.Parte(fixo, "Base", Vector3.new(24, 0.6, 24), base * CFrame.new(0, 0.3, 0), Color3.fromRGB(70, 72, 76), Enum.Material.DiamondPlate)
	for _, s in ipairs({ { 0, 11.6, 24, 0.8 }, { 0, -11.6, 24, 0.8 }, { 11.6, 0, 0.8, 24 }, { -11.6, 0, 0.8, 24 } }) do
		local f = C.Parte(fixo, "Zebrado", Vector3.new(s[3], 0.62, s[4]), base * CFrame.new(s[1], 0.31, s[2]), AMARELO, Enum.Material.SmoothPlastic)
		C.Zebrado(f, Enum.NormalId.Top)
	end
	-- bloco central (unidade de controle de movimento)
	C.Cilindro(fixo, "Pedestal", 5, 1.6, base * CFrame.new(0, 1.4, 0) * CFrame.Angles(0, 0, math.rad(90)), GRAFITE, Enum.Material.Metal)
	local anel = C.Cilindro(fixo, "AnelLuz", 5.3, 0.25, base * CFrame.new(0, 2.25, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(60, 140, 255), Enum.Material.Neon)
	C.Luz(anel, "PointLight", { Range = 10, Brightness = 0.8, Color = Color3.fromRGB(80, 150, 255) })

	-- pontos das juntas inferiores e superiores (pares a cada 120 graus)
	local juntasBaixo, juntasCima = {}, {}
	for k = 0, 2 do
		for _, d in ipairs({ -1, 1 }) do
			local aB = math.rad(k * 120 + d * 16)
			local aC = math.rad(k * 120 + 60 - d * 44)
			table.insert(juntasBaixo, Vector3.new(math.cos(aB) * RAIO_BAIXO, 1.0, math.sin(aB) * RAIO_BAIXO))
			table.insert(juntasCima, Vector3.new(math.cos(aC) * RAIO_CIMA, -0.7, math.sin(aC) * RAIO_CIMA))
		end
	end
	for _, j in ipairs(juntasBaixo) do
		C.Parte(fixo, "SuporteJunta", Vector3.new(1.6, 0.8, 1.6), base * CFrame.new(j.X, 0.9, j.Z), ACO, Enum.Material.Metal)
		C.Esfera(fixo, "JuntaInferior", 1.1, base * CFrame.new(j), CROMO, Enum.Material.Metal)
	end

	-- atuadores (cilindro + haste), atualizados a cada quadro
	local atuadores = {}
	for i = 1, 6 do
		local camisa = C.Cilindro(fixo, "Camisa" .. i, 1.15, 4.4, CFrame.new(), Color3.fromRGB(46, 48, 52), Enum.Material.Metal)
		local faixa = C.Cilindro(fixo, "FaixaAtuador" .. i, 1.2, 0.2, CFrame.new(), Color3.fromRGB(60, 140, 255), Enum.Material.Neon)
		local haste = C.Cilindro(fixo, "Haste" .. i, 0.55, 3, CFrame.new(), CROMO, Enum.Material.Metal, { Reflectance = 0.25 })
		local bota = C.Cilindro(fixo, "Sanfona" .. i, 0.8, 0.9, CFrame.new(), Color3.fromRGB(25, 25, 25), Enum.Material.Rubber)
		atuadores[i] = { Camisa = camisa, Faixa = faixa, Haste = haste, Bota = bota }
	end

	-- PARTE MOVEL ---------------------------------------------------------------
	local movel = Instance.new("Folder")
	movel.Name = "Movel"
	movel.Parent = m
	local cfNeutro = base * CFrame.new(0, ALTURA, 0)
	local raiz = C.Parte(movel, "PlataformaSuperior", Vector3.new(12, 0.8, 12), cfNeutro, Color3.fromRGB(60, 62, 66), Enum.Material.DiamondPlate)
	-- cantos chanfrados da plataforma (forma hexagonal)
	for k = 0, 5 do
		local a = math.rad(k * 60)
		C.Parte(movel, "Chanfro", Vector3.new(6.4, 0.8, 1.2), cfNeutro * CFrame.Angles(0, -a, 0) * CFrame.new(0, 0, 6.2), Color3.fromRGB(60, 62, 66), Enum.Material.DiamondPlate)
	end
	for _, j in ipairs(juntasCima) do
		C.Esfera(movel, "JuntaSuperior", 1, cfNeutro * CFrame.new(j), CROMO, Enum.Material.Metal)
		C.Parte(movel, "Garra", Vector3.new(1.4, 0.6, 1.4), cfNeutro * CFrame.new(j.X, -0.35, j.Z), ACO, Enum.Material.Metal)
	end

	-- cabine (carenagem branca com cupula de projecao na frente)
	local cab = cfNeutro * CFrame.new(0, 4.4, 0.5)
	local corpo = C.Parte(movel, "Carenagem", Vector3.new(9, 7, 9), cab, BRANCO, Enum.Material.SmoothPlastic)
	local cupula = C.Esfera(movel, "Cupula", 11.5, cab * CFrame.new(0, 0.4, -3.4), BRANCO, Enum.Material.SmoothPlastic)
	local tampaTras = C.Cilindro(movel, "TampaTraseira", 9.6, 0.6, cab * CFrame.new(0, 0, 4.6) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(225, 226, 224), Enum.Material.SmoothPlastic)
	-- tenta fundir a carenagem em uma peca so (fica com cantos arredondados)
	local fundido, unido = C.Unir(corpo, { cupula, tampaTras })
	fundido.Name = "Carenagem"
	if unido then
		-- deixa a cabine oca e abre o vao da porta
		local oco = C.Parte(movel, "Oco", Vector3.new(8.2, 6.2, 8.2), cab * CFrame.new(0, 0, 0.2), BRANCO)
		local cupulaInterna = C.Esfera(movel, "CupulaInterna", 10.6, cab * CFrame.new(0, 0.4, -3.4), BRANCO)
		local vao = C.Parte(movel, "Vao", Vector3.new(3, 4.8, 3), cab * CFrame.new(0, -0.6, 4.6), BRANCO)
		fundido = C.Unir(fundido, { oco, cupulaInterna, vao }, true)
		fundido.Name = "Carenagem"
	end
	-- faixas e detalhes
	C.Parte(movel, "FaixaGrafite", Vector3.new(9.15, 0.9, 9.15), cab * CFrame.new(0, -2.2, 0), GRAFITE, Enum.Material.SmoothPlastic)
	C.Parte(movel, "FaixaAzul", Vector3.new(9.2, 0.25, 9.2), cab * CFrame.new(0, -1.6, 0), AZUL, Enum.Material.SmoothPlastic)
	C.Parte(movel, "Saia", Vector3.new(10, 1, 10.5), cab * CFrame.new(0, -3.7, 0), Color3.fromRGB(205, 206, 204), Enum.Material.Metal)
	-- grades de ventilacao nas laterais
	for _, sx in ipairs({ -1, 1 }) do
		for i = 0, 5 do
			C.Parte(movel, "Grade", Vector3.new(0.1, 0.12, 2.6), cab * CFrame.new(sx * 4.55, 1.2 + i * 0.35, 1.8), GRAFITE, Enum.Material.Metal)
		end
		local plaquinha = C.Parte(movel, "Identificacao", Vector3.new(0.05, 1.3, 4.2), cab * CFrame.new(sx * 4.56, -0.6, -0.5), BRANCO, Enum.Material.SmoothPlastic)
		local g = C.Tela(plaquinha, sx > 0 and Enum.NormalId.Right or Enum.NormalId.Left, 60)
		C.Texto(g, "FAB  |  SIMULADOR " .. string.format("%02d", numero), { TextColor3 = AZUL, Font = Enum.Font.GothamBlack })
	end
	-- equipamentos no teto: modulo de projetores e trocadores de calor
	C.Parte(movel, "ModuloTeto", Vector3.new(5, 1.2, 4), cab * CFrame.new(0, 4.1, 1.5), Color3.fromRGB(210, 212, 214), Enum.Material.Metal)
	for i = -1, 1 do
		C.Cilindro(movel, "Ventoinha", 1.2, 0.3, cab * CFrame.new(i * 1.5, 4.8, 1.5) * CFrame.Angles(0, 0, math.rad(90)), GRAFITE, Enum.Material.Metal)
	end
	for i = -1, 1, 2 do
		C.Cilindro(movel, "Projetor", 0.9, 1.6, cab * CFrame.new(i * 1.8, 4.2, -1.5) * CFrame.Angles(0, math.rad(90), math.rad(-20)), GRAFITE, Enum.Material.Metal)
	end
	-- porta traseira (moldura fixa; a folha desliza)
	C.Parte(movel, "MolduraPorta", Vector3.new(3.4, 5.2, 0.3), cab * CFrame.new(0, -0.6, 4.95), GRAFITE, Enum.Material.Metal)
	-- interior: assento ejetavel, manche, painel e telas
	local interior = cab * CFrame.new(0, -2.9, 0.5)
	C.Parte(movel, "PisoCabine", Vector3.new(6, 0.3, 7), interior, Color3.fromRGB(30, 30, 32), Enum.Material.Rubber)
	C.Parte(movel, "Assento", Vector3.new(2.2, 1.4, 2.2), interior * CFrame.new(0, 1, 1), Color3.fromRGB(40, 44, 40), Enum.Material.Fabric)
	C.Parte(movel, "Encosto", Vector3.new(2.2, 3.6, 0.6), interior * CFrame.new(0, 3, 2.2) * CFrame.Angles(math.rad(-12), 0, 0), Color3.fromRGB(40, 44, 40), Enum.Material.Fabric)
	C.Parte(movel, "Cabeceira", Vector3.new(1.6, 1, 0.8), interior * CFrame.new(0, 5.1, 2.6), Color3.fromRGB(240, 120, 20), Enum.Material.Fabric)
	C.Tubo(movel, "Manche", (interior * CFrame.new(0, 0.2, -0.4)).Position, (interior * CFrame.new(0, 2.4, -0.6)).Position, 0.18, GRAFITE, Enum.Material.Metal)
	local painel = C.Parte(movel, "Painel", Vector3.new(5, 2, 0.6), interior * CFrame.new(0, 3.2, -2.6) * CFrame.Angles(math.rad(-20), 0, 0), GRAFITE, Enum.Material.Metal)
	local gPainel = C.Tela(painel, Enum.NormalId.Back, 80)
	local fPainel = Instance.new("Frame")
	fPainel.Size = UDim2.fromScale(1, 1)
	fPainel.BackgroundColor3 = Color3.fromRGB(8, 8, 8)
	fPainel.Parent = gPainel
	C.Texto(fPainel, "PFD        HSI        EICAS", { TextColor3 = Color3.fromRGB(120, 255, 160), Font = Enum.Font.Code, Size = UDim2.fromScale(1, 0.3), Position = UDim2.fromScale(0, 0.35) })
	local telaCupula = C.Esfera(movel, "TelaProjecao", 10.6, cab * CFrame.new(0, 0.4, -3.4), Color3.fromRGB(250, 250, 250), Enum.Material.SmoothPlastic, { CanCollide = false })
	telaCupula.Transparency = 1
	-- giroflex
	local giroBase = C.Cilindro(movel, "BaseGiroflex", 0.9, 0.3, cab * CFrame.new(-2.8, 3.65, 3.2) * CFrame.Angles(0, 0, math.rad(90)), GRAFITE, Enum.Material.Metal)
	local lente = C.Esfera(movel, "Giroflex", 0.8, cab * CFrame.new(-2.8, 4, 3.2), Color3.fromRGB(255, 150, 20), Enum.Material.Glass, { Transparency = 0.2 })
	local luzGiro = C.Luz(lente, "SpotLight", { Range = 40, Brightness = 0, Angle = 50, Color = Color3.fromRGB(255, 150, 20), Face = Enum.NormalId.Front })

	-- folha da porta (desliza para o lado)
	local porta = C.Parte(movel, "Porta", Vector3.new(3, 4.8, 0.25), cab * CFrame.new(0, -0.6, 5.12), Color3.fromRGB(225, 226, 224), Enum.Material.SmoothPlastic)
	local macaneta = C.Parte(movel, "Macaneta", Vector3.new(0.15, 0.6, 0.15), cab * CFrame.new(1.1, -0.6, 5.3), GRAFITE, Enum.Material.Metal)
	local visor = C.Parte(movel, "VisorPorta", Vector3.new(1.2, 0.8, 0.27), cab * CFrame.new(0, 0.8, 5.12), Color3.fromRGB(40, 60, 80), Enum.Material.Glass, { Transparency = 0.3 })

	soldar(raiz, movel)
	-- a porta e soldada a raiz, mas guarda o deslocamento para deslizar
	for _, p in ipairs({ porta, macaneta, visor, lente }) do
		local w = p:FindFirstChildOfClass("WeldConstraint")
		if w then w:Destroy() end
		local wj = Instance.new("Weld")
		wj.Part0 = raiz
		wj.Part1 = p
		wj.C0 = raiz.CFrame:ToObjectSpace(p.CFrame)
		wj.Parent = p
		p:SetAttribute("C0", wj.C0)
	end

	-- TORRE DE ACESSO, PONTE E ESCADA ------------------------------------------
	local acesso = Instance.new("Folder")
	acesso.Name = "Acesso"
	acesso.Parent = m
	local alturaPiso = ALTURA + 0.4 + 4.4 - 3.05
	local torre = base * CFrame.new(0, 0, 15.5)
	C.Parte(acesso, "PisoTorre", Vector3.new(7, 0.5, 5), torre * CFrame.new(0, alturaPiso - 0.25, 0), Color3.fromRGB(70, 72, 76), Enum.Material.DiamondPlate)
	for _, px in ipairs({ -3.2, 3.2 }) do
		for _, pz in ipairs({ -2.2, 2.2 }) do
			C.Parte(acesso, "Coluna", Vector3.new(0.5, alturaPiso, 0.5), torre * CFrame.new(px, alturaPiso / 2, pz), AMARELO, Enum.Material.Metal)
		end
	end
	C.Corrimao(acesso, {
		(torre * CFrame.new(-3.3, alturaPiso, -2.3)).Position, (torre * CFrame.new(-3.3, alturaPiso, 2.4)).Position,
		(torre * CFrame.new(3.3, alturaPiso, 2.4)).Position,
	}, 3.2)
	-- escada descendo para o lado interno do hangar
	local inicioEscada = torre * CFrame.new(-lado * 3.5, 0, 0)
	local degraus = math.floor(alturaPiso / 0.6 + 0.5)
	local comprimento = degraus * 1.1
	local cfEscada = CFrame.lookAt((inicioEscada * CFrame.new(-lado * comprimento, 0, 0)).Position, inicioEscada.Position)
	C.Escada(acesso, cfEscada, 3.4, alturaPiso, degraus, Color3.fromRGB(70, 72, 76))
	local topo = (inicioEscada * CFrame.new(0, alturaPiso, 0)).Position
	local pe = (inicioEscada * CFrame.new(-lado * comprimento, 0, 0)).Position
	for _, dz in ipairs({ -1.8, 1.8 }) do
		C.Tubo(acesso, "CorrimaoEscada", pe + Vector3.new(0, 3.2, dz), topo + Vector3.new(0, 3.2, dz), 0.22, AMARELO, Enum.Material.Metal)
		C.Tubo(acesso, "PosteEscada", pe + Vector3.new(0, 0, dz), pe + Vector3.new(0, 3.2, dz), 0.22, AMARELO, Enum.Material.Metal)
	end
	-- ponte basculante (articulada na torre)
	local dobradica = torre * CFrame.new(0, alturaPiso - 0.2, -2.5)
	local ponte = C.Parte(acesso, "Ponte", Vector3.new(3.2, 0.4, 5.6), dobradica * CFrame.new(0, 0, -2.8), Color3.fromRGB(80, 82, 86), Enum.Material.DiamondPlate)
	local corrPonte = C.Parte(acesso, "GuardaPonte", Vector3.new(0.2, 3, 5.6), dobradica * CFrame.new(1.6, 1.5, -2.8), AMARELO, Enum.Material.Metal, { Transparency = 0 })
	local corrPonte2 = C.Parte(acesso, "GuardaPonte", Vector3.new(0.2, 3, 5.6), dobradica * CFrame.new(-1.6, 1.5, -2.8), AMARELO, Enum.Material.Metal)
	local pistao = C.Tubo(acesso, "PistaoPonte", (torre * CFrame.new(1.2, 0.5, -2.3)).Position, (dobradica * CFrame.new(1.2, -0.3, -2.4)).Position, 0.3, CROMO, Enum.Material.Metal)

	-- corrimao de seguranca em volta da area de movimento (com abertura na escada)
	local pontos = {}
	for i = 0, 20 do
		local a = math.rad(110 + i * 16)
		table.insert(pontos, (base * CFrame.new(math.cos(a) * 13.5, 0.6, math.sin(a) * 13.5)).Position)
	end
	C.Corrimao(fixo, pontos, 3.4)

	-- unidade hidraulica e cabos
	local uh = base * CFrame.new(lado * 9, 0, -16)
	C.Parte(fixo, "UnidadeHidraulica", Vector3.new(6, 6, 3.5), uh * CFrame.new(0, 3.6, 0), Color3.fromRGB(28, 70, 140), Enum.Material.Metal)
	C.Parte(fixo, "BaseUH", Vector3.new(6.4, 0.6, 3.9), uh * CFrame.new(0, 0.3, 0), GRAFITE, Enum.Material.Metal)
	local leds = {}
	for i = 0, 5 do
		local led = C.Parte(fixo, "LED", Vector3.new(0.25, 0.25, 0.1), uh * CFrame.new(-2.2 + i * 0.5, 5.6, -1.8), Color3.fromRGB(40, 255, 90), Enum.Material.Neon)
		table.insert(leds, led)
	end
	local manometro = C.Cilindro(fixo, "Manometro", 1, 0.15, uh * CFrame.new(1.8, 4.4, -1.8) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(240, 240, 240), Enum.Material.SmoothPlastic)
	C.Tubo(fixo, "Tubulacao", (uh * CFrame.new(-2, 1.2, 1.8)).Position, (base * CFrame.new(-2, 0.9, -9)).Position, 0.4, GRAFITE, Enum.Material.Metal)
	C.Tubo(fixo, "Tubulacao", (uh * CFrame.new(2, 1.2, 1.8)).Position, (base * CFrame.new(2, 0.9, -9)).Position, 0.4, GRAFITE, Enum.Material.Metal)
	-- calha de cabos ate a estacao do instrutor
	local ios = base * CFrame.new(lado * 17, 0, 2) * CFrame.Angles(0, math.rad(lado * 90), 0)
	C.Barra(fixo, "CalhaCabos", (base * CFrame.new(lado * 12, 0.25, 2)).Position, (ios * CFrame.new(0, 0.25, 2)).Position, 0.5, Color3.fromRGB(50, 50, 52), Enum.Material.Metal)

	-- mangueiras hidraulicas (beams curvos) da base ate cada atuador
	for i, j in ipairs(juntasBaixo) do
		local a0 = Instance.new("Attachment")
		a0.Parent = workspace.Terrain
		a0.WorldPosition = (base * CFrame.new(j.X * 0.55, 1.2, j.Z * 0.55)).Position
		local a1 = Instance.new("Attachment")
		a1.Name = "Mangueira"
		a1.Parent = atuadores[i].Camisa
		a1.Position = Vector3.new(-1.6, 0, 0.5)
		local b = Instance.new("Beam")
		b.Attachment0 = a0
		b.Attachment1 = a1
		b.Width0 = 0.22
		b.Width1 = 0.22
		b.CurveSize0 = 1.5
		b.CurveSize1 = -1.5
		b.FaceCamera = true
		b.Color = ColorSequence.new(Color3.fromRGB(20, 20, 20))
		b.Segments = 12
		b.Parent = atuadores[i].Camisa
	end

	-- ESTACAO DO INSTRUTOR (IOS) -----------------------------------------------
	local est = Instance.new("Folder")
	est.Name = "EstacaoInstrutor"
	est.Parent = m
	C.Parte(est, "Mesa", Vector3.new(8, 0.3, 3.4), ios * CFrame.new(0, 3.1, 0), Color3.fromRGB(30, 30, 32), Enum.Material.Wood)
	C.Parte(est, "Gabinete", Vector3.new(8, 2.9, 3), ios * CFrame.new(0, 1.5, 0.2), Color3.fromRGB(45, 46, 50), Enum.Material.Metal)
	local fitaLed = C.Parte(est, "FitaLED", Vector3.new(8, 0.08, 0.08), ios * CFrame.new(0, 2.95, -1.55), Color3.fromRGB(60, 140, 255), Enum.Material.Neon)
	C.Parte(est, "Teclado", Vector3.new(2.2, 0.12, 0.8), ios * CFrame.new(-0.6, 3.31, -0.8), Color3.fromRGB(20, 20, 20), Enum.Material.SmoothPlastic)
	C.Parte(est, "Mouse", Vector3.new(0.3, 0.12, 0.45), ios * CFrame.new(1, 3.31, -0.8), Color3.fromRGB(20, 20, 20), Enum.Material.SmoothPlastic)
	C.Parte(est, "Cadeira", Vector3.new(2, 0.4, 2), ios * CFrame.new(0, 2, -3), Color3.fromRGB(25, 25, 28), Enum.Material.Fabric)
	C.Parte(est, "EncostoCadeira", Vector3.new(2, 2.6, 0.4), ios * CFrame.new(0, 3.5, -4), Color3.fromRGB(25, 25, 28), Enum.Material.Fabric)
	C.Tubo(est, "ColunaCadeira", (ios * CFrame.new(0, 0.2, -3)).Position, (ios * CFrame.new(0, 1.8, -3)).Position, 0.3, ACO, Enum.Material.Metal)
	local telas = {}
	for i = -1, 1 do
		local cfm = ios * CFrame.new(i * 2.7, 4.6, 0.6) * CFrame.Angles(0, math.rad(-i * 18), 0)
		local mon = C.Parte(est, "Monitor", Vector3.new(2.6, 1.6, 0.12), cfm, Color3.fromRGB(15, 15, 15), Enum.Material.SmoothPlastic)
		C.Parte(est, "Suporte", Vector3.new(0.2, 1.2, 0.2), cfm * CFrame.new(0, -1.2, 0.15), ACO, Enum.Material.Metal)
		local g = C.Tela(mon, Enum.NormalId.Front, 120)
		local f = Instance.new("Frame")
		f.Size = UDim2.fromScale(1, 1)
		f.BackgroundColor3 = Color3.fromRGB(5, 7, 10)
		f.BorderSizePixel = 0
		f.Parent = g
		local t = C.Texto(f, "", { Font = Enum.Font.Code, TextScaled = false, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top, TextColor3 = Color3.fromRGB(150, 255, 170), Size = UDim2.new(1, -12, 1, -10), Position = UDim2.fromOffset(8, 6) })
		telas[i + 2] = { Frame = f, Texto = t }
	end
	-- monitor central: horizonte artificial da aeronave do cadete
	local horizonte = Instance.new("Frame")
	horizonte.Size = UDim2.fromScale(0.5, 0.75)
	horizonte.Position = UDim2.fromScale(0.48, 0.18)
	horizonte.BackgroundColor3 = Color3.fromRGB(70, 40, 20)
	horizonte.ClipsDescendants = true
	horizonte.Parent = telas[2].Frame
	local ceu = Instance.new("Frame")
	ceu.AnchorPoint = Vector2.new(0.5, 1)
	ceu.Size = UDim2.fromScale(3, 3)
	ceu.Position = UDim2.fromScale(0.5, 0.5)
	ceu.BackgroundColor3 = Color3.fromRGB(40, 110, 200)
	ceu.BorderSizePixel = 0
	ceu.Parent = horizonte
	local marca = Instance.new("Frame")
	marca.AnchorPoint = Vector2.new(0.5, 0.5)
	marca.Size = UDim2.new(0.5, 0, 0, 3)
	marca.Position = UDim2.fromScale(0.5, 0.5)
	marca.BackgroundColor3 = Color3.fromRGB(255, 220, 0)
	marca.BorderSizePixel = 0
	marca.ZIndex = 3
	marca.Parent = horizonte

	-- painel de entrada com o prompt e coluna de status
	local entrada = (inicioEscada * CFrame.new(-lado * (comprimento + 2.5), 0, 3))
	local totem = C.Parte(fixo, "Totem", Vector3.new(2.2, 5, 0.5), entrada * CFrame.new(0, 2.5, 0), Color3.fromRGB(14, 14, 14), Enum.Material.SmoothPlastic)
	local gT = C.Tela(totem, Enum.NormalId.Front, 60)
	local fT = Instance.new("Frame")
	fT.Size = UDim2.fromScale(1, 1)
	fT.BackgroundColor3 = Color3.fromRGB(8, 8, 8)
	fT.Parent = gT
	C.Texto(fT, "SIMULADOR " .. string.format("%02d", numero), { Size = UDim2.fromScale(0.86, 0.12), Position = UDim2.fromScale(0.07, 0.08) })
	local textoStatus = C.Texto(fT, "LIVRE", { Size = UDim2.fromScale(0.86, 0.1), Position = UDim2.fromScale(0.07, 0.26), TextColor3 = Color3.fromRGB(80, 255, 120) })
	C.Texto(fT, "Full motion · 6 graus de liberdade\nT-25 · T-27 · A-29 · F-5EM · F-39E", { Size = UDim2.fromScale(0.86, 0.16), Position = UDim2.fromScale(0.07, 0.42),
		Font = Enum.Font.Gotham, TextColor3 = Color3.fromRGB(180, 180, 180) })
	totem.CFrame = CFrame.lookAt(totem.Position, Vector3.new(base.Position.X + lado * -40, totem.Position.Y, totem.Position.Z))
	local colunaStatus = C.Parte(fixo, "LuzStatus", Vector3.new(0.5, 1.2, 0.5), entrada * CFrame.new(0, 5.6, 0), Color3.fromRGB(40, 255, 90), Enum.Material.Neon)
	local luzStatus = C.Luz(colunaStatus, "PointLight", { Range = 8, Brightness = 1, Color = Color3.fromRGB(40, 255, 90) })

	-- televisao externa: mostra aos outros cadetes a visao do piloto, com ligacao por telemetria
	local tvCF = base * CFrame.new(0, 0, -22)
	C.Parte(fixo, "TVPe", Vector3.new(7, 0.5, 3.4), tvCF * CFrame.new(0, 0.25, 0), GRAFITE, Enum.Material.Metal)
	C.Parte(fixo, "TVColuna", Vector3.new(0.9, 4.6, 0.9), tvCF * CFrame.new(0, 2.8, 0), ACO, Enum.Material.Metal)
	C.Parte(fixo, "TVMoldura", Vector3.new(17.6, 10.6, 0.8), tvCF * CFrame.new(0, 9.6, 0), Color3.fromRGB(12, 12, 14), Enum.Material.SmoothPlastic)
	local tv = C.Parte(fixo, "TVTela", Vector3.new(16.6, 9.6, 0.3), tvCF * CFrame.new(0, 9.6, -0.5), Color3.fromRGB(4, 4, 6), Enum.Material.SmoothPlastic)
	C.Parte(fixo, "TVLed", Vector3.new(1.2, 0.18, 0.2), tvCF * CFrame.new(0, 4.2, -0.5), Color3.fromRGB(60, 140, 255), Enum.Material.Neon)
	tv:SetAttribute("TVSim", true)
	tv:SetAttribute("Angulo", 1)
	tv:SetAttribute("Ativo", false)
	tv:SetAttribute("Maquina", numero)

	-- luzes de piso e destaque da maquina
	for k = 0, 3 do
		local a = math.rad(45 + k * 90)
		local refl = C.Parte(fixo, "Refletor", Vector3.new(0.8, 0.5, 0.8), base * CFrame.new(math.cos(a) * 11, 0.85, math.sin(a) * 11), GRAFITE, Enum.Material.Metal)
		C.Luz(refl, "SpotLight", { Face = Enum.NormalId.Top, Range = 16, Brightness = 1.2, Angle = 70, Color = Color3.fromRGB(200, 220, 255) })
	end

	return {
		Modelo = m, Base = base, Raiz = raiz, Neutro = cfNeutro, Atuadores = atuadores,
		JuntasBaixo = juntasBaixo, JuntasCima = juntasCima, Porta = porta, PortaPartes = { porta, macaneta, visor },
		Ponte = ponte, GuardasPonte = { corrPonte, corrPonte2 }, Dobradica = dobradica, Pistao = pistao, Torre = torre,
		TV = tv, Lente = lente, LuzGiro = luzGiro, Leds = leds, Telas = telas, Ceu = ceu, Status = textoStatus,
		LuzStatus = colunaStatus, LuzStatusLuz = luzStatus, Totem = totem, Assento = interior * CFrame.new(0, 3.2, 1),
		Saida = CFrame.new(topo + Vector3.new(0, 3, 0)), Pe = CFrame.new(pe + Vector3.new(-lado * 2, 3, 0)),
		Pose = { Arf = 0, Rol = 0, Alt = 0, Gui = 0 }, Alvo = { Arf = 0, Rol = 0, Alt = 0, Gui = 0 },
		AnguloPonte = 0, Porta01 = 0, Ocupante = nil, Telemetria = nil, Numero = numero, Lado = lado,
	}
end

-- posiciona os atuadores entre as juntas
local function atualizarAtuadores(maq)
	for i = 1, 6 do
		local a = maq.Atuadores[i]
		local baixo = (maq.Base * CFrame.new(maq.JuntasBaixo[i])).Position
		local cima = (maq.Raiz.CFrame * CFrame.new(maq.JuntasCima[i])).Position
		local dir = (cima - baixo)
		local comp = dir.Magnitude
		local u = dir.Unit
		local camisaComp = 4.4
		local function cfEixo(centro)
			return CFrame.lookAt(centro, centro + u) * CFrame.Angles(0, math.rad(90), 0)
		end
		a.Camisa.CFrame = cfEixo(baixo + u * (0.4 + camisaComp / 2))
		a.Faixa.CFrame = cfEixo(baixo + u * (0.4 + camisaComp - 0.3))
		a.Bota.CFrame = cfEixo(baixo + u * (0.4 + camisaComp + 0.45))
		local inicioHaste = 0.4 + camisaComp - 0.6
		local hasteComp = math.max(0.5, comp - inicioHaste - 0.3)
		a.Haste.Size = Vector3.new(hasteComp, 0.55, 0.55)
		a.Haste.CFrame = cfEixo(baixo + u * (inicioHaste + hasteComp / 2))
	end
end

local function aplicarPose(maq)
	local p = maq.Pose
	maq.Raiz.CFrame = maq.Neutro * CFrame.new(0, p.Alt, 0) * CFrame.Angles(p.Arf, p.Gui, -p.Rol)
	atualizarAtuadores(maq)
	-- porta deslizante
	for _, parte in ipairs(maq.PortaPartes) do
		local w = parte:FindFirstChildOfClass("Weld")
		local c0 = parte:GetAttribute("C0")
		if w and c0 then w.C0 = c0 * CFrame.new(maq.Porta01 * 3.1, 0, 0) end
	end
end

local function aplicarPonte(maq)
	local cf = maq.Dobradica * CFrame.Angles(maq.AnguloPonte, 0, 0)
	maq.Ponte.CFrame = cf * CFrame.new(0, 0, -2.8)
	maq.GuardasPonte[1].CFrame = cf * CFrame.new(1.6, 1.5, -2.8)
	maq.GuardasPonte[2].CFrame = cf * CFrame.new(-1.6, 1.5, -2.8)
	local baseP = (maq.Torre * CFrame.new(1.2, 0.5, -2.3)).Position
	local fimP = (cf * CFrame.new(1.2, -0.3, -2.4)).Position
	local cfP, comp = C.CFrameEntre(baseP, fimP)
	maq.Pistao.Size = Vector3.new(comp, 0.3, 0.3)
	maq.Pistao.CFrame = cfP
end

local function animarNumero(inicial, final, tempo, fn)
	local v = Instance.new("NumberValue")
	v.Value = inicial
	v.Changed:Connect(fn)
	local t = TweenService:Create(v, TweenInfo.new(tempo, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Value = final })
	t:Play()
	t.Completed:Connect(function() v:Destroy() end)
	return t
end

function MAQ.Iniciar(N)
	local maquinas = {
		construir("Simulador01", N.Local("Simulador1"), -1, 1),
		construir("Simulador02", N.Local("Simulador2"), 1, 2),
	}
	local porJogador = {}

	for _, maq in ipairs(maquinas) do
		aplicarPose(maq)
		aplicarPonte(maq)
	end

	local function definirStatus(maq, emUso)
		maq.Status.Text = emUso and "EM USO" or "LIVRE"
		maq.Status.TextColor3 = emUso and Color3.fromRGB(255, 80, 70) or Color3.fromRGB(80, 255, 120)
		local cor = emUso and Color3.fromRGB(255, 50, 40) or Color3.fromRGB(40, 255, 90)
		maq.LuzStatus.Color = cor
		maq.LuzStatusLuz.Color = cor
		maq.LuzGiro.Brightness = emUso and 6 or 0
		maq.Lente.Material = emUso and Enum.Material.Neon or Enum.Material.Glass
	end

	local function listaLicoes(plr)
		local d = N.Dados[plr]
		local itens = {}
		for _, l in ipairs(N.Config.Licoes) do
			local r = d and d.Atividades[l.Id]
			local ok = N.Requisitos(plr, l.Id)
			table.insert(itens, {
				Id = l.Id, Nome = l.Nome, Aeronave = l.Aeronave, NomeAeronave = Aeronaves[l.Aeronave].Nome,
				Liberado = ok, Aprovado = r and r.Aprovado or false, Pendente = r and r.Pendente or false,
				Nota = r and r.Nota or nil, Cheque = l.Cheque or false,
			})
		end
		return itens
	end

	local function abrirMenu(plr, maq)
		N.Abrir(plr, "Sim_Menu", { Licoes = listaLicoes(plr), Maquina = maq.Numero,
			Horas = N.Dados[plr] and N.Dados[plr].HorasSimulador or 0 })
	end

	local focos = {}
	local function limparFoco(plr)
		pcall(function() plr.ReplicationFocus = nil end)
		if focos[plr] then focos[plr]:Destroy() focos[plr] = nil end
	end

	local function sair(plr)
		local maq = porJogador[plr]
		if not maq then return end
		limparFoco(plr)
		porJogador[plr] = nil
		maq.Telemetria = nil
		maq.TV:SetAttribute("Ativo", false)
		maq.Alvo = { Arf = 0, Rol = 0, Alt = 0, Gui = 0 }
		local s = N.Sessao(plr)
		if s and s.Simulador then
			local d = N.Dados[plr]
			if d then d.HorasSimulador = (d.HorasSimulador or 0) + (os.clock() - s.Inicio) end
		end
		N.EncerrarSessao(plr)
		task.spawn(function()
			task.wait(2.5)
			animarNumero(maq.Porta01, 1, 1.6, function(v) maq.Porta01 = v end)
			animarNumero(maq.AnguloPonte, 0, 3, function(v) maq.AnguloPonte = v; aplicarPonte(maq) end)
			task.wait(3.2)
			if plr.Parent then
				N.Congelar(plr, false, maq.Saida)
				N.Pose(plr, "")
				N.Abrir(plr, "Sim_Fim", {})
				N.Sincronizar(plr)
			end
			maq.Ocupante = nil
			definirStatus(maq, false)
		end)
	end

	for _, maq in ipairs(maquinas) do
		N.Prompt(maq.Totem, "Simulador " .. string.format("%02d", maq.Numero), "Entrar no simulador", function(plr)
			if maq.Ocupante or porJogador[plr] or N.Sessao(plr) then return end
			maq.Ocupante = plr
			porJogador[plr] = maq
			definirStatus(maq, true)
			-- leva o cadete ao assento e fecha a cabine
			N.Congelar(plr, true, maq.Raiz.CFrame * maq.Neutro:ToObjectSpace(maq.Assento))
			N.Pose(plr, "SentadoCabine")
			maq.Porta01 = 1
			aplicarPose(maq)
			animarNumero(1, 0, 1.6, function(v) maq.Porta01 = v end)
			animarNumero(maq.AnguloPonte, math.rad(70), 3, function(v) maq.AnguloPonte = v; aplicarPonte(maq) end)
			abrirMenu(plr, maq)
		end, 12)
	end

	local NOMES_ANGULO = { "Cabine", "Perseguição", "Lateral", "Torre" }
	for _, maq in ipairs(maquinas) do
		N.Prompt(maq.TV, "Monitor do simulador " .. string.format("%02d", maq.Numero), "Trocar ângulo da câmera", function()
			local a = (maq.TV:GetAttribute("Angulo") or 1) % #NOMES_ANGULO + 1
			maq.TV:SetAttribute("Angulo", a)
		end, 20)
	end

	N.RegistrarAcao("Sim_Iniciar", function(plr, p)
		local maq = porJogador[plr]
		if not maq then return end
		local def = N.Config.PorId[p.Id]
		if not def or not def.Sim then return end
		if not N.Requisitos(plr, p.Id) then N.MostrarBloqueio(plr, p.Id) return end
		N.IniciarSessao(plr, def.Id, { Simulador = true })
		N.Abrir(plr, "Sim_Licao", { Id = def.Id, Nome = def.Nome, Aeronave = def.Aeronave, Cheque = def.Cheque })
	end)

	N.RegistrarAcao("Sim_Resultado", function(plr, p)
		local maq = porJogador[plr]
		local s = N.Sessao(plr)
		if not maq or not s or not s.Simulador or s.Id ~= p.Id then return end
		local def = N.Config.PorId[s.Id]
		local duracao = os.clock() - s.Inicio
		local d = N.Dados[plr]
		if d then d.HorasSimulador = (d.HorasSimulador or 0) + duracao end
		N.EncerrarSessao(plr)
		maq.Telemetria = nil
		maq.Alvo = { Arf = 0, Rol = 0, Alt = 0, Gui = 0 }
		local linhas = {}
		if type(p.Linhas) == "table" then
			for i = 1, math.min(#p.Linhas, 14) do
				if type(p.Linhas[i]) == "string" then table.insert(linhas, string.sub(p.Linhas[i], 1, 220)) end
			end
		end
		local nota = math.clamp(tonumber(p.Nota) or 0, 0, 10)
		local aprovado = p.Aprovado == true
		if duracao < (def.Minimo or 10) then
			nota = 0
			aprovado = false
			linhas = { "Lição encerrada antes do tempo mínimo." }
		end
		if p.Cancelado then
			abrirMenu(plr, maq)
			return
		end
		N.RegistrarResultado(plr, s.Id, nota, { Linhas = linhas, Aprovado = aprovado and nota >= N.Config.NotaMinima,
			Titulo = "Simulador | " .. def.Nome })
		task.delay(0.3, abrirMenu, plr, maq)
	end)

	N.RegistrarAcao("Sim_Menu", function(plr)
		local maq = porJogador[plr]
		if maq then abrirMenu(plr, maq) end
	end)

	N.RegistrarAcao("Sim_Sair", function(plr) sair(plr) end)
	N.AoSair(function(plr) sair(plr) end)

	-- telemetria: a atitude da aeronave move a plataforma
	local tele = N.Remotos:WaitForChild("Telemetria")
	tele.OnServerEvent:Connect(function(plr, t)
		local maq = porJogador[plr]
		if not maq or type(t) ~= "table" then return end
		maq.Telemetria = t
		-- o mapa carrega em volta da aeronave (o personagem fica parado na cabine do simulador)
		if t.Virt ~= nil then
			local f = focos[plr]
			if not f then
				f = Instance.new("Part")
				f.Name = "FocoSimulador"
				f.Anchored, f.CanCollide, f.CanQuery, f.CanTouch, f.CastShadow = true, false, false, false, false
				f.Transparency = 1
				f.Size = Vector3.one
				f.Parent = workspace
				focos[plr] = f
				pcall(function() plr.ReplicationFocus = f end)
			end
			local function lim(v, m) return math.clamp(tonumber(v) or 0, -m, m) end
			local E = 1 / 0.28 -- telemetria em metros; o mundo esta em studs
			f.Position = Vector3.new(lim(t.X, 1e5), lim(t.Y, 1e5), lim(t.Z, 1e5)) * E
		end
		do
			local tv = maq.TV
			local function num(v, lim) return math.clamp(tonumber(v) or 0, -lim, lim) end
			tv:SetAttribute("Pos", Vector3.new(num(t.X, 1e6), num(t.Y, 2e5), num(t.Z, 1e6)))
			tv:SetAttribute("Att", Vector3.new(num(t.Rumo, 720), num(t.Arf, 180), num(t.Inc, 720)))
			tv:SetAttribute("Anv", type(t.AnvId) == "string" and string.sub(t.AnvId, 1, 8) or "")
			tv:SetAttribute("Virt", t.Virt == true)
			tv:SetAttribute("Cadete", plr.DisplayName)
			tv:SetAttribute("Lic", type(t.Lic) == "string" and string.sub(t.Lic, 1, 60) or "")
			tv:SetAttribute("Dados", string.format("IAS %d kt   ALT %d ft   RUMO %03d   VS %+d fpm   G %.1f   M %.2f",
				math.floor(num(t.IAS, 2000)), math.floor(num(t.Alt, 99999)), math.floor(num(t.Rumo, 720)) % 360, math.floor(num(t.VS, 99999)),
				num(t.G, 20), num(t.M, 10)))
			tv:SetAttribute("Ativo", true)
		end
		local arf = math.rad(tonumber(t.Arf) or 0)
		local rol = math.rad(tonumber(t.Inc) or 0)
		local ax = tonumber(t.Ax) or 0 -- aceleracao longitudinal (G)
		local nz = tonumber(t.G) or 1
		local tremor = tonumber(t.Tremor) or 0
		-- "washout": a atitude e reduzida e a aceleracao vira inclinacao sustentada
		maq.Alvo.Arf = math.clamp(arf * 0.35 + ax * 0.25, -LIMITE_ANG, LIMITE_ANG)
		maq.Alvo.Rol = math.clamp(rol * 0.25, -LIMITE_ANG, LIMITE_ANG)
		maq.Alvo.Alt = math.clamp((nz - 1) * 0.35, -0.8, 1.2)
		maq.Tremor = math.clamp(tremor, 0, 1)
	end)

	-- laco de movimento e monitores
	local acumuladoTela = 0
	RunService.Heartbeat:Connect(function(dt)
		acumuladoTela = acumuladoTela + dt
		local atualizarTelas = acumuladoTela > 0.25
		if atualizarTelas then acumuladoTela = 0 end
		for _, maq in ipairs(maquinas) do
			local p, a = maq.Pose, maq.Alvo
			local k = math.min(1, dt * 3)
			local antes = p.Arf + p.Rol + p.Alt
			p.Arf = p.Arf + (a.Arf - p.Arf) * k
			p.Rol = p.Rol + (a.Rol - p.Rol) * k
			p.Alt = p.Alt + (a.Alt - p.Alt) * k
			if maq.Tremor and maq.Tremor > 0 and maq.Telemetria then
				p.Alt = p.Alt + (math.random() - 0.5) * 0.06 * maq.Tremor
			end
			local mudou = math.abs((p.Arf + p.Rol + p.Alt) - antes) > 1e-5 or maq.Ocupante
			if mudou then aplicarPose(maq) end
			-- giroflex
			if maq.Ocupante then
				local wj = maq.Lente:FindFirstChildOfClass("Weld")
				if wj then wj.C0 = wj.C0 * CFrame.Angles(0, dt * 6, 0) end
				for i, led in ipairs(maq.Leds) do
					led.Color = (math.random() < 0.15) and Color3.fromRGB(255, 190, 40) or Color3.fromRGB(40, 255, 90)
				end
			end
			if atualizarTelas then
				local t = maq.Telemetria
				local ocupante = maq.Ocupante
				if t and ocupante then
					maq.Telas[1].Texto.Text = string.format(
						"CADETE  %s\nLIÇÃO   %s\nAERONAVE %s\n\nESTADO  %s\nTEMPO   %s",
						ocupante.DisplayName, tostring(t.Lic or "-"), tostring(t.Anv or "-"), tostring(t.Est or "-"), tostring(t.Tmp or "-"))
					maq.Telas[2].Texto.Text = string.format("ALT %6d ft\nIAS %5d kt\nM   %.2f\nRUMO %03d\nVS %6d fpm\nG   %.1f\nAOA %.1f",
						math.floor(tonumber(t.Alt) or 0), math.floor(tonumber(t.IAS) or 0), tonumber(t.M) or 0,
						math.floor(tonumber(t.Rumo) or 0), math.floor(tonumber(t.VS) or 0), tonumber(t.G) or 1, tonumber(t.AoA) or 0)
					maq.Telas[3].Texto.Text = string.format("MOTOR  %d%%\nPÓS    %s\nTREM   %s\nFLAPE  %d%%\nCOMB.  %d kg\n\nPLATAFORMA\nARF %+.1f°  ROL %+.1f°",
						math.floor((tonumber(t.N) or 0) * 100), t.PC and "LIGADO" or "-", t.Trem and "EMBAIXO" or "RECOLHIDO",
						math.floor((tonumber(t.Flap) or 0) * 100), math.floor(tonumber(t.Comb) or 0),
						math.deg(maq.Pose.Arf), math.deg(maq.Pose.Rol))
					local arf = tonumber(t.Arf) or 0
					local inc = tonumber(t.Inc) or 0
					maq.Ceu.Rotation = -inc
					maq.Ceu.Position = UDim2.new(0.5, 0, 0.5 + arf / 90, 0)
				elseif ocupante then
					maq.Telas[1].Texto.Text = "CADETE  " .. ocupante.DisplayName .. "\n\nINICIANDO A SIMULAÇÃO"
					maq.Telas[2].Texto.Text = ""
					maq.Telas[3].Texto.Text = "PLATAFORMA EM REPOUSO"
				else
					maq.Telas[1].Texto.Text = "SIMULADOR " .. string.format("%02d", maq.Numero) .. "\n\nSISTEMA PRONTO\nAGUARDANDO CADETE"
					maq.Telas[2].Texto.Text = ""
					maq.Telas[3].Texto.Text = "HIDRÁULICA  OK\nPROJEÇÃO   OK\nMOVIMENTO  OK"
					maq.Ceu.Rotation = 0
					maq.Ceu.Position = UDim2.fromScale(0.5, 0.5)
				end
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(plr) sair(plr) end)
end

return MAQ
