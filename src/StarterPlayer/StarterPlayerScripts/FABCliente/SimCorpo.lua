--[[
	FAB - Corpo do piloto na cabine (cliente)

	Clona o personagem R15 do jogador (bracos com camisa e mangas), senta o corpo no assento e anima:
	- mao direita sempre no manche (acompanha o movimento do manche);
	- mao esquerda na manete; para apertar um botao, interruptor ou alavanca ela sai da manete,
	  alcanca o ponto, aperta e volta. A mao do manche nunca sai do manche.
	Tudo e local (so o proprio jogador ve) e fica ancorado; as pecas sao posicionadas uma a uma.
	A cabeca fica invisivel para a camera nao ficar dentro dela.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local FAB = ReplicatedStorage:WaitForChild("FAB")
local MD = require(FAB:WaitForChild("MapaDados"))
local LAYOUT = require(FAB:WaitForChild("CabineLayout"))

local CORPO = {}
local E = MD.StudPorMetro
local ESCALA = 1.15 -- o R6 tem 5 studs; a cabine esta em escala de 3,57 studs por metro

local function suave(t)
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

-- orientacao de uma peca cujo eixo "para baixo" (-Y local) aponta na direcao dir
local function orientar(centro, dir)
	local cima = -dir.Unit
	local ref = (math.abs(cima.X) < 0.9) and Vector3.xAxis or Vector3.yAxis
	local vx = (ref - cima * ref:Dot(cima)).Unit
	return CFrame.fromMatrix(centro, vx, cima)
end

function CORPO.Criar(P, pasta)
	local obj = {}
	local jogador = Players.LocalPlayer
	local char = jogador.Character
	local lay = LAYOUT[P.Id]
	if not lay or not lay.Manche or not lay.Manete then obj.Erro = "layout sem manche/manete" return nil, obj.Erro end
	-- corpo R15: bracos redondos com a camisa e as mangas do proprio avatar (nada de bloco R6)
	local ok, clone
	if char and char:FindFirstChild("LeftUpperArm") then
		ok, clone = pcall(function() return char:Clone() end)
	else
		ok, clone = pcall(function()
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			local desc = hum and hum:GetAppliedDescription() or Players:GetHumanoidDescriptionFromUserId(jogador.UserId)
			return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
		end)
	end
	if not ok or not clone then return nil, "nao foi possivel montar o corpo R15: " .. tostring(clone) end
	clone.Name = "CorpoPiloto"
	for _, d in ipairs(clone:GetDescendants()) do
		if d:IsA("Script") or d:IsA("LocalScript") then d:Destroy() end
	end
	local hum = clone:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		hum.PlatformStand = true
	end
	local function peca(nome) return clone:FindFirstChild(nome) end
	local cabeca = peca("Head")
	local pedacos = {
		E = { peca("LeftUpperArm"), peca("LeftLowerArm"), peca("LeftHand") },
		D = { peca("RightUpperArm"), peca("RightLowerArm"), peca("RightHand") },
	}
	if not (cabeca and pedacos.E[3] and pedacos.D[3] and pedacos.E[1] and pedacos.D[1] and pedacos.E[2] and pedacos.D[2]) then
		clone:Destroy() return nil, "corpo sem as pecas R15"
	end
	local visiveis = {}
	for _, lado in pairs(pedacos) do for _, q in ipairs(lado) do visiveis[q] = true end end
	for _, d in ipairs(clone:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			if visiveis[d] then
				d.Material = Enum.Material.SmoothPlastic
				d.Reflectance = 0
				d.Transparency = 0
				for _, f in ipairs(d:GetChildren()) do
					if f:IsA("SurfaceAppearance") then f:Destroy() end
				end
			else
				d.Transparency = 1
				for _, f in ipairs(d:GetChildren()) do
					if f:IsA("Decal") or f:IsA("Texture") then f.Transparency = 1 end
				end
			end
		elseif d:IsA("Motor6D") or d:IsA("Weld") then
			d.Enabled = false
		end
	end
	local raizHum = peca("HumanoidRootPart")
	if raizHum then raizHum.Transparency = 1 end
	pcall(function() clone:ScaleTo(ESCALA) end)
	local k = ESCALA
	local tams = {}
	for lado, q in pairs(pedacos) do
		tams[lado] = { q[1].Size.Y, q[2].Size.Y, q[3].Size.Y, q[1].Size, q[2].Size }
	end
	for _, d in ipairs(clone:GetChildren()) do
		if d:IsA("Accessory") then
			local h = d:FindFirstChild("Handle")
			if h then h.Transparency = 1 end
		end
	end
	clone.Parent = pasta

	-- geometria da cabine (em studs, referencial da aeronave) ---------------------------------
	local ox, oy, oz = lay.Olho[1] * E, lay.Olho[2] * E, lay.Olho[3] * E
	local pManche = Vector3.new(lay.Manche.Pivo[1], lay.Manche.Pivo[2], lay.Manche.Pivo[3]) * E
	local pManete = Vector3.new(lay.Manete.Pivo[1], lay.Manete.Pivo[2], lay.Manete.Pivo[3]) * E
	-- o corpo gira em torno do quadril; "inclinacao" (0 a 1) inclina o tronco para alcancar longe
	local quadril = Vector3.new(ox, oy - 1.95 * k, oz + 0.95 * k) -- corpo recuado: a cabeca fica no olho, o tronco atras dela
	local inclinacao, inclinaLado = 0, 0
	local function cfTroncoCom(inc, lado)
		local rot = CFrame.Angles(math.rad(-9 - 28 * inc), 0, math.rad(lado * 20 * inc))
		return CFrame.new(quadril) * rot * CFrame.new(0, 1 * k, 0)
	end
	local cfTorso = cfTroncoCom(0, 0)
	local cfTronco0 = cfTorso
	local function noTorso(x, y, z) return cfTorso * Vector3.new(x * k, y * k, z * k) end
	local ombroE, ombroD = noTorso(-1, 0.5, 0), noTorso(1, 0.5, 0)
	obj.Desloc = Vector3.zero
	obj.Giro = CFrame.new()

	local function topoManche(e)
		local arf = math.clamp(e.Arfagem or 0, -1, 1)
		local rol = math.clamp(e.Rolagem or 0, -1, 1)
		local rot = CFrame.Angles(arf * math.rad(14), 0, -rol * math.rad(14))
		return pManche + rot * Vector3.new(0, 0.33 * E, 0)
	end
	local function topoManete(e)
		local m = math.clamp(e.Manete or 0, 0, 1)
		return pManete + Vector3.new(0, 0.12 * E, -(m - 0.4) * 0.16 * E)
	end

	-- alvos de alcance por nome de comando e por interruptor -----------------------------------
	local function ponto(t)
		return t and Vector3.new(t.P[1], t.P[2], t.P[3]) * E
	end
	local function alvoComando(nome, cab)
		if cab and cab.Interruptores and cab.Interruptores[nome] and cab.Interruptores[nome].Base then
			local base = cab.Interruptores[nome].Base
			local raiz = cab.Raiz
			if raiz then return raiz.CFrame:PointToObjectSpace(base.Position) end
		end
		if nome == "Trem" then return ponto(lay.Trem) end
		if nome == "Ejetar" and lay.Ejecao then return ponto(lay.Ejecao) end
		if nome == "Flape" then return ponto(lay.Flape) end
		if nome == "AeroFreio" or nome == "Manete" then return topoManete({ Manete = 0.5 }) end
		if nome == "Motor" then
			for _, it in ipairs(lay.Interruptores or {}) do
				if it.Id == "Partida" then return ponto(it) end
			end
		end
		return nil
	end

	-- o braco do lado do manche segura o manche; o outro, a manete
	local mancheDireita = pManche.X >= pManete.X
	local estado = { Fase = "repouso", T = 0, Alvo = nil, Dur = 0 }
	local posEsq = topoManete({ Manete = 0.4 })
	local cfRaiz = CFrame.new()

	-- braco de duas articulacoes (ombro, cotovelo, punho) que termina com a mao no alvo ---------
	local function braco(lado, ombro, alvo)
		local sup, inf, mao = pedacos[lado][1], pedacos[lado][2], pedacos[lado][3]
		local T = tams[lado]
		local dist = (alvo - ombro).Magnitude
		local f = math.clamp(dist / ((T[1] + T[2] + T[3] * 0.5) * 0.97), 1, 1.35)
		local L1, L2, LM = T[1] * f, T[2] * f, T[3]
		sup.Size = Vector3.new(T[4].X, L1, T[4].Z)
		inf.Size = Vector3.new(T[5].X, L2, T[5].Z)
		local sinal = (lado == "E") and -1 or 1
		local v = alvo - ombro
		local d = v.Magnitude
		if d < 0.05 then return end
		local dir = v.Unit
		-- punho = alvo recuado meia mao; se estiver alem do alcance, a mao fica na ponta do braco
		local punho = alvo - dir * (LM * 0.5)
		local dp = (punho - ombro).Magnitude
		local alcance = (L1 + L2) * 0.995
		if dp > alcance then dp = alcance end
		local dirP = (punho - ombro).Unit
		punho = ombro + dirP * dp
		local a = (L1 * L1 - L2 * L2 + dp * dp) / (2 * dp)
		local h = math.sqrt(math.max(L1 * L1 - a * a, 0))
		local pole = Vector3.new(sinal * 0.1, -1, 0.6)
		local perp = pole - dirP * pole:Dot(dirP)
		perp = (perp.Magnitude > 1e-3) and perp.Unit or Vector3.yAxis
		local cotovelo = ombro + dirP * a + perp * h
		sup.CFrame = cfRaiz * orientar((ombro + cotovelo) / 2, cotovelo - ombro)
		inf.CFrame = cfRaiz * orientar((cotovelo + punho) / 2, punho - cotovelo)
		local dirM = (punho - cotovelo).Unit
		mao.CFrame = cfRaiz * orientar(punho + dirM * (LM * 0.5), dirM)
	end

	function obj.Alcancar(nome, cab)
		local alvo = alvoComando(nome, cab)
		if alvo and estado.Fase == "repouso" then
			estado.Fase, estado.T, estado.Alvo, estado.Dur = "ir", 0, alvo + Vector3.new(0, 0.02 * E, 0.05 * E), 0.28
		end
	end

	function obj.Apertar(posMundo, cab)
		if estado.Fase ~= "repouso" then return end
		local alvo = cfRaiz:PointToObjectSpace(posMundo)
		estado.Fase, estado.T, estado.Alvo, estado.Dur = "ir", 0, alvo + Vector3.new(0, 0, 0.04 * E), 0.28
	end

	function obj.Atualizar(cf, e, dt)
		cfRaiz = cf
		local repousoE = topoManete(e)
		local alvoE = repousoE
		if estado.Fase ~= "repouso" then
			estado.T = estado.T + dt
			local f = suave(estado.T / estado.Dur)
			if estado.Fase == "ir" then
				alvoE = repousoE:Lerp(estado.Alvo, f)
				if estado.T >= estado.Dur then estado.Fase, estado.T, estado.Dur = "apertar", 0, 0.16 end
			elseif estado.Fase == "apertar" then
				alvoE = estado.Alvo + Vector3.new(0, 0, -0.02 * E * math.sin(f * math.pi))
				if estado.T >= estado.Dur then estado.Fase, estado.T, estado.Dur = "voltar", 0, 0.32 end
			else
				alvoE = estado.Alvo:Lerp(repousoE, f)
				if estado.T >= estado.Dur then estado.Fase = "repouso" end
			end
		end
		posEsq = alvoE
		local alvoD = topoManche(e)

		-- inclina o tronco quando o alvo esta longe do alcance do braco
		local alvoInc, alvoLado = 0, 0
		if estado.Fase == "ir" or estado.Fase == "apertar" then
			local dist = (estado.Alvo - (mancheDireita and ombroE or ombroD)).Magnitude
			alvoInc = math.clamp((dist - 1.55 * k) / (1.3 * k), 0, 1)
			alvoLado = math.clamp((ox - estado.Alvo.X) / (2.2 * k), -1, 1)
		end
		local a = math.min(1, dt * 7)
		inclinacao = inclinacao + (alvoInc - inclinacao) * a
		inclinaLado = inclinaLado + (alvoLado - inclinaLado) * a
		cfTorso = cfTroncoCom(inclinacao, inclinaLado)
		ombroE, ombroD = noTorso(-1, 0.5, 0), noTorso(1, 0.5, 0)
		-- a camera acompanha a cabeca (posicao inteira, giro pela metade)
		local cabecaPos = cfTorso * Vector3.new(0, 1.5 * k, 0)
		local cabecaRepouso = cfTronco0 * Vector3.new(0, 1.5 * k, 0)
		obj.Desloc = cabecaPos - cabecaRepouso
		obj.Giro = CFrame.Angles(math.rad(-28 * inclinacao * 0.5), 0, math.rad(inclinaLado * 20 * inclinacao * 0.5))

		cabeca.CFrame = cf * (cfTorso * CFrame.new(0, 1.5 * k, 0))
		if mancheDireita then
			braco("E", ombroE, posEsq)
			braco("D", ombroD, alvoD)
		else
			braco("D", ombroD, posEsq)
			braco("E", ombroE, alvoD)
		end
	end

	function obj.Destruir()
		clone:Destroy()
	end

	return obj
end

return CORPO
