--[[
	FAB - Fisiologia do piloto (ModuleScript, cliente)

	Modelo de tolerancia a G e efeitos visuais na tela:
	- G positivo: perda da visao periferica (tunel), visao cinza (greyout),
	  apagao (blackout) e perda de consciencia (G-LOC)
	- G negativo: visao avermelhada (redout)
	- Manobra anti-G (AGSM): contrair a musculatura aumenta a tolerancia em ~2,3 G,
	  mas so funciona com respiracoes curtas a cada ~3 segundos
	- Hipoxia: visao turva, perda de cores e de contraste

	Usado pela centrifuga e pelo simulador de voo.
]]

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")

local F = {}

local painel
local tela, tunel, traco, cinza, preto, vermelho, vinhetas
local correcao, desfoque

function F.Criar()
	if tela and tela.Parent then return end
	tela = Instance.new("ScreenGui")
	tela.Name = "FABFisiologia"
	tela.IgnoreGuiInset = true
	tela.ResetOnSpawn = false
	tela.DisplayOrder = 5
	tela.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	-- tunel: circulo transparente com borda preta enorme
	tunel = Instance.new("Frame")
	tunel.AnchorPoint = Vector2.new(0.5, 0.5)
	tunel.Position = UDim2.fromScale(0.5, 0.5)
	tunel.BackgroundTransparency = 1
	tunel.Size = UDim2.fromScale(2.6, 2.6)
	local ar = Instance.new("UIAspectRatioConstraint")
	ar.AspectRatio = 1
	ar.DominantAxis = Enum.DominantAxis.Width
	ar.Parent = tunel
	local canto = Instance.new("UICorner")
	canto.CornerRadius = UDim.new(1, 0)
	canto.Parent = tunel
	traco = Instance.new("UIStroke")
	traco.Color = Color3.new(0, 0, 0)
	traco.Thickness = 3000
	traco.Transparency = 1
	traco.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	traco.Parent = tunel
	local grad = Instance.new("UIGradient")
	grad.Parent = traco
	tunel.Parent = tela
	local function camada(cor)
		local f = Instance.new("Frame")
		f.Size = UDim2.fromScale(1, 1)
		f.BackgroundColor3 = cor
		f.BackgroundTransparency = 1
		f.BorderSizePixel = 0
		f.Parent = tela
		return f
	end
	-- vinheta nas bordas (reforca o tunel em qualquer tamanho de tela)
	vinhetas = {}
	for i, cfg in ipairs({ { 0, 0, 1, 0, 90 }, { 0, 1, 1, 0, -90 }, { 0, 0, 0, 1, 0 }, { 1, 0, 0, 1, 180 } }) do
		local f = Instance.new("Frame")
		f.BackgroundColor3 = Color3.new(0, 0, 0)
		f.BorderSizePixel = 0
		f.AnchorPoint = Vector2.new(cfg[1], cfg[2])
		f.Position = UDim2.fromScale(cfg[1], cfg[2])
		f.Size = UDim2.fromScale(cfg[3], cfg[4])
		f.Parent = tela
		local gr = Instance.new("UIGradient")
		gr.Rotation = cfg[5]
		gr.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
		gr.Parent = f
		vinhetas[i] = { Quadro = f, Horizontal = cfg[3] == 0 }
	end
	cinza = camada(Color3.fromRGB(120, 120, 120))
	vermelho = camada(Color3.fromRGB(160, 0, 0))
	preto = camada(Color3.new(0, 0, 0))
	correcao = Instance.new("ColorCorrectionEffect")
	correcao.Name = "FABFisiologia"
	correcao.Parent = Lighting
	desfoque = Instance.new("BlurEffect")
	desfoque.Name = "FABFisiologia"
	desfoque.Size = 0
	desfoque.Parent = Lighting
end

-- Aplica os efeitos. tunel/cinza/apagao/vermelho/hipoxia de 0 a 1.
function F.Definir(e)
	F.Criar()
	local t = e.Tunel or 0
	local hip = e.Hipoxia or 0
	-- o circulo encolhe de 2,6 telas ate 0,15 tela
	local raio = 2.6 - 2.45 * math.clamp(math.max(t, hip * 0.6), 0, 1)
	tunel.Size = UDim2.fromScale(raio, raio)
	traco.Transparency = (t <= 0.01 and hip <= 0.01) and 1 or 0
	local k = math.clamp(math.max(t, hip * 0.6), 0, 1)
	for _, v in ipairs(vinhetas) do
		local tam = 0.5 * k
		v.Quadro.Size = v.Horizontal and UDim2.fromScale(tam, 1) or UDim2.fromScale(1, tam)
		v.Quadro.Visible = k > 0.01
	end
	cinza.BackgroundTransparency = 1 - 0.55 * math.clamp(e.Cinza or 0, 0, 1)
	preto.BackgroundTransparency = 1 - math.clamp(e.Apagao or 0, 0, 1)
	vermelho.BackgroundTransparency = 1 - 0.5 * math.clamp(e.Vermelho or 0, 0, 1)
	correcao.Saturation = -math.clamp((e.Cinza or 0) * 0.9 + hip * 0.75, 0, 1)
	correcao.Brightness = -0.25 * hip - 0.15 * (e.Cinza or 0)
	correcao.Contrast = -0.3 * hip
	desfoque.Size = 18 * hip + 6 * (e.Cinza or 0)
end

function F.Limpar()
	if tela then tela:Destroy() tela = nil end
	painel = nil
	if correcao then correcao:Destroy() correcao = nil end
	if desfoque then desfoque:Destroy() desfoque = nil end
end

-- Painel de G: valor, reserva de tolerancia e estado da manobra anti-G ---------------------
function F.Painel(p, g)
	if not tela or not tela.Parent then return end
	if not painel then
		local q = Instance.new("Frame")
		q.Name = "PainelG"
		q.Position = UDim2.fromScale(0.3, 0.012)
		q.Size = UDim2.fromScale(0.145, 0.085)
		q.BackgroundColor3 = Color3.fromRGB(8, 10, 12)
		q.BackgroundTransparency = 0.25
		q.BorderSizePixel = 0
		q.Parent = tela
		local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 8) c.Parent = q
		local t = Instance.new("TextLabel")
		t.Name = "Texto"
		t.BackgroundTransparency = 1
		t.Size = UDim2.fromScale(1, 0.5)
		t.Position = UDim2.fromScale(0, 0.04)
		t.Font = Enum.Font.GothamBold
		t.TextScaled = true
		t.TextColor3 = Color3.fromRGB(235, 240, 235)
		t.Parent = q
		local fundo = Instance.new("Frame")
		fundo.Name = "Fundo"
		fundo.Position = UDim2.fromScale(0.06, 0.58)
		fundo.Size = UDim2.fromScale(0.88, 0.14)
		fundo.BackgroundColor3 = Color3.fromRGB(40, 44, 48)
		fundo.BorderSizePixel = 0
		fundo.Parent = q
		local barra = Instance.new("Frame")
		barra.Name = "Barra"
		barra.Size = UDim2.fromScale(1, 1)
		barra.BorderSizePixel = 0
		barra.Parent = fundo
		local d = Instance.new("TextLabel")
		d.Name = "Dica"
		d.BackgroundTransparency = 1
		d.Position = UDim2.fromScale(0, 0.75)
		d.Size = UDim2.fromScale(1, 0.23)
		d.Font = Enum.Font.GothamMedium
		d.TextScaled = true
		d.TextColor3 = Color3.fromRGB(190, 200, 190)
		d.Parent = q
		painel = q
	end
	local reserva = math.clamp(1 - p.S / 1.0, 0, 1)
	local ativo = g > 1.6 or p.S > 0.04 or p.Contraindo
	painel.Visible = ativo
	if not ativo then return end
	painel.Texto.Text = string.format("%.1f G", g)
	local b = painel.Fundo.Barra
	b.Size = UDim2.fromScale(reserva, 1)
	b.BackgroundColor3 = reserva > 0.6 and Color3.fromRGB(80, 200, 110) or (reserva > 0.3 and Color3.fromRGB(235, 190, 60) or Color3.fromRGB(230, 70, 60))
	local dica
	if p.GLOC then dica = "G-LOC"
	elseif p.Contraindo then
		local sem = p.Relogio - p.UltimaRespiracao
		dica = (sem > 2.8) and "RESPIRE" or "ANTI-G ATIVO"
	elseif g > 3.2 then dica = "SEGURE ANTI-G"
	else dica = "TRAJE AUTOMATICO" end
	painel.Dica.Text = dica
end

-- Modelo de tolerancia a G ------------------------------------------------------
function F.NovoPiloto(tolerancia)
	return {
		Tolerancia = tolerancia or 4.4, -- G relaxado em que comeca o apagao
		S = 0,                          -- deficit de oxigenacao da retina/cerebro (0 a 1,2)
		Contraindo = false,
		TempoContracao = 0,
		UltimaRespiracao = -100,
		Relogio = 0,
		GLOC = false,
		FimGLOC = 0,
		Eficiencia = 1,
	}
end

function F.Respirar(p)
	p.UltimaRespiracao = p.Relogio
end

-- Atualiza o modelo e devolve os efeitos visuais
function F.AtualizarG(p, g, dt)
	p.Relogio = p.Relogio + dt
	-- eficiencia da manobra anti-G
	local semRespirar = p.Relogio - p.UltimaRespiracao
	if p.Contraindo then
		p.TempoContracao = p.TempoContracao + dt
		if semRespirar > 3.5 then
			-- prender o ar demais reduz o retorno venoso
			p.Eficiencia = math.max(0.6, 1 - (semRespirar - 3.5) / 6)
		elseif semRespirar < 0.45 then
			p.Eficiencia = 0.8 -- durante a inspiracao rapida
		else
			p.Eficiencia = 1
		end
		if semRespirar > 3.5 then p.Eficiencia = math.max(p.Eficiencia, 0.6) end
	else
		p.TempoContracao = 0
		p.Eficiencia = 0
	end
	-- o traje anti-G enche sozinho conforme o G sobe (valvula automatica)
	local traje = (p.Traje or 0) * math.clamp((g - 1.8) / 2.2, 0, 1)
	local tol = p.Tolerancia + traje + (p.Contraindo and 3.2 * p.Eficiencia or 0)
	local inicio = tol * 0.82
	local alvo = math.clamp((g - inicio) / (tol * 0.32), 0, 1.3)
	local tau = (alvo > p.S) and 3.2 or 1.4
	p.S = p.S + (alvo - p.S) * math.min(1, dt / tau)
	local efeitos = {
		Tunel = math.clamp(p.S / 0.6, 0, 1),
		Cinza = math.clamp((p.S - 0.45) / 0.35, 0, 1),
		Apagao = math.clamp((p.S - 0.85) / 0.2, 0, 1),
		Vermelho = math.clamp((-g - 1.5) / 1.5, 0, 1),
	}
	if not p.GLOC and p.S >= 1.12 then
		p.GLOC = true
		p.FimGLOC = p.Relogio + 12
	end
	if p.GLOC then
		efeitos.Apagao = 1
		efeitos.Tunel = 1
		if p.Relogio > p.FimGLOC and g < 2.5 then
			p.GLOC = false
			p.S = 0.6
		end
	end
	efeitos.GLOC = p.GLOC
	p.Tol = tol
	return efeitos
end

return F
