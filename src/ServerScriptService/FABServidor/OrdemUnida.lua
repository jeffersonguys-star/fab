--[[
	FAB - Ordem Unida (servidor)

	O cadete entra em forma no patio. Um instrutor (pelo painel) ou o comando
	automatico da voz de comando em duas partes: a voz de advertencia ("Turma...")
	e a voz de execucao ("SENTIDO!"). O cadete deve executar o movimento so na voz de
	execucao, dentro do tempo. Antecipar, errar ou nao reagir conta como falta.
]]

local Players = game:GetService("Players")

local OU = {}

local COMANDOS = {
	Sentido = { Advertencia = "Turma...", Execucao = "SENTIDO!", Resposta = "Sentido", Requer = { Descansar = true, AVontade = true, Continencia = true } },
	Descansar = { Advertencia = "Turma...", Execucao = "DESCANSAR!", Resposta = "Descansar", Requer = { Sentido = true } },
	AVontade = { Advertencia = "Turma...", Execucao = "À VONTADE!", Resposta = "AVontade", Requer = { Descansar = true } },
	Continencia = { Advertencia = "Em continência à Bandeira...", Execucao = "CONTINÊNCIA!", Resposta = "Continencia", Requer = { Sentido = true } },
	DireitaVolver = { Advertencia = "Direita...", Execucao = "VOLVER!", Resposta = "Direita", Requer = { Sentido = true }, Giro = -90 },
	EsquerdaVolver = { Advertencia = "Esquerda...", Execucao = "VOLVER!", Resposta = "Esquerda", Requer = { Sentido = true }, Giro = 90 },
	MeiaVolta = { Advertencia = "Meia-volta...", Execucao = "VOLVER!", Resposta = "MeiaVolta", Requer = { Sentido = true }, Giro = 180 },
}
OU.Comandos = COMANDOS

local JANELA = 2.4 -- segundos para reagir depois da voz de execucao
local TOTAL_AUTO = 12

function OU.Iniciar(N)
	local formacao = {
		Cadetes = {},       -- [plr] = { Vaga, Acertos, Antecipou, SemReacao, Erros, Total, Tempos = {}, Postura, Rumo }
		Ativa = false,
		Instrutor = nil,
		Atual = nil,        -- comando em andamento
		Fase = nil,         -- "Advertencia" ou "Execucao"
		Postura = "Descansar",
		Executados = 0,
	}

	local function participantes()
		local lista = {}
		for plr in pairs(formacao.Cadetes) do table.insert(lista, plr) end
		if formacao.Instrutor and formacao.Instrutor.Parent then table.insert(lista, formacao.Instrutor) end
		return lista
	end

	local function avisar(nome, params)
		for _, plr in ipairs(participantes()) do N.Abrir(plr, nome, params) end
	end

	local function vagaLivre()
		local usadas = {}
		for _, c in pairs(formacao.Cadetes) do usadas[c.Vaga] = true end
		for i = 1, 45 do
			if not usadas[i] then return i end
		end
		return nil
	end

	local function cfVaga(vaga, giro)
		local fila = math.floor((vaga - 1) / 9)
		local col = ((vaga - 1) % 9) - 4
		local base = N.Local("FormaturaGrade")
		return CFrame.new(base.Position + Vector3.new(col * 4.5, 0, fila * 5)) * CFrame.Angles(0, math.rad(giro or 0), 0)
	end

	local function sair(plr, semNota)
		local c = formacao.Cadetes[plr]
		if not c then return end
		formacao.Cadetes[plr] = nil
		N.EncerrarSessao(plr)
		if plr.Parent then
			N.Congelar(plr, false)
			N.Pose(plr, "")
			N.Abrir(plr, "OU_Fim", {})
			if not semNota and c.Total >= 8 then
				local nota = c.Acertos / c.Total * 10
				local medio = 0
				for _, t in ipairs(c.Tempos) do medio = medio + t end
				if #c.Tempos > 0 then medio = medio / #c.Tempos end
				N.RegistrarResultado(plr, "OrdemUnida", nota, {
					Linhas = {
						"Comandos executados corretamente: " .. c.Acertos .. " de " .. c.Total,
						"Antecipações (movimento antes da voz de execução): " .. c.Antecipou,
						"Movimentos errados: " .. c.Erros,
						"Sem reação no tempo: " .. c.SemReacao,
						string.format("Tempo médio de reação: %.2f s", medio),
					},
				})
			end
		end
	end

	local function encerrar()
		local lista = {}
		for plr in pairs(formacao.Cadetes) do table.insert(lista, plr) end
		for _, plr in ipairs(lista) do sair(plr, false) end
		if formacao.Instrutor and formacao.Instrutor.Parent then N.Abrir(formacao.Instrutor, "OU_Fim", {}) end
		formacao.Ativa = false
		formacao.Instrutor = nil
		formacao.Atual = nil
		formacao.Fase = nil
		formacao.Postura = "Descansar"
		formacao.Executados = 0
	end

	-- Executa um comando completo (bloqueia ate terminar a janela de reacao)
	local function executar(id)
		local cmd = COMANDOS[id]
		if not cmd or formacao.Atual then return false end
		if not cmd.Requer[formacao.Postura] then return false end
		formacao.Atual = id
		formacao.Fase = "Advertencia"
		for _, c in pairs(formacao.Cadetes) do c.Respondeu = false; c.Antecipado = false end
		avisar("OU_Comando", { Fase = "Advertencia", Texto = cmd.Advertencia })
		task.wait(1.4 + math.random() * 1.4)
		formacao.Fase = "Execucao"
		formacao.InicioExecucao = os.clock()
		avisar("OU_Comando", { Fase = "Execucao", Texto = cmd.Execucao, Janela = JANELA })
		task.wait(JANELA)
		for plr, c in pairs(formacao.Cadetes) do
			c.Total = c.Total + 1
			if c.Antecipado then
				c.Antecipou = c.Antecipou + 1
			elseif not c.Respondeu then
				c.SemReacao = c.SemReacao + 1
			end
			-- a pose acompanha o comando para todos (mesmo quem errou), para nao travar a formacao
			c.Postura = cmd.Resposta
			if cmd.Giro then
				c.Rumo = (c.Rumo + cmd.Giro) % 360
				N.Congelar(plr, true, cfVaga(c.Vaga, c.Rumo))
				N.Pose(plr, "Sentido")
			else
				N.Pose(plr, cmd.Resposta)
			end
			N.Abrir(plr, "OU_Placar", { Acertos = c.Acertos, Total = c.Total })
		end
		if not cmd.Giro then formacao.Postura = cmd.Resposta end
		formacao.Atual = nil
		formacao.Fase = nil
		formacao.Executados = formacao.Executados + 1
		return true
	end

	-- Escolhe um comando valido para a postura atual
	local function proximoAutomatico()
		local validos = {}
		for id, cmd in pairs(COMANDOS) do
			if cmd.Requer[formacao.Postura] then table.insert(validos, id) end
		end
		-- os giros so valem se todos estiverem de frente para a bandeira no fim
		return validos[math.random(1, #validos)]
	end

	local function sessaoAutomatica()
		formacao.Ativa = true
		avisar("OU_Comando", { Fase = "Aviso", Texto = "Atenção, a formatura vai começar." })
		task.wait(6)
		local giroTotal = 0
		while formacao.Ativa and not formacao.Instrutor and next(formacao.Cadetes) and formacao.Executados < TOTAL_AUTO do
			local id
			local restantes = TOTAL_AUTO - formacao.Executados
			-- nos ultimos comandos, desfaz os giros para terminar de frente
			if restantes <= 3 and giroTotal % 360 ~= 0 and formacao.Postura == "Sentido" then
				if giroTotal % 360 == 180 then id = "MeiaVolta"
				elseif giroTotal % 360 == 90 then id = "DireitaVolver"
				else id = "EsquerdaVolver" end
			else
				id = proximoAutomatico()
			end
			if executar(id) then
				if COMANDOS[id].Giro then giroTotal = (giroTotal + COMANDOS[id].Giro) % 360 end
			end
			task.wait(1.2 + math.random() * 1.2)
		end
		if formacao.Ativa and not formacao.Instrutor then
			avisar("OU_Comando", { Fase = "Aviso", Texto = "Fora de forma... MARCHE!" })
			task.wait(2)
			encerrar()
		end
	end

	local function entrar(plr)
		if formacao.Cadetes[plr] then return end
		local vaga = vagaLivre()
		if not vaga then return end
		N.IniciarSessao(plr, "OrdemUnida")
		formacao.Cadetes[plr] = { Vaga = vaga, Acertos = 0, Antecipou = 0, SemReacao = 0, Erros = 0, Total = 0, Tempos = {}, Postura = formacao.Postura, Rumo = 0 }
		N.Congelar(plr, true, cfVaga(vaga, 0))
		N.Pose(plr, formacao.Postura)
		N.Abrir(plr, "OU_Entrar", { Modo = formacao.Instrutor and "Instrutor" or "Automatico" })
		if not formacao.Ativa then
			task.spawn(sessaoAutomatica)
		end
	end

	N.Prompt(N.Placas.OrdemUnida, "Ordem Unida", "Entrar em forma", function(plr)
		local ok = N.Requisitos(plr, "OrdemUnida")
		if not ok then N.MostrarBloqueio(plr, "OrdemUnida") return end
		entrar(plr)
	end, 14)

	-- Resposta do cadete
	N.RegistrarAcao("OU_Resposta", function(plr, p)
		local c = formacao.Cadetes[plr]
		if not c or not formacao.Atual or c.Respondeu or c.Antecipado then return end
		local cmd = COMANDOS[formacao.Atual]
		if formacao.Fase == "Advertencia" then
			c.Antecipado = true
			N.Abrir(plr, "OU_Retorno", { Texto = "Antecipou", Certo = false })
			return
		end
		local dt = os.clock() - (formacao.InicioExecucao or os.clock())
		if dt > JANELA then return end
		c.Respondeu = true
		if p.Resposta == cmd.Resposta then
			c.Acertos = c.Acertos + 1
			table.insert(c.Tempos, dt)
			N.Abrir(plr, "OU_Retorno", { Texto = "Correto", Certo = true })
		else
			c.Erros = c.Erros + 1
			N.Abrir(plr, "OU_Retorno", { Texto = "Movimento errado", Certo = false })
		end
	end)

	N.RegistrarAcao("OU_Sair", function(plr)
		sair(plr, true)
	end)

	-- Comandos do instrutor
	N.RegistrarAcao("OU_Assumir", function(plr)
		if not N.EhInstrutor(plr) then return end
		formacao.Instrutor = plr
		formacao.Ativa = true
		N.Teleportar(plr, N.Local("FormaturaInstrutor"))
		N.Abrir(plr, "OU_Painel", { Postura = formacao.Postura })
		avisar("OU_Comando", { Fase = "Aviso", Texto = "O instrutor " .. plr.DisplayName .. " assumiu o comando da tropa." })
	end)

	N.RegistrarAcao("OU_Comando", function(plr, p)
		if formacao.Instrutor ~= plr then return end
		if type(p.Id) ~= "string" then return end
		task.spawn(function()
			executar(p.Id)
			if formacao.Instrutor and formacao.Instrutor.Parent then
				N.Abrir(formacao.Instrutor, "OU_Painel", { Postura = formacao.Postura })
			end
		end)
	end)

	N.RegistrarAcao("OU_Encerrar", function(plr)
		if formacao.Instrutor ~= plr and not N.EhInstrutor(plr) then return end
		avisar("OU_Comando", { Fase = "Aviso", Texto = "Fora de forma... MARCHE!" })
		task.delay(2, encerrar)
	end)

	N.AoSair(function(plr)
		formacao.Cadetes[plr] = nil
		if formacao.Instrutor == plr then
			formacao.Instrutor = nil
			-- sem instrutor, o comando automatico assume
			if next(formacao.Cadetes) then task.spawn(sessaoAutomatica) end
		end
	end)

	Players.PlayerRemoving:Connect(function()
		if not next(formacao.Cadetes) then
			formacao.Ativa = false
		end
	end)
end

return OU
