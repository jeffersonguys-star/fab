--[[
	FAB - Instrucao teorica e fisiologica (servidor)

	Teoria: provas de 7 questoes sorteadas de cada materia. As respostas ficam so no
	servidor. Aprovacao com 5 acertos (nota 7,1).
	Fisiologica: camara hipobarica (hipoxia) e centrifuga (tolerancia a G). A experiencia
	roda no cliente e o servidor confere a duracao antes de registrar.
]]

local RunService = game:GetService("RunService")

local INS = {}

local QUESTOES = {
	Aerodinamica = {
		{ "Em voo reto e nivelado, qual força equilibra o peso da aeronave?", { "Sustentação", "Tração", "Arrasto", "Empuxo lateral" } },
		{ "O ângulo entre a corda da asa e o vento relativo chama-se:", { "Ângulo de ataque", "Ângulo de incidência", "Ângulo de diedro", "Ângulo de enflechamento" } },
		{ "O estol acontece quando:", { "O ângulo de ataque ultrapassa o ângulo crítico", "A velocidade passa da VNE", "O motor perde potência", "Os flapes são recolhidos" } },
		{ "Ao baixar os flapes, a aeronave:", { "Ganha sustentação e arrasto, e a velocidade de estol diminui", "Perde sustentação e arrasto", "Fica mais rápida em cruzeiro", "Não sofre alteração aerodinâmica" } },
		{ "Em uma curva nivelada com 60 graus de inclinação, o fator de carga é:", { "2 G", "1 G", "1,5 G", "3 G" } },
		{ "O movimento em torno do eixo longitudinal (rolagem) é comandado pelos:", { "Ailerons", "Profundores", "Lemes", "Flapes" } },
		{ "O profundor controla o movimento de:", { "Arfagem", "Rolagem", "Guinada", "Derrapagem" } },
		{ "Com o aumento do fator de carga, a velocidade de estol:", { "Aumenta", "Diminui", "Não muda", "Cai a zero" } },
		{ "O arrasto induzido é maior quando a aeronave voa:", { "Devagar, com alto ângulo de ataque", "Rápido, com baixo ângulo de ataque", "Em descida com motor reduzido", "Sempre na mesma proporção" } },
		{ "O efeito solo, perto da pista, provoca:", { "Redução do arrasto induzido, e a aeronave tende a flutuar", "Aumento do arrasto induzido", "Estol imediato", "Perda total de sustentação" } },
	},
	Navegacao = {
		{ "O rumo 090 corresponde a qual direção?", { "Leste", "Norte", "Sul", "Oeste" } },
		{ "Uma milha náutica equivale a aproximadamente:", { "1.852 metros", "1.609 metros", "1.000 metros", "2.000 metros" } },
		{ "Um nó (kt) é uma unidade de:", { "Velocidade: milhas náuticas por hora", "Distância", "Altitude", "Pressão" } },
		{ "A diferença angular entre o norte verdadeiro e o norte magnético chama-se:", { "Declinação magnética", "Desvio da bússola", "Deriva", "Proa" } },
		{ "O rumo recíproco de 270 é:", { "090", "180", "360", "045" } },
		{ "A cabeceira de pista numerada 36 está alinhada com qual rumo magnético aproximado?", { "360 graus", "036 graus", "180 graus", "306 graus" } },
		{ "Sem vento, uma aeronave a 120 kt voa durante 30 minutos. Qual distância percorre?", { "60 NM", "120 NM", "30 NM", "240 NM" } },
		{ "O instrumento que indica a altitude a partir da pressão estática é o:", { "Altímetro", "Velocímetro", "Variômetro", "Horizonte artificial" } },
		{ "Com o ajuste QNH, o altímetro indica a altitude em relação ao:", { "Nível médio do mar", "Solo da pista", "Nível padrão 1013,2 hPa", "Topo das nuvens" } },
		{ "Vento de través durante a navegação provoca:", { "Deriva da trajetória", "Aumento da sustentação", "Estol", "Redução do consumo" } },
	},
	Meteorologia = {
		{ "Na atmosfera padrão, a temperatura ao nível do mar é:", { "15 °C", "0 °C", "20 °C", "25 °C" } },
		{ "A pressão padrão ao nível do mar é:", { "1013,25 hPa", "1000 hPa", "950 hPa", "1030 hPa" } },
		{ "Na atmosfera padrão, a temperatura cai aproximadamente:", { "2 °C a cada 1.000 pés", "10 °C a cada 1.000 pés", "1 °C a cada 100 pés", "Não muda com a altitude" } },
		{ "A nuvem associada a trovoadas, granizo e turbulência severa é o:", { "Cumulonimbus (CB)", "Cirrus (CI)", "Stratus (ST)", "Altostratus (AS)" } },
		{ "O METAR é:", { "O informe meteorológico regular de aeródromo", "A previsão de área para 24 horas", "Um aviso de cinzas vulcânicas", "O plano de voo" } },
		{ "O nevoeiro tende a se formar quando:", { "A temperatura se aproxima do ponto de orvalho", "O vento fica muito forte", "A pressão sobe rapidamente", "O ar está muito seco" } },
		{ "Com o aumento da altitude, a densidade do ar:", { "Diminui", "Aumenta", "Permanece constante", "Dobra a cada 1.000 pés" } },
		{ "Decolar com vento de proa:", { "Reduz a distância de decolagem", "Aumenta a distância de decolagem", "Não altera a corrida", "Impede a decolagem" } },
		{ "A esteira de turbulência é causada principalmente por:", { "Vórtices nas pontas das asas de aeronaves pesadas", "Gases do escapamento", "Ondas de montanha", "Chuva forte" } },
		{ "Dias quentes e aeródromos altos reduzem o desempenho porque:", { "A densidade do ar é menor", "A gravidade aumenta", "A pressão estática sobe", "O ar fica mais úmido" } },
	},
	Regulamentos = {
		{ "Salvo instrução em contrário, o circuito de tráfego padrão é feito com curvas:", { "À esquerda", "À direita", "Alternadas", "Livres" } },
		{ "A perna do circuito paralela à pista, no sentido oposto ao pouso, chama-se:", { "Perna do vento", "Perna base", "Reta final", "Perna de través" } },
		{ "O código de transponder para emergência geral é:", { "7700", "7600", "7500", "1200" } },
		{ "O código de transponder para falha de comunicação é:", { "7600", "7700", "7500", "2000" } },
		{ "Luz verde contínua da torre para uma aeronave em voo significa:", { "Autorizado pousar", "Regresse para pouso", "Aeródromo impraticável", "Dê passagem" } },
		{ "Duas aeronaves em rota de colisão de frente devem:", { "Desviar ambas para a direita", "Desviar ambas para a esquerda", "Subir as duas", "Manter o rumo" } },
		{ "A palavra MAYDAY indica:", { "Perigo grave e iminente, com pedido de socorro imediato", "Situação de urgência sem perigo imediato", "Pedido de informação meteorológica", "Fim de transmissão" } },
		{ "VFR significa:", { "Regras de voo visual", "Regras de voo por instrumentos", "Voo de formação regular", "Velocidade final de referência" } },
		{ "No alfabeto fonético, a letra F é:", { "Foxtrot", "Fox", "Frank", "Fanta" } },
		{ "Quem tem prioridade para pousar?", { "A aeronave em emergência", "A aeronave mais rápida", "A aeronave mais pesada", "A primeira que chamar a torre" } },
	},
}

local QUANTIDADE = 7
local ACERTOS_MINIMOS = 5

local function embaralhar(t)
	for i = #t, 2, -1 do
		local j = math.random(1, i)
		t[i], t[j] = t[j], t[i]
	end
	return t
end

function INS.Iniciar(N)
	local provas = {}

	-- Menu das materias (mesa do instrutor na sala de aula)
	N.Prompt(N.Placas.Teoria, "Instrução Teórica", "Fazer prova", function(plr)
		local itens = {}
		for _, id in ipairs({ "Aerodinamica", "Navegacao", "Meteorologia", "Regulamentos" }) do
			local def = N.Config.PorId[id]
			local ok = N.Requisitos(plr, id)
			table.insert(itens, { Id = id, Nome = def.Nome, Liberado = ok })
		end
		N.Abrir(plr, "Teoria_Menu", { Materias = itens })
	end, 12)

	N.RegistrarAcao("Teoria_Iniciar", function(plr, p)
		local id = p.Id
		if not QUESTOES[id] then return end
		if not N.Requisitos(plr, id) then N.MostrarBloqueio(plr, id) return end
		local banco = {}
		for i = 1, #QUESTOES[id] do table.insert(banco, i) end
		embaralhar(banco)
		local questoes, gabarito = {}, {}
		for i = 1, QUANTIDADE do
			local q = QUESTOES[id][banco[i]]
			local ordem = embaralhar({ 1, 2, 3, 4 })
			local opcoes = {}
			for k, o in ipairs(ordem) do
				opcoes[k] = q[2][o]
				if o == 1 then gabarito[i] = k end
			end
			questoes[i] = { Texto = q[1], Opcoes = opcoes }
		end
		provas[plr] = { Id = id, Gabarito = gabarito, Questoes = questoes, Inicio = os.clock() }
		N.IniciarSessao(plr, "Teoria_" .. id)
		N.Congelar(plr, true)
		N.Pose(plr, "Sentado")
		N.Abrir(plr, "Teoria_Prova", { Id = id, Nome = N.Config.PorId[id].Nome, Questoes = questoes })
	end)

	N.RegistrarAcao("Teoria_Respostas", function(plr, p)
		local prova = provas[plr]
		if not prova or prova.Id ~= p.Id or type(p.Respostas) ~= "table" then return end
		provas[plr] = nil
		N.EncerrarSessao(plr)
		N.Congelar(plr, false)
		N.Pose(plr, "")
		local acertos = 0
		local linhas = {}
		for i, certo in ipairs(prova.Gabarito) do
			if p.Respostas[i] == certo then
				acertos = acertos + 1
			else
				table.insert(linhas, "Questão " .. i .. ": a resposta correta era \"" .. prova.Questoes[i].Opcoes[certo] .. "\".")
			end
		end
		table.insert(linhas, 1, "Acertos: " .. acertos .. " de " .. QUANTIDADE .. " (mínimo para aprovação: " .. ACERTOS_MINIMOS .. ").")
		N.RegistrarResultado(plr, prova.Id, acertos / QUANTIDADE * 10, {
			Linhas = linhas, Aprovado = acertos >= ACERTOS_MINIMOS,
		})
	end)

	N.RegistrarAcao("Teoria_Cancelar", function(plr)
		if provas[plr] then
			provas[plr] = nil
			N.EncerrarSessao(plr)
			N.Congelar(plr, false)
			N.Pose(plr, "")
		end
	end)

	-- Fisiologica ----------------------------------------------------------
	local MINIMO = { Hipoxia = 35, Centrifuga = 45 }
	local naCentrifuga = {}

	local function iniciarFisio(plr, id, local_)
		if not N.Requisitos(plr, id) then N.MostrarBloqueio(plr, id) return end
		if N.Sessao(plr) then return end
		N.IniciarSessao(plr, id)
		N.Congelar(plr, true, N.Local(local_))
		N.Pose(plr, "Sentado")
		if id == "Centrifuga" then naCentrifuga[plr] = true end
		N.Abrir(plr, id .. "_Iniciar", {})
	end

	N.Prompt(N.Placas.Hipoxia, "Câmara Hipobárica", "Iniciar treinamento", function(plr) iniciarFisio(plr, "Hipoxia", "Hipoxia") end, 10)
	N.Prompt(N.Placas.Centrifuga, "Centrífuga", "Iniciar treinamento", function(plr) iniciarFisio(plr, "Centrifuga", "Centrifuga") end, 10)

	N.RegistrarAcao("Fisio_Resultado", function(plr, p)
		local s = N.Sessao(plr)
		if not s or (s.Id ~= "Hipoxia" and s.Id ~= "Centrifuga") then return end
		local id = s.Id
		local duracao = os.clock() - s.Inicio
		N.EncerrarSessao(plr)
		naCentrifuga[plr] = nil
		N.Congelar(plr, false)
		N.Pose(plr, "")
		if p.Cancelado then return end
		local linhas = {}
		if type(p.Linhas) == "table" then
			for i = 1, math.min(#p.Linhas, 10) do
				if type(p.Linhas[i]) == "string" then table.insert(linhas, string.sub(p.Linhas[i], 1, 200)) end
			end
		end
		local nota = tonumber(p.Nota) or 0
		if duracao < MINIMO[id] then
			nota = 0
			linhas = { "Treinamento interrompido antes do fim do perfil." }
		end
		N.RegistrarResultado(plr, id, nota, { Linhas = linhas, Aprovado = (p.Aprovado == true) and nota >= N.Config.NotaMinima })
	end)

	-- a centrifuga gira enquanto alguem estiver treinando
	local braco = N.BracoCentrifuga
	local angulo = 0
	local velocidade = 0
	RunService.Heartbeat:Connect(function(dt)
		if not braco or not braco.PrimaryPart then return end
		local alvo = next(naCentrifuga) and 3.2 or 0
		velocidade = velocidade + (alvo - velocidade) * math.min(1, dt * 0.4)
		if velocidade < 0.01 then return end
		angulo = angulo + velocidade * dt
		if not braco:GetAttribute("Base") then
			braco:SetAttribute("Base", braco.PrimaryPart.CFrame)
		end
		local base = braco:GetAttribute("Base")
		braco:PivotTo(base * CFrame.Angles(angulo, 0, 0))
	end)

	N.AoSair(function(plr)
		provas[plr] = nil
		naCentrifuga[plr] = nil
	end)
end

return INS
