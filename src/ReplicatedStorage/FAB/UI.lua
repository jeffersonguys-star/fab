--[[
	FAB - Interface (ModuleScript, usado so no cliente)

	Kit de interface moderno em preto e branco: modais, botoes, listas, chips,
	caderneta do cadete, briefing e debriefing. Tambem distribui as mensagens do
	servidor ("Abrir") para os sistemas que se registraram.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local UI = {}

UI.Cor = {
	Fundo = Color3.fromRGB(0, 0, 0),
	Cartao = Color3.fromRGB(10, 10, 10),
	Elevado = Color3.fromRGB(20, 20, 20),
	Linha = Color3.fromRGB(42, 42, 42),
	Branco = Color3.fromRGB(255, 255, 255),
	Texto = Color3.fromRGB(240, 240, 240),
	Sub = Color3.fromRGB(150, 150, 150),
	Apagado = Color3.fromRGB(85, 85, 85),
}
local COR = UI.Cor
local FONTE = Enum.Font.Gotham
local FONTE_MEDIA = Enum.Font.GothamMedium
local FONTE_FORTE = Enum.Font.GothamBold

local handlers = {}
local aoDados = {}
UI.Dados = nil

function UI.Novo(classe, props, filhos)
	local o = Instance.new(classe)
	if props then
		for k, v in pairs(props) do
			if k ~= "Parent" then o[k] = v end
		end
	end
	if filhos then
		for _, f in ipairs(filhos) do f.Parent = o end
	end
	if props and props.Parent then o.Parent = props.Parent end
	return o
end
local Novo = UI.Novo

function UI.Canto(obj, r)
	return Novo("UICorner", { CornerRadius = UDim.new(0, r or 12), Parent = obj })
end

function UI.Contorno(obj, transp, esp, cor)
	return Novo("UIStroke", { Color = cor or COR.Branco, Transparency = transp or 0.85, Thickness = esp or 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = obj })
end

function UI.Rotulo(pai, texto, tamanho, props)
	local t = Novo("TextLabel", {
		BackgroundTransparency = 1, Text = texto or "", TextSize = tamanho or 15, Font = FONTE,
		TextColor3 = COR.Texto, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, 0, 0, (tamanho or 15) + 6), AutomaticSize = Enum.AutomaticSize.Y, Parent = pai,
	})
	if props then
		for k, v in pairs(props) do t[k] = v end
	end
	return t
end

-- Botao: "primario" (branco), "secundario" (contorno), "fantasma" (so texto)
function UI.Botao(pai, texto, estilo, fn, props)
	estilo = estilo or "primario"
	local b = Novo("TextButton", {
		AutoButtonColor = false, Text = texto, TextSize = 15, Font = FONTE_FORTE,
		Size = UDim2.new(0, 160, 0, 42), BorderSizePixel = 0, Parent = pai,
	})
	if estilo == "primario" then
		b.BackgroundColor3 = COR.Branco
		b.TextColor3 = COR.Fundo
	elseif estilo == "secundario" then
		b.BackgroundColor3 = COR.Cartao
		b.TextColor3 = COR.Branco
		UI.Contorno(b, 0.55)
	else
		b.BackgroundTransparency = 1
		b.TextColor3 = COR.Sub
	end
	UI.Canto(b, 21)
	local escala = Novo("UIScale", { Parent = b })
	b.MouseButton1Down:Connect(function()
		TweenService:Create(escala, TweenInfo.new(0.08), { Scale = 0.96 }):Play()
	end)
	b.MouseButton1Up:Connect(function()
		TweenService:Create(escala, TweenInfo.new(0.12), { Scale = 1 }):Play()
	end)
	b.MouseLeave:Connect(function() escala.Scale = 1 end)
	if fn then
		b.Activated:Connect(function()
			if b:GetAttribute("Desativado") then return end
			fn(b)
		end)
	end
	if props then
		for k, v in pairs(props) do b[k] = v end
	end
	return b
end

function UI.Desativar(b, sim)
	b:SetAttribute("Desativado", sim)
	b.TextTransparency = sim and 0.6 or 0
end

-- Tela principal
local tela
function UI.Tela()
	if tela and tela.Parent then return tela end
	tela = Novo("ScreenGui", {
		Name = "FAB", ResetOnSpawn = false, IgnoreGuiInset = true, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 10, Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
	})
	return tela
end

-- Modal centralizado com fundo escurecido
local modaisAbertos = 0
function UI.Modal(opcoes)
	opcoes = opcoes or {}
	local raiz = Novo("Frame", {
		Name = "Modal", Size = UDim2.fromScale(1, 1), BackgroundColor3 = COR.Fundo, BackgroundTransparency = 1,
		ZIndex = 50, Parent = UI.Tela(), Active = true,
	})
	local cartao = Novo("Frame", {
		Name = "Cartao", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.53),
		Size = UDim2.new(0.92, 0, 0.88, 0), BackgroundColor3 = COR.Cartao, Parent = raiz,
	})
	Novo("UISizeConstraint", { MaxSize = Vector2.new(opcoes.Largura or 520, opcoes.Altura or 560), Parent = cartao })
	UI.Canto(cartao, 18)
	UI.Contorno(cartao, 0.82)
	Novo("UIPadding", { PaddingLeft = UDim.new(0, 20), PaddingRight = UDim.new(0, 20), PaddingTop = UDim.new(0, 18), PaddingBottom = UDim.new(0, 16), Parent = cartao })
	local topo = Novo("Frame", { Size = UDim2.new(1, 0, 0, 52), BackgroundTransparency = 1, Parent = cartao })
	UI.Rotulo(topo, string.upper(opcoes.Sobretitulo or "Força Aérea Brasileira"), 11, {
		Font = FONTE_MEDIA, TextColor3 = COR.Sub, Size = UDim2.new(1, -44, 0, 14), AutomaticSize = Enum.AutomaticSize.None,
	})
	UI.Rotulo(topo, opcoes.Titulo or "", 21, {
		Font = FONTE_FORTE, TextColor3 = COR.Branco, Position = UDim2.fromOffset(0, 18), Size = UDim2.new(1, -44, 0, 28),
		AutomaticSize = Enum.AutomaticSize.None, TextTruncate = Enum.TextTruncate.AtEnd,
	})
	local obj = { Raiz = raiz, Cartao = cartao }
	if not opcoes.SemFechar then
		local x = Novo("TextButton", {
			AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 2), Size = UDim2.fromOffset(34, 34),
			BackgroundColor3 = COR.Elevado, Text = "×", TextSize = 22, Font = FONTE_MEDIA, TextColor3 = COR.Branco,
			AutoButtonColor = false, Parent = topo,
		})
		UI.Canto(x, 17)
		x.Activated:Connect(function() obj.Fechar() end)
	end
	Novo("Frame", { Position = UDim2.fromOffset(0, 58), Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = COR.Linha, BorderSizePixel = 0, Parent = cartao })
	local alturaRodape = opcoes.SemRodape and 0 or 52
	local conteudo = Novo("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 70), Size = UDim2.new(1, 0, 1, -70 - alturaRodape), BackgroundTransparency = 1,
		BorderSizePixel = 0, ScrollBarThickness = 3, ScrollBarImageColor3 = COR.Apagado, CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y, Parent = cartao,
	})
	Novo("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = conteudo })
	Novo("UIPadding", { PaddingRight = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6), Parent = conteudo })
	local rodape = Novo("Frame", {
		AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 44),
		BackgroundTransparency = 1, Visible = not opcoes.SemRodape, Parent = cartao,
	})
	Novo("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Right,
		Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = rodape })
	obj.Conteudo = conteudo
	obj.Rodape = rodape
	local fechado = false
	function obj.Fechar()
		if fechado then return end
		fechado = true
		modaisAbertos = math.max(0, modaisAbertos - 1)
		TweenService:Create(raiz, TweenInfo.new(0.15), { BackgroundTransparency = 1 }):Play()
		TweenService:Create(cartao, TweenInfo.new(0.15), { Position = UDim2.fromScale(0.5, 0.56) }):Play()
		task.delay(0.15, function() raiz:Destroy() end)
		if opcoes.AoFechar then opcoes.AoFechar() end
	end
	modaisAbertos = modaisAbertos + 1
	TweenService:Create(raiz, TweenInfo.new(0.2), { BackgroundTransparency = 0.35 }):Play()
	TweenService:Create(cartao, TweenInfo.new(0.25, Enum.EasingStyle.Quint), { Position = UDim2.fromScale(0.5, 0.5) }):Play()
	return obj
end

function UI.ModalAberto() return modaisAbertos > 0 end

-- Linha de lista (titulo, subtitulo e selo de estado)
function UI.Item(pai, titulo, sub, estado, fn, ordem)
	local f = Novo("TextButton", {
		Size = UDim2.new(1, 0, 0, 62), BackgroundColor3 = COR.Elevado, AutoButtonColor = false, Text = "",
		LayoutOrder = ordem or 0, Parent = pai,
	})
	UI.Canto(f, 12)
	UI.Contorno(f, 0.92)
	Novo("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 12), Parent = f })
	UI.Rotulo(f, titulo, 15, { Font = FONTE_MEDIA, Position = UDim2.fromOffset(0, 11), Size = UDim2.new(1, -110, 0, 20),
		AutomaticSize = Enum.AutomaticSize.None, TextTruncate = Enum.TextTruncate.AtEnd })
	UI.Rotulo(f, sub or "", 12, { TextColor3 = COR.Sub, Position = UDim2.fromOffset(0, 33), Size = UDim2.new(1, -110, 0, 16),
		AutomaticSize = Enum.AutomaticSize.None, TextTruncate = Enum.TextTruncate.AtEnd })
	if estado then
		local selo = Novo("TextLabel", {
			AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromScale(1, 0.5), Size = UDim2.fromOffset(96, 26),
			Text = string.upper(estado), TextSize = 10, Font = FONTE_FORTE, Parent = f,
		})
		UI.Canto(selo, 13)
		if estado == "Aprovado" then
			selo.BackgroundColor3 = COR.Branco
			selo.TextColor3 = COR.Fundo
		elseif estado == "Bloqueado" then
			selo.BackgroundTransparency = 1
			selo.TextColor3 = COR.Apagado
			UI.Contorno(selo, 0.8)
		else
			selo.BackgroundColor3 = COR.Cartao
			selo.TextColor3 = COR.Branco
			UI.Contorno(selo, 0.5)
		end
	end
	if fn then f.Activated:Connect(fn) end
	return f
end

-- Titulo de secao dentro de um modal
function UI.Secao(pai, texto, ordem)
	return UI.Rotulo(pai, string.upper(texto), 11, { Font = FONTE_FORTE, TextColor3 = COR.Sub, LayoutOrder = ordem or 0 })
end

-- Chip informativo no topo da tela (cronometro, contagem etc.)
function UI.Chip(texto, posicao)
	local c = Novo("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0), Position = posicao or UDim2.new(0.5, 0, 0, 14), Size = UDim2.fromOffset(0, 34),
		AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = COR.Fundo, BackgroundTransparency = 0.15,
		Text = texto, TextSize = 15, Font = FONTE_FORTE, TextColor3 = COR.Branco, Parent = UI.Tela(),
	})
	Novo("UIPadding", { PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16), Parent = c })
	UI.Canto(c, 17)
	UI.Contorno(c, 0.8)
	return c
end

-- Painel de botoes de acao no canto inferior direito (para celular)
function UI.PainelAcoes(botoes, posicao)
	local p = Novo("Frame", {
		AnchorPoint = Vector2.new(1, 1), Position = posicao or UDim2.new(1, -18, 1, -18), Size = UDim2.fromOffset(0, 0),
		AutomaticSize = Enum.AutomaticSize.XY, BackgroundTransparency = 1, Parent = UI.Tela(),
	})
	Novo("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Right,
		VerticalAlignment = Enum.VerticalAlignment.Bottom, Padding = UDim.new(0, 10), Wrap = true, Parent = p })
	local lista = {}
	for i, b in ipairs(botoes) do
		local bt = UI.Botao(p, b.Texto, b.Estilo or "secundario", b.Fn, { Size = UDim2.fromOffset(b.Largura or 120, b.Altura or 52), LayoutOrder = i })
		lista[b.Id or i] = bt
	end
	return p, lista
end

-- Mensagens do servidor
function UI.Registrar(nome, fn) handlers[nome] = fn end
function UI.AoDados(fn)
	table.insert(aoDados, fn)
	if UI.Dados then task.spawn(fn, UI.Dados) end
end

local remotos
function UI.Enviar(nome, params)
	remotos = remotos or ReplicatedStorage:WaitForChild("FABRemotos")
	remotos.Acao:FireServer(nome, params or {})
end

function UI.Conectar()
	remotos = ReplicatedStorage:WaitForChild("FABRemotos")
	remotos.Abrir.OnClientEvent:Connect(function(nome, params)
		local fn = handlers[nome]
		if fn then
			local ok, erro = pcall(fn, params or {})
			if not ok then warn("[FAB] Erro em " .. tostring(nome) .. ": " .. tostring(erro)) end
		end
	end)
	remotos.Dados.OnClientEvent:Connect(function(d)
		UI.Dados = d
		for _, fn in ipairs(aoDados) do task.spawn(fn, d) end
	end)
end

-- Briefing padrao: lista de topicos e botao de iniciar
function UI.Briefing(opcoes)
	local m = UI.Modal({ Titulo = opcoes.Titulo, Sobretitulo = opcoes.Sobretitulo or "Briefing", Largura = 560, Altura = 600,
		AoFechar = opcoes.AoCancelar })
	if opcoes.Descricao then UI.Rotulo(m.Conteudo, opcoes.Descricao, 15, { TextColor3 = COR.Texto, LayoutOrder = 1 }) end
	for i, item in ipairs(opcoes.Itens or {}) do
		local linha = Novo("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = 10 + i, Parent = m.Conteudo })
		local n = Novo("TextLabel", { Size = UDim2.fromOffset(24, 24), BackgroundColor3 = COR.Elevado, Text = tostring(i), TextSize = 12,
			Font = FONTE_FORTE, TextColor3 = COR.Branco, Parent = linha })
		UI.Canto(n, 12)
		UI.Rotulo(linha, item, 14, { Position = UDim2.fromOffset(34, 2), Size = UDim2.new(1, -34, 0, 20), TextColor3 = COR.Texto })
	end
	if opcoes.Controles then
		UI.Secao(m.Conteudo, "Comandos", 100)
		UI.Rotulo(m.Conteudo, opcoes.Controles, 13, { TextColor3 = COR.Sub, LayoutOrder = 101 })
	end
	UI.Botao(m.Rodape, opcoes.Cancelar or "Cancelar", "fantasma", function() m.Fechar() end, { Size = UDim2.fromOffset(110, 42), LayoutOrder = 1 })
	UI.Botao(m.Rodape, opcoes.Botao or "Iniciar", "primario", function()
		opcoes.AoCancelar = nil
		m.Fechar()
		if opcoes.AoConfirmar then opcoes.AoConfirmar() end
	end, { Size = UDim2.fromOffset(150, 42), LayoutOrder = 2 })
	return m
end

-- Debriefing (resultado de atividade)
local function debriefing(p)
	local m = UI.Modal({ Titulo = p.Titulo or "Resultado", Sobretitulo = "Debriefing", Largura = 540, Altura = 600, AoFechar = p.AoFechar })
	local topo = Novo("Frame", { Size = UDim2.new(1, 0, 0, 96), BackgroundColor3 = COR.Elevado, LayoutOrder = 1, Parent = m.Conteudo })
	UI.Canto(topo, 14)
	Novo("UIPadding", { PaddingLeft = UDim.new(0, 18), PaddingRight = UDim.new(0, 18), Parent = topo })
	local nota = tonumber(p.Nota) or 0
	UI.Rotulo(topo, string.format("%.1f", nota):gsub("%.", ","), 46, { Font = FONTE_FORTE, Position = UDim2.fromOffset(0, 14),
		Size = UDim2.new(0, 120, 0, 54), AutomaticSize = Enum.AutomaticSize.None, TextColor3 = COR.Branco })
	UI.Rotulo(topo, "NOTA", 11, { Font = FONTE_MEDIA, TextColor3 = COR.Sub, Position = UDim2.fromOffset(2, 70), Size = UDim2.new(0, 100, 0, 14), AutomaticSize = Enum.AutomaticSize.None })
	local estado
	if p.Pendente then estado = "AGUARDANDO INSTRUTOR"
	elseif p.Parcial then estado = p.Aprovado and "PROVA CONCLUÍDA" or "ABAIXO DO MÍNIMO"
	else estado = p.Aprovado and "APROVADO" or "REPROVADO" end
	local selo = Novo("TextLabel", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromScale(1, 0.5), Size = UDim2.fromOffset(190, 34),
		Text = estado, TextSize = 12, Font = FONTE_FORTE, Parent = topo })
	UI.Canto(selo, 17)
	if p.Aprovado and not p.Pendente then
		selo.BackgroundColor3 = COR.Branco
		selo.TextColor3 = COR.Fundo
	else
		selo.BackgroundColor3 = COR.Cartao
		selo.TextColor3 = COR.Branco
		UI.Contorno(selo, 0.4)
	end
	if p.Pendente then
		UI.Rotulo(m.Conteudo, "Este é um cheque. O resultado foi registrado e um instrutor vai confirmar a aprovação.", 13, { TextColor3 = COR.Sub, LayoutOrder = 2 })
	end
	UI.Secao(m.Conteudo, "Observações", 3)
	for i, l in ipairs(p.Linhas or {}) do
		local linha = Novo("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = 10 + i, Parent = m.Conteudo })
		Novo("Frame", { Size = UDim2.fromOffset(6, 6), Position = UDim2.fromOffset(2, 7), BackgroundColor3 = COR.Branco, Parent = linha }, { Novo("UICorner", { CornerRadius = UDim.new(1, 0) }) })
		UI.Rotulo(linha, l, 14, { Position = UDim2.fromOffset(18, 0), Size = UDim2.new(1, -18, 0, 18) })
	end
	UI.Botao(m.Rodape, "Concluir", "primario", function() m.Fechar() end, { Size = UDim2.fromOffset(150, 42) })
	return m
end
UI.Debriefing = debriefing

-- Caderneta do cadete
local nomesFase = {}
function UI.Caderneta(destaque)
	local Config = require(ReplicatedStorage:WaitForChild("FAB"):WaitForChild("Config"))
	for _, f in ipairs(Config.Fases) do nomesFase[f.Id] = f.Nome end
	local d = UI.Dados or { Atividades = {} }
	local m = UI.Modal({ Titulo = "Caderneta do Cadete", Sobretitulo = "Esquadrilha " .. tostring(d.Esquadrilha or "-"), Largura = 560, Altura = 620 })
	local resumo = Novo("Frame", { Size = UDim2.new(1, 0, 0, 64), BackgroundColor3 = COR.Elevado, LayoutOrder = 0, Parent = m.Conteudo })
	UI.Canto(resumo, 14)
	local feitos = 0
	for _, a in ipairs(Config.Atividades) do
		local r = d.Atividades[a.Id]
		if r and r.Aprovado then feitos = feitos + 1 end
	end
	local pct = feitos / #Config.Atividades
	local barra = Novo("Frame", { Position = UDim2.new(0, 16, 1, -16), Size = UDim2.new(1, -32, 0, 4), BackgroundColor3 = COR.Linha, BorderSizePixel = 0, Parent = resumo })
	UI.Canto(barra, 2)
	local cheio = Novo("Frame", { Size = UDim2.fromScale(pct, 1), BackgroundColor3 = COR.Branco, BorderSizePixel = 0, Parent = barra })
	UI.Canto(cheio, 2)
	UI.Rotulo(resumo, string.format("%d de %d atividades concluídas", feitos, #Config.Atividades), 15, { Font = FONTE_MEDIA,
		Position = UDim2.fromOffset(16, 12), Size = UDim2.new(1, -32, 0, 20), AutomaticSize = Enum.AutomaticSize.None })
	UI.Rotulo(resumo, string.format("Horas de simulador: %.1f", (d.HorasSimulador or 0) / 3600), 12, { TextColor3 = COR.Sub,
		Position = UDim2.fromOffset(16, 32), Size = UDim2.new(1, -32, 0, 14), AutomaticSize = Enum.AutomaticSize.None })
	local ordem = 1
	local faseAtual
	local function liberado(a)
		if d.ExigirRequisitos == false then return true end
		for _, req in ipairs(a.Requisitos or {}) do
			local r = d.Atividades[req]
			if not (r and r.Aprovado) then return false end
		end
		return true
	end
	for _, a in ipairs(Config.Atividades) do
		if a.Fase ~= faseAtual then
			faseAtual = a.Fase
			ordem = ordem + 1
			UI.Secao(m.Conteudo, nomesFase[a.Fase] or a.Fase, ordem)
		end
		ordem = ordem + 1
		local r = d.Atividades[a.Id]
		local estado, sub
		if r and r.Aprovado then
			estado = "Aprovado"
			sub = string.format("Nota %.1f", r.Nota or 0):gsub("%.", ",", 1)
		elseif r and r.Pendente then
			estado = "Aguardando"
			sub = "Cheque aguardando o instrutor"
		elseif liberado(a) then
			estado = "Disponível"
			sub = a.Descricao or ""
			if r and r.Tentativas then sub = "Tentativas: " .. r.Tentativas .. (r.UltimaNota and string.format(" · última nota %.1f", r.UltimaNota) or "") end
		else
			estado = "Bloqueado"
			sub = "Conclua as etapas anteriores"
		end
		local item = UI.Item(m.Conteudo, a.Nome, sub, estado, nil, ordem)
		if destaque == a.Id then UI.Contorno(item, 0.2, 2) end
	end
	UI.Botao(m.Rodape, "Fechar", "secundario", function() m.Fechar() end, { Size = UDim2.fromOffset(130, 42) })
	return m
end

-- Inicializa handlers basicos e o botao da caderneta
function UI.Iniciar()
	UI.Tela()
	UI.Conectar()
	UI.Registrar("Debriefing", debriefing)
	UI.Registrar("Bloqueado", function(p)
		local Config = require(ReplicatedStorage:WaitForChild("FAB"):WaitForChild("Config"))
		local a = Config.PorId[p.Atividade]
		local m = UI.Modal({ Titulo = a and a.Nome or "Atividade", Sobretitulo = "Requisitos", Largura = 480, Altura = 420 })
		UI.Rotulo(m.Conteudo, "Para fazer esta atividade, conclua antes:", 14, { TextColor3 = COR.Sub, LayoutOrder = 1 })
		for i, nome in ipairs(p.Faltando or {}) do
			UI.Item(m.Conteudo, nome, "Pendente", "Pendente", nil, 1 + i)
		end
		UI.Botao(m.Rodape, "Ver caderneta", "secundario", function() m.Fechar() UI.Caderneta(p.Atividade) end, { Size = UDim2.fromOffset(150, 42), LayoutOrder = 1 })
		UI.Botao(m.Rodape, "Entendido", "primario", function() m.Fechar() end, { Size = UDim2.fromOffset(130, 42), LayoutOrder = 2 })
	end)
	local barra = Novo("Frame", {
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 14), Size = UDim2.fromOffset(0, 36),
		AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1, Name = "BarraSuperior", Parent = UI.Tela(),
	})
	Novo("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), HorizontalAlignment = Enum.HorizontalAlignment.Right, Parent = barra })
	UI.BarraSuperior = barra
	UI.Botao(barra, "CADERNETA", "secundario", function() UI.Caderneta() end, { Size = UDim2.fromOffset(118, 36), TextSize = 12, LayoutOrder = 2 })
end

return UI
