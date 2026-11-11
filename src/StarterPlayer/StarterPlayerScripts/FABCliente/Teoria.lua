--[[
	FAB - Instrucao teorica (cliente)

	Menu das materias e prova com uma questao por vez.
]]

local TEORIA = {}

function TEORIA.Iniciar(UI)
	local COR = UI.Cor

	UI.Registrar("Teoria_Menu", function(p)
		local m = UI.Modal({ Titulo = "Provas teóricas", Sobretitulo = "Divisão de Ensino", Largura = 520, Altura = 480 })
		UI.Rotulo(m.Conteudo, "Cada prova tem 7 questões sorteadas. São necessários 5 acertos para aprovação.", 13, { TextColor3 = COR.Sub, LayoutOrder = 0 })
		local dados = UI.Dados or { Atividades = {} }
		for i, mat in ipairs(p.Materias) do
			local r = dados.Atividades[mat.Id]
			local estado = (r and r.Aprovado) and "Aprovado" or (mat.Liberado and "Disponível" or "Bloqueado")
			local sub = (r and r.Aprovado) and string.format("Nota %.1f", r.Nota or 0) or (mat.Liberado and "7 questões" or "Conclua a adaptação militar")
			UI.Item(m.Conteudo, mat.Nome, sub, estado, function()
				m.Fechar()
				UI.Enviar("Teoria_Iniciar", { Id = mat.Id })
			end, i)
		end
		UI.Botao(m.Rodape, "Fechar", "secundario", function() m.Fechar() end, { Size = UDim2.fromOffset(130, 42) })
	end)

	UI.Registrar("Teoria_Prova", function(p)
		local respostas = {}
		local atual = 1
		local enviado = false
		local m = UI.Modal({ Titulo = p.Nome, Sobretitulo = "Prova teórica", Largura = 620, Altura = 600, SemFechar = true })
		local cabecalho = UI.Rotulo(m.Conteudo, "", 12, { Font = Enum.Font.GothamBold, TextColor3 = COR.Sub, LayoutOrder = 0 })
		local enunciado = UI.Rotulo(m.Conteudo, "", 19, { Font = Enum.Font.GothamMedium, LayoutOrder = 1 })
		local opcoes = UI.Novo("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = 2, Parent = m.Conteudo })
		UI.Novo("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = opcoes })
		local anterior, proximo

		local function mostrar()
			local q = p.Questoes[atual]
			cabecalho.Text = string.format("QUESTÃO %d DE %d", atual, #p.Questoes)
			enunciado.Text = q.Texto
			for _, c in ipairs(opcoes:GetChildren()) do
				if c:IsA("GuiObject") then c:Destroy() end
			end
			for i, texto in ipairs(q.Opcoes) do
				local marcada = respostas[atual] == i
				local b = UI.Novo("TextButton", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, AutoButtonColor = false, Text = "",
					BackgroundColor3 = marcada and COR.Branco or COR.Elevado, LayoutOrder = i, Parent = opcoes })
				UI.Canto(b, 12)
				UI.Contorno(b, marcada and 0 or 0.88)
				UI.Novo("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14), PaddingTop = UDim.new(0, 12), PaddingBottom = UDim.new(0, 12), Parent = b })
				UI.Rotulo(b, string.char(64 + i) .. ")   " .. texto, 15, { TextColor3 = marcada and COR.Fundo or COR.Texto })
				b.Activated:Connect(function()
					respostas[atual] = i
					mostrar()
				end)
			end
			anterior.Visible = atual > 1
			if atual == #p.Questoes then
				proximo.Text = "Entregar prova"
			else
				proximo.Text = "Próxima"
			end
			UI.Desativar(proximo, respostas[atual] == nil)
		end

		anterior = UI.Botao(m.Rodape, "Anterior", "fantasma", function()
			atual = math.max(1, atual - 1)
			mostrar()
		end, { Size = UDim2.fromOffset(120, 42), LayoutOrder = 1 })
		proximo = UI.Botao(m.Rodape, "Próxima", "primario", function()
			if not respostas[atual] then return end
			if atual < #p.Questoes then
				atual = atual + 1
				mostrar()
			elseif not enviado then
				enviado = true
				m.Fechar()
				UI.Enviar("Teoria_Respostas", { Id = p.Id, Respostas = respostas })
			end
		end, { Size = UDim2.fromOffset(170, 42), LayoutOrder = 2 })
		mostrar()
	end)
end

return TEORIA
