--[[
	FAB - Licoes do simulador (cliente)

	Cada licao define: briefing, condicao inicial, objetivos e a avaliacao feita
	durante o voo. A nota e calculada aqui e conferida no servidor (tempo minimo).
	Unidades da fisica: metros, m/s e graus. Pista 18/36 no eixo Z, cabeceira 36 em
	z = +1500 m, cabeceira 18 em z = -1500 m. Elevacao do aerodromo: 5,6 m (18 ft).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MD = require(ReplicatedStorage:WaitForChild("FAB"):WaitForChild("MapaDados"))
local CEN = require(script.Parent:WaitForChild("SimCenario"))

local L = {}

local E = MD.StudPorMetro
local CAB = MD.Pista.MeioComp / E          -- 1500 m
local ELEV = MD.Plato / E                   -- 5,6 m
local MEIA_LARG = MD.Pista.MeiaLarg / E     -- 22,5 m

local function kt(v) return v * 1.943844 end
local function ft(m) return m * 3.28084 end
local function m(pes) return pes / 3.28084 end
local function ms(nos) return nos / 1.943844 end
local function difRumo(a, b) return ((a - b + 540) % 360) - 180 end
L.Kt, L.Ft = kt, ft

local function naPista(x, z)
	return math.abs(x) <= MEIA_LARG and math.abs(z) <= CAB
end

-- Avaliador de pouso na cabeceira 36 (comum a varias licoes)
local function novoPouso()
	return { Amostras = 0, Estavel = 0, Toque = nil, Parado = false, FimRolagem = nil }
end

local function avaliarPouso(ctx, s, dt, pz, VAprox)
	-- estabilidade da aproximacao entre 1.000 e 200 pes
	local agl = ft(s.AGL)
	if not pz.Toque and agl < 1000 and agl > 200 and s.pz > CAB then
		local dist = s.pz - (CAB - 300)
		local angulo = math.deg(math.atan2(s.py - ELEV, math.max(dist, 1)))
		pz.Amostras = pz.Amostras + dt
		if math.abs(angulo - 3) < 0.7 and math.abs(kt(s.IAS) - kt(VAprox)) < 8 then pz.Estavel = pz.Estavel + dt end
	end
	if s.Toque and not pz.Toque then
		pz.Toque = s.Toque
		ctx.Mensagem(string.format("Toque: %d pés por minuto", math.floor(s.Toque.Afundamento * 196.85)))
	end
	if pz.Toque and s.EmSolo and s.V < 1.5 then
		pz.Parado = true
	end
	if pz.Toque and not s.EmSolo and ctx.T - pz.Toque.Tempo > 0 and s.AGL > 3 and not pz.Arremeteu then
		pz.Quiques = (pz.Quiques or 0) + 1
		pz.Arremeteu = true
	end
	if s.EmSolo then pz.Arremeteu = false end
	return pz.Parado
end

local function notaPouso(s, pz)
	local nota, linhas = 0, {}
	local t = pz.Toque
	if not t then return 0, { "Não houve pouso." } end
	local fpm = t.Afundamento * 196.85
	if t.Afundamento <= 1.0 then nota = nota + 3 elseif t.Afundamento <= 1.8 then nota = nota + 2.5 elseif t.Afundamento <= 2.5 then nota = nota + 1.5 else nota = nota + 0.5 end
	table.insert(linhas, string.format("Razão de descida no toque: %d pés/min.", math.floor(fpm)))
	local desvio = math.abs(t.X)
	if desvio <= 5 then nota = nota + 2 elseif desvio <= 10 then nota = nota + 1.5 elseif desvio <= MEIA_LARG then nota = nota + 0.5 end
	table.insert(linhas, string.format("Desvio do eixo no toque: %.1f m.", desvio))
	local d = CAB - t.Z
	if d >= 150 and d <= 600 then nota = nota + 2
	elseif d >= 0 and d <= 900 then nota = nota + 1.2
	elseif d >= 0 then nota = nota + 0.3 end
	if d < 0 then
		table.insert(linhas, "Toque antes da cabeceira.")
	else
		table.insert(linhas, string.format("Toque a %d m da cabeceira (zona ideal: 150 a 600 m).", math.floor(d)))
	end
	if pz.Parado and naPista(s.px, s.pz) then
		nota = nota + 2
		table.insert(linhas, "Aeronave parada sobre a pista.")
	else
		table.insert(linhas, "A aeronave não parou sobre a pista.")
	end
	local est = pz.Amostras > 0 and pz.Estavel / pz.Amostras or 0
	nota = nota + est
	table.insert(linhas, string.format("Aproximação estabilizada (rampa e velocidade): %d%% do tempo.", math.floor(est * 100)))
	if (pz.Quiques or 0) > 0 then
		nota = nota - 1
		table.insert(linhas, "A aeronave quicou após o toque.")
	end
	return math.clamp(nota, 0, 10), linhas
end

local function inicioPista(P, extra)
	local t = { X = 0, Z = CAB - 25, Y = ELEV + P.AlturaTrem - 0.03, Rumo = 0, Velocidade = 0, Manete = 0, Trem = 1, Flap = 0 }
	if extra then for k, v in pairs(extra) do t[k] = v end end
	return t
end

local function inicioFinal(P, distanciaCab)
	local dist = distanciaCab + 300
	local altura = math.tan(math.rad(3)) * dist
	return { X = 0, Z = CAB + distanciaCab, Y = ELEV + altura + P.AlturaTrem, Rumo = 0, Velocidade = P.VAprox * 1.02,
		Manete = (P.Tipo == "jato") and 0.62 or 0.45, Trem = 1, Flap = 1 }
end

L.Definicoes = {}
local D = L.Definicoes

-- T-25 -----------------------------------------------------------------------------
D.T25_1 = {
	Descricao = "Antes de todo voo, o piloto faz o cheque de cabine e a partida do motor seguindo a lista de verificação.",
	Itens = {
		"Siga a lista na ordem, acionando os interruptores da cabine (toque ou clique neles). O próximo item fica destacado.",
		"Para a partida, a manete deve estar entre 10% e 35%.",
		"Mantenha o acionador de partida até o motor pegar.",
		"Fora da ordem conta como erro. Tempo de referência: 2 minutos.",
	},
	Inicio = function(P) return inicioPista(P, { MotorLigado = false }) end,
	MotorDesligado = true,
	Objetivos = { "Freio de estacionamento: APLICADO", "Bateria: LIGA", "Bomba de combustível: LIGA", "Mistura: RICA",
		"Manete: 1/4 aberta", "Magnetos: AMBOS", "Partida: ACIONAR", "Comandos: LIVRES (movimente o manche)", "Luzes de navegação: LIGA" },
	Limite = 300,
	Iniciar = function(ctx)
		ctx.Dados.Passo = 1
		ctx.Dados.Erros = 0
		ctx.Dados.Comandos = { 0, 0, 0, 0 }
		ctx.Destacar("FreioEst")
	end,
	Interruptor = function(ctx, id, valor)
		local ordem = { "FreioEst", "Bateria", "Bomba", "Mistura", "Manete", "Magnetos", "Partida", "Comandos", "Luzes" }
		local esperado = ordem[ctx.Dados.Passo]
		if id == esperado and valor then
			return true
		end
		ctx.Dados.Erros = ctx.Dados.Erros + 1
		ctx.Mensagem("Fora da sequência da lista de verificação")
		return false -- desfaz o acionamento
	end,
	Atualizar = function(ctx, s, dt, e)
		local d = ctx.Dados
		local ordem = { "FreioEst", "Bateria", "Bomba", "Mistura", "Manete", "Magnetos", "Partida", "Comandos", "Luzes" }
		local passo = d.Passo
		local id = ordem[passo]
		local feito = false
		if id == "Manete" then
			ctx.Destacar(nil)
			feito = e.Manete >= 0.1 and e.Manete <= 0.35
		elseif id == "Partida" then
			ctx.Destacar("Partida")
			feito = s.MotorLigado
		elseif id == "Comandos" then
			ctx.Destacar(nil)
			local c = d.Comandos
			c[1] = math.max(c[1], e.Arfagem)
			c[2] = math.min(c[2], e.Arfagem)
			c[3] = math.max(c[3], e.Rolagem)
			c[4] = math.min(c[4], e.Rolagem)
			feito = c[1] > 0.85 and c[2] < -0.85 and c[3] > 0.85 and c[4] < -0.85
		elseif id then
			ctx.Destacar(id)
			feito = ctx.Interruptores[id] == true
		end
		if feito then
			ctx.Marcar(passo, true)
			d.Passo = passo + 1
			if not ordem[d.Passo] then
				ctx.Destacar(nil)
				local nota = 10 - d.Erros * 0.8 - math.max(0, (ctx.T - 120) / 30)
				return ctx.Concluir(nota, nota >= 7, {
					string.format("Lista de verificação concluída em %d s.", math.floor(ctx.T)),
					"Itens fora da sequência: " .. d.Erros .. ".",
					"Motor acionado com a manete na posição correta.",
				})
			end
		end
	end,
}

D.T25_2 = {
	Descricao = "Decolagem da pista 36 com o T-25 Universal.",
	Itens = {
		"Solte os freios e aplique potência máxima de forma suave.",
		"Mantenha o eixo da pista com o leme (o torque da hélice puxa o nariz para a esquerda).",
		"Rode (puxe o manche) a partir de 58 kt e suba a cerca de 80 kt.",
		"Mantenha o rumo 360 e suba até 500 pés acima da pista.",
	},
	Inicio = function(P) return inicioPista(P) end,
	Objetivos = { "Corrida no eixo da pista", "Rotação na velocidade correta", "Subida a 80 kt", "Atingir 500 pés" },
	Limite = 240,
	Iniciar = function(ctx) ctx.Dados.DesvioMax = 0 ctx.Dados.Subida = 0 ctx.Dados.SubidaBoa = 0 end,
	Atualizar = function(ctx, s, dt)
		local d = ctx.Dados
		if s.EmSolo then
			d.DesvioMax = math.max(d.DesvioMax, math.abs(s.px))
		elseif not d.Decolou then
			d.Decolou = true
			d.VelRotacao = kt(s.IAS)
			ctx.Marcar(1, d.DesvioMax < 8)
			ctx.Marcar(2, d.VelRotacao >= 56)
		end
		if d.Decolou then
			d.Subida = d.Subida + dt
			if math.abs(kt(s.IAS) - 80) < 8 then d.SubidaBoa = d.SubidaBoa + dt end
			d.RumoMax = math.max(d.RumoMax or 0, math.abs(difRumo(s.Rumo, 0)))
			if ft(s.AGL) >= 500 then
				local boa = d.SubidaBoa / math.max(d.Subida, 1)
				ctx.Marcar(3, boa > 0.5)
				ctx.Marcar(4, true)
				local nota = 10
				local linhas = {}
				if d.DesvioMax > 8 then nota = nota - math.min(3, (d.DesvioMax - 8) / 4) end
				table.insert(linhas, string.format("Maior desvio do eixo na corrida: %.1f m.", d.DesvioMax))
				if d.VelRotacao < 56 then nota = nota - 2 end
				table.insert(linhas, string.format("Decolagem a %d kt.", math.floor(d.VelRotacao)))
				nota = nota - (1 - boa) * 2.5
				table.insert(linhas, string.format("Subida na velocidade correta: %d%% do tempo.", math.floor(boa * 100)))
				if d.RumoMax > 10 then nota = nota - 1 end
				table.insert(linhas, string.format("Maior desvio de rumo: %d graus.", math.floor(d.RumoMax)))
				return ctx.Concluir(nota, nota >= 7, linhas)
			end
		end
	end,
}

D.T25_3 = {
	Descricao = "Voo reto nivelado e curvas coordenadas a 2.000 pés.",
	Itens = {
		"Fase 1: mantenha 2.000 pés (±100) e rumo 360 (±10°) por 40 segundos. Use o compensador.",
		"Fase 2: curva de 360° pela esquerda com 30° de inclinação, mantendo a altitude.",
		"Fase 3: curva de 360° pela direita, também com 30°.",
		"Coordene com o leme: a bolinha do indicador de curva deve ficar no centro.",
	},
	Inicio = function(P) return { X = -600, Z = 1000, Y = m(2000), Rumo = 0, Velocidade = ms(110), Manete = 0.62, Trem = 1, Flap = 0, Arfagem = 1.5 } end,
	Objetivos = { "Voo nivelado por 40 s", "Curva de 360° à esquerda", "Curva de 360° à direita" },
	Limite = 360,
	Iniciar = function(ctx) ctx.Dados.Fase = 1 ctx.Dados.Bom = { 0, 0, 0 } ctx.Dados.Total = { 0, 0, 0 } ctx.Dados.Giro = 0 end,
	Atualizar = function(ctx, s, dt)
		local d = ctx.Dados
		local alt = ft(s.Altitude)
		local f = d.Fase
		if f == 1 then
			d.Total[1] = d.Total[1] + dt
			if math.abs(alt - 2000) < 100 and math.abs(difRumo(s.Rumo, 0)) < 10 then d.Bom[1] = d.Bom[1] + dt end
			if d.Total[1] >= 40 then
				ctx.Marcar(1, true)
				d.Fase = 2
				d.RumoAnt = s.Rumo
				ctx.Mensagem("Inicie a curva pela esquerda")
			end
		else
			local delta = difRumo(s.Rumo, d.RumoAnt)
			d.RumoAnt = s.Rumo
			d.Giro = d.Giro + delta
			local alvoInc = (f == 2) and -30 or 30
			d.Total[f] = d.Total[f] + dt
			if math.abs(alt - 2000) < 150 and math.abs(s.Inclinacao - alvoInc) < 10 and math.abs(s.BetaGraus or 0) < 4 then d.Bom[f] = d.Bom[f] + dt end
			if f == 2 and d.Giro <= -360 then
				ctx.Marcar(2, true)
				d.Fase = 3
				d.Giro = 0
				ctx.Mensagem("Nivele e inicie a curva pela direita")
			elseif f == 3 and d.Giro >= 360 then
				ctx.Marcar(3, true)
				local p = {}
				for i = 1, 3 do p[i] = d.Bom[i] / math.max(d.Total[i], 1) end
				local nota = (p[1] * 0.4 + p[2] * 0.3 + p[3] * 0.3) * 10 / 0.8
				return ctx.Concluir(nota, nota >= 7, {
					string.format("Voo nivelado dentro das tolerâncias: %d%%.", math.floor(p[1] * 100)),
					string.format("Curva à esquerda dentro das tolerâncias: %d%%.", math.floor(p[2] * 100)),
					string.format("Curva à direita dentro das tolerâncias: %d%%.", math.floor(p[3] * 100)),
				})
			end
		end
	end,
}

D.T25_4 = {
	Descricao = "Reconhecimento do estol e recuperação a 3.000 pés.",
	Itens = {
		"Reduza a manete para marcha lenta e levante o nariz aos poucos para manter a altitude.",
		"Observe o alerta de estol, a vibração e a queda do nariz.",
		"Recupere: baixe o nariz, aplique potência máxima e nivele as asas com aileron e leme.",
		"Perca o mínimo de altitude possível sem entrar em parafuso.",
	},
	Inicio = function(P) return { X = 600, Z = -500, Y = m(3000), Rumo = 0, Velocidade = ms(90), Manete = 0.45, Trem = 1, Flap = 0, Arfagem = 2 } end,
	Objetivos = { "Levar a aeronave ao estol", "Recuperar o voo nivelado", "Perder menos de 300 pés" },
	Limite = 240,
	Atualizar = function(ctx, s, dt)
		local d = ctx.Dados
		if not d.Estolou then
			if s.Estol then
				d.Estolou = true
				d.AltEstol = ft(s.Altitude)
				d.MinAlt = d.AltEstol
				ctx.Marcar(1, true)
				ctx.Mensagem("ESTOL! Recupere")
			end
			return
		end
		d.MinAlt = math.min(d.MinAlt, ft(s.Altitude))
		local guinada = math.abs(math.deg(s.wy or 0))
		if guinada > 40 and math.abs(s.Inclinacao) > 30 then d.Parafuso = (d.Parafuso or 0) + dt else d.Parafuso = 0 end
		if d.Parafuso and d.Parafuso > 3 then
			return ctx.Concluir(2, false, { "A aeronave entrou em parafuso.", "Na recuperação, centralize os comandos, leme contrário à rotação e manche à frente." })
		end
		local perda = d.AltEstol - d.MinAlt
		if perda > 1000 then
			return ctx.Concluir(2, false, { string.format("Perda de altitude excessiva: %d pés.", math.floor(perda)) })
		end
		if not s.Estol and s.VS > -1 and s.Arfagem > -5 and math.abs(s.Inclinacao) < 15 and kt(s.IAS) > 70 then
			d.Estavel = (d.Estavel or 0) + dt
			if d.Estavel > 3 then
				ctx.Marcar(2, true)
				ctx.Marcar(3, perda < 300)
				local nota = 10 - math.max(0, perda - 150) / 70
				return ctx.Concluir(nota, nota >= 7, {
					string.format("Altitude perdida na recuperação: %d pés.", math.floor(perda)),
					"Recuperação: nariz baixo, potência máxima, asas niveladas e subida suave.",
				})
			end
		else
			d.Estavel = 0
		end
	end,
}

D.T25_5 = {
	Descricao = "Aproximação final e pouso na pista 36, começando a 2,5 milhas náuticas.",
	Itens = {
		"Mantenha 70 kt com flape todo baixado.",
		"Use o PAPI: duas luzes brancas e duas vermelhas indicam a rampa correta de 3°.",
		"Toque entre 150 e 600 m depois da cabeceira, no eixo, com pouca razão de descida.",
		"Depois do toque, reduza a manete e freie até parar sobre a pista.",
	},
	Inicio = function(P) return inicioFinal(P, 4600) end,
	Objetivos = { "Aproximação estabilizada", "Toque suave na zona de toque", "Parar sobre a pista" },
	Limite = 300,
	Iniciar = function(ctx) ctx.Dados.Pouso = novoPouso() end,
	Atualizar = function(ctx, s, dt)
		local pz = ctx.Dados.Pouso
		if avaliarPouso(ctx, s, dt, pz, s.P.VAprox) then
			local nota, linhas = notaPouso(s, pz)
			ctx.Marcar(1, pz.Estavel / math.max(pz.Amostras, 1) > 0.5)
			ctx.Marcar(2, true)
			ctx.Marcar(3, true)
			return ctx.Concluir(nota, nota >= 7, linhas)
		end
	end,
}

D.T25_6 = {
	Descricao = "Pane de motor em voo: planeio e pouso forçado no aeródromo.",
	Itens = {
		"Você está na perna do vento, a 3.000 pés. Em alguns segundos o motor vai parar.",
		"Mantenha a velocidade de melhor planeio: 75 kt.",
		"Planeje o circuito para chegar alto e pousar na pista 36 (ou, se não der, no gramado ao lado).",
		"Sem motor não há segunda chance: priorize o controle da aeronave.",
	},
	Inicio = function(P) return { X = -900, Z = -400, Y = m(3000), Rumo = 180, Velocidade = ms(95), Manete = 0.55, Trem = 1, Flap = 0 } end,
	Objetivos = { "Manter a velocidade de planeio", "Pousar na pista ou ao lado dela", "Parar com segurança" },
	Limite = 420,
	Iniciar = function(ctx) ctx.Dados.Pouso = novoPouso() ctx.Dados.Planeio = 0 ctx.Dados.PlaneioBom = 0 end,
	Atualizar = function(ctx, s, dt)
		local d = ctx.Dados
		if ctx.T > 10 and not s.FalhaMotor then
			s.FalhaMotor = true
			ctx.Mensagem("PANE DE MOTOR")
		end
		if s.FalhaMotor and not s.EmSolo and s.AGL > 60 then
			d.Planeio = d.Planeio + dt
			if math.abs(kt(s.IAS) - 75) < 8 then d.PlaneioBom = d.PlaneioBom + dt end
		end
		if s.Toque and not d.Pouso.Toque then d.Pouso.Toque = s.Toque end
		if d.Pouso.Toque and s.EmSolo and s.V < 1.5 then
			local p = d.PlaneioBom / math.max(d.Planeio, 1)
			ctx.Marcar(1, p > 0.5)
			local nota = 3 + p * 3
			local linhas = { string.format("Velocidade de planeio mantida: %d%% do tempo.", math.floor(p * 100)) }
			if naPista(s.px, s.pz) then
				nota = nota + 4
				ctx.Marcar(2, true)
				table.insert(linhas, "Pouso na pista. Excelente gerenciamento de energia.")
			elseif math.abs(s.px) < 150 and math.abs(s.pz) < CAB + 200 then
				nota = nota + 2
				ctx.Marcar(2, true)
				table.insert(linhas, "Pouso no gramado ao lado da pista: aeronave preservada.")
			else
				table.insert(linhas, "Pouso fora da área do aeródromo.")
			end
			ctx.Marcar(3, true)
			return ctx.Concluir(nota, nota >= 7, linhas)
		end
	end,
}

D.T25_7 = {
	Cheque = true,
	Descricao = "Cheque do T-25: decolagem, circuito de tráfego pela esquerda e pouso na pista 36.",
	Itens = {
		"Decole da pista 36 e suba até 1.000 pés.",
		"Faça a curva pela esquerda (perna de través) e depois a perna do vento, voando no rumo 180 a 1.000 pés (±200).",
		"Na perna base e na final, curve pela esquerda e alinhe com a pista.",
		"Pouse na zona de toque e pare na pista. O resultado será avaliado por um instrutor.",
	},
	Inicio = function(P) return inicioPista(P) end,
	Objetivos = { "Decolagem", "Subida a 1.000 pés", "Perna do vento a 1.000 pés", "Pouso e parada" },
	Limite = 600,
	Iniciar = function(ctx) ctx.Dados.Pouso = novoPouso() ctx.Dados.Vento = 0 ctx.Dados.VentoBom = 0 end,
	Atualizar = function(ctx, s, dt)
		local d = ctx.Dados
		if not d.Decolou and not s.EmSolo and s.AGL > 15 then d.Decolou = true ctx.Marcar(1, true) end
		if d.Decolou and not d.Subiu and ft(s.AGL) > 900 then d.Subiu = true ctx.Marcar(2, true) end
		if d.Subiu and s.px < -300 and math.abs(difRumo(s.Rumo, 180)) < 25 then
			d.Vento = d.Vento + dt
			if math.abs(ft(s.AGL) - 1000) < 200 then d.VentoBom = d.VentoBom + dt end
			if d.Vento > 15 and not d.FezVento then d.FezVento = true ctx.Marcar(3, true) end
		end
		if d.FezVento then
			d.Pouso.Toque = d.Pouso.Toque -- mantem
			if avaliarPouso(ctx, s, dt, d.Pouso, s.P.VAprox) then
				local notaP, linhas = notaPouso(s, d.Pouso)
				local circuito = d.VentoBom / math.max(d.Vento, 1)
				local nota = notaP * 0.75 + (2 + circuito * 0.5) * 1
				table.insert(linhas, 1, string.format("Perna do vento dentro da altitude: %d%% do tempo.", math.floor(circuito * 100)))
				ctx.Marcar(4, true)
				return ctx.Concluir(nota, nota >= 7, linhas)
			end
		end
	end,
}

-- T-27 ------------------------------------------------------------------------------
D.T27_1 = {
	Descricao = "Looping no T-27 Tucano a 5.000 pés.",
	Itens = {
		"Comece com 230 kt, asas niveladas e potência máxima.",
		"Puxe com cerca de 4 G e mantenha as asas niveladas durante todo o looping.",
		"No topo (de dorso), alivie a pressão e deixe o nariz passar pelo horizonte.",
		"Saia no mesmo rumo e na mesma altitude de entrada. Não ultrapasse 6 G.",
	},
	Inicio = function(P) return { X = -1500, Z = 1500, Y = m(5000), Rumo = 0, Velocidade = ms(230), Manete = 1, Trem = 0, Flap = 0, Arfagem = 1 } end,
	Objetivos = { "Subida vertical", "Passagem de dorso no topo", "Saída nivelada no rumo inicial" },
	Limite = 180,
	Iniciar = function(ctx) ctx.Dados.Fase = 0 end,
	Atualizar = function(ctx, s, dt)
		local d = ctx.Dados
		d.GMax = math.max(d.GMax or 1, s.Nz)
		if d.Fase == 0 then
			if not d.Alt0 then d.Alt0 = ft(s.Altitude) d.Rumo0 = s.Rumo end
			if s.Arfagem > 60 then d.Fase = 1 ctx.Marcar(1, true) end
		elseif d.Fase == 1 then
			if math.abs(s.Inclinacao) > 150 then d.Fase = 2 ctx.Marcar(2, true) end
		elseif d.Fase == 2 then
			if s.Arfagem < -40 then d.Fase = 3 end
		elseif d.Fase == 3 then
			if s.Arfagem > -5 and math.abs(s.Inclinacao) < 30 then
				ctx.Marcar(3, true)
				local erroRumo = math.abs(difRumo(s.Rumo, d.Rumo0))
				local erroAlt = math.abs(ft(s.Altitude) - d.Alt0)
				local nota = 10 - math.max(0, erroRumo - 5) / 4 - math.max(0, erroAlt - 150) / 150 - math.abs(s.Inclinacao) / 10
				if d.GMax > 6 then nota = nota - 2 end
				return ctx.Concluir(nota, nota >= 7, {
					string.format("Desvio de rumo na saída: %d graus.", math.floor(erroRumo)),
					string.format("Diferença de altitude: %d pés.", math.floor(erroAlt)),
					string.format("G máximo: %.1f.", d.GMax),
				})
			end
		end
		if s.Altitude < m(1500) then
			return ctx.Concluir(2, false, { "Altitude mínima de segurança (1.500 pés) ultrapassada." })
		end
	end,
}

D.T27_2 = {
	Descricao = "Tonneau (rolagem de 360°) no T-27 a 5.000 pés.",
	Itens = {
		"Comece nivelado a cerca de 200 kt e levante o nariz uns 10° acima do horizonte.",
		"Aplique aileron total para um lado e mantenha até completar a volta.",
		"Termine com as asas niveladas, no mesmo rumo, sem perder muita altitude.",
	},
	Inicio = function(P) return { X = 1500, Z = 1500, Y = m(5000), Rumo = 0, Velocidade = ms(200), Manete = 0.85, Trem = 0, Flap = 0, Arfagem = 2 } end,
	Objetivos = { "Rolagem completa de 360°", "Saída nivelada no rumo" },
	Limite = 120,
	Iniciar = function(ctx) ctx.Dados.Acumulado = 0 end,
	Atualizar = function(ctx, s, dt)
		local d = ctx.Dados
		local p = math.deg(-(s.wz or 0))
		if not d.Inicio and math.abs(p) > 30 then
			d.Inicio = ctx.T
			d.Rumo0 = s.Rumo
			d.Alt0 = ft(s.Altitude)
		end
		if d.Inicio then
			d.Acumulado = d.Acumulado + p * dt
			if math.abs(d.Acumulado) >= 345 then ctx.Marcar(1, true) d.Completo = true end
			if d.Completo and math.abs(s.Inclinacao) < 12 then
				ctx.Marcar(2, true)
				local tempo = ctx.T - d.Inicio
				local erroRumo = math.abs(difRumo(s.Rumo, d.Rumo0))
				local perda = d.Alt0 - ft(s.Altitude)
				local nota = 10 - math.max(0, erroRumo - 8) / 3 - math.max(0, perda - 100) / 60 - math.max(0, tempo - 5)
				return ctx.Concluir(nota, nota >= 7, {
					string.format("Rolagem completa em %.1f s.", tempo),
					string.format("Desvio de rumo: %d graus.", math.floor(erroRumo)),
					string.format("Altitude perdida: %d pés.", math.floor(math.max(perda, 0))),
				})
			end
			if ctx.T - d.Inicio > 15 then return ctx.Concluir(3, false, { "A rolagem não foi completada." }) end
		end
	end,
}

local function navegacao(pontos, altMin, altMax, agl)
	return function(ctx, s, dt)
		local d = ctx.Dados
		d.Indice = d.Indice or 1
		local wp = pontos[d.Indice]
		local alvoM = Vector3.new(wp[1] / E, 0, wp[2] / E)
		local dx, dz = alvoM.X - s.px, alvoM.Z - s.pz
		local dist = math.sqrt(dx * dx + dz * dz)
		local rumoAlvo = math.deg(math.atan2(dx, -dz)) % 360
		ctx.Navegacao(string.format("PONTO %d   %03d°   %.1f km", d.Indice, math.floor(rumoAlvo + 0.5), dist / 1000), Vector3.new(wp[1], MD.Plato + 400, wp[2]))
		local alt = agl and ft(s.AGL) or ft(s.Altitude)
		d.Total = (d.Total or 0) + dt
		if alt >= altMin and alt <= altMax then d.Dentro = (d.Dentro or 0) + dt end
		if agl and ft(s.AGL) < 60 and not s.EmSolo then d.MuitoBaixo = true end
		if dist < 300 then
			ctx.Marcar(d.Indice, true)
			ctx.Mensagem("Ponto " .. d.Indice .. " sobrevoado")
			d.Indice = d.Indice + 1
			if not pontos[d.Indice] then
				local p = d.Dentro / math.max(d.Total, 1)
				local nota = 4 + p * 6 - (d.MuitoBaixo and 2 or 0)
				return ctx.Concluir(nota, nota >= 7, {
					string.format("Todos os %d pontos sobrevoados em %d min %02d s.", #pontos, math.floor(ctx.T / 60), math.floor(ctx.T % 60)),
					string.format("Tempo dentro da faixa de altitude (%d a %d pés%s): %d%%.", altMin, altMax, agl and " acima do solo" or "", math.floor(p * 100)),
					d.MuitoBaixo and "Você voou abaixo de 60 pés do solo: risco de colisão." or "Altura de segurança respeitada.",
				})
			end
		end
	end
end

D.T27_3 = {
	Descricao = "Navegação visual por três pontos da ilha.",
	Itens = {
		"Ponto 1: o farol na ponta norte da ilha.",
		"Ponto 2: o topo da serra a oeste.",
		"Ponto 3: o través do aeródromo.",
		"Voe entre 1.500 e 3.500 pés. A seta e a distância de cada ponto aparecem na tela.",
	},
	Inicio = function(P) return { X = 0, Z = 1200, Y = m(2000), Rumo = 0, Velocidade = ms(200), Manete = 0.7, Trem = 0, Flap = 0 } end,
	Objetivos = { "Ponto 1: farol", "Ponto 2: serra oeste", "Ponto 3: aeródromo" },
	Limite = 720,
	Atualizar = navegacao({ { 700, -9500 }, { -4300, -3600 }, { 900, 0 } }, 1500, 3500, false),
}

-- A-29 --------------------------------------------------------------------------------
D.A29_1 = {
	Descricao = "Voo em formação como ala do líder, em posição de escalão à direita.",
	Itens = {
		"Junte-se ao líder (a aeronave à sua frente) em até 40 segundos.",
		"Posição de ala: à direita e um pouco atrás do líder, na mesma altura (entre 10 e 35 m de afastamento).",
		"O líder vai fazer curvas suaves e uma subida. Acompanhe com manete e pequenas correções.",
		"Nunca perca o líder de vista. Muito perto é perigoso.",
	},
	Inicio = function(P) return { X = 60, Z = 300, Y = m(3000), Rumo = 0, Velocidade = ms(225), Manete = 0.7, Trem = 0, Flap = 0 } end,
	Objetivos = { "Juntar-se ao líder", "Manter a posição de ala" },
	Limite = 240,
	Iniciar = function(ctx)
		local d = ctx.Dados
		d.Lider = CEN.NovoVoo(0, m(3000), 0, 0, ms(215))
		d.Modelo = ctx.Cen.Aeronave("A29", Color3.fromRGB(95, 104, 92))
		d.Dentro = 0
		d.Total = 0
	end,
	Atualizar = function(ctx, s, dt)
		local d = ctx.Dados
		local t = ctx.T
		local inc, vs = 0, 0
		if t > 25 and t < 45 then inc = -30 elseif t > 60 and t < 80 then inc = 30 end
		if t > 95 and t < 110 then vs = 4 end
		CEN.Voar(d.Lider, dt, inc, vs, ms(215))
		local cfL = CEN.CFrameVoo(d.Lider)
		d.Modelo:PivotTo(cfL)
		-- posicao relativa no referencial do lider (metros)
		local rel = cfL:PointToObjectSpace(Vector3.new(s.px * E, s.py * E, s.pz * E)) / E
		local direita, atras, cima = rel.X, rel.Z, rel.Y
		if direita < 2 and math.abs(atras) < 12 and math.abs(cima) < 4 then
			return ctx.Concluir(0, false, { "Colisão em voo com o líder." })
		end
		local naPosicao = direita >= 10 and direita <= 35 and atras >= 6 and atras <= 35 and math.abs(cima) <= 8
		if naPosicao and not d.Juntou then d.Juntou = true ctx.Marcar(1, true) ctx.Mensagem("Na posição") end
		if t > 40 then
			d.Total = d.Total + dt
			if naPosicao then d.Dentro = d.Dentro + dt end
		end
		ctx.Estado(naPosicao and "NA POSIÇÃO" or string.format("DIR %d  TRÁS %d  ALT %+d", math.floor(direita), math.floor(atras), math.floor(cima)))
		if t > 125 then
			local p = d.Dentro / math.max(d.Total, 1)
			ctx.Marcar(2, p > 0.6)
			local nota = math.clamp(p / 0.7 * 10, 0, 10)
			return ctx.Concluir(nota, nota >= 7, {
				string.format("Tempo na posição de ala: %d%%.", math.floor(p * 100)),
				d.Juntou and "Junção ao líder realizada." or "Você não chegou a se juntar ao líder.",
			})
		end
	end,
}

D.A29_2 = {
	Descricao = "Navegação a baixa altura sobre a ilha, entre 100 e 500 pés do solo.",
	Itens = {
		"Siga os três pontos marcados, voando entre 100 e 500 pés acima do terreno.",
		"O altímetro radar (R) no HUD mostra a altura sobre o solo.",
		"Cuidado com as serras do lado oeste e com a torre de controle.",
	},
	Inicio = function(P) return { X = 6000 / E, Z = -2000 / E, Y = ELEV + 90, Rumo = 200, Velocidade = ms(240), Manete = 0.75, Trem = 0, Flap = 0 } end,
	Objetivos = { "Ponto 1: sudeste da ilha", "Ponto 2: serra sudoeste", "Ponto 3: costa oeste" },
	Limite = 600,
	Atualizar = navegacao({ { 3000, 6000 }, { -3000, 7000 }, { -5000, 0 } }, 100, 500, true),
}

-- F-5EM ------------------------------------------------------------------------------
D.F5_1 = {
	Descricao = "Decolagem do F-5EM com pós-combustor e subida até 10.000 pés.",
	Itens = {
		"Manete à frente até o pós-combustor (botão F ou topo da manete).",
		"Rode a 150 kt e mantenha cerca de 10° de arfagem.",
		"Recolha o trem antes de 260 kt (limite estrutural do trem).",
		"Suba até 10.000 pés mantendo o rumo 360.",
	},
	Inicio = function(P) return inicioPista(P, { Manete = 0.3 }) end,
	Objetivos = { "Decolagem com pós-combustor", "Trem recolhido no limite", "Atingir 10.000 pés" },
	Limite = 300,
	Atualizar = function(ctx, s, dt)
		local d = ctx.Dados
		if not d.Decolou and not s.EmSolo and s.AGL > 10 then
			d.Decolou = true
			d.VelRot = kt(s.IAS)
			ctx.Marcar(1, (s.PosCombustor or 0) > 0.5)
			d.ComPos = (s.PosCombustor or 0) > 0.5
		end
		if d.Decolou and not d.TremOk and s.Trem < 0.02 then d.TremOk = true ctx.Marcar(2, true) end
		if s.Trem > 0.02 and kt(s.IAS) > 260 and not d.Excesso then d.Excesso = true ctx.Mensagem("Velocidade limite do trem ultrapassada!") end
		if d.Decolou then d.RumoMax = math.max(d.RumoMax or 0, math.abs(difRumo(s.Rumo, 0))) end
		if ft(s.Altitude) >= 10000 then
			ctx.Marcar(3, true)
			local nota = 10
			if not d.ComPos then nota = nota - 2 end
			if d.Excesso then nota = nota - 3 end
			if not d.TremOk then nota = nota - 3 end
			if math.abs(d.VelRot - 150) > 15 then nota = nota - 1 end
			if d.RumoMax > 15 then nota = nota - 1 end
			return ctx.Concluir(nota, nota >= 7, {
				string.format("Decolagem a %d kt%s.", math.floor(d.VelRot), d.ComPos and " com pós-combustor" or " sem pós-combustor"),
				d.Excesso and "O trem ficou embaixo acima de 260 kt." or "Trem recolhido dentro do limite.",
				string.format("Tempo até 10.000 pés: %d s.", math.floor(ctx.T)),
			})
		end
	end,
}

D.F5_2 = {
	Descricao = "Voo supersônico a 30.000 pés.",
	Itens = {
		"Comece em Mach 0,85. Acelere com o pós-combustor mantendo entre 28.000 e 38.000 pés.",
		"Na região transônica (Mach 0,95 a 1,05) o avião vibra e o comando de arfagem fica mais pesado.",
		"Atinja Mach 1,10 em até 2 minutos e meio.",
	},
	Inicio = function(P) return { X = 0, Z = 3000, Y = 9144, Rumo = 0, Velocidade = 258, Manete = 1, Trem = 0, Flap = 0, Arfagem = 1 } end,
	Objetivos = { "Passar Mach 1", "Atingir Mach 1,10", "Manter a faixa de altitude" },
	Limite = 200,
	Atualizar = function(ctx, s, dt)
		local d = ctx.Dados
		local alt = ft(s.Altitude)
		d.Total = (d.Total or 0) + dt
		if alt >= 28000 and alt <= 38000 then d.Dentro = (d.Dentro or 0) + dt end
		if s.Mach >= 1 and not d.M1 then d.M1 = ctx.T ctx.Marcar(1, true) ctx.Mensagem("Supersônico") end
		if s.Mach >= 1.1 then
			ctx.Marcar(2, true)
			local p = (d.Dentro or 0) / d.Total
			ctx.Marcar(3, p > 0.8)
			local nota = 10 - math.max(0, ctx.T - 90) / 15 - (1 - p) * 5
			return ctx.Concluir(nota, nota >= 7, {
				string.format("Mach 1,10 atingido em %d s.", math.floor(ctx.T)),
				string.format("Tempo dentro da faixa de altitude: %d%%.", math.floor(p * 100)),
			})
		end
		if ctx.T > 150 then return ctx.Concluir(3, false, { "Mach 1,10 não foi atingido no tempo." }) end
	end,
}

local function posicaoAtaque(s, alvo)
	-- alcance, angulo do alvo em relacao ao nariz e angulo em relacao a cauda do alvo
	local pAlvo = Vector3.new(alvo.X, alvo.Y, alvo.Z)
	local pEu = Vector3.new(s.px, s.py, s.pz)
	local rel = pAlvo - pEu
	local alcance = rel.Magnitude
	local nariz = Vector3.new(-s.cx, -s.cy, -s.cz)
	local angNariz = math.deg(math.acos(math.clamp(nariz:Dot(rel.Unit), -1, 1)))
	local r = math.rad(alvo.Rumo)
	local caudaAlvo = Vector3.new(-math.sin(r), 0, math.cos(r))
	local angCauda = math.deg(math.acos(math.clamp(caudaAlvo:Dot((-rel).Unit), -1, 1)))
	return alcance, angNariz, angCauda, pAlvo
end

D.F5_3 = {
	Descricao = "Interceptação de um alvo não identificado a 18.000 pés.",
	Itens = {
		"O alvo está a noroeste, mais alto. O designador (quadrado) e a distância aparecem no HUD.",
		"Aproxime-se pelo setor traseiro do alvo (cauda), a menos de 1.500 m.",
		"Mantenha a posição de identificação por 8 segundos.",
	},
	Inicio = function(P) return { X = 0, Z = 3000, Y = m(15000), Rumo = 0, Velocidade = ms(350), Manete = 0.9, Trem = 0, Flap = 0 } end,
	Objetivos = { "Localizar o alvo", "Posição traseira a menos de 1.500 m", "Identificação (8 s)" },
	Limite = 300,
	Iniciar = function(ctx)
		local d = ctx.Dados
		d.Alvo = CEN.NovoVoo(-3000, m(18000), -6000, 90, ms(300))
		d.Modelo = ctx.Cen.Aeronave("Alvo", Color3.fromRGB(230, 230, 230))
		d.Ident = 0
	end,
	Atualizar = function(ctx, s, dt)
		local d = ctx.Dados
		local inc = math.sin(ctx.T / 20) * 20
		CEN.Voar(d.Alvo, dt, inc, 0, ms(300))
		d.Modelo:PivotTo(CEN.CFrameVoo(d.Alvo))
		local alcance, angNariz, angCauda, pAlvo = posicaoAtaque(s, d.Alvo)
		ctx.Alvo(pAlvo * E, string.format("%.1f km", alcance / 1000))
		if angNariz < 20 and not d.Visto then d.Visto = true ctx.Marcar(1, true) end
		if alcance < 300 then return ctx.Concluir(2, false, { "Aproximação perigosa: menos de 300 m do alvo." }) end
		local bom = alcance < 1500 and angCauda < 45 and math.abs(pAlvo.Y - s.py) < 300
		if bom then
			if not d.Atras then d.Atras = true ctx.Marcar(2, true) end
			d.Ident = d.Ident + dt
		else
			d.Ident = 0
		end
		ctx.Estado(bom and string.format("IDENTIFICANDO %d s", math.floor(d.Ident)) or "")
		if d.Ident >= 8 then
			ctx.Marcar(3, true)
			local nota = 10 - math.max(0, ctx.T - 120) / 30
			return ctx.Concluir(nota, nota >= 7, { string.format("Interceptação concluída em %d min %02d s.", math.floor(ctx.T / 60), math.floor(ctx.T % 60)) })
		end
	end,
}

-- F-39E -------------------------------------------------------------------------------
D.F39_1 = {
	Descricao = "Curva de alto G no F-39E Gripen.",
	Itens = {
		"O fly-by-wire limita a aeronave a 9 G: puxe o manche todo atrás em uma curva inclinada.",
		"Faça a manobra anti-G (ANTI-G segurado) e respire a cada 3 segundos (RESPIRAR).",
		"Acumule 15 segundos acima de 6,5 G sem perder a consciência, entre 5.000 e 15.000 pés.",
	},
	Inicio = function(P) return { X = 0, Z = 0, Y = m(10000), Rumo = 0, Velocidade = ms(420), Manete = 1, Trem = 0, Flap = 0 } end,
	Objetivos = { "15 s acima de 6,5 G", "Sem perda de consciência", "Entre 5.000 e 15.000 pés" },
	Limite = 180,
	Iniciar = function(ctx) ctx.Dados.TempoG = 0 end,
	Atualizar = function(ctx, s, dt)
		local d = ctx.Dados
		if s.Nz >= 6.5 then d.TempoG = d.TempoG + dt end
		ctx.Estado(string.format("ALTO G %.1f s", d.TempoG))
		local alt = ft(s.Altitude)
		if alt < 5000 or alt > 15000 then d.ForaAlt = true end
		if ctx.GLOC then d.Perdeu = true end
		if d.Perdeu and not d.Avisou then d.Avisou = true ctx.Mensagem("G-LOC: perda de consciência") end
		if d.TempoG >= 15 then
			ctx.Marcar(1, true)
			ctx.Marcar(2, not d.Perdeu)
			ctx.Marcar(3, not d.ForaAlt)
			local nota = 10 - (d.Perdeu and 6 or 0) - (d.ForaAlt and 2 or 0)
			return ctx.Concluir(nota, nota >= 7, {
				"15 segundos acima de 6,5 G concluídos.",
				d.Perdeu and "Houve perda de consciência (G-LOC). A manobra anti-G precisa ser contínua." or "Manobra anti-G eficiente: sem perda de consciência.",
				d.ForaAlt and "A faixa de altitude não foi respeitada." or "Faixa de altitude respeitada.",
			})
		end
		if alt < 2000 then return ctx.Concluir(1, false, { "Altitude mínima de segurança ultrapassada." }) end
	end,
}

D.F39_2 = {
	Descricao = "Combate aéreo básico (BFM): manobra contra um adversário.",
	Itens = {
		"O adversário está à sua frente e vai manobrar para fugir.",
		"Fique atrás dele, entre 300 e 1.200 m, com o alvo a menos de 10° do nariz (solução de tiro).",
		"Acumule 20 segundos de solução de tiro em até 2 minutos e meio.",
		"Use a manobra anti-G nas curvas fechadas.",
	},
	Inicio = function(P) return { X = 0, Z = 1500, Y = 4000, Rumo = 0, Velocidade = 210, Manete = 0.9, Trem = 0, Flap = 0 } end,
	Objetivos = { "Manter o adversário à frente", "20 s de solução de tiro" },
	Limite = 200,
	Iniciar = function(ctx)
		local d = ctx.Dados
		d.Alvo = CEN.NovoVoo(0, 4000, 0, 0, 200)
		d.Modelo = ctx.Cen.Aeronave("F5", Color3.fromRGB(120, 128, 134))
		d.Tiro = 0
		d.ProxManobra = 4
		d.Inc = 0
	end,
	Atualizar = function(ctx, s, dt)
		local d = ctx.Dados
		if ctx.T > d.ProxManobra then
			d.ProxManobra = ctx.T + 6 + math.random() * 5
			d.Inc = (math.random() < 0.5 and -1 or 1) * (40 + math.random() * 30)
			d.VS = (math.random() - 0.5) * 30
		end
		CEN.Voar(d.Alvo, dt, d.Inc, d.VS or 0, 200)
		if d.Alvo.Y < 2000 then d.VS = 15 end
		d.Modelo:PivotTo(CEN.CFrameVoo(d.Alvo))
		local alcance, angNariz, angCauda, pAlvo = posicaoAtaque(s, d.Alvo)
		ctx.Alvo(pAlvo * E, string.format("%d m", math.floor(alcance)))
		if alcance < 150 then return ctx.Concluir(2, false, { "Aproximação perigosa: risco de colisão." }) end
		local tiro = alcance >= 300 and alcance <= 1200 and angNariz < 10 and angCauda < 60
		if tiro then d.Tiro = d.Tiro + dt end
		if angNariz < 30 then ctx.Marcar(1, true) end
		ctx.Estado(tiro and string.format("SOLUÇÃO DE TIRO %d s", math.floor(d.Tiro)) or "")
		if d.Tiro >= 20 then
			ctx.Marcar(2, true)
			local nota = 10 - math.max(0, ctx.T - 90) / 20 - (ctx.GLOCs or 0) * 3
			return ctx.Concluir(nota, nota >= 7, { string.format("20 s de solução de tiro em %d s.", math.floor(ctx.T)) })
		end
		if ctx.T > 150 then
			return ctx.Concluir(math.clamp(d.Tiro / 20 * 7, 0, 6.5), false, { string.format("Solução de tiro acumulada: %d s de 20.", math.floor(d.Tiro)) })
		end
	end,
}

D.F39_3 = {
	Cheque = true,
	Descricao = "Cheque do F-39E: aproximação final e pouso na pista 36, começando a 4 milhas náuticas.",
	Itens = {
		"Trem embaixo, 145 kt na final, rampa de 3° pelo PAPI.",
		"O F-39 pousa com o nariz alto: mantenha o marcador de trajetória (FPM) sobre a cabeceira.",
		"Depois do toque, freio aerodinâmico e freios até parar.",
		"O resultado será avaliado por um instrutor.",
	},
	Inicio = function(P) return inicioFinal(P, 7400) end,
	Objetivos = { "Aproximação estabilizada", "Toque na zona de toque", "Parar sobre a pista" },
	Limite = 360,
	Iniciar = function(ctx) ctx.Dados.Pouso = novoPouso() end,
	Atualizar = function(ctx, s, dt)
		local pz = ctx.Dados.Pouso
		if avaliarPouso(ctx, s, dt, pz, s.P.VAprox) then
			local nota, linhas = notaPouso(s, pz)
			ctx.Marcar(1, pz.Estavel / math.max(pz.Amostras, 1) > 0.5)
			ctx.Marcar(2, true)
			ctx.Marcar(3, true)
			return ctx.Concluir(nota, nota >= 7, linhas)
		end
	end,
}

return L
