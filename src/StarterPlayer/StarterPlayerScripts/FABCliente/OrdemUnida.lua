--[[
	FAB - Ordem Unida (cliente)

	Mostra as vozes de comando e os botoes de movimento. O cadete so deve executar
	na voz de execucao (em caixa alta). Teclas: 1 Sentido, 2 Descansar, 3 A vontade,
	4 Continencia, Q Esquerda volver, E Direita volver, R Meia-volta.
]]

local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local OU = {}

function OU.Iniciar(UI)
	local COR = UI.Cor
	local ativo = false
	local tela = {}
	local painel

	local function limpar()
		ativo = false
		for _, v in pairs(tela) do
			if typeof(v) == "Instance" then v:Destroy() end
		end
		tela = {}
	end

	local function responder(r)
		if not ativo then return end
		UI.Enviar("OU_Resposta", { Resposta = r })
	end

	local MOVIMENTOS = {
		{ "Sentido", "SENTIDO", Enum.KeyCode.One }, { "Descansar", "DESCANSAR", Enum.KeyCode.Two },
		{ "AVontade", "À VONTADE", Enum.KeyCode.Three }, { "Continencia", "CONTINÊNCIA", Enum.KeyCode.Four },
		{ "Esquerda", "ESQ. VOLVER", Enum.KeyCode.Q }, { "Direita", "DIR. VOLVER", Enum.KeyCode.E },
		{ "MeiaVolta", "MEIA-VOLTA", Enum.KeyCode.R },
	}

	UI.Registrar("OU_Entrar", function(p)
		limpar()
		ativo = true
		local t = UI.Tela()
		-- faixa da voz de comando
		local voz = UI.Novo("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 64), Size = UDim2.new(0.7, 0, 0, 96),
			BackgroundColor3 = COR.Fundo, BackgroundTransparency = 0.25, Parent = t })
		UI.Canto(voz, 18)
		UI.Contorno(voz, 0.8)
		UI.Novo("UISizeConstraint", { MaxSize = Vector2.new(620, 96), Parent = voz })
		local rotulo = UI.Rotulo(voz, "VOZ DE COMANDO", 11, { Font = Enum.Font.GothamBold, TextColor3 = COR.Sub, Position = UDim2.fromOffset(20, 12),
			Size = UDim2.new(1, -40, 0, 14), AutomaticSize = Enum.AutomaticSize.None })
		local texto = UI.Rotulo(voz, "Aguardando o comando", 30, { Font = Enum.Font.GothamBold, Position = UDim2.fromOffset(20, 32),
			Size = UDim2.new(1, -40, 0, 40), AutomaticSize = Enum.AutomaticSize.None, TextXAlignment = Enum.TextXAlignment.Center, TextScaled = true })
		local barraTempo = UI.Novo("Frame", { Position = UDim2.new(0, 20, 1, -12), Size = UDim2.new(1, -40, 0, 3), BackgroundColor3 = COR.Branco, BorderSizePixel = 0, Parent = voz })
		barraTempo.Size = UDim2.new(0, 0, 0, 3)
		tela.Voz = voz
		tela.Texto = texto
		tela.Barra = barraTempo
		tela.Placar = UI.Chip("0 / 0", UDim2.new(0, 120, 0, 14))
		-- botoes dos movimentos
		local grade = UI.Novo("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -16), Size = UDim2.new(0.96, 0, 0, 124),
			BackgroundTransparency = 1, Parent = t })
		UI.Novo("UIGridLayout", { CellSize = UDim2.new(0.24, -6, 0, 54), CellPadding = UDim2.fromOffset(8, 8), HorizontalAlignment = Enum.HorizontalAlignment.Center, Parent = grade })
		for _, mv in ipairs(MOVIMENTOS) do
			UI.Botao(grade, mv[2], "secundario", function() responder(mv[1]) end, { TextSize = 13 })
		end
		UI.Botao(grade, "SAIR DE FORMA", "fantasma", function()
			UI.Enviar("OU_Sair")
			limpar()
		end, { TextSize = 12 })
		tela.Grade = grade
		tela.Retorno = UI.Chip("", UDim2.new(0.5, 0, 0, 172))
		tela.Retorno.Visible = false
	end)

	UI.Registrar("OU_Comando", function(p)
		if not tela.Texto then return end
		tela.Texto.Text = p.Texto or ""
		if p.Fase == "Execucao" then
			tela.Voz.BackgroundColor3 = COR.Branco
			tela.Texto.TextColor3 = COR.Fundo
			tela.Barra.BackgroundColor3 = COR.Fundo
			tela.Barra.Size = UDim2.new(1, -40, 0, 3)
			TweenService:Create(tela.Barra, TweenInfo.new(p.Janela or 2.4, Enum.EasingStyle.Linear), { Size = UDim2.new(0, 0, 0, 3) }):Play()
			task.delay(p.Janela or 2.4, function()
				if tela.Voz then
					tela.Voz.BackgroundColor3 = COR.Fundo
					tela.Texto.TextColor3 = COR.Branco
				end
			end)
		else
			tela.Voz.BackgroundColor3 = COR.Fundo
			tela.Texto.TextColor3 = (p.Fase == "Aviso") and COR.Sub or COR.Branco
		end
	end)

	UI.Registrar("OU_Retorno", function(p)
		if not tela.Retorno then return end
		tela.Retorno.Text = p.Texto
		tela.Retorno.Visible = true
		tela.Retorno.BackgroundColor3 = p.Certo and COR.Branco or COR.Fundo
		tela.Retorno.TextColor3 = p.Certo and COR.Fundo or COR.Branco
		task.delay(1.2, function() if tela.Retorno then tela.Retorno.Visible = false end end)
	end)

	UI.Registrar("OU_Placar", function(p)
		if tela.Placar then tela.Placar.Text = p.Acertos .. " / " .. p.Total end
	end)

	UI.Registrar("OU_Fim", function()
		limpar()
		if painel then painel:Destroy() painel = nil end
	end)

	-- painel do instrutor para comandar a tropa
	UI.Registrar("OU_Painel", function(p)
		if painel then painel:Destroy() end
		painel = UI.Novo("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 16, 1, -16), Size = UDim2.fromOffset(330, 0),
			AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = COR.Cartao, Parent = UI.Tela() })
		UI.Canto(painel, 16)
		UI.Contorno(painel, 0.8)
		UI.Novo("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), PaddingTop = UDim.new(0, 12), PaddingBottom = UDim.new(0, 12), Parent = painel })
		UI.Novo("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = painel })
		UI.Rotulo(painel, "COMANDO DA TROPA  ·  postura atual: " .. tostring(p.Postura), 11, { Font = Enum.Font.GothamBold, TextColor3 = COR.Sub, LayoutOrder = 0 })
		local grade = UI.Novo("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = 1, Parent = painel })
		UI.Novo("UIGridLayout", { CellSize = UDim2.new(0.5, -4, 0, 40), CellPadding = UDim2.fromOffset(8, 8), Parent = grade })
		local cmds = { { "Sentido", "SENTIDO" }, { "Descansar", "DESCANSAR" }, { "AVontade", "À VONTADE" }, { "Continencia", "CONTINÊNCIA" },
			{ "DireitaVolver", "DIREITA VOLVER" }, { "EsquerdaVolver", "ESQUERDA VOLVER" }, { "MeiaVolta", "MEIA-VOLTA" } }
		for _, c in ipairs(cmds) do
			UI.Botao(grade, c[2], "secundario", function() UI.Enviar("OU_Comando", { Id = c[1] }) end, { TextSize = 12 })
		end
		UI.Botao(grade, "FORA DE FORMA", "primario", function()
			UI.Enviar("OU_Encerrar")
			if painel then painel:Destroy() painel = nil end
		end, { TextSize = 12 })
	end)

	UserInputService.InputBegan:Connect(function(input, processado)
		if processado or not ativo then return end
		for _, mv in ipairs(MOVIMENTOS) do
			if input.KeyCode == mv[3] then responder(mv[1]) end
		end
	end)
end

return OU
