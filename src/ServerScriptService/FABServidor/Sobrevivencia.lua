--[[
	FAB - Sobrevivencia na Selva (servidor)

	Cenario de piloto abatido: o cadete aparece no meio da mata, precisa achar o kit
	de sobrevivencia (bussola, isqueiro e sinalizador), juntar 3 gravetos, acender
	uma fogueira e ir ate a clareira ao norte para disparar o sinalizador.
	O resgate chega alguns segundos depois do sinal. Tempo limite: 8 minutos.
]]

local TweenService = game:GetService("TweenService")

local SOB = {}

local LIMITE = 480
local GRAVETOS_NECESSARIOS = 3

function SOB.Iniciar(N)
	local ativos = {}
	local pastaItens = Instance.new("Folder")
	pastaItens.Name = "SobrevivenciaItens"
	pastaItens.Parent = workspace

	local function limpar(a)
		if a.Itens then a.Itens:Destroy() end
	end

	local function terminar(plr, nota, linhas, aprovadoForcado)
		local a = ativos[plr]
		if not a then return end
		ativos[plr] = nil
		N.EncerrarSessao(plr)
		task.delay(6, limpar, a)
		N.Abrir(plr, "Sob_Fim", {})
		if nota then
			N.RegistrarResultado(plr, "Sobrevivencia", nota, { Linhas = linhas, Aprovado = aprovadoForcado })
		end
		task.delay(1.5, function()
			if plr.Parent then N.Teleportar(plr, N.Local("Chegada")) end
		end)
	end

	local function soloEm(pos)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		local filtro = { pastaItens }
		local base = workspace:FindFirstChild("BaseAerea")
		if base and base:FindFirstChild("Mata") then table.insert(filtro, base.Mata) end
		params.FilterDescendantsInstances = filtro
		local r = workspace:Raycast(pos + Vector3.new(0, 60, 0), Vector3.new(0, -200, 0), params)
		if r then return r.Position end
		return Vector3.new(pos.X, 0, pos.Z)
	end

	local function item(a, nome, pos, cor, tamanho, acao, fn)
		local p = Instance.new("Part")
		p.Name = nome
		p.Anchored = true
		p.Size = tamanho
		p.Color = cor
		p.Material = Enum.Material.Wood
		p.CFrame = CFrame.new(soloEm(pos) + Vector3.new(0, tamanho.Y / 2, 0)) * CFrame.Angles(0, math.random() * 6.28, 0)
		p:SetAttribute("Dono", a.Dono.UserId)
		p.Parent = a.Itens
		local pr = Instance.new("ProximityPrompt")
		pr.ActionText = acao
		pr.ObjectText = nome
		pr.HoldDuration = 0.6
		pr.MaxActivationDistance = 8
		pr.RequiresLineOfSight = false
		pr.Parent = p
		pr.Triggered:Connect(function(quem)
			if quem ~= a.Dono or ativos[quem] ~= a then return end
			fn(p)
		end)
		return p
	end

	local function kit(a, pos)
		local m = Instance.new("Model")
		m.Name = "KitSobrevivencia"
		local caixa = Instance.new("Part")
		caixa.Name = "Caixa"
		caixa.Anchored = true
		caixa.Size = Vector3.new(2.4, 1.2, 1.6)
		caixa.Color = Color3.fromRGB(80, 90, 60)
		caixa.Material = Enum.Material.Fabric
		caixa.CFrame = CFrame.new(soloEm(pos) + Vector3.new(0, 0.6, 0))
		caixa.Parent = m
		local faixa = Instance.new("Part")
		faixa.Name = "Faixa"
		faixa.Anchored = true
		faixa.CanCollide = false
		faixa.Size = Vector3.new(2.45, 0.35, 1.65)
		faixa.Color = Color3.fromRGB(240, 120, 20)
		faixa.Material = Enum.Material.Fabric
		faixa.CFrame = caixa.CFrame
		faixa.Parent = m
		local luz = Instance.new("PointLight")
		luz.Color = Color3.fromRGB(255, 160, 60)
		luz.Range = 6
		luz.Brightness = 0.6
		luz.Parent = caixa
		m.Parent = a.Itens
		local pr = Instance.new("ProximityPrompt")
		pr.ActionText = "Abrir kit"
		pr.ObjectText = "Kit de sobrevivência"
		pr.HoldDuration = 1
		pr.MaxActivationDistance = 8
		pr.RequiresLineOfSight = false
		pr.Parent = caixa
		pr.Triggered:Connect(function(quem)
			if quem ~= a.Dono or ativos[quem] ~= a or a.Kit then return end
			a.Kit = true
			m:Destroy()
			N.Abrir(quem, "Sob_Estado", { Kit = true, Gravetos = a.Gravetos, Fogueira = a.Fogueira })
		end)
	end

	N.Prompt(N.Placas.Sobrevivencia, "Sobrevivência", "Iniciar estágio", function(plr)
		if not N.Requisitos(plr, "Sobrevivencia") then N.MostrarBloqueio(plr, "Sobrevivencia") return end
		if ativos[plr] then return end
		local a = { Dono = plr, Gravetos = 0, Kit = false, Fogueira = false, Itens = Instance.new("Folder") }
		a.Itens.Name = "Itens_" .. plr.UserId
		a.Itens.Parent = pastaItens
		ativos[plr] = a
		N.IniciarSessao(plr, "Sobrevivencia")
		N.Abrir(plr, "Sob_Briefing", { Limite = LIMITE })
	end, 12)

	N.RegistrarAcao("Sob_Pronto", function(plr)
		local a = ativos[plr]
		if not a or a.Inicio then return end
		a.Inicio = os.clock()
		local centro = N.Local("MataCentro").Position
		local queda = centro + Vector3.new(math.random(-40, 40), 0, math.random(30, 60))
		a.Queda = queda
		N.Teleportar(plr, CFrame.new(soloEm(queda) + Vector3.new(0, 4, 0)) * CFrame.Angles(0, math.random() * 6.28, 0))
		-- kit perto do ponto de queda
		local ang = math.random() * 6.28
		kit(a, queda + Vector3.new(math.cos(ang) * 22, 0, math.sin(ang) * 22))
		-- gravetos espalhados
		for i = 1, 6 do
			local g = math.random() * 6.28
			local r = 15 + math.random() * 45
			item(a, "Graveto", queda + Vector3.new(math.cos(g) * r, 0, math.sin(g) * r), Color3.fromRGB(110, 80, 50),
				Vector3.new(0.35, 0.35, 3.2), "Pegar", function(p)
					a.Gravetos = a.Gravetos + 1
					p:Destroy()
					N.Abrir(plr, "Sob_Estado", { Kit = a.Kit, Gravetos = a.Gravetos, Fogueira = a.Fogueira })
				end)
		end
		N.Abrir(plr, "Sob_Iniciar", { Limite = LIMITE, Clareira = N.Local("Clareira").Position })
		task.delay(LIMITE, function()
			if ativos[plr] == a then
				terminar(plr, 0, { "O tempo de sobrevivência acabou antes do resgate encontrar você.",
					"Dica: use a bússola do kit e siga para o norte até a clareira." }, false)
			end
		end)
	end)

	N.RegistrarAcao("Sob_Fogueira", function(plr)
		local a = ativos[plr]
		if not a or a.Fogueira or not a.Kit or a.Gravetos < GRAVETOS_NECESSARIOS then return end
		local _, hrp = N.Personagem(plr)
		if not hrp then return end
		a.Fogueira = true
		local pos = soloEm(hrp.Position + hrp.CFrame.LookVector * 3)
		local m = Instance.new("Model")
		m.Name = "Fogueira"
		for i = 0, 5 do
			local tora = Instance.new("Part")
			tora.Anchored = true
			tora.CanCollide = false
			tora.Size = Vector3.new(0.4, 0.4, 2.6)
			tora.Color = Color3.fromRGB(70, 48, 30)
			tora.Material = Enum.Material.Wood
			tora.CFrame = CFrame.new(pos + Vector3.new(0, 0.5, 0)) * CFrame.Angles(0, i / 6 * math.pi * 2, math.rad(25)) * CFrame.new(0, 0, 0.6)
			tora.Parent = m
		end
		for i = 0, 7 do
			local pedra = Instance.new("Part")
			pedra.Shape = Enum.PartType.Ball
			pedra.Anchored = true
			pedra.Size = Vector3.new(0.9, 0.9, 0.9)
			pedra.Color = Color3.fromRGB(100, 100, 96)
			pedra.Material = Enum.Material.Slate
			pedra.CFrame = CFrame.new(pos + Vector3.new(math.cos(i / 8 * 6.28) * 1.6, 0.3, math.sin(i / 8 * 6.28) * 1.6))
			pedra.Parent = m
		end
		local nucleo = Instance.new("Part")
		nucleo.Anchored = true
		nucleo.CanCollide = false
		nucleo.Transparency = 1
		nucleo.Size = Vector3.new(1, 1, 1)
		nucleo.CFrame = CFrame.new(pos + Vector3.new(0, 1, 0))
		nucleo.Parent = m
		local fogo = Instance.new("Fire")
		fogo.Size = 6
		fogo.Heat = 9
		fogo.Parent = nucleo
		local fumaca = Instance.new("Smoke")
		fumaca.Opacity = 0.25
		fumaca.RiseVelocity = 6
		fumaca.Size = 4
		fumaca.Parent = nucleo
		local luz = Instance.new("PointLight")
		luz.Color = Color3.fromRGB(255, 150, 60)
		luz.Range = 22
		luz.Brightness = 2
		luz.Parent = nucleo
		m.Parent = a.Itens
		N.Abrir(plr, "Sob_Estado", { Kit = a.Kit, Gravetos = a.Gravetos, Fogueira = true })
	end)

	N.RegistrarAcao("Sob_Sinalizar", function(plr)
		local a = ativos[plr]
		if not a or a.Sinalizou or not a.Kit then return end
		local _, hrp = N.Personagem(plr)
		if not hrp then return end
		local clareira = N.Local("Clareira").Position
		local plano = Vector3.new(hrp.Position.X - clareira.X, 0, hrp.Position.Z - clareira.Z)
		if plano.Magnitude > 24 then
			N.Abrir(plr, "Sob_Retorno", { Texto = "Aqui as árvores cobrem o sinal. Vá para a clareira." })
			return
		end
		a.Sinalizou = true
		-- foguete sinalizador
		local f = Instance.new("Part")
		f.Name = "Sinalizador"
		f.Anchored = true
		f.CanCollide = false
		f.Size = Vector3.new(0.6, 0.6, 0.6)
		f.Shape = Enum.PartType.Ball
		f.Material = Enum.Material.Neon
		f.Color = Color3.fromRGB(255, 40, 30)
		f.CFrame = CFrame.new(hrp.Position + Vector3.new(0, 3, 0))
		f.Parent = a.Itens
		local luz = Instance.new("PointLight")
		luz.Color = Color3.fromRGB(255, 50, 40)
		luz.Range = 60
		luz.Brightness = 4
		luz.Parent = f
		local fogo = Instance.new("Fire")
		fogo.Color = Color3.fromRGB(255, 60, 40)
		fogo.SecondaryColor = Color3.fromRGB(255, 200, 120)
		fogo.Size = 3
		fogo.Parent = f
		local fumaca = Instance.new("Smoke")
		fumaca.Color = Color3.fromRGB(255, 120, 110)
		fumaca.Opacity = 0.4
		fumaca.Parent = f
		TweenService:Create(f, TweenInfo.new(4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = f.CFrame + Vector3.new(0, 180, 0) }):Play()
		N.Abrir(plr, "Sob_Estado", { Kit = a.Kit, Gravetos = a.Gravetos, Fogueira = a.Fogueira, Sinalizou = true })
		task.delay(8, function()
			if ativos[plr] ~= a then return end
			local tempo = os.clock() - a.Inicio
			local nota = 10
			local linhas = { string.format("Resgate realizado em %d min %02d s.", math.floor(tempo / 60), math.floor(tempo % 60)) }
			if tempo > 180 then nota = nota - (tempo - 180) / 45 end
			if not a.Fogueira then
				nota = nota - 3
				table.insert(linhas, "Sem fogueira: em uma situação real, o frio e a noite colocariam a sua vida em risco.")
			else
				table.insert(linhas, "Fogueira acesa: abrigo, calor e sinal de fumaça garantidos.")
			end
			table.insert(linhas, "Sinal disparado na clareira, onde a equipe de resgate consegue ver.")
			terminar(plr, math.max(nota, 0), linhas)
		end)
	end)

	N.RegistrarAcao("Sob_Desistir", function(plr)
		if ativos[plr] then terminar(plr, nil) end
	end)

	N.AoSair(function(plr)
		local a = ativos[plr]
		if a then
			ativos[plr] = nil
			limpar(a)
		end
	end)
end

return SOB
