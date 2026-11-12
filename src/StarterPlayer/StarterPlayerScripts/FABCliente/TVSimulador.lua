--[[
	FAB - Televisao externa do simulador (cliente)

	Cada maquina tem uma TV do lado de fora. Quem se aproxima ve o que o piloto esta
	fazendo: o cliente reconstroi a cena (terreno, pista, aeronave) em um ViewportFrame a
	partir da telemetria que o servidor publica na TV (posicao, atitude, dados de voo).
	O Roblox nao permite copiar a tela de outro jogador, entao a imagem e recriada aqui.

	Angulos (trocados pelo prompt da TV, valem para todos): Cabine, Perseguicao, Lateral, Torre.
	So renderiza quando o jogador esta perto da TV.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local TVS = {}

local FAB = ReplicatedStorage:WaitForChild("FAB")
local MD = require(FAB:WaitForChild("MapaDados"))
local Aeronaves = require(FAB:WaitForChild("Aeronaves"))
local E = MD.StudPorMetro

local CELULA = 160                  -- metros por celula do terreno
local N = 17                        -- celulas por lado
local DISTANCIA = 130               -- studs: so renderiza perto da TV
local NOMES = { "CABINE", "PERSEGUIÇÃO", "LATERAL", "TORRE" }

local COR_TIPO = {
	grama = Color3.fromRGB(78, 112, 60),
	praia = Color3.fromRGB(214, 196, 150),
	pista = Color3.fromRGB(86, 88, 92),
}

function TVS.Iniciar(UI)
	local pasta = script.Parent
	local PV = require(pasta:WaitForChild("SimPistaVirtual"))
	local jogador = Players.LocalPlayer
	local telas = {}      -- lista de TVs ativas
	local encontradas = {}

	local function solo(virt, xm, zm)
		if virt then return PV.Solo(xm, zm) end
		local h, tipo = MD.Altura(xm * E, zm * E)
		return h / E, tipo
	end

	local function parte(pai, tam, cf, cor, mat)
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CastShadow = false
		p.Size = tam
		p.CFrame = cf
		p.Color = cor
		p.Material = mat or Enum.Material.SmoothPlastic
		p.Parent = pai
		return p
	end

	-- faixa grande dividida em partes de ate 2000 studs
	local function faixa(pai, cx, y, cz, larg, comp, cor)
		local seg = 2000
		local z0 = cz - comp / 2
		while z0 < cz + comp / 2 do
			local z1 = math.min(z0 + seg, cz + comp / 2)
			parte(pai, Vector3.new(larg, 1, z1 - z0), CFrame.new(cx, y, (z0 + z1) / 2), cor)
			z0 = z1
		end
	end

	local function aeronaveSimples(tipo)
		local m = Instance.new("Model")
		local function peca(tam, cf, cor, forma)
			local p = Instance.new("Part")
			p.Anchored = true
			p.CanCollide = false
			p.Size = tam * E
			p.Color = cor or Color3.fromRGB(140, 146, 150)
			p.Material = Enum.Material.Metal
			if forma then p.Shape = forma end
			p.Parent = m
			return p, cf
		end
		local jato = tipo ~= "A29" and tipo ~= "T25"
		local comp = jato and 14 or 9
		local partes = {}
		local function add(tam, cf, cor, forma)
			local p = peca(tam, cf, cor, forma)
			table.insert(partes, { P = p, CF = cf })
		end
		add(Vector3.new(comp, 1.3, 1.3), CFrame.new(0, 0, 0) * CFrame.Angles(0, math.rad(90), 0), nil, Enum.PartType.Cylinder)
		add(Vector3.new(jato and 8.5 or 10.5, 0.15, jato and 3 or 1.6), CFrame.new(0, -0.2, jato and 1 or -0.3), nil)
		add(Vector3.new(3.6, 0.12, 1.2), CFrame.new(0, 0.1, comp / 2 - 0.6), nil)
		add(Vector3.new(0.15, 2, 1.6), CFrame.new(0, 1.1, comp / 2 - 0.8), nil)
		add(Vector3.new(0.9, 0.5, 1.8), CFrame.new(0, 0.7, -comp / 2 + 3.2), Color3.fromRGB(30, 40, 50))
		local function posicionar(cf)
			for _, x in ipairs(partes) do x.P.CFrame = cf * CFrame.new(x.CF.Position * E) * (x.CF - x.CF.Position) end
		end
		return m, posicionar
	end

	-- CONSTRUCAO DA TELA ---------------------------------------------------------------------
	local function criarTela(tv)
		local est = { Parte = tv, Mundo = nil }
		local g = Instance.new("SurfaceGui")
		g.Name = "FAB_TVSim"
		g.Face = Enum.NormalId.Front
		g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		g.PixelsPerStud = 40
		g.LightInfluence = 0
		g.Brightness = 1.2
		g.Adornee = tv
		g.ResetOnSpawn = false
		g.Parent = jogador:WaitForChild("PlayerGui")
		est.Gui = g

		local fundo = Instance.new("Frame")
		fundo.Size = UDim2.fromScale(1, 1)
		fundo.BorderSizePixel = 0
		fundo.BackgroundColor3 = Color3.new(1, 1, 1)
		fundo.Parent = g
		local grad = Instance.new("UIGradient")
		grad.Rotation = 90
		grad.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(22, 64, 150)),
			ColorSequenceKeypoint.new(0.55, Color3.fromRGB(120, 170, 225)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(190, 215, 235)),
		})
		grad.Parent = fundo

		local vp = Instance.new("ViewportFrame")
		vp.Size = UDim2.fromScale(1, 1)
		vp.BackgroundTransparency = 1
		vp.Ambient = Color3.fromRGB(165, 168, 176)
		vp.LightColor = Color3.fromRGB(255, 242, 220)
		vp.LightDirection = Vector3.new(-0.6, -1, -0.4)
		vp.Parent = fundo
		local cam = Instance.new("Camera")
		cam.FieldOfView = 70
		cam.Parent = vp
		vp.CurrentCamera = cam
		est.Vp, est.Cam = vp, cam

		local function rotulo(nome, pos, tam, tamTexto, alinh, cor)
			local l = Instance.new("TextLabel")
			l.Name = nome
			l.BackgroundTransparency = 1
			l.Position = pos
			l.Size = tam
			l.Font = Enum.Font.GothamBold
			l.TextSize = tamTexto
			l.TextColor3 = cor or Color3.new(1, 1, 1)
			l.TextXAlignment = alinh
			l.Text = ""
			l.TextStrokeTransparency = 0.5
			l.Parent = fundo
			return l
		end
		est.Topo = rotulo("Topo", UDim2.fromOffset(18, 10), UDim2.new(0.6, 0, 0, 30), 22, Enum.TextXAlignment.Left)
		est.Angulo = rotulo("Angulo", UDim2.new(0.4, -18, 0, 10), UDim2.new(0.6, 0, 0, 30), 22, Enum.TextXAlignment.Right)
		est.Dados = rotulo("Dados", UDim2.new(0, 18, 1, -44), UDim2.new(1, -36, 0, 34), 24, Enum.TextXAlignment.Center, Color3.fromRGB(150, 255, 170))
		-- retículo do angulo de cabine
		local mira = Instance.new("Frame")
		mira.AnchorPoint = Vector2.new(0.5, 0.5)
		mira.Position = UDim2.fromScale(0.5, 0.5)
		mira.Size = UDim2.fromOffset(46, 46)
		mira.BackgroundTransparency = 1
		mira.Visible = false
		mira.Parent = fundo
		local circ = Instance.new("UIStroke")
		circ.Color = Color3.fromRGB(150, 255, 170)
		circ.Thickness = 2
		circ.Parent = mira
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(1, 0)
		c.Parent = mira
		for _, d in ipairs({ { -42, 0 }, { 42, 0 } }) do
			local b = Instance.new("Frame")
			b.AnchorPoint = Vector2.new(0.5, 0.5)
			b.Position = UDim2.new(0.5, d[1], 0.5, 0)
			b.Size = UDim2.fromOffset(28, 2)
			b.BackgroundColor3 = Color3.fromRGB(150, 255, 170)
			b.BorderSizePixel = 0
			b.Parent = mira
		end
		est.Mira = mira

		-- espera
		local espera = Instance.new("Frame")
		espera.Size = UDim2.fromScale(1, 1)
		espera.BackgroundColor3 = Color3.fromRGB(6, 8, 10)
		espera.BorderSizePixel = 0
		espera.ZIndex = 10
		espera.Parent = fundo
		local te = Instance.new("TextLabel")
		te.Size = UDim2.fromScale(1, 1)
		te.BackgroundTransparency = 1
		te.Font = Enum.Font.GothamBold
		te.TextSize = 34
		te.TextColor3 = Color3.fromRGB(240, 240, 240)
		te.ZIndex = 11
		te.Text = "SIMULADOR " .. string.format("%02d", tv:GetAttribute("Maquina") or 1) .. "\nSISTEMA PRONTO\nAguardando cadete"
		te.Parent = espera
		est.Espera = espera
		est.TextoEspera = te
		return est
	end

	local function montarMundo(est, virt)
		if est.Mundo then est.Mundo:Destroy() end
		local mundo = Instance.new("Model")
		mundo.Name = "Mundo"
		mundo.Parent = est.Vp
		est.Mundo = mundo
		est.Virt = virt
		-- oceano em volta (grade de 2.048 studs)
		est.Agua = {}
		for i = 1, 25 do
			est.Agua[i] = parte(mundo, Vector3.new(2048, 1, 2048), CFrame.new(0, -0.5, 0), Color3.fromRGB(24, 78, 104), Enum.Material.SmoothPlastic)
		end
		est.Celulas = {}
		for i = 1, N * N do
			est.Celulas[i] = parte(mundo, Vector3.new(CELULA * E, 1, CELULA * E), CFrame.new(0, -1000, 0), COR_TIPO.grama, Enum.Material.SmoothPlastic)
		end
		est.CelAtual = nil
		-- pista, taxi, patio e referencias
		if virt then
			local cx = PV.CentroX * E
			local y = PV.Elevacao * E + 0.3
			faixa(mundo, cx, y, 0, 45 * E, 3120 * E, Color3.fromRGB(46, 47, 50))
			for z = -1400, 1400, 100 do
				parte(mundo, Vector3.new(1.6 * E, 0.3, 40 * E), CFrame.new(cx, y + 0.35, z * E), Color3.fromRGB(240, 240, 234))
			end
			parte(mundo, Vector3.new(320 * E, 1, 720 * E), CFrame.new(cx + 185 * E, y, 1660 * E), Color3.fromRGB(150, 150, 146))
			parte(mundo, Vector3.new(310 * E, 1, 23 * E), CFrame.new(cx + 175 * E, y, 1380 * E), Color3.fromRGB(46, 47, 50))
			for _, hz in ipairs({ 1760, 1840, 1920 }) do
				parte(mundo, Vector3.new(40 * E, 10 * E, 56 * E), CFrame.new(cx + 330 * E, y + 5 * E, hz * E), Color3.fromRGB(150, 154, 158), Enum.Material.Metal)
			end
			parte(mundo, Vector3.new(7 * E, 24 * E, 7 * E), CFrame.new(cx + 120 * E, y + 12 * E, 1540 * E), Color3.fromRGB(218, 216, 208))
			parte(mundo, Vector3.new(13 * E, 4.4 * E, 13 * E), CFrame.new(cx + 120 * E, y + 26 * E, 1540 * E), Color3.fromRGB(40, 70, 84))
		else
			local y = MD.Plato + 0.3
			faixa(mundo, 0, y, 0, MD.Pista.Largura, MD.Pista.Comprimento + 2 * MD.Pista.Zona, Color3.fromRGB(46, 47, 50))
			for z = -1400, 1400, 100 do
				parte(mundo, Vector3.new(1.6 * E, 0.3, 40 * E), CFrame.new(0, y + 0.35, z * E), Color3.fromRGB(240, 240, 234))
			end
			faixa(mundo, MD.TaxiX, y, 0, MD.TaxiLargura, MD.Pista.Comprimento, Color3.fromRGB(56, 57, 60))
			local pa = MD.Patio
			parte(mundo, Vector3.new(pa.X2 - pa.X1, 1, pa.Z2 - pa.Z1), CFrame.new((pa.X1 + pa.X2) / 2, y, (pa.Z1 + pa.Z2) / 2), Color3.fromRGB(150, 150, 146))
		end
	end

	local function atualizarCelulas(est, px, pz, virt)
		local ix = math.floor(px / CELULA + 0.5)
		local iz = math.floor(pz / CELULA + 0.5)
		local chave = ix .. ":" .. iz
		if chave == est.CelAtual then return end
		est.CelAtual = chave
		local meio = (N - 1) / 2
		local k = 0
		for dx = 0, N - 1 do
			for dz = 0, N - 1 do
				k = k + 1
				local cx = (ix + dx - meio) * CELULA
				local cz = (iz + dz - meio) * CELULA
				local h, tipo = solo(virt, cx, cz)
				local p = est.Celulas[k]
				if tipo == "agua" or h <= 0.05 then
					p.CFrame = CFrame.new(0, -1000, 0)
				else
					p.Color = COR_TIPO[tipo] or COR_TIPO.grama
					if tipo == "grama" and h > 40 then
						p.Color = Color3.fromRGB(70, 96, 60):Lerp(Color3.fromRGB(120, 112, 100), math.clamp((h - 40) / 120, 0, 1))
					end
					local alt = math.max(h * E, 2)
					p.Size = Vector3.new(CELULA * E, alt, CELULA * E)
					p.CFrame = CFrame.new(cx * E, alt / 2 - 0.2, cz * E)
				end
			end
		end
		local gx = math.floor(px * E / 2048 + 0.5)
		local gz = math.floor(pz * E / 2048 + 0.5)
		local i = 0
		for dx = -2, 2 do
			for dz = -2, 2 do
				i = i + 1
				est.Agua[i].CFrame = CFrame.new((gx + dx) * 2048, -0.5, (gz + dz) * 2048)
			end
		end
	end

	local function modeloAeronave(est, id)
		if est.AnvId == id and est.Anv then return end
		if est.Anv then est.Anv.Obj:Destroy() end
		est.AnvId = id
		local origem = ReplicatedStorage:FindFirstChild("FABMalhas")
		origem = origem and origem:FindFirstChild("Aeronave_" .. id)
		local m, posicionar
		if origem then
			m = origem:Clone()
			for _, d in ipairs(m:GetDescendants()) do
				if d:IsA("BasePart") then
					d.Anchored = true
					d.CanCollide = false
				end
			end
			posicionar = function(cf) m:PivotTo(cf) end
		else
			m, posicionar = aeronaveSimples(id)
		end
		est.Anv = { Obj = m, Posicionar = posicionar }
		m.Parent = est.Mundo
	end

	-- ATUALIZACAO ---------------------------------------------------------------------------
	local function atualizar(est, dt, agora)
		local tv = est.Parte
		local ativo = tv:GetAttribute("Ativo") == true
		est.Espera.Visible = not ativo
		if not ativo then
			est.TextoEspera.Text = "SIMULADOR " .. string.format("%02d", tv:GetAttribute("Maquina") or 1) .. "\nSISTEMA PRONTO\nAguardando cadete"
			return
		end
		local virt = tv:GetAttribute("Virt") == true
		if est.Virt ~= virt or not est.Mundo then montarMundo(est, virt) end
		local pos = tv:GetAttribute("Pos")
		local att = tv:GetAttribute("Att")
		local id = tv:GetAttribute("Anv")
		if not (pos and att) or id == "" then
			est.Espera.Visible = true
			est.TextoEspera.Text = "SIMULADOR " .. string.format("%02d", tv:GetAttribute("Maquina") or 1) .. "\nIniciando a simulação"
			return
		end
		-- amostra nova: estima a velocidade e segue com suavizacao
		if est.UltimaPos ~= pos then
			if est.UltimaPos and est.TAmostra then
				local d = math.clamp(agora - est.TAmostra, 0.05, 1)
				local v = (pos - est.UltimaPos) / d
				if v.Magnitude < 1500 then est.Vel = v else est.Vel = Vector3.zero end
				if (pos - est.UltimaPos).Magnitude > 600 then est.PosAtual = nil end
			end
			est.UltimaPos = pos
			est.TAmostra = agora
		end
		local alvo = pos + (est.Vel or Vector3.zero) * math.clamp(agora - (est.TAmostra or agora), 0, 0.4)
		if not est.PosAtual then est.PosAtual = alvo else est.PosAtual = est.PosAtual:Lerp(alvo, 1 - math.exp(-dt * 10)) end
		local p = est.PosAtual
		local cfAtt = CFrame.Angles(0, -math.rad(att.X), 0) * CFrame.Angles(math.rad(att.Y), 0, 0) * CFrame.Angles(0, 0, -math.rad(att.Z))
		if not est.CFAtt then est.CFAtt = cfAtt else est.CFAtt = est.CFAtt:Lerp(cfAtt, 1 - math.exp(-dt * 8)) end
		local cfA = CFrame.new(p * E) * est.CFAtt
		modeloAeronave(est, id)
		atualizarCelulas(est, p.X, p.Z, virt)
		est.Anv.Posicionar(cfA)

		local ang = tv:GetAttribute("Angulo") or 1
		local P = Aeronaves[id]
		local cam = est.Cam
		local fov = 70
		if ang == 1 then
			local o = P and P.Olho or { 0, 1, -1 }
			cam.CFrame = cfA * CFrame.new(o[1] * E, o[2] * E, o[3] * E)
			est.Anv.Obj.Parent = nil
			fov = 75
		elseif ang == 2 then
			est.Anv.Obj.Parent = est.Mundo
			local c = cfA * Vector3.new(0, 4 * E, 24 * E)
			cam.CFrame = CFrame.lookAt(c, cfA.Position + cfA.LookVector * 8 * E + Vector3.new(0, 1.5 * E, 0))
			fov = 62
		elseif ang == 3 then
			est.Anv.Obj.Parent = est.Mundo
			local c = cfA * Vector3.new(32 * E, 2 * E, -2 * E)
			cam.CFrame = CFrame.lookAt(c, cfA.Position)
			fov = 55
		else
			est.Anv.Obj.Parent = est.Mundo
			local base = virt and Vector3.new(PV.CentroX + 120, 29, 1540) or Vector3.new(120, 14, 0)
			local c = base * E
			cam.CFrame = CFrame.lookAt(c, cfA.Position)
			local dist = (cfA.Position - c).Magnitude / E
			fov = math.clamp(math.deg(2 * math.atan(32 / math.max(dist, 60))), 7, 60)
		end
		cam.FieldOfView = fov
		est.Mira.Visible = (ang == 1)
		est.Topo.Text = string.upper(tostring(tv:GetAttribute("Cadete") or "")) .. "  ·  " .. string.upper(tostring(tv:GetAttribute("Lic") or ""))
		est.Angulo.Text = NOMES[ang] .. "  " .. ang .. "/" .. #NOMES
		est.Dados.Text = tostring(tv:GetAttribute("Dados") or "")
	end

	-- procura as TVs (a maquina e criada pelo servidor depois do mapa)
	task.spawn(function()
		while #encontradas < 2 do
			for _, d in ipairs(workspace:GetDescendants()) do
				if d:IsA("BasePart") and d:GetAttribute("TVSim") and not telas[d] then
					telas[d] = { Parte = d }
					table.insert(encontradas, d)
				end
			end
			task.wait(3)
		end
	end)

	local acumulado = 0
	RunService.Heartbeat:Connect(function(dt)
		acumulado = acumulado + dt
		if acumulado < 0.05 then return end
		local passo = acumulado
		acumulado = 0
		local char = jogador.Character
		local raiz = char and char:FindFirstChild("HumanoidRootPart")
		local agora = os.clock()
		for tv, est in pairs(telas) do
			local perto = raiz and tv.Parent and (raiz.Position - tv.Position).Magnitude < DISTANCIA
			-- quem esta dentro da maquina nao precisa da TV
			if perto and not est.Gui then
				telas[tv] = criarTela(tv)
				est = telas[tv]
			end
			if est.Gui then
				if perto then
					local ok, erro = pcall(atualizar, est, passo, agora)
					if not ok and not est.Avisou then
						est.Avisou = true
						warn("[FAB] TV do simulador: " .. tostring(erro))
					end
				else
					est.Gui:Destroy()
					telas[tv] = { Parte = tv }
				end
			end
		end
	end)
end

return TVS
