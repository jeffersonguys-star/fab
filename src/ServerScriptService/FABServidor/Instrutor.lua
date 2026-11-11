--[[
	FAB - Instrutor e quadro das esquadrilhas (servidor)

	Painel do instrutor: lista de cadetes, cheques aguardando avaliacao,
	aprovar ou zerar atividades e ir ate as instalacoes.
	Quadro das esquadrilhas no patio: pontuacao de Aquila, Centaurus, Leo e Orion.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local C = require(ReplicatedStorage:WaitForChild("FAB"):WaitForChild("Construtor"))

local INSTR = {}

local LOCAIS = {
	{ Id = "Chegada", Nome = "Chegada" },
	{ Id = "FormaturaInstrutor", Nome = "Palanque da formatura" },
	{ Id = "Exercicios", Nome = "Área de exercícios" },
	{ Id = "SalaAula", Nome = "Sala de instrução" },
	{ Id = "Hipoxia", Nome = "Medicina aeroespacial" },
	{ Id = "HangarSimulador", Nome = "Centro de simulação" },
	{ Id = "AlvoSalto", Nome = "Área de salto" },
	{ Id = "Clareira", Nome = "Clareira da mata" },
}

function INSTR.Iniciar(N)
	local function lista()
		local jogadores = {}
		for _, plr in ipairs(Players:GetPlayers()) do
			local d = N.Dados[plr]
			if d then
				local pendentes, atividades = {}, {}
				local feitos = 0
				for _, a in ipairs(N.Config.Atividades) do
					local r = d.Atividades[a.Id]
					if r and r.Pendente then
						table.insert(pendentes, { Id = a.Id, Nome = a.Nome, Nota = r.NotaPendente, Detalhes = r.Detalhes })
					end
					if r and r.Aprovado then feitos = feitos + 1 end
					table.insert(atividades, { Id = a.Id, Nome = a.Nome, Aprovado = r and r.Aprovado or false, Nota = r and r.Nota or nil })
				end
				table.insert(jogadores, {
					UserId = plr.UserId, Nome = plr.DisplayName, Usuario = plr.Name, Esquadrilha = d.Esquadrilha,
					Progresso = math.floor(feitos / #N.Config.Atividades * 100), Pendentes = pendentes, Atividades = atividades,
					Horas = math.floor((d.HorasSimulador or 0) / 60),
				})
			end
		end
		return jogadores
	end

	N.RegistrarAcao("Instr_Lista", function(plr)
		if not N.EhInstrutor(plr) then return end
		N.Abrir(plr, "Instr_Lista", { Jogadores = lista(), Locais = LOCAIS })
	end)

	local function alvo(userId)
		for _, p in ipairs(Players:GetPlayers()) do
			if p.UserId == userId then return p end
		end
		return nil
	end

	N.RegistrarAcao("Instr_Cheque", function(plr, p)
		if not N.EhInstrutor(plr) then return end
		local cadete = alvo(p.UserId)
		if not cadete or not N.Config.PorId[p.Id] then return end
		N.DecidirCheque(cadete, p.Id, p.Aprovar == true, plr)
		N.Abrir(cadete, "Debriefing", {
			Titulo = "Cheque: " .. N.Config.PorId[p.Id].Nome,
			Nota = N.Dados[cadete] and N.Dados[cadete].Atividades[p.Id] and N.Dados[cadete].Atividades[p.Id].Nota or 0,
			Aprovado = p.Aprovar == true,
			Linhas = { "Avaliado pelo instrutor " .. plr.DisplayName .. "." },
		})
		N.Abrir(plr, "Instr_Lista", { Jogadores = lista(), Locais = LOCAIS })
	end)

	N.RegistrarAcao("Instr_Definir", function(plr, p)
		if not N.EhInstrutor(plr) then return end
		local cadete = alvo(p.UserId)
		if not cadete or not N.Config.PorId[p.Id] then return end
		local d = N.Dados[cadete]
		if not d then return end
		if p.Aprovar then
			N.DecidirCheque(cadete, p.Id, true, plr)
		else
			d.Atividades[p.Id] = nil
			N.Sincronizar(cadete)
			task.spawn(N.Salvar, cadete)
		end
		N.Abrir(plr, "Instr_Lista", { Jogadores = lista(), Locais = LOCAIS })
	end)

	N.RegistrarAcao("Instr_Ir", function(plr, p)
		if not N.EhInstrutor(plr) or N.Sessao(plr) then return end
		local cf = N.Local(p.Local)
		if cf then N.Teleportar(plr, cf + Vector3.new(0, 3, 0)) end
	end)

	-- Quadro das esquadrilhas
	local quadro = N.QuadroEsquadrilhas
	if quadro then
		local g = C.Tela(quadro, Enum.NormalId.Front, 30)
		local f = Instance.new("Frame")
		f.Size = UDim2.fromScale(1, 1)
		f.BackgroundColor3 = Color3.fromRGB(8, 8, 8)
		f.BorderSizePixel = 0
		f.Parent = g
		C.Texto(f, "ESQUADRILHAS", { Size = UDim2.fromScale(0.9, 0.14), Position = UDim2.fromScale(0.05, 0.05), TextXAlignment = Enum.TextXAlignment.Left })
		C.Texto(f, "Corpo de Cadetes da Aeronáutica", { Size = UDim2.fromScale(0.9, 0.07), Position = UDim2.fromScale(0.05, 0.19),
			Font = Enum.Font.Gotham, TextColor3 = Color3.fromRGB(170, 170, 170), TextXAlignment = Enum.TextXAlignment.Left })
		local linhas = {}
		for i = 1, 4 do
			local l = Instance.new("Frame")
			l.Size = UDim2.fromScale(0.9, 0.13)
			l.Position = UDim2.fromScale(0.05, 0.3 + (i - 1) * 0.165)
			l.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
			l.BorderSizePixel = 0
			l.Parent = f
			local canto = Instance.new("UICorner")
			canto.CornerRadius = UDim.new(0.2, 0)
			canto.Parent = l
			local barra = Instance.new("Frame")
			barra.Size = UDim2.fromScale(0, 1)
			barra.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
			barra.BackgroundTransparency = 0.85
			barra.BorderSizePixel = 0
			barra.Parent = l
			local nome = C.Texto(l, "", { Size = UDim2.fromScale(0.6, 0.7), Position = UDim2.fromScale(0.04, 0.15), TextXAlignment = Enum.TextXAlignment.Left })
			local pts = C.Texto(l, "", { Size = UDim2.fromScale(0.3, 0.7), Position = UDim2.fromScale(0.66, 0.15), TextXAlignment = Enum.TextXAlignment.Right, Font = Enum.Font.Code })
			linhas[i] = { Barra = barra, Nome = nome, Pontos = pts }
		end
		task.spawn(function()
			while true do
				local ordem = {}
				for _, e in ipairs(N.Config.Esquadrilhas) do table.insert(ordem, { Nome = e, Pontos = N.PontosEsquadrilha[e] or 0 }) end
				table.sort(ordem, function(a, b) return a.Pontos > b.Pontos end)
				local maior = math.max(1, ordem[1].Pontos)
				for i, e in ipairs(ordem) do
					linhas[i].Nome.Text = i .. "º  " .. string.upper(e.Nome)
					linhas[i].Pontos.Text = tostring(e.Pontos)
					linhas[i].Barra.Size = UDim2.fromScale(e.Pontos / maior, 1)
				end
				task.wait(5)
			end
		end)
	end
end

return INSTR
