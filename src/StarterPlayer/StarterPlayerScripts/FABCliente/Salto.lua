--[[
	FAB - Salto de emergencia (cliente)

	Queda livre com velocidade terminal, abertura pelo punho (ou pelo DAA a 1.000 pes),
	choque de abertura, navegacao do velame (curvas e freio) e arredondamento (flare)
	antes do toque. A fisica do personagem e controlada aqui (o cliente e dono dele).
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local SALTO = {}

local GRAVIDADE = 196.2
local TERMINAL = 190      -- ~53 m/s
local DESCIDA_VELAME = 30
local FRENTE_VELAME = 34
local GIRO_VELAME = math.rad(55)

function SALTO.Iniciar(UI)
	local COR = UI.Cor
	local plr = Players.LocalPlayer
	local itens, conexoes = {}, {}

	local function limpar()
		for _, c in ipairs(conexoes) do c:Disconnect() end
		conexoes = {}
		for _, v in pairs(itens) do
			if typeof(v) == "Instance" then v:Destroy() end
		end
		itens = {}
	end

	UI.Registrar("Salto_Briefing", function()
		UI.Briefing({
			Titulo = "Salto de Emergência", Sobretitulo = "Instrução de salto",
			Descricao = "Abandono da aeronave a 2.500 pés sobre a área de lançamento.",
			Itens = {
				"Mantenha a posição arqueada na queda livre.",
				"Acione o punho entre 2.000 e 1.500 pés. Se não abrir, o dispositivo automático abre a 1.000 pés.",
				"Com o velame aberto, navegue até o centro do alvo usando as curvas.",
				"A cerca de 15 pés do solo, faça o arredondamento (flare) para amortecer o pouso.",
			},
			Controles = "PUXAR PUNHO (ou Espaço). Velame: ESQUERDA e DIREITA (A e D), FLARE (Espaço segurado).",
			Botao = "Saltar",
			AoCancelar = function() UI.Enviar("Salto_Cancelar") end,
			AoConfirmar = function() UI.Enviar("Salto_Pronto") end,
		})
	end)

	UI.Registrar("Salto_Iniciar", function(p)
		limpar()
		local char = plr.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if not hrp or not hum then return end
		local alvo = p.Alvo
		local pesPorStud = p.PesPorStud or 0.92
		hum.PlatformStand = true
		local estado = "Queda"
		local vy = 0
		local rumo = math.atan2(-hrp.CFrame.LookVector.X, -hrp.CFrame.LookVector.Z)
		local giro = 0
		local flare = false
		local flareInicio = 0
		local ultimoFlare = -10
		local abertura = 0
		local chip = UI.Chip("")
		itens.Chip = chip
		local dica = UI.Chip("", UDim2.new(0.5, 0, 0, 56))
		itens.Dica = dica
		local _, botoes = UI.PainelAcoes({
			{ Id = "Esq", Texto = "ESQUERDA", Largura = 120, Altura = 60 },
			{ Id = "Dir", Texto = "DIREITA", Largura = 120, Altura = 60 },
			{ Id = "Acao", Texto = "PUXAR PUNHO", Estilo = "primario", Largura = 170, Altura = 60 },
		})
		itens.Painel = botoes.Acao.Parent
		local esq, dir = false, false
		botoes.Esq.MouseButton1Down:Connect(function() esq = true end)
		botoes.Esq.MouseButton1Up:Connect(function() esq = false end)
		botoes.Dir.MouseButton1Down:Connect(function() dir = true end)
		botoes.Dir.MouseButton1Up:Connect(function() dir = false end)
		botoes.Esq.Visible = false
		botoes.Dir.Visible = false

		local function abrir(daa)
			if estado ~= "Queda" then return end
			estado = "Abrindo"
			abertura = os.clock()
			UI.Enviar("Salto_Abrir", { DAA = daa })
			botoes.Acao.Text = "FLARE"
			botoes.Esq.Visible = true
			botoes.Dir.Visible = true
		end
		local function iniciarFlare()
			if estado == "Queda" then abrir(false) return end
			if estado == "Velame" and not flare then
				flare = true
				flareInicio = os.clock()
				ultimoFlare = os.clock()
			end
		end
		botoes.Acao.MouseButton1Down:Connect(iniciarFlare)
		botoes.Acao.MouseButton1Up:Connect(function() flare = false end)
		table.insert(conexoes, UserInputService.InputBegan:Connect(function(i, proc)
			if proc then return end
			if i.KeyCode == Enum.KeyCode.Space then iniciarFlare() end
			if i.KeyCode == Enum.KeyCode.A then esq = true end
			if i.KeyCode == Enum.KeyCode.D then dir = true end
		end))
		table.insert(conexoes, UserInputService.InputEnded:Connect(function(i)
			if i.KeyCode == Enum.KeyCode.Space then flare = false end
			if i.KeyCode == Enum.KeyCode.A then esq = false end
			if i.KeyCode == Enum.KeyCode.D then dir = false end
		end))

		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { char }

		table.insert(conexoes, RunService.Heartbeat:Connect(function(dt)
			if not hrp.Parent then limpar() return end
			local pos = hrp.Position
			local alturaPes = (pos.Y - alvo.Y) * pesPorStud
			local hv = Vector3.new()
			if estado == "Queda" then
				vy = math.max(vy - GRAVIDADE * dt, -TERMINAL)
				-- deslocamento horizontal com o direcional (posicao de deriva)
				local md = hum.MoveDirection
				hv = Vector3.new(md.X, 0, md.Z) * 18
				if alturaPes < 1000 then abrir(true) end
				hrp.CFrame = CFrame.new(pos) * CFrame.Angles(0, rumo, 0) * CFrame.Angles(math.rad(-75), 0, 0)
				dica.Text = (alturaPes <= 2000 and alturaPes >= 1500) and "Acione o punho" or "Queda livre"
			else
				-- choque de abertura: a velocidade vertical cai em ~1,5 s
				local alvoVy = -DESCIDA_VELAME
				local frente = FRENTE_VELAME
				if estado == "Abrindo" and os.clock() - abertura > 1.5 then estado = "Velame" end
				if flare and os.clock() - flareInicio < 2.5 then
					alvoVy = -5
					frente = 10
				end
				vy = vy + (alvoVy - vy) * math.min(1, dt * (estado == "Abrindo" and 2.5 or 3))
				local alvoGiro = 0
				if esq then alvoGiro = alvoGiro + GIRO_VELAME end
				if dir then alvoGiro = alvoGiro - GIRO_VELAME end
				giro = giro + (alvoGiro - giro) * math.min(1, dt * 2)
				rumo = rumo + giro * dt
				-- curvas aumentam a razao de descida
				vy = vy - math.abs(giro) * 6 * dt
				hv = Vector3.new(-math.sin(rumo), 0, -math.cos(rumo)) * frente
				hrp.CFrame = CFrame.new(pos) * CFrame.Angles(0, rumo, 0) * CFrame.Angles(0, 0, -giro * 0.25)
				dica.Text = alturaPes < 40 and "Arredonde agora" or "Navegue até o alvo"
			end
			hrp.AssemblyLinearVelocity = hv + Vector3.new(0, vy, 0)
			hrp.AssemblyAngularVelocity = Vector3.new()
			local distAlvo = Vector3.new(pos.X - alvo.X, 0, pos.Z - alvo.Z).Magnitude * 0.28
			chip.Text = string.format("ALTITUDE %s ft   ·   %d m do alvo", tostring(math.floor(math.max(alturaPes, 0))), math.floor(distAlvo))
			-- toque no solo
			if estado ~= "Queda" then
				local r = workspace:Raycast(pos, Vector3.new(0, -4.2, 0), params)
				if r then
					local usouFlare = (os.clock() - ultimoFlare) < 3
					hum.PlatformStand = false
					hrp.AssemblyLinearVelocity = Vector3.new()
					UI.Enviar("Salto_Pouso", { VelocidadeVertical = math.abs(vy), Flare = usouFlare })
					limpar()
				end
			end
		end))
	end)
end

return SALTO
