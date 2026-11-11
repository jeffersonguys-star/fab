--[[
	FAB - Painel do instrutor (cliente)

	Cheques aguardando avaliacao, ficha de cada cadete (aprovar ou zerar atividades),
	comando da formatura e deslocamento rapido pelas instalacoes.
]]

local INSTR = {}

function INSTR.Iniciar(UI)
	local COR = UI.Cor
	local botao

	local function abrirCadete(j, locais)
		local m = UI.Modal({ Titulo = j.Nome, Sobretitulo = "Ficha do cadete · @" .. j.Usuario, Largura = 560, Altura = 620 })
		UI.Rotulo(m.Conteudo, string.format("Esquadrilha %s  ·  %d%% concluído  ·  %d min de simulador", tostring(j.Esquadrilha), j.Progresso, j.Horas), 13,
			{ TextColor3 = COR.Sub, LayoutOrder = 0 })
		for i, a in ipairs(j.Atividades) do
			local item = UI.Item(m.Conteudo, a.Nome, a.Aprovado and string.format("Nota %.1f · toque para zerar", a.Nota or 0) or "Toque para aprovar",
				a.Aprovado and "Aprovado" or "Pendente", nil, i)
			item.Activated:Connect(function()
				m.Fechar()
				UI.Enviar("Instr_Definir", { UserId = j.UserId, Id = a.Id, Aprovar = not a.Aprovado })
			end)
		end
		UI.Botao(m.Rodape, "Voltar", "secundario", function() m.Fechar() UI.Enviar("Instr_Lista") end, { Size = UDim2.fromOffset(130, 42) })
	end

	local function abrirCheque(j, c)
		local m = UI.Modal({ Titulo = c.Nome, Sobretitulo = "Cheque de " .. j.Nome, Largura = 540, Altura = 560 })
		UI.Rotulo(m.Conteudo, string.format("Nota automática: %.1f", c.Nota or 0), 18, { Font = Enum.Font.GothamBold, LayoutOrder = 0 })
		UI.Secao(m.Conteudo, "Observações do voo", 1)
		for i, l in ipairs(c.Detalhes or {}) do
			UI.Rotulo(m.Conteudo, "·  " .. l, 14, { LayoutOrder = 1 + i })
		end
		UI.Botao(m.Rodape, "Reprovar", "secundario", function()
			m.Fechar()
			UI.Enviar("Instr_Cheque", { UserId = j.UserId, Id = c.Id, Aprovar = false })
		end, { Size = UDim2.fromOffset(130, 42), LayoutOrder = 1 })
		UI.Botao(m.Rodape, "Aprovar", "primario", function()
			m.Fechar()
			UI.Enviar("Instr_Cheque", { UserId = j.UserId, Id = c.Id, Aprovar = true })
		end, { Size = UDim2.fromOffset(130, 42), LayoutOrder = 2 })
	end

	UI.Registrar("Instr_Lista", function(p)
		local m = UI.Modal({ Titulo = "Painel do Instrutor", Sobretitulo = "Corpo de Cadetes", Largura = 580, Altura = 640 })
		local ordem = 0
		local function prox() ordem = ordem + 1 return ordem end
		UI.Secao(m.Conteudo, "Cheques aguardando avaliação", prox())
		local algum = false
		for _, j in ipairs(p.Jogadores) do
			for _, c in ipairs(j.Pendentes) do
				algum = true
				UI.Item(m.Conteudo, c.Nome, j.Nome .. string.format(" · nota %.1f", c.Nota or 0), "Aguardando", function()
					m.Fechar()
					abrirCheque(j, c)
				end, prox())
			end
		end
		if not algum then UI.Rotulo(m.Conteudo, "Nenhum cheque pendente.", 13, { TextColor3 = COR.Sub, LayoutOrder = prox() }) end
		UI.Secao(m.Conteudo, "Formatura", prox())
		UI.Item(m.Conteudo, "Assumir o comando da tropa", "Vai para o palanque e abre os comandos de ordem unida", "Disponível", function()
			m.Fechar()
			UI.Enviar("OU_Assumir")
		end, prox())
		UI.Secao(m.Conteudo, "Cadetes", prox())
		for _, j in ipairs(p.Jogadores) do
			UI.Item(m.Conteudo, j.Nome, "Esquadrilha " .. tostring(j.Esquadrilha) .. " · " .. j.Progresso .. "%", nil, function()
				m.Fechar()
				abrirCadete(j, p.Locais)
			end, prox())
		end
		UI.Secao(m.Conteudo, "Ir para", prox())
		for _, l in ipairs(p.Locais or {}) do
			UI.Item(m.Conteudo, l.Nome, "Deslocamento rápido", nil, function()
				m.Fechar()
				UI.Enviar("Instr_Ir", { Local = l.Id })
			end, prox())
		end
		UI.Botao(m.Rodape, "Fechar", "secundario", function() m.Fechar() end, { Size = UDim2.fromOffset(130, 42) })
	end)

	UI.AoDados(function(d)
		if d.Instrutor and not botao and UI.BarraSuperior then
			botao = UI.Botao(UI.BarraSuperior, "INSTRUTOR", "primario", function() UI.Enviar("Instr_Lista") end,
				{ Size = UDim2.fromOffset(118, 36), TextSize = 12, LayoutOrder = 1 })
		end
	end)
end

return INSTR
