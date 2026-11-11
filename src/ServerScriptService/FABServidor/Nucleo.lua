--[[
	FAB - Nucleo do servidor (ModuleScript)

	Dados dos cadetes (DataStore), esquadrilhas, remotos, sessoes de atividade,
	resultados, permissoes de instrutor e funcoes de apoio usadas pelos outros sistemas.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("FAB"):WaitForChild("Config"))

local N = {}
N.Config = Config
N.Dados = {}
N.Sessoes = {}
N.Locais = {}
local acoes = {}
local aoEntrar = {}
local aoSair = {}

-- Remotos
local pasta = Instance.new("Folder")
pasta.Name = "FABRemotos"
local function remoto(nome, classe)
	local r = Instance.new(classe or "RemoteEvent")
	r.Name = nome
	r.Parent = pasta
	return r
end
local rAbrir = remoto("Abrir")
local rDados = remoto("Dados")
local rAcao = remoto("Acao")
local okUnr = pcall(function() remoto("Telemetria", "UnreliableRemoteEvent") end)
if not okUnr then remoto("Telemetria") end
pasta.Parent = ReplicatedStorage
N.Remotos = pasta

-- DataStore (com plano B em memoria quando a API nao esta liberada)
local store, storeEsq
pcall(function()
	store = DataStoreService:GetDataStore("FAB_Cadetes_v1")
	storeEsq = DataStoreService:GetDataStore("FAB_Esquadrilhas_v1")
end)

N.PontosEsquadrilha = {}
for _, e in ipairs(Config.Esquadrilhas) do N.PontosEsquadrilha[e] = 0 end
local pontosPendentes = {}

task.spawn(function()
	if not storeEsq then return end
	for _, e in ipairs(Config.Esquadrilhas) do
		local ok, v = pcall(function() return storeEsq:GetAsync(e) end)
		if ok and type(v) == "number" then N.PontosEsquadrilha[e] = v end
	end
end)

local function dadosPadrao()
	return { Versao = 1, Esquadrilha = nil, Atividades = {}, TACF = {}, HorasSimulador = 0 }
end

local function contarEsquadrilhas()
	local cont = {}
	for _, e in ipairs(Config.Esquadrilhas) do cont[e] = 0 end
	for _, d in pairs(N.Dados) do
		if d.Esquadrilha and cont[d.Esquadrilha] then cont[d.Esquadrilha] = cont[d.Esquadrilha] + 1 end
	end
	local menor, nomeMenor = math.huge, Config.Esquadrilhas[1]
	for _, e in ipairs(Config.Esquadrilhas) do
		if cont[e] < menor then menor = cont[e]; nomeMenor = e end
	end
	return nomeMenor
end

local function salvar(plr)
	local d = N.Dados[plr]
	if not d or not store or d._SemDados then return end
	pcall(function()
		store:SetAsync("C_" .. plr.UserId, d)
	end)
end
N.Salvar = salvar

-- Progresso em porcentagem (para a lista de jogadores)
local function progresso(d)
	local total, feitos = 0, 0
	for _, a in ipairs(Config.Atividades) do
		total = total + 1
		local r = d.Atividades[a.Id]
		if r and r.Aprovado then feitos = feitos + 1 end
	end
	return math.floor(feitos / math.max(total, 1) * 100 + 0.5)
end

local function atualizarLeaderstats(plr)
	local d = N.Dados[plr]
	if not d then return end
	local ls = plr:FindFirstChild("leaderstats")
	if not ls then
		ls = Instance.new("Folder")
		ls.Name = "leaderstats"
		local e = Instance.new("StringValue")
		e.Name = "Esquadrilha"
		e.Parent = ls
		local p = Instance.new("StringValue")
		p.Name = "Formação"
		p.Parent = ls
		ls.Parent = plr
	end
	ls.Esquadrilha.Value = d.Esquadrilha or "-"
	ls["Formação"].Value = progresso(d) .. "%"
end

function N.Sincronizar(plr)
	local d = N.Dados[plr]
	if not d then return end
	local copia = {
		Esquadrilha = d.Esquadrilha, Atividades = d.Atividades, TACF = d.TACF,
		HorasSimulador = d.HorasSimulador, Instrutor = N.EhInstrutor(plr),
		PontosEsquadrilha = N.PontosEsquadrilha, ExigirRequisitos = Config.ExigirRequisitos and not N.EhInstrutor(plr),
	}
	rDados:FireClient(plr, copia)
	atualizarLeaderstats(plr)
end

function N.SincronizarTodos()
	for _, p in ipairs(Players:GetPlayers()) do N.Sincronizar(p) end
end

-- Permissoes
local cacheInstrutor = {}
function N.EhInstrutor(plr)
	if cacheInstrutor[plr] ~= nil then return cacheInstrutor[plr] end
	local sim = false
	if plr.UserId == game.CreatorId and game.CreatorType == Enum.CreatorType.User then sim = true end
	for _, id in ipairs(Config.Instrutores) do
		if id == plr.UserId then sim = true end
	end
	if not sim and game.CreatorType == Enum.CreatorType.Group then
		pcall(function()
			if plr:GetRankInGroup(game.CreatorId) >= 254 then sim = true end
		end)
	end
	if not sim and Config.GrupoId and Config.GrupoId > 0 then
		pcall(function()
			if plr:GetRankInGroup(Config.GrupoId) >= Config.RankInstrutor then sim = true end
		end)
	end
	if RunService:IsStudio() then sim = true end
	cacheInstrutor[plr] = sim
	return sim
end

-- Comunicacao
function N.RegistrarAcao(nome, fn) acoes[nome] = fn end
function N.Abrir(plr, nome, params) rAbrir:FireClient(plr, nome, params or {}) end
function N.AbrirTodos(nome, params) rAbrir:FireAllClients(nome, params or {}) end
function N.AoEntrar(fn) table.insert(aoEntrar, fn) end
function N.AoSair(fn) table.insert(aoSair, fn) end

rAcao.OnServerEvent:Connect(function(plr, nome, params)
	if type(nome) ~= "string" then return end
	local fn = acoes[nome]
	if not fn then return end
	if type(params) ~= "table" then params = {} end
	local ok, erro = pcall(fn, plr, params)
	if not ok then warn("[FAB] Erro na acao " .. nome .. ": " .. tostring(erro)) end
end)

-- Requisitos
function N.Requisitos(plr, id)
	local a = Config.PorId[id]
	local d = N.Dados[plr]
	if not a or not d then return false, {} end
	-- instrutores (e o dono do jogo) podem fazer qualquer atividade, para testar e demonstrar
	if not Config.ExigirRequisitos or N.EhInstrutor(plr) then return true, {} end
	local faltando = {}
	for _, req in ipairs(a.Requisitos or {}) do
		local r = d.Atividades[req]
		if not (r and r.Aprovado) then
			local def = Config.PorId[req]
			table.insert(faltando, def and def.Nome or req)
		end
	end
	return #faltando == 0, faltando
end

-- Abre a caderneta mostrando o que falta para a atividade
function N.MostrarBloqueio(plr, id)
	local _, faltando = N.Requisitos(plr, id)
	N.Abrir(plr, "Bloqueado", { Atividade = id, Faltando = faltando })
end

-- Sessoes
function N.IniciarSessao(plr, id, extra)
	local s = extra or {}
	s.Id = id
	s.Inicio = os.clock()
	N.Sessoes[plr] = s
	return s
end
function N.Sessao(plr, id)
	local s = N.Sessoes[plr]
	if s and (id == nil or s.Id == id) then return s end
	return nil
end
function N.EncerrarSessao(plr)
	N.Sessoes[plr] = nil
end

-- Personagem
function N.Personagem(plr)
	local c = plr.Character
	if not c then return nil end
	return c, c:FindFirstChild("HumanoidRootPart"), c:FindFirstChildOfClass("Humanoid")
end

function N.Congelar(plr, congelado, cf)
	local c, hrp, hum = N.Personagem(plr)
	if not hrp then return end
	if cf then hrp.CFrame = cf end
	hrp.Anchored = congelado and true or false
	if hum then
		if congelado then
			hum.WalkSpeed = 0
			hum.JumpPower = 0
			hum.JumpHeight = 0
		else
			hum.WalkSpeed = 16
			hum.JumpPower = 50
			hum.JumpHeight = 7.2
		end
	end
end

function N.Pose(plr, nome)
	local c = plr.Character
	if c then c:SetAttribute("PoseFAB", nome or "") end
end

function N.Teleportar(plr, cf)
	local _, hrp = N.Personagem(plr)
	if hrp then hrp.CFrame = cf end
end

-- Locais (pontos de referencia do mapa)
function N.DefinirLocal(nome, cf) N.Locais[nome] = cf end
function N.Local(nome) return N.Locais[nome] end

-- Cria um ProximityPrompt
function N.Prompt(parte, objeto, acao, fn, distancia)
	local p = Instance.new("ProximityPrompt")
	p.ObjectText = objeto or ""
	p.ActionText = acao or "Interagir"
	p.HoldDuration = 0.3
	p.MaxActivationDistance = distancia or 10
	p.RequiresLineOfSight = false
	p.Parent = parte
	p.Triggered:Connect(function(plr)
		local ok, erro = pcall(fn, plr, p)
		if not ok then warn("[FAB] Erro no prompt " .. tostring(acao) .. ": " .. tostring(erro)) end
	end)
	return p
end

-- Pontos de esquadrilha
function N.Pontuar(esquadrilha, pontos)
	if not esquadrilha or not N.PontosEsquadrilha[esquadrilha] then return end
	N.PontosEsquadrilha[esquadrilha] = N.PontosEsquadrilha[esquadrilha] + pontos
	pontosPendentes[esquadrilha] = (pontosPendentes[esquadrilha] or 0) + pontos
end

task.spawn(function()
	while true do
		task.wait(60)
		if storeEsq then
			for e, p in pairs(pontosPendentes) do
				pontosPendentes[e] = nil
				pcall(function()
					storeEsq:UpdateAsync(e, function(v)
						return (type(v) == "number" and v or 0) + p
					end)
				end)
			end
		end
	end
end)

--[[
	Registra o resultado de uma atividade.
	opcoes: { Linhas = {textos do debriefing}, Titulo, SemDebriefing, Aprovado (forca o resultado) }
]]
function N.RegistrarResultado(plr, id, nota, opcoes)
	opcoes = opcoes or {}
	local d = N.Dados[plr]
	local a = Config.PorId[id]
	if not d or not a then return end
	nota = math.floor(math.clamp(nota or 0, 0, 10) * 10 + 0.5) / 10
	local aprovado = opcoes.Aprovado
	if aprovado == nil then aprovado = nota >= Config.NotaMinima end
	local r = d.Atividades[id] or { Tentativas = 0, Nota = 0 }
	r.Tentativas = (r.Tentativas or 0) + 1
	r.UltimaNota = nota
	local pendente = false
	if aprovado and a.Cheque and not r.Aprovado then
		-- cheque: aguarda a confirmacao de um instrutor
		r.Pendente = true
		r.NotaPendente = nota
		r.Detalhes = opcoes.Linhas
		pendente = true
	elseif aprovado then
		local primeira = not r.Aprovado
		r.Aprovado = true
		r.Pendente = false
		if nota > (r.Nota or 0) then r.Nota = nota end
		if primeira then N.Pontuar(d.Esquadrilha, math.floor(nota * 10)) end
	end
	d.Atividades[id] = r
	if not opcoes.SemDebriefing then
		N.Abrir(plr, "Debriefing", {
			Titulo = opcoes.Titulo or a.Nome, Nota = nota, Aprovado = aprovado, Pendente = pendente,
			Linhas = opcoes.Linhas or {},
		})
	end
	N.Sincronizar(plr)
	task.spawn(salvar, plr)
	return aprovado
end

-- Aprovacao manual (instrutor)
function N.DecidirCheque(plr, id, aprovar, instrutor)
	local d = N.Dados[plr]
	if not d then return end
	local r = d.Atividades[id] or { Tentativas = 0, Nota = 0 }
	if aprovar then
		local primeira = not r.Aprovado
		r.Aprovado = true
		r.Nota = math.max(r.Nota or 0, r.NotaPendente or r.UltimaNota or Config.NotaMinima)
		if primeira then N.Pontuar(d.Esquadrilha, math.floor(r.Nota * 10)) end
	else
		r.Aprovado = false
		r.Nota = 0
	end
	r.Pendente = false
	r.Avaliador = instrutor and instrutor.Name or nil
	d.Atividades[id] = r
	N.Sincronizar(plr)
	task.spawn(salvar, plr)
end

-- Entrada e saida
local function carregar(plr)
	local d
	local ok, v = true, nil
	if store then
		ok, v = pcall(function() return store:GetAsync("C_" .. plr.UserId) end)
	end
	if ok and type(v) == "table" then
		d = v
		d.Atividades = d.Atividades or {}
		d.TACF = d.TACF or {}
		d.HorasSimulador = d.HorasSimulador or 0
	else
		d = dadosPadrao()
		if not ok then d._SemDados = true end
	end
	if not d.Esquadrilha then d.Esquadrilha = contarEsquadrilhas() end
	if not plr.Parent then return end
	N.Dados[plr] = d
	N.Sincronizar(plr)
	for _, fn in ipairs(aoEntrar) do task.spawn(fn, plr) end
end

Players.PlayerAdded:Connect(carregar)
for _, p in ipairs(Players:GetPlayers()) do task.spawn(carregar, p) end

Players.PlayerRemoving:Connect(function(plr)
	for _, fn in ipairs(aoSair) do pcall(fn, plr) end
	salvar(plr)
	N.Dados[plr] = nil
	N.Sessoes[plr] = nil
	cacheInstrutor[plr] = nil
end)

game:BindToClose(function()
	for _, p in ipairs(Players:GetPlayers()) do salvar(p) end
	if storeEsq then
		for e, p in pairs(pontosPendentes) do
			pcall(function()
				storeEsq:UpdateAsync(e, function(v) return (type(v) == "number" and v or 0) + p end)
			end)
		end
	end
end)

task.spawn(function()
	while true do
		task.wait(120)
		for _, p in ipairs(Players:GetPlayers()) do salvar(p) end
	end
end)

return N
