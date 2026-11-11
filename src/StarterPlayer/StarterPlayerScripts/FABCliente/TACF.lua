--[[
	FAB - TACF (cliente)

	Corrida: 3 ritmos (caminhada, trote e corrida) com barra de folego. Correr gasta
	folego; trotar mantem; caminhar recupera. Sem folego, o cadete e obrigado a caminhar.
	Exercicios: botoes DESCER e SUBIR (ou teclas S e W). Movimento apressado nao conta,
	e a fadiga aumenta o tempo minimo de cada repeticao.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local TACF = {}

local RITMOS = {
	Caminhada = { Velocidade = 12, Folego = 9 },
	Trote = { Velocidade = 19, Folego = 0.6 },
	Corrida = { Velocidade = 25, Folego = -11 },
}

function TACF.Iniciar(UI)
	local COR = UI.Cor
	local plr = Players.LocalPlayer
	local itens = {}
	local conexoes = {}

	local function limpar()
		for _, c in ipairs(conexoes) do c:Disconnect() end
		conexoes = {}
		for _, v in pairs(itens) do
			if typeof(v) == "Instance" then v:Destroy() end
		end
		itens = {}
		local hum = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
		if hum and hum.WalkSpeed ~= 0 then hum.WalkSpeed = 16 end
	end

	-- CORRIDA ---------------------------------------------------------------
	UI.Registrar("TACF_Corrida", function(p)
		UI.Briefing({
			Titulo = "TACF - Corrida", Sobretitulo = "Teste de condicionamento físico",
			Descricao = "Complete " .. p.Voltas .. " voltas na pista no menor tempo possível.",
			Itens = {
				"Correr gasta fôlego, trotar quase não gasta e caminhar recupera.",
				"Sem fôlego, você só consegue caminhar até recuperar 30%.",
				"Passe por todos os cones da pista: cortar caminho não conta a volta.",
				"Nota 10 com ritmo médio próximo de uma corrida forte. Mínimo 5 para não reprovar.",
			},
			Controles = "Botões TROTE e CORRIDA na tela, ou Shift para correr.",
			Botao = "Ir para a largada",
			AoCancelar = function() UI.Enviar("TACF_Desistir") end,
			AoConfirmar = function()
				limpar()
				local pontos = p.Pontos
				-- cones de referencia (so no cliente)
				local pasta = Instance.new("Folder")
				pasta.Name = "ConesCorrida"
				pasta.Parent = workspace
				itens.Cones = pasta
				for i, pt in ipairs(pontos) do
					if i % 2 == 1 then
						local cone = Instance.new("Part")
						cone.Anchored = true
						cone.CanCollide = false
						cone.Size = Vector3.new(1.2, 2, 1.2)
						cone.Color = Color3.fromRGB(255, 120, 20)
						cone.Material = Enum.Material.SmoothPlastic
						cone.CFrame = CFrame.new(pt + Vector3.new(5.5, 1.4, 0))
						cone.Parent = pasta
					end
				end
				local folego = 100
				local ritmo = "Trote"
				local exausto = false
				local inicio
				local voltas = 0
				local chip = UI.Chip("Prepare-se")
				itens.Chip = chip
				local barraFundo = UI.Novo("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 56), Size = UDim2.fromOffset(240, 8),
					BackgroundColor3 = COR.Linha, Parent = UI.Tela() })
				UI.Canto(barraFundo, 4)
				local barra = UI.Novo("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = COR.Branco, Parent = barraFundo })
				UI.Canto(barra, 4)
				itens.Barra = barraFundo
				local painel, botoes = UI.PainelAcoes({
					{ Id = "Caminhada", Texto = "CAMINHADA", Fn = function() ritmo = "Caminhada" end, Largura = 120 },
					{ Id = "Trote", Texto = "TROTE", Fn = function() ritmo = "Trote" end, Largura = 110 },
					{ Id = "Corrida", Texto = "CORRIDA", Fn = function() ritmo = "Corrida" end, Largura = 120 },
					{ Id = "Desistir", Texto = "DESISTIR", Estilo = "fantasma", Fn = function() UI.Enviar("TACF_Desistir") limpar() end, Largura = 100 },
				})
				itens.Painel = painel
				-- contagem regressiva
				task.spawn(function()
					for n = 3, 1, -1 do
						chip.Text = tostring(n)
						task.wait(1)
					end
					chip.Text = "Já!"
					UI.Enviar("TACF_Largada")
					inicio = os.clock()
				end)
				table.insert(conexoes, UserInputService.InputBegan:Connect(function(i, proc)
					if proc then return end
					if i.KeyCode == Enum.KeyCode.LeftShift then ritmo = "Corrida" end
				end))
				table.insert(conexoes, UserInputService.InputEnded:Connect(function(i)
					if i.KeyCode == Enum.KeyCode.LeftShift then ritmo = "Trote" end
				end))
				table.insert(conexoes, RunService.Heartbeat:Connect(function(dt)
					local hum = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
					if not hum then return end
					if not inicio then hum.WalkSpeed = 0 return end
					local r = ritmo
					if exausto then r = "Caminhada" end
					local movendo = hum.MoveDirection.Magnitude > 0.1
					local dados = RITMOS[r]
					hum.WalkSpeed = dados.Velocidade
					local taxa = movendo and dados.Folego or 12
					folego = math.clamp(folego + taxa * dt, 0, 100)
					if folego <= 0 then exausto = true end
					if exausto and folego >= 30 then exausto = false end
					barra.Size = UDim2.fromScale(folego / 100, 1)
					barra.BackgroundColor3 = exausto and COR.Apagado or COR.Branco
					for id, b in pairs(botoes) do
						if RITMOS[id] then
							b.BackgroundColor3 = (id == r) and COR.Branco or COR.Cartao
							b.TextColor3 = (id == r) and COR.Fundo or COR.Branco
						end
					end
					local t = os.clock() - inicio
					chip.Text = string.format("Volta %d de %d   ·   %d:%02d", math.min(voltas + 1, p.Voltas), p.Voltas, math.floor(t / 60), math.floor(t % 60))
				end))
				itens.AtualizarVolta = nil
				UI.Registrar("TACF_Volta", function(v) voltas = v.Voltas end)
			end,
		})
	end)

	-- FLEXOES E ABDOMINAIS --------------------------------------------------------
	UI.Registrar("TACF_Exercicio", function(p)
		UI.Briefing({
			Titulo = "TACF - " .. p.Nome, Sobretitulo = "Teste de condicionamento físico",
			Descricao = "Você tem " .. p.Duracao .. " segundos. O cronômetro começa no primeiro movimento.",
			Itens = {
				"Alterne DESCER e SUBIR. Cada subida completa conta uma repetição.",
				"Movimento apressado não conta: espere o indicador de força encher.",
				"A fadiga aumenta a cada repetição. Mantenha um ritmo constante.",
			},
			Controles = "Botões na tela, ou S para descer e W para subir.",
			AoCancelar = function() UI.Enviar("TACF_Parar") end,
			AoConfirmar = function()
				limpar()
				local fase = "Cima"
				local ultimo = 0
				local minimo = 0.42
				local reps = 0
				local inicio
				local chip = UI.Chip(p.Nome .. "  ·  0")
				itens.Chip = chip
				local indicador = UI.Novo("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 56), Size = UDim2.fromOffset(240, 8),
					BackgroundColor3 = COR.Linha, Parent = UI.Tela() })
				UI.Canto(indicador, 4)
				local carga = UI.Novo("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = COR.Branco, Parent = indicador })
				UI.Canto(carga, 4)
				itens.Indicador = indicador
				local function mover(m)
					if m == fase then return end
					fase = m
					ultimo = os.clock()
					if not inicio then inicio = os.clock() end
					UI.Enviar("TACF_Mov", { Mov = m })
				end
				local painel = UI.PainelAcoes({
					{ Texto = "DESCER", Fn = function() mover("Baixo") end, Largura = 150, Altura = 70 },
					{ Texto = "SUBIR", Estilo = "primario", Fn = function() mover("Cima") end, Largura = 150, Altura = 70 },
				})
				itens.Painel = painel
				local sair = UI.Botao(UI.Tela(), "ENCERRAR", "fantasma", function() UI.Enviar("TACF_Parar") end,
					{ AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 16, 1, -16), Size = UDim2.fromOffset(120, 44) })
				itens.Sair = sair
				UI.Registrar("TACF_Rep", function(r)
					reps = r.Reps
					minimo = r.Minimo or minimo
					chip.Text = p.Nome .. "  ·  " .. reps .. (r.Valida and "" or "   (não contou)")
				end)
				table.insert(conexoes, UserInputService.InputBegan:Connect(function(i, proc)
					if proc then return end
					if i.KeyCode == Enum.KeyCode.S then mover("Baixo") elseif i.KeyCode == Enum.KeyCode.W then mover("Cima") end
				end))
				table.insert(conexoes, RunService.Heartbeat:Connect(function()
					local pronto = math.clamp((os.clock() - ultimo) / minimo, 0, 1)
					carga.Size = UDim2.fromScale(pronto, 1)
					carga.BackgroundColor3 = pronto >= 1 and COR.Branco or COR.Apagado
					if inicio then
						local resta = math.max(0, p.Duracao - (os.clock() - inicio))
						chip.Text = string.format("%s  ·  %d   ·   %ds", p.Nome, reps, math.ceil(resta))
					end
				end))
			end,
		})
	end)

	UI.Registrar("TACF_Fim", function() limpar() end)
end

return TACF
