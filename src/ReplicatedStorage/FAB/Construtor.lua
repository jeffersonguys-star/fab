--[[
	FAB - Construtor (ModuleScript)

	Funcoes para montar modelos por codigo: pecas, cilindros entre dois pontos,
	luzes, telas (SurfaceGui), corrimoes, escadas e uniao de pecas (GeometryService).
	Usado pelo mapa, pela maquina do simulador e pela cabine 3D.
]]

local C = {}

local function aplicar(obj, props)
	if props then
		for k, v in pairs(props) do
			if k ~= "Parent" then obj[k] = v end
		end
		if props.Parent then obj.Parent = props.Parent end
	end
	return obj
end
C.Aplicar = aplicar

function C.Novo(classe, props)
	return aplicar(Instance.new(classe), props)
end

-- Peca ancorada padrao
function C.Parte(pai, nome, tamanho, cf, cor, material, extra)
	local p = Instance.new("Part")
	p.Name = nome or "Parte"
	p.Anchored = true
	p.Size = tamanho
	p.CFrame = cf
	p.Color = cor or Color3.fromRGB(200, 200, 200)
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	aplicar(p, extra)
	p.Parent = pai
	return p
end

function C.Cilindro(pai, nome, diametro, comprimento, cf, cor, material, extra)
	-- o eixo do cilindro do Roblox e o X; cf aponta o eixo para X
	local p = C.Parte(pai, nome, Vector3.new(comprimento, diametro, diametro), cf, cor, material, extra)
	p.Shape = Enum.PartType.Cylinder
	return p
end

function C.Esfera(pai, nome, diametro, cf, cor, material, extra)
	local p = C.Parte(pai, nome, Vector3.new(diametro, diametro, diametro), cf, cor, material, extra)
	p.Shape = Enum.PartType.Ball
	return p
end

function C.Cunha(pai, nome, tamanho, cf, cor, material, extra)
	local p = Instance.new("WedgePart")
	p.Name = nome or "Cunha"
	p.Anchored = true
	p.Size = tamanho
	p.CFrame = cf
	p.Color = cor or Color3.fromRGB(200, 200, 200)
	p.Material = material or Enum.Material.SmoothPlastic
	aplicar(p, extra)
	p.Parent = pai
	return p
end

-- Cilindro ligando dois pontos (tubos, atuadores, cabos)
function C.CFrameEntre(a, b)
	local meio = (a + b) / 2
	local dir = b - a
	local cf = CFrame.lookAt(meio, b)
	-- gira para o eixo X ficar ao longo da direcao
	return cf * CFrame.Angles(0, math.rad(90), 0), dir.Magnitude
end

function C.Tubo(pai, nome, a, b, diametro, cor, material, extra)
	local cf, comp = C.CFrameEntre(a, b)
	return C.Cilindro(pai, nome, diametro, comp, cf, cor, material, extra)
end

-- Barra retangular entre dois pontos
function C.Barra(pai, nome, a, b, espessura, cor, material, extra)
	local meio = (a + b) / 2
	local comp = (b - a).Magnitude
	return C.Parte(pai, nome, Vector3.new(espessura, espessura, comp), CFrame.lookAt(meio, b), cor, material, extra)
end

function C.Luz(parte, classe, props)
	local l = Instance.new(classe or "PointLight")
	aplicar(l, props)
	l.Parent = parte
	return l
end

-- Tela com texto (SurfaceGui)
function C.Tela(parte, face, pixelsPorStud)
	local g = Instance.new("SurfaceGui")
	g.Face = face or Enum.NormalId.Front
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = pixelsPorStud or 50
	g.LightInfluence = 0
	g.Brightness = 1.5
	g.ZOffset = 0.5
	g.Parent = parte
	return g
end

function C.Texto(pai, texto, props)
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.Text = texto or ""
	t.TextColor3 = Color3.new(1, 1, 1)
	t.Font = Enum.Font.GothamBold
	t.TextScaled = true
	aplicar(t, props)
	t.Parent = pai
	return t
end

-- Une pecas (CSG). Se o GeometryService falhar, devolve as pecas originais.
function C.Unir(principal, outras, subtrair)
	local GeometryService = game:GetService("GeometryService")
	local ok, resultado = pcall(function()
		if subtrair then
			return GeometryService:SubtractAsync(principal, outras, { CollisionFidelity = Enum.CollisionFidelity.PreciseConvexDecomposition })
		end
		return GeometryService:UnionAsync(principal, outras, { CollisionFidelity = Enum.CollisionFidelity.PreciseConvexDecomposition })
	end)
	if ok and resultado and resultado[1] then
		local u = resultado[1]
		u.Anchored = true
		u.Name = principal.Name
		u.Color = principal.Color
		u.Material = principal.Material
		u.UsePartColor = true
		u.Parent = principal.Parent
		principal:Destroy()
		for _, o in ipairs(outras) do o:Destroy() end
		return u, true
	end
	if subtrair then
		for _, o in ipairs(outras) do o:Destroy() end
	end
	return principal, false
end

-- Corrimao ao longo de uma lista de pontos
function C.Corrimao(pai, pontos, altura, cor)
	cor = cor or Color3.fromRGB(240, 190, 30)
	for i = 1, #pontos - 1 do
		local a, b = pontos[i], pontos[i + 1]
		C.Tubo(pai, "Corrimao", a + Vector3.new(0, altura, 0), b + Vector3.new(0, altura, 0), 0.25, cor, Enum.Material.Metal)
		C.Tubo(pai, "CorrimaoMeio", a + Vector3.new(0, altura * 0.5, 0), b + Vector3.new(0, altura * 0.5, 0), 0.18, cor, Enum.Material.Metal)
	end
	for _, p in ipairs(pontos) do
		C.Tubo(pai, "Poste", p, p + Vector3.new(0, altura, 0), 0.25, cor, Enum.Material.Metal)
	end
end

-- Escada de degraus subindo ao longo do LookVector de cf
function C.Escada(pai, cf, largura, altura, degraus, cor)
	local profundidade = 1.1
	local passoAltura = altura / degraus
	for i = 1, degraus do
		C.Parte(pai, "Degrau", Vector3.new(largura, passoAltura, profundidade),
			cf * CFrame.new(0, passoAltura * (i - 0.5), -profundidade * (i - 0.5)),
			cor or Color3.fromRGB(70, 72, 76), Enum.Material.DiamondPlate)
	end
end

-- Faixa zebrada (amarelo e preto) com SurfaceGui
function C.Zebrado(parte, face)
	local g = C.Tela(parte, face or Enum.NormalId.Top, 10)
	local f = Instance.new("Frame")
	f.Size = UDim2.fromScale(1, 1)
	f.BackgroundColor3 = Color3.fromRGB(245, 195, 20)
	f.BorderSizePixel = 0
	f.Parent = g
	local grad = Instance.new("UIGradient")
	local pontos = {}
	local n = 9 -- ColorSequence aceita no maximo 20 pontos
	for i = 0, n do
		local t = i / n
		local preto = (i % 2 == 0)
		table.insert(pontos, ColorSequenceKeypoint.new(t, preto and Color3.fromRGB(20, 20, 20) or Color3.fromRGB(245, 195, 20)))
	end
	-- cria listras usando mudancas abruptas
	local seq = {}
	for i = 0, n - 1 do
		local cor = (i % 2 == 0) and Color3.fromRGB(20, 20, 20) or Color3.fromRGB(245, 195, 20)
		table.insert(seq, ColorSequenceKeypoint.new(i / n, cor))
		table.insert(seq, ColorSequenceKeypoint.new(math.min(1, (i + 1) / n - 0.0001), cor))
	end
	table.insert(seq, ColorSequenceKeypoint.new(1, (n % 2 == 0) and Color3.fromRGB(245, 195, 20) or Color3.fromRGB(20, 20, 20)))
	local ok = pcall(function() grad.Color = ColorSequence.new(seq) end)
	if not ok then grad.Color = ColorSequence.new(pontos) end
	grad.Rotation = 45
	grad.Parent = f
	return g
end

return C
