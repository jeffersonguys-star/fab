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
	if correcao then correcao:Destroy() correcao = nil end
	if desfoque then desfoque:Destroy() desfoque = nil end
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
			p.Eficiencia = math.max(0.15, 1 - (semRespirar - 3.5) / 3)
		elseif semRespirar < 0.45 then
			p.Eficiencia = 0.55 -- durante a inspiracao rapida
		else
			p.Eficiencia = 1
		end
	else
		p.TempoContracao = 0
		p.Eficiencia = 0
	end
	local tol = p.Tolerancia + (p.Traje or 0) + (p.Contraindo and 3.2 * p.Eficiencia or 0)
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
	return efeitos
end

return F
