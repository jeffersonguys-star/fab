--[[
	FAB - Instrucao de Salto de Emergencia (servidor)

	O cadete abandona a aeronave a 2.500 pes, faz a queda livre, aciona o punho do
	paraquedas entre 2.000 e 1.500 pes, navega com o velame ate o alvo e faz o
	arredondamento (flare) antes de tocar o solo. Se nao abrir ate 1.000 pes,
	o dispositivo automatico (DAA) abre o paraquedas e a nota fica limitada.

	Escala de altitude: 1 stud = 0,28 m (1 stud = 0,92 pe).
]]

local SALTO = {}

local PES_POR_STUD = 0.9186
local ALTURA_SALTO = 2500 / PES_POR_STUD

function SALTO.Iniciar(N)
	local ativos = {}

	local function criarParaquedas(plr)
		local c, hrp = N.Personagem(plr)
		if not hrp then return nil end
		local m = Instance.new("Model")
		m.Name = "Paraquedas"
		local velame = Instance.new("Part")
		velame.Name = "Velame"
		velame.Size = Vector3.new(16, 3.2, 9)
		velame.Color = Color3.fromRGB(235, 235, 230)
		velame.Material = Enum.Material.Fabric
		velame.CanCollide = false
		velame.Massless = true
		velame.CFrame = hrp.CFrame * CFrame.new(0, 11, 0)
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = velame
		velame.Parent = m
		-- gomos coloridos
		for i = -3, 3 do
			local gomo = Instance.new("Part")
			gomo.Name = "Gomo"
			gomo.Size = Vector3.new(1.6, 0.3, 8.6)
			gomo.Color = (i % 2 == 0) and Color3.fromRGB(230, 110, 30) or Color3.fromRGB(240, 240, 240)
			gomo.Material = Enum.Material.Fabric
			gomo.CanCollide = false
			gomo.Massless = true
			local altura = 1.55 * math.sqrt(math.max(0, 1 - (i / 4) ^ 2))
			gomo.CFrame = velame.CFrame * CFrame.new(i * 2.1, altura, 0) * CFrame.Angles(0, 0, math.rad(-i * 9))
			gomo.Parent = m
			local w = Instance.new("WeldConstraint")
			w.Part0 = velame
			w.Part1 = gomo
			w.Parent = gomo
		end
		-- linhas de suspensao (Beams)
		local function anexo(parte, pos)
			local a = Instance.new("Attachment")
			a.Position = pos
			a.Parent = parte
			return a
		end
		local ombroE = anexo(hrp, Vector3.new(-0.8, 1, 0))
		local ombroD = anexo(hrp, Vector3.new(0.8, 1, 0))
		for i = 0, 7 do
			local x = -7 + i * 2
			local frente = anexo(velame, Vector3.new(x, -1.2, -3.8))
			local tras = anexo(velame, Vector3.new(x, -1.2, 3.8))
			for _, a in ipairs({ frente, tras }) do
				local b = Instance.new("Beam")
				b.Attachment0 = (x < 0) and ombroE or ombroD
				b.Attachment1 = a
				b.Width0 = 0.05
				b.Width1 = 0.05
				b.Color = ColorSequence.new(Color3.fromRGB(60, 60, 60))
				b.FaceCamera = true
				b.Parent = velame
			end
		end
		local w = Instance.new("WeldConstraint")
		w.Part0 = hrp
		w.Part1 = velame
		w.Parent = velame
		m.Parent = c
		return m
	end

	local function terminar(plr, nota, linhas)
		local a = ativos[plr]
		if not a then return end
		ativos[plr] = nil
		N.EncerrarSessao(plr)
		N.Pose(plr, "")
		task.delay(3, function()
			if a.Paraquedas then a.Paraquedas:Destroy() end
		end)
		if nota then
			N.RegistrarResultado(plr, "SaltoEmergencia", nota, { Linhas = linhas })
		end
	end

	N.Prompt(N.Placas.Salto, "Salto de Emergência", "Embarcar", function(plr)
		if not N.Requisitos(plr, "SaltoEmergencia") then N.MostrarBloqueio(plr, "SaltoEmergencia") return end
		if ativos[plr] then return end
		local alvo = N.Local("AlvoSalto")
		-- ponto de saida a 300-450 studs do alvo, em direcao aleatoria
		local ang = math.random() * math.pi * 2
		local dist = 300 + math.random() * 150
		local saida = alvo.Position + Vector3.new(math.cos(ang) * dist, ALTURA_SALTO, math.sin(ang) * dist)
		local rumoAlvo = CFrame.lookAt(saida, Vector3.new(alvo.Position.X, saida.Y, alvo.Position.Z))
		ativos[plr] = { Inicio = os.clock(), Abertura = nil, DAA = false }
		N.IniciarSessao(plr, "SaltoEmergencia")
		N.Abrir(plr, "Salto_Briefing", {})
		ativos[plr].Saida = rumoAlvo
	end, 12)

	-- o cadete confirmou o briefing: vai para a porta da aeronave
	N.RegistrarAcao("Salto_Pronto", function(plr)
		local a = ativos[plr]
		if not a or a.Saltou then return end
		a.Saltou = true
		a.Inicio = os.clock()
		N.Congelar(plr, false)
		N.Teleportar(plr, a.Saida)
		N.Pose(plr, "QuedaLivre")
		N.Abrir(plr, "Salto_Iniciar", { Alvo = N.Local("AlvoSalto").Position, PesPorStud = PES_POR_STUD })
	end)

	N.RegistrarAcao("Salto_Abrir", function(plr, p)
		local a = ativos[plr]
		if not a or a.Abertura then return end
		local _, hrp = N.Personagem(plr)
		if not hrp then return end
		local alvo = N.Local("AlvoSalto")
		a.Abertura = (hrp.Position.Y - alvo.Position.Y) * PES_POR_STUD
		a.DAA = p.DAA == true
		a.Paraquedas = criarParaquedas(plr)
		N.Pose(plr, "Paraquedas")
	end)

	N.RegistrarAcao("Salto_Pouso", function(plr, p)
		local a = ativos[plr]
		if not a or not a.Abertura then return end
		if os.clock() - a.Inicio < 10 then return end
		local _, hrp = N.Personagem(plr)
		if not hrp then return end
		local alvo = N.Local("AlvoSalto")
		local delta = hrp.Position - alvo.Position
		local dist = Vector3.new(delta.X, 0, delta.Z).Magnitude
		if delta.Y > 30 then return end
		local linhas = {}
		local nota = 0
		-- abertura
		if a.DAA then
			table.insert(linhas, "O paraquedas foi aberto pelo dispositivo automático (DAA) a 1.000 pés.")
		elseif a.Abertura <= 2050 and a.Abertura >= 1450 then
			nota = nota + 3
			table.insert(linhas, string.format("Abertura correta a %d pés.", math.floor(a.Abertura)))
		else
			nota = nota + 1
			table.insert(linhas, string.format("Abertura fora da faixa (%d pés). O correto é entre 2.000 e 1.500 pés.", math.floor(a.Abertura)))
		end
		-- precisao
		local pPrecisao
		if dist <= 6 then pPrecisao = 6
		elseif dist <= 18 then pPrecisao = 5
		elseif dist <= 30 then pPrecisao = 4
		elseif dist <= 60 then pPrecisao = 2.5
		elseif dist <= 120 then pPrecisao = 1
		else pPrecisao = 0 end
		nota = nota + pPrecisao
		table.insert(linhas, string.format("Distância do centro do alvo: %.1f m", dist * 0.28))
		-- arredondamento
		local vVert = tonumber(p.VelocidadeVertical) or 0
		if p.Flare == true and vVert < 25 then
			nota = nota + 1
			table.insert(linhas, "Arredondamento (flare) feito no momento certo.")
		else
			table.insert(linhas, "Pouso sem arredondamento: impacto forte no solo.")
		end
		if a.DAA then nota = math.min(nota, 4) end
		terminar(plr, nota, linhas)
	end)

	N.RegistrarAcao("Salto_Cancelar", function(plr)
		local a = ativos[plr]
		if a and not a.Saltou then
			ativos[plr] = nil
			N.EncerrarSessao(plr)
		end
	end)

	N.AoSair(function(plr) ativos[plr] = nil end)
end

return SALTO
