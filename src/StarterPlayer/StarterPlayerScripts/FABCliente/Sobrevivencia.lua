--[[
	FAB - Sobrevivencia (cliente)

	Lista de objetivos, cronometro, bussola (depois de abrir o kit) e botoes de
	fogueira e sinalizador.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local SOB = {}

function SOB.Iniciar(UI)
	local COR = UI.Cor
	local plr = Players.LocalPlayer
	local itens, conexoes = {}, {}
	local estado = { Kit = false, Gravetos = 0, Fogueira = false, Sinalizou = false }
	local atualizar

	local function limpar()
		for _, c in ipairs(conexoes) do c:Disconnect() end
		conexoes = {}
		for _, v in pairs(itens) do
			if typeof(v) == "Instance" then v:Destroy() end
		end
		itens = {}
		atualizar = nil
	end

	UI.Registrar("Sob_Briefing", function(p)
		UI.Briefing({
			Titulo = "Sobrevivência na Selva", Sobretitulo = "Estágio de sobrevivência",
			Descricao = "Sua aeronave foi abatida e você se ejetou sobre a mata. A equipe de resgate vai procurar na clareira ao NORTE do ponto de queda.",
			Itens = {
				"Encontre o kit de sobrevivência (bússola, isqueiro e sinalizador). Ele caiu perto de você.",
				"Junte 3 gravetos e monte uma fogueira.",
				"Use a bússola para seguir até a clareira, ao norte.",
				"Na clareira, dispare o sinalizador. Embaixo das árvores o sinal não é visto.",
				"Tempo limite: " .. math.floor(p.Limite / 60) .. " minutos.",
			},
			Botao = "Começar",
			AoCancelar = function() UI.Enviar("Sob_Desistir") end,
			AoConfirmar = function() UI.Enviar("Sob_Pronto") end,
		})
	end)

	UI.Registrar("Sob_Iniciar", function(p)
		limpar()
		estado = { Kit = false, Gravetos = 0, Fogueira = false, Sinalizou = false }
		local inicio = os.clock()
		local chip = UI.Chip("")
		itens.Chip = chip
		-- objetivos
		local lista = UI.Novo("Frame", { Position = UDim2.new(0, 16, 0, 64), Size = UDim2.fromOffset(250, 0), AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = COR.Fundo, BackgroundTransparency = 0.2, Parent = UI.Tela() })
		UI.Canto(lista, 14)
		UI.Contorno(lista, 0.82)
		UI.Novo("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14), PaddingTop = UDim.new(0, 12), PaddingBottom = UDim.new(0, 12), Parent = lista })
		UI.Novo("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = lista })
		UI.Rotulo(lista, "OBJETIVOS", 11, { Font = Enum.Font.GothamBold, TextColor3 = COR.Sub, LayoutOrder = 0 })
		local linhas = {}
		for i, t in ipairs({ "Encontrar o kit", "Juntar gravetos (0/3)", "Montar a fogueira", "Sinalizar na clareira" }) do
			linhas[i] = UI.Rotulo(lista, "○  " .. t, 14, { LayoutOrder = i })
		end
		itens.Lista = lista
		-- bussola
		local bussola = UI.Novo("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 56), Size = UDim2.fromOffset(300, 34),
			BackgroundColor3 = COR.Fundo, BackgroundTransparency = 0.2, ClipsDescendants = true, Visible = false, Parent = UI.Tela() })
		UI.Canto(bussola, 17)
		UI.Contorno(bussola, 0.8)
		local fita = UI.Novo("Frame", { Size = UDim2.new(0, 1440, 1, 0), BackgroundTransparency = 1, Parent = bussola })
		local rotulos = { [0] = "N", [45] = "NE", [90] = "L", [135] = "SE", [180] = "S", [225] = "SO", [270] = "O", [315] = "NO" }
		for volta = 0, 1 do
			for g = 0, 345, 15 do
				local x = (g + volta * 360) * 2
				local r = rotulos[g]
				UI.Novo("TextLabel", { Position = UDim2.fromOffset(x - 20, 0), Size = UDim2.fromOffset(40, 34), BackgroundTransparency = 1,
					Text = r or "|", TextSize = r and 15 or 10, Font = Enum.Font.GothamBold, TextColor3 = (g == 0) and COR.Branco or COR.Sub, Parent = fita })
			end
		end
		UI.Novo("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromOffset(2, 8), BackgroundColor3 = COR.Branco, Parent = bussola })
		itens.Bussola = bussola
		local painel, botoes = UI.PainelAcoes({
			{ Id = "Fogueira", Texto = "MONTAR FOGUEIRA", Fn = function() UI.Enviar("Sob_Fogueira") end, Largura = 170, Altura = 54 },
			{ Id = "Sinal", Texto = "SINALIZADOR", Estilo = "primario", Fn = function() UI.Enviar("Sob_Sinalizar") end, Largura = 150, Altura = 54 },
			{ Id = "Desistir", Texto = "DESISTIR", Estilo = "fantasma", Fn = function() UI.Enviar("Sob_Desistir") end, Largura = 100, Altura = 54 },
		})
		itens.Painel = painel
		atualizar = function()
			linhas[1].Text = (estado.Kit and "●  " or "○  ") .. "Encontrar o kit"
			linhas[2].Text = (estado.Gravetos >= 3 and "●  " or "○  ") .. "Juntar gravetos (" .. math.min(estado.Gravetos, 3) .. "/3)"
			linhas[3].Text = (estado.Fogueira and "●  " or "○  ") .. "Montar a fogueira"
			linhas[4].Text = (estado.Sinalizou and "●  " or "○  ") .. "Sinalizar na clareira"
			for i = 1, 4 do linhas[i].TextColor3 = linhas[i].Text:sub(1, 3) == "●" and COR.Sub or COR.Texto end
			bussola.Visible = estado.Kit
			botoes.Fogueira.Visible = estado.Kit and estado.Gravetos >= 3 and not estado.Fogueira
			botoes.Sinal.Visible = estado.Kit and not estado.Sinalizou
		end
		atualizar()
		table.insert(conexoes, RunService.RenderStepped:Connect(function()
			local t = os.clock() - inicio
			local resta = math.max(0, p.Limite - t)
			chip.Text = string.format("Resgate  ·  %d:%02d", math.floor(resta / 60), math.floor(resta % 60))
			if bussola.Visible then
				local look = workspace.CurrentCamera.CFrame.LookVector
				local rumo = math.deg(math.atan2(look.X, -look.Z)) % 360
				fita.Position = UDim2.new(0, 150 - (rumo + 360) * 2, 0, 0)
			end
		end))
	end)

	UI.Registrar("Sob_Estado", function(p)
		for k, v in pairs(p) do estado[k] = v end
		if atualizar then atualizar() end
	end)

	UI.Registrar("Sob_Retorno", function(p)
		if itens.Chip then
			local c = UI.Chip(p.Texto, UDim2.new(0.5, 0, 0, 98))
			task.delay(2.5, function() c:Destroy() end)
		end
	end)

	UI.Registrar("Sob_Fim", function() limpar() end)
end

return SOB
