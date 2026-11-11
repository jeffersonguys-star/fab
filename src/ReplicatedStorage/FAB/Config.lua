--[[
	FAB - Configuracao geral (ModuleScript)

	Fases da formacao, atividades, licoes do simulador, esquadrilhas
	e permissoes de instrutor. Usado pelo servidor e pelos clientes.
]]

local Config = {}

-- Instrutores: IDs de usuario do Roblox. O dono do jogo sempre e instrutor.
Config.Instrutores = {
	-- 123456789,
}
-- Comunidade (grupo) do Roblox: membros com cargo igual ou acima de RankInstrutor sao instrutores.
Config.GrupoId = 0
Config.RankInstrutor = 200

-- Se falso, todas as atividades ficam liberadas (util para testes).
Config.ExigirRequisitos = true

Config.Esquadrilhas = { "Aquila", "Centaurus", "Leo", "Orion" }

Config.NotaMinima = 7

Config.Fases = {
	{ Id = "Adaptacao", Nome = "Estágio de Adaptação Militar" },
	{ Id = "Teorica", Nome = "Instrução Teórica" },
	{ Id = "Fisiologica", Nome = "Instrução Fisiológica" },
	{ Id = "Simulador", Nome = "Instrução em Simulador" },
}

local ADAPTACAO = { "OrdemUnida", "TACF", "SaltoEmergencia", "Sobrevivencia" }

Config.Atividades = {
	{ Id = "OrdemUnida", Fase = "Adaptacao", Nome = "Ordem Unida", Requisitos = {},
		Descricao = "Formatura no pátio: responda aos comandos do instrutor no tempo certo." },
	{ Id = "TACF", Fase = "Adaptacao", Nome = "Teste de Condicionamento Físico (TACF)", Requisitos = {},
		Descricao = "Corrida na pista, flexões de braço e abdominais." },
	{ Id = "SaltoEmergencia", Fase = "Adaptacao", Nome = "Instrução de Salto de Emergência", Requisitos = {},
		Descricao = "Abandono da aeronave em voo, abertura do paraquedas e pouso no alvo." },
	{ Id = "Sobrevivencia", Fase = "Adaptacao", Nome = "Sobrevivência na Selva", Requisitos = {},
		Descricao = "Piloto abatido: encontre o kit, acenda uma fogueira e sinalize para o resgate." },

	{ Id = "Aerodinamica", Fase = "Teorica", Nome = "Aerodinâmica", Requisitos = ADAPTACAO,
		Descricao = "Prova teórica de aerodinâmica." },
	{ Id = "Navegacao", Fase = "Teorica", Nome = "Navegação Aérea", Requisitos = ADAPTACAO,
		Descricao = "Prova teórica de navegação aérea." },
	{ Id = "Meteorologia", Fase = "Teorica", Nome = "Meteorologia", Requisitos = ADAPTACAO,
		Descricao = "Prova teórica de meteorologia." },
	{ Id = "Regulamentos", Fase = "Teorica", Nome = "Regulamentos de Tráfego Aéreo", Requisitos = ADAPTACAO,
		Descricao = "Prova teórica de regras do ar e tráfego aéreo." },

	{ Id = "Hipoxia", Fase = "Fisiologica", Nome = "Câmara Hipobárica (Hipóxia)", Requisitos = ADAPTACAO,
		Descricao = "Reconheça os sintomas da hipóxia e coloque a máscara a tempo." },
	{ Id = "Centrifuga", Fase = "Fisiologica", Nome = "Centrífuga (Tolerância a G)", Requisitos = ADAPTACAO,
		Descricao = "Suporte o perfil de G com a manobra anti-G sem perder a consciência." },
}

-- Licoes do simulador, na ordem da formacao
local REQ_SIM = { "Aerodinamica", "Navegacao", "Meteorologia", "Regulamentos", "Hipoxia", "Centrifuga" }
Config.Licoes = {
	{ Id = "T25_1", Aeronave = "T25", Nome = "Cheque de cabine e partida", Minimo = 25 },
	{ Id = "T25_2", Aeronave = "T25", Nome = "Rolagem e decolagem", Minimo = 30 },
	{ Id = "T25_3", Aeronave = "T25", Nome = "Voo reto nivelado e curvas", Minimo = 60 },
	{ Id = "T25_4", Aeronave = "T25", Nome = "Estol e recuperação", Minimo = 20 },
	{ Id = "T25_5", Aeronave = "T25", Nome = "Aproximação e pouso", Minimo = 40 },
	{ Id = "T25_6", Aeronave = "T25", Nome = "Pane de motor e pouso forçado", Minimo = 40 },
	{ Id = "T25_7", Aeronave = "T25", Nome = "Cheque T-25: decolagem, circuito e pouso", Minimo = 90, Cheque = true },
	{ Id = "T27_1", Aeronave = "T27", Nome = "Acrobacia: looping", Minimo = 20 },
	{ Id = "T27_2", Aeronave = "T27", Nome = "Acrobacia: tonneau", Minimo = 10 },
	{ Id = "T27_3", Aeronave = "T27", Nome = "Navegação por pontos", Minimo = 90 },
	{ Id = "A29_1", Aeronave = "A29", Nome = "Voo em formação (ala)", Minimo = 60 },
	{ Id = "A29_2", Aeronave = "A29", Nome = "Navegação à baixa altura", Minimo = 60 },
	{ Id = "F5_1", Aeronave = "F5", Nome = "Decolagem com pós-combustor e subida", Minimo = 30 },
	{ Id = "F5_2", Aeronave = "F5", Nome = "Voo supersônico", Minimo = 40 },
	{ Id = "F5_3", Aeronave = "F5", Nome = "Interceptação de alvo", Minimo = 60 },
	{ Id = "F39_1", Aeronave = "F39", Nome = "Curva de alto G", Minimo = 20 },
	{ Id = "F39_2", Aeronave = "F39", Nome = "Combate aéreo básico (BFM)", Minimo = 40 },
	{ Id = "F39_3", Aeronave = "F39", Nome = "Cheque F-39: aproximação e pouso", Minimo = 40, Cheque = true },
}
for i, l in ipairs(Config.Licoes) do
	l.Fase = "Simulador"
	l.Sim = true
	if i == 1 then
		l.Requisitos = REQ_SIM
	else
		l.Requisitos = { Config.Licoes[i - 1].Id }
	end
	l.Descricao = "Lição de simulador"
	table.insert(Config.Atividades, l)
end

Config.PorId = {}
for _, a in ipairs(Config.Atividades) do
	Config.PorId[a.Id] = a
end

-- Hierarquia da FAB (para uso futuro na overhead)
Config.Patentes = {
	"Soldado", "Cabo", "Terceiro-Sargento", "Segundo-Sargento", "Primeiro-Sargento", "Suboficial",
	"Cadete", "Aspirante", "Segundo-Tenente", "Primeiro-Tenente", "Capitão", "Major",
	"Tenente-Coronel", "Coronel", "Brigadeiro", "Major-Brigadeiro", "Tenente-Brigadeiro",
	"Comandante da Aeronáutica",
}

return Config
