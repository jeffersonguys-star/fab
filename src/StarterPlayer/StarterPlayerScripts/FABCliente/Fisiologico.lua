--[[
	FAB - Instrucao fisiologica (cliente)

	Camara hipobarica: subida a 25.000 pes com mascara, retirada da mascara, tarefas
	de raciocinio enquanto a hipoxia avanca e reconhecimento dos sintomas.
	Centrifuga: perfil relaxado (mede a tolerancia), depois inicio rapido a 6 G e 7,5 G
	com manobra anti-G (contrair e respirar a cada ~3 segundos).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local FISIO = {}

function FISIO.Iniciar(UI)
	local COR = UI.Cor
	local F = require(ReplicatedStorage:WaitForChild("FAB"):WaitForChild("Fisiologia"))
	local itens, conexoes = {}, {}

	local function limpar()
		for _, c in ipairs(conexoes) do c:Disconnect() end
		conexoes = {}
		for _, v in pairs(itens) do
			if typeof(v) == "Instance" then v:Destroy() end
		end
		itens = {}
		F.Limpar()
	end

	local function enviar(nota, aprovado, linhas, cancelado)
		UI.Enviar("Fisio_Resultado", { Nota = nota, Aprovado = aprovado, Linhas = linhas, Cancelado = cancelado })
	end

	-- CAMARA HIPOBARICA -----------------------------------------------------------
	UI.Registrar("Hipoxia_Iniciar", function()
		UI.Briefing({
			Titulo = "Câmara Hipobárica", Sobretitulo = "Instrução fisiológica",
			Descricao = "A câmara vai simular a subida até 25.000 pés. Em altitude, sem oxigênio, o tempo útil de consciência é de poucos minutos.",
			Itens = {
				"A subida é feita com a máscara de oxigênio.",
				"A 25.000 pés, retire a máscara quando o instrutor mandar e resolva as contas na tela.",
				"Observe o seu corpo. Ao perceber os sintomas da hipóxia, coloque a máscara.",
				"Colocar a máscara cedo demais não permite reconhecer os sintomas. Tarde demais, você perde a consciência.",
			},
			Botao = "Entrar na câmara",
			AoCancelar = function() enviar(0, false, {}, true) end,
			AoConfirmar = function()
				limpar()
				local inicio = os.clock()
				local fase = "Subida"
				local semMascara = 0
				local TUC = 80
				local acertos, respondidas = 0, 0
				local chip = UI.Chip("")
				itens.Chip = chip
				local cartao = UI.Novo("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45), Size = UDim2.fromOffset(380, 210),
					BackgroundColor3 = COR.Cartao, Visible = false, Parent = UI.Tela() })
				UI.Canto(cartao, 18)
				UI.Contorno(cartao, 0.8)
				itens.Cartao = cartao
				local pergunta = UI.Rotulo(cartao, "", 28, { Font = Enum.Font.GothamBold, Position = UDim2.fromOffset(0, 24), Size = UDim2.new(1, 0, 0, 40),
					AutomaticSize = Enum.AutomaticSize.None, TextXAlignment = Enum.TextXAlignment.Center })
				local opcoes = UI.Novo("Frame", { Position = UDim2.new(0, 20, 0, 100), Size = UDim2.new(1, -40, 0, 56), BackgroundTransparency = 1, Parent = cartao })
				UI.Novo("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 10), HorizontalAlignment = Enum.HorizontalAlignment.Center, Parent = opcoes })
				local certa
				local function novaConta()
					local a, b = math.random(11, 49), math.random(11, 49)
					certa = a + b
					pergunta.Text = a .. " + " .. b .. " = ?"
					for _, c in ipairs(opcoes:GetChildren()) do if c:IsA("GuiObject") then c:Destroy() end end
					local valores = { certa, certa + (math.random(1, 2) == 1 and 10 or -10), certa + (math.random(1, 2) == 1 and 1 or -1) }
					for i = 3, 2, -1 do local j = math.random(1, i) valores[i], valores[j] = valores[j], valores[i] end
					for _, v in ipairs(valores) do
						UI.Botao(opcoes, tostring(v), "secundario", function()
							-- com hipoxia, a resposta demora a sair
							local atraso = math.clamp(semMascara / TUC, 0, 1) * 0.9
							task.delay(atraso, function()
								if fase ~= "SemMascara" then return end
								respondidas = respondidas + 1
								if v == certa then acertos = acertos + 1 end
								novaConta()
							end)
						end, { Size = UDim2.fromOffset(100, 52), TextSize = 20 })
					end
				end
				local _, botoes = UI.PainelAcoes({
					{ Id = "Mascara", Texto = "RETIRAR MÁSCARA", Estilo = "primario", Largura = 210, Altura = 60 },
				})
				itens.Painel = botoes.Mascara.Parent
				botoes.Mascara.Visible = false
				local function concluir(tempo, perdeu)
					fase = "Fim"
					cartao.Visible = false
					botoes.Mascara.Visible = false
					-- recuperacao com oxigenio
					local t0 = os.clock()
					while os.clock() - t0 < 4 do
						local k = 1 - (os.clock() - t0) / 4
						F.Definir({ Hipoxia = math.clamp(tempo / TUC, 0, 1) * k, Apagao = perdeu and k or 0 })
						task.wait()
					end
					local linhas = {}
					local nota, aprovado
					if perdeu then
						nota, aprovado = 3, false
						table.insert(linhas, "Você perdeu a consciência. O instrutor colocou a sua máscara.")
						table.insert(linhas, "Na hipóxia, o julgamento piora antes de você perceber. Reaja aos primeiros sinais.")
					elseif tempo < 15 then
						nota, aprovado = 5, false
						table.insert(linhas, string.format("Máscara colocada após %d s: cedo demais para reconhecer os sintomas.", math.floor(tempo)))
					else
						nota = 10 - math.max(0, tempo - 55) * 0.18
						aprovado = true
						table.insert(linhas, string.format("Sintomas reconhecidos e máscara colocada após %d s sem oxigênio.", math.floor(tempo)))
					end
					table.insert(linhas, string.format("Contas resolvidas sem máscara: %d de %d corretas.", acertos, respondidas))
					table.insert(linhas, "Sintomas comuns: visão turva e sem cores, formigamento, calor, euforia e raciocínio lento.")
					table.insert(linhas, "O tempo útil de consciência a 25.000 pés é de 3 a 5 minutos (aqui foi reduzido).")
					limpar()
					enviar(nota, aprovado, linhas)
				end
				botoes.Mascara.Activated:Connect(function()
					if fase == "Ordem" then
						fase = "SemMascara"
						semMascara = 0
						botoes.Mascara.Text = "COLOCAR MÁSCARA"
						cartao.Visible = true
						novaConta()
					elseif fase == "SemMascara" then
						task.spawn(concluir, semMascara, false)
					end
				end)
				table.insert(conexoes, RunService.Heartbeat:Connect(function(dt)
					local t = os.clock() - inicio
					if fase == "Subida" then
						local alt = math.min(25000, t / 18 * 25000)
						chip.Text = string.format("ALTITUDE %d ft  ·  com máscara", math.floor(alt / 100) * 100)
						if t >= 18 then
							fase = "Ordem"
							chip.Text = "ALTITUDE 25.000 ft  ·  Retire a máscara"
							botoes.Mascara.Visible = true
						end
					elseif fase == "SemMascara" then
						semMascara = semMascara + dt
						local h = math.clamp(semMascara / TUC, 0, 1)
						-- os sintomas aparecem aos poucos e de forma irregular
						local oscila = 0.04 * math.sin(semMascara * 1.7)
						F.Definir({ Hipoxia = math.clamp(h * h * 1.1 + oscila, 0, 1) })
						cartao.Position = UDim2.new(0.5, math.sin(semMascara * 3.1) * 6 * h, 0.45, math.cos(semMascara * 2.3) * 4 * h)
						chip.Text = "ALTITUDE 25.000 ft  ·  sem máscara"
						if semMascara >= TUC then task.spawn(concluir, semMascara, true) end
					end
				end))
			end,
		})
	end)

	-- CENTRIFUGA --------------------------------------------------------------------
	UI.Registrar("Centrifuga_Iniciar", function()
		UI.Briefing({
			Titulo = "Centrífuga Humana", Sobretitulo = "Instrução fisiológica",
			Descricao = "Treinamento de tolerância à aceleração (G) e da manobra anti-G (AGSM).",
			Itens = {
				"Fase 1, relaxado: não contraia. Toque em PERDI A PERIFERIA quando a visão começar a fechar.",
				"Fase 2: 6 G por 15 s. Fase 3: 7,5 G por 15 s. Use a manobra anti-G.",
				"Manobra anti-G: segure CONTRAIR e faça uma respiração curta (RESPIRAR) a cada 3 segundos.",
				"Prender o ar por muito tempo ou soltar a contração faz a visão fechar e pode causar perda de consciência.",
			},
			Controles = "CONTRAIR: segure o botão ou Shift. RESPIRAR: toque no botão ou Espaço.",
			Botao = "Entrar na gôndola",
			AoCancelar = function() enviar(0, false, {}, true) end,
			AoConfirmar = function()
				limpar()
				local piloto = F.NovoPiloto(4.4)
				local fase = 1
				local g = 1
				local tFase = 0
				local toleranciaMedida
				local tempoCinza = 0
				local perdeuConsciencia = false
				local medidor = UI.Novo("TextLabel", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 60), Size = UDim2.fromOffset(200, 70),
					BackgroundTransparency = 1, Text = "1,0 G", TextSize = 54, Font = Enum.Font.GothamBold, TextColor3 = COR.Branco, Parent = UI.Tela() })
				itens.Medidor = medidor
				local chip = UI.Chip("Fase 1  ·  relaxado")
				itens.Chip = chip
				local respiracao = UI.Novo("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 132), Size = UDim2.fromOffset(220, 6),
					BackgroundColor3 = COR.Linha, Parent = UI.Tela() })
				UI.Canto(respiracao, 3)
				local barraResp = UI.Novo("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = COR.Branco, Parent = respiracao })
				UI.Canto(barraResp, 3)
				itens.Respiracao = respiracao
				local _, botoes = UI.PainelAcoes({
					{ Id = "Periferia", Texto = "PERDI A PERIFERIA", Largura = 200, Altura = 64 },
					{ Id = "Respirar", Texto = "RESPIRAR", Largura = 140, Altura = 64 },
					{ Id = "Contrair", Texto = "CONTRAIR", Estilo = "primario", Largura = 160, Altura = 64 },
				})
				itens.Painel = botoes.Contrair.Parent
				botoes.Respirar.Visible = false
				botoes.Contrair.Visible = false
				botoes.Contrair.MouseButton1Down:Connect(function() piloto.Contraindo = true end)
				botoes.Contrair.MouseButton1Up:Connect(function() piloto.Contraindo = false end)
				botoes.Contrair.MouseLeave:Connect(function() piloto.Contraindo = false end)
				botoes.Respirar.Activated:Connect(function() F.Respirar(piloto) end)
				botoes.Periferia.Activated:Connect(function()
					if fase == 1 and not toleranciaMedida then
						toleranciaMedida = g
						fase = 1.5
						tFase = 0
					end
				end)
				table.insert(conexoes, UserInputService.InputBegan:Connect(function(i, proc)
					if proc then return end
					if i.KeyCode == Enum.KeyCode.LeftShift then piloto.Contraindo = true end
					if i.KeyCode == Enum.KeyCode.Space then F.Respirar(piloto) end
				end))
				table.insert(conexoes, UserInputService.InputEnded:Connect(function(i)
					if i.KeyCode == Enum.KeyCode.LeftShift then piloto.Contraindo = false end
				end))
				local function terminar()
					local linhas = {}
					table.insert(linhas, toleranciaMedida and string.format("Tolerância relaxada medida: %.1f G.", toleranciaMedida)
						or "Você não informou a perda da visão periférica na fase relaxada.")
					local nota, aprovado
					if perdeuConsciencia then
						nota, aprovado = 3, false
						table.insert(linhas, "Perda de consciência (G-LOC) durante o perfil. A manobra anti-G precisa ser contínua.")
					else
						nota = math.clamp(10 - tempoCinza * 0.3 - (toleranciaMedida and 0 or 1.5), 0, 10)
						aprovado = true
						table.insert(linhas, "Perfil de 6 G e 7,5 G concluído sem perda de consciência.")
						table.insert(linhas, string.format("Tempo com visão cinza nas fases com manobra: %.1f s.", tempoCinza))
					end
					table.insert(linhas, "Na manobra anti-G, contraia pernas e abdômen e faça respirações curtas a cada 3 segundos.")
					limpar()
					enviar(nota, aprovado, linhas)
				end
				table.insert(conexoes, RunService.Heartbeat:Connect(function(dt)
					tFase = tFase + dt
					local alvo = 1.4
					if fase == 1 then
						alvo = math.min(1.4 + tFase * 0.12, 6)
						piloto.Contraindo = false
						if piloto.S > 0.75 then
							-- passou do ponto sem avisar: o operador para a centrifuga
							toleranciaMedida = nil
							fase = 1.5
							tFase = 0
						end
					elseif fase == 1.5 then
						alvo = 1.4
						chip.Text = "Recuperação  ·  prepare a manobra anti-G"
						botoes.Periferia.Visible = false
						botoes.Respirar.Visible = true
						botoes.Contrair.Visible = true
						if tFase > 8 then fase = 2 tFase = 0 end
					elseif fase == 2 then
						alvo = 6
						chip.Text = string.format("Fase 2  ·  6 G  ·  %d s", math.max(0, math.ceil(17 - tFase)))
						if tFase > 17 then fase = 2.5 tFase = 0 end
					elseif fase == 2.5 then
						alvo = 1.4
						chip.Text = "Intervalo"
						if tFase > 6 then fase = 3 tFase = 0 end
					elseif fase == 3 then
						alvo = 7.5
						chip.Text = string.format("Fase 3  ·  7,5 G  ·  %d s", math.max(0, math.ceil(18 - tFase)))
						if tFase > 18 then fase = 4 tFase = 0 end
					elseif fase == 4 then
						alvo = 1
						chip.Text = "Desaceleração"
						if tFase > 4 then fase = 5 task.spawn(terminar) end
					end
					-- inicio rapido de ~1 G/s nas fases 2 e 3
					local taxa = (fase == 1) and 10 or 1.1
					g = g + math.clamp(alvo - g, -taxa * dt * 1.5, taxa * dt)
					local e = F.AtualizarG(piloto, g, dt)
					F.Definir(e)
					if e.GLOC then perdeuConsciencia = true end
					if (fase == 2 or fase == 3) and e.Cinza > 0.5 then tempoCinza = tempoCinza + dt end
					medidor.Text = string.format("%.1f G", g):gsub("%.", ",")
					local desde = piloto.Relogio - piloto.UltimaRespiracao
					barraResp.Size = UDim2.fromScale(math.clamp(1 - desde / 3.5, 0, 1), 1)
					botoes.Contrair.BackgroundColor3 = piloto.Contraindo and COR.Branco or COR.Cartao
					botoes.Contrair.TextColor3 = piloto.Contraindo and COR.Fundo or COR.Branco
				end))
			end,
		})
	end)
end

return FISIO
