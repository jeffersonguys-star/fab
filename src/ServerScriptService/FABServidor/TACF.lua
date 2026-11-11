--[[
	FAB - TACF (Teste de Avaliacao do Condicionamento Fisico) - servidor

	Tres provas: corrida (4 voltas na pista, com controle de ritmo e folego),
	flexoes de braco e abdominais (60 segundos cada, com fadiga muscular).
	O servidor confere os pontos de passagem, o tempo e o ritmo dos movimentos.
	O TACF so e registrado quando as tres provas foram feitas.
]]

local RunService = game:GetService("RunService")

local TACF = {}

local VOLTAS = 4
local DURACAO_EXERCICIO = 60
local VEL_MAX = 27.5 -- studs/s (velocidade maxima permitida, com folga)

local TABELA = {
	Flexoes = { Zero = 8, Dez = 38, Nome = "Flexões de braço" },
	Abdominais = { Zero = 12, Dez = 45, Nome = "Abdominais" },
}

function TACF.Iniciar(N)
	local pontos = N.PontosCorrida
	local perimetro = 0
	for i = 1, #pontos do
		perimetro = perimetro + (pontos[i % #pontos + 1] - pontos[i]).Magnitude
	end
	local distTotal = perimetro * VOLTAS

	local function notaLinear(v, zero, dez)
		return math.clamp((v - zero) / (dez - zero) * 10, 0, 10)
	end

	-- Fecha o TACF quando as tres provas tiverem nota
	local function verificarConclusao(plr)
		local d = N.Dados[plr]
		if not d then return end
		local t = d.TACF
		if t.Corrida and t.Flexoes and t.Abdominais then
			local media = (t.Corrida + t.Flexoes + t.Abdominais) / 3
			local minimo = math.min(t.Corrida, t.Flexoes, t.Abdominais)
			N.RegistrarResultado(plr, "TACF", media, {
				Aprovado = media >= N.Config.NotaMinima and minimo >= 5,
				Linhas = {
					string.format("Corrida: %.1f", t.Corrida),
					string.format("Flexões de braço: %.1f", t.Flexoes),
					string.format("Abdominais: %.1f", t.Abdominais),
					"Para aprovação: média 7 e nenhuma prova abaixo de 5.",
				},
			})
			d.TACF = {}
			N.Sincronizar(plr)
		end
	end

	local function registrarProva(plr, prova, nota, titulo, linhas)
		local d = N.Dados[plr]
		if not d then return end
		nota = math.floor(nota * 10 + 0.5) / 10
		if not d.TACF[prova] or nota > d.TACF[prova] then d.TACF[prova] = nota end
		local faltam = {}
		if not d.TACF.Corrida then table.insert(faltam, "Corrida") end
		if not d.TACF.Flexoes then table.insert(faltam, "Flexões") end
		if not d.TACF.Abdominais then table.insert(faltam, "Abdominais") end
		if #faltam > 0 then table.insert(linhas, "Provas restantes do TACF: " .. table.concat(faltam, ", ")) end
		N.Abrir(plr, "Debriefing", { Titulo = titulo, Nota = nota, Aprovado = nota >= 5, Linhas = linhas, Parcial = true })
		N.Sincronizar(plr)
		task.delay(0.5, verificarConclusao, plr)
	end

	-- CORRIDA ---------------------------------------------------------------
	local corredores = {}

	N.Prompt(N.Placas.Corrida, "TACF", "Iniciar corrida", function(plr)
		if not N.Requisitos(plr, "TACF") then N.MostrarBloqueio(plr, "TACF") return end
		if corredores[plr] then return end
		local inicio = pontos[1]
		local cf = CFrame.lookAt(inicio + Vector3.new(0, 4, 0), pontos[2] + Vector3.new(0, 4, 0))
		N.Teleportar(plr, cf)
		N.IniciarSessao(plr, "TACF_Corrida")
		corredores[plr] = { Indice = 2, Voltas = 0, Inicio = nil, UltimaPos = inicio, Pronto = false }
		N.Abrir(plr, "TACF_Corrida", { Pontos = pontos, Voltas = VOLTAS, Distancia = distTotal })
	end, 12)

	N.RegistrarAcao("TACF_Largada", function(plr)
		local c = corredores[plr]
		if not c or c.Inicio then return end
		local _, hrp = N.Personagem(plr)
		if not hrp then return end
		if (hrp.Position - pontos[1]).Magnitude > 12 then
			N.Teleportar(plr, CFrame.lookAt(pontos[1] + Vector3.new(0, 4, 0), pontos[2] + Vector3.new(0, 4, 0)))
		end
		c.Inicio = os.clock()
		c.UltimaPos = pontos[1]
		c.UltimoTempo = os.clock()
	end)

	N.RegistrarAcao("TACF_Desistir", function(plr)
		corredores[plr] = nil
		N.EncerrarSessao(plr)
		N.Abrir(plr, "TACF_Fim", {})
	end)

	local acumulado = 0
	RunService.Heartbeat:Connect(function(dt)
		acumulado = acumulado + dt
		if acumulado < 0.1 then return end
		acumulado = 0
		for plr, c in pairs(corredores) do
			local _, hrp = N.Personagem(plr)
			if not hrp or not plr.Parent then
				corredores[plr] = nil
			elseif c.Inicio then
				local agora = os.clock()
				local pos = hrp.Position
				local desloc = (Vector3.new(pos.X, 0, pos.Z) - Vector3.new(c.UltimaPos.X, 0, c.UltimaPos.Z)).Magnitude
				local intervalo = agora - c.UltimoTempo
				if intervalo > 0 and desloc / intervalo > VEL_MAX * 1.35 and desloc > 6 then
					-- velocidade impossivel: prova anulada
					corredores[plr] = nil
					N.EncerrarSessao(plr)
					N.Abrir(plr, "TACF_Fim", {})
					N.Abrir(plr, "Debriefing", { Titulo = "TACF - Corrida", Nota = 0, Aprovado = false, Parcial = true,
						Linhas = { "Prova anulada: deslocamento acima da velocidade possível." } })
				else
					c.UltimaPos = pos
					c.UltimoTempo = agora
					local alvo = pontos[c.Indice]
					local plano = Vector3.new(pos.X - alvo.X, 0, pos.Z - alvo.Z)
					if plano.Magnitude < 9 then
						if c.Indice == 1 then
							c.Voltas = c.Voltas + 1
							N.Abrir(plr, "TACF_Volta", { Voltas = c.Voltas })
						end
						if c.Voltas >= VOLTAS then
							local tempo = agora - c.Inicio
							corredores[plr] = nil
							N.EncerrarSessao(plr)
							N.Abrir(plr, "TACF_Fim", {})
							local minimo = distTotal / VEL_MAX
							if tempo < minimo then
								N.Abrir(plr, "Debriefing", { Titulo = "TACF - Corrida", Nota = 0, Aprovado = false, Parcial = true,
									Linhas = { "Prova anulada: tempo menor que o possível." } })
							else
								-- 10 com ritmo excelente, 0 andando
								local velMedia = distTotal / tempo
								local nota = math.clamp((velMedia - 14) / (22.5 - 14) * 10, 0, 10)
								registrarProva(plr, "Corrida", nota, "TACF - Corrida", {
									string.format("Tempo: %d min %02d s", math.floor(tempo / 60), math.floor(tempo % 60)),
									string.format("Distância: %d voltas", VOLTAS),
									string.format("Ritmo médio: %.1f studs/s", velMedia),
								})
							end
						else
							c.Indice = c.Indice % #pontos + 1
						end
					end
				end
			end
		end
	end)

	-- FLEXOES E ABDOMINAIS ---------------------------------------------------
	local exercicios = {}

	local function iniciarExercicio(plr, prova)
		if exercicios[plr] then return end
		if not N.Requisitos(plr, "TACF") then N.MostrarBloqueio(plr, "TACF") return end
		local base = N.Local("Exercicios")
		local vaga = math.random(-2, 2)
		local cf = base * CFrame.new(vaga * 5, -1.2, 0)
		N.IniciarSessao(plr, "TACF_" .. prova)
		N.Congelar(plr, true, cf)
		local pose = prova == "Flexoes" and "FlexaoCima" or "AbdominalDeitado"
		N.Pose(plr, pose)
		exercicios[plr] = { Prova = prova, Reps = 0, Fase = "Cima", UltimoMov = 0, Inicio = nil, Invalidas = 0 }
		N.Abrir(plr, "TACF_Exercicio", { Prova = prova, Nome = TABELA[prova].Nome, Duracao = DURACAO_EXERCICIO })
	end

	N.Prompt(N.Placas.Exercicios, "TACF", "Flexões de braço", function(plr) iniciarExercicio(plr, "Flexoes") end, 14)
	local p2 = N.Prompt(N.Placas.Exercicios, "TACF", "Abdominais", function(plr) iniciarExercicio(plr, "Abdominais") end, 14)
	p2.UIOffset = Vector2.new(0, 80)
	p2.KeyboardKeyCode = Enum.KeyCode.R
	p2.GamepadKeyCode = Enum.KeyCode.ButtonY

	local function finalizarExercicio(plr)
		local e = exercicios[plr]
		if not e then return end
		exercicios[plr] = nil
		N.EncerrarSessao(plr)
		N.Congelar(plr, false)
		N.Pose(plr, "")
		N.Abrir(plr, "TACF_Fim", {})
		local tab = TABELA[e.Prova]
		local nota = notaLinear(e.Reps, tab.Zero, tab.Dez)
		registrarProva(plr, e.Prova, nota, "TACF - " .. tab.Nome, {
			"Repetições válidas: " .. e.Reps,
			"Repetições não contadas (movimento incompleto ou apressado): " .. e.Invalidas,
			"Nota 10 a partir de " .. tab.Dez .. " repetições.",
		})
	end

	N.RegistrarAcao("TACF_Mov", function(plr, p)
		local e = exercicios[plr]
		if not e then return end
		local agora = os.clock()
		if not e.Inicio then
			e.Inicio = agora
			task.delay(DURACAO_EXERCICIO, function()
				if exercicios[plr] == e then finalizarExercicio(plr) end
			end)
		end
		local mov = p.Mov
		if mov ~= "Baixo" and mov ~= "Cima" then return end
		if mov == e.Fase then return end
		-- tempo minimo de cada meio movimento cresce com a fadiga
		local minimo = 0.42 + 0.011 * e.Reps
		local valido = (agora - e.UltimoMov) >= minimo
		e.UltimoMov = agora
		e.Fase = mov
		local pose
		if e.Prova == "Flexoes" then pose = (mov == "Baixo") and "FlexaoBaixo" or "FlexaoCima"
		else pose = (mov == "Baixo") and "AbdominalDeitado" or "AbdominalSentado" end
		N.Pose(plr, pose)
		if mov == "Cima" then
			if valido and not e.MeioInvalido then
				e.Reps = e.Reps + 1
				N.Abrir(plr, "TACF_Rep", { Reps = e.Reps, Valida = true, Minimo = 0.42 + 0.011 * e.Reps })
			else
				e.Invalidas = e.Invalidas + 1
				N.Abrir(plr, "TACF_Rep", { Reps = e.Reps, Valida = false, Minimo = 0.42 + 0.011 * e.Reps })
			end
			e.MeioInvalido = false
		else
			e.MeioInvalido = not valido
		end
	end)

	N.RegistrarAcao("TACF_Parar", function(plr)
		local e = exercicios[plr]
		if e and e.Inicio then finalizarExercicio(plr)
		elseif e then
			exercicios[plr] = nil
			N.EncerrarSessao(plr)
			N.Congelar(plr, false)
			N.Pose(plr, "")
			N.Abrir(plr, "TACF_Fim", {})
		end
	end)

	N.AoSair(function(plr)
		corredores[plr] = nil
		exercicios[plr] = nil
	end)
end

return TACF
