--[[
	FAB - Viaturas e equipamentos de apoio em solo (ModuleScript)

	Viaturas militares e de servico montadas por partes: jipe 4x4, onibus, ambulancia,
	caminhao-tanque de combustivel, trator de reboque, unidade de energia (GPU), carro
	de passeio e escada de embarque. Posicionadas no patio, na entrada, no hospital e na vila.
	Frente de cada veiculo voltada para -Z do CFrame recebido (origem no chao).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local FAB = ReplicatedStorage:WaitForChild("FAB")
local C = require(FAB:WaitForChild("Construtor"))
local MD = require(FAB:WaitForChild("MapaDados"))

local VE = {}

local PRETO = Color3.fromRGB(22, 22, 24)
local VIDRO = Color3.fromRGB(70, 96, 116)
local FAROL = Color3.fromRGB(255, 244, 210)
local PLAS, MET, BORR = Enum.Material.SmoothPlastic, Enum.Material.Metal, Enum.Material.Rubber

local function roda(pai, cf, x, y, z, d, larg)
	C.Cilindro(pai, "Pneu", d, larg, cf * CFrame.new(x, y, z), PRETO, BORR)
	C.Cilindro(pai, "Calota", d * 0.55, larg + 0.1, cf * CFrame.new(x + (x > 0 and 0.05 or -0.05), y, z), Color3.fromRGB(176, 178, 182), MET)
end

local function modelo(pai, nome)
	local m = Instance.new("Model")
	m.Name = nome
	m.Parent = pai
	return m
end

local function luzes(m, cf, larg, zFrente, y, zTras)
	for _, s in ipairs({ -1, 1 }) do
		C.Parte(m, "Farol", Vector3.new(1.4, 0.9, 0.3), cf * CFrame.new(s * (larg / 2 - 1.4), y, zFrente), FAROL, Enum.Material.Neon, { CanCollide = false })
		C.Parte(m, "Lanterna", Vector3.new(1.2, 0.8, 0.3), cf * CFrame.new(s * (larg / 2 - 1.2), y, zTras), Color3.fromRGB(200, 30, 30), Enum.Material.Neon, { CanCollide = false })
	end
end

-- Jipe 4x4 (estilo Marrua)
function VE.Jipe(pai, cf, cor)
	local m = modelo(pai, "Jipe")
	cor = cor or Color3.fromRGB(86, 94, 62)
	C.Parte(m, "Chassi", Vector3.new(6.2, 1, 15), cf * CFrame.new(0, 2.6, 0), PRETO, MET)
	C.Parte(m, "Capo", Vector3.new(6, 2.4, 5), cf * CFrame.new(0, 4.4, -4.6), cor, PLAS)
	C.Parte(m, "Corpo", Vector3.new(6.2, 3.6, 8.2), cf * CFrame.new(0, 4.9, 3), cor, PLAS)
	C.Parte(m, "Cabine", Vector3.new(6, 2.6, 4.6), cf * CFrame.new(0, 7.6, 1.4), cor, PLAS)
	C.Parte(m, "Teto", Vector3.new(6.3, 0.5, 5), cf * CFrame.new(0, 9, 1.4), cor, PLAS)
	C.Parte(m, "Parabrisa", Vector3.new(5.4, 2.3, 0.3), cf * CFrame.new(0, 7.7, -0.9) * CFrame.Angles(math.rad(-12), 0, 0), VIDRO, Enum.Material.Glass, { Transparency = 0.35 })
	for _, s in ipairs({ -1, 1 }) do
		C.Parte(m, "VidroLado", Vector3.new(0.3, 2, 3.6), cf * CFrame.new(s * 3.05, 7.7, 1.6), VIDRO, Enum.Material.Glass, { Transparency = 0.35 })
	end
	C.Parte(m, "Para-choque", Vector3.new(6.6, 0.8, 0.7), cf * CFrame.new(0, 3, -7.4), PRETO, MET)
	C.Parte(m, "GradeFrente", Vector3.new(4, 1.4, 0.3), cf * CFrame.new(0, 4.4, -7.2), Color3.fromRGB(40, 42, 40), MET)
	C.Parte(m, "Estepe", Vector3.new(1, 3, 3), cf * CFrame.new(0, 5.6, 7.4), PRETO, BORR)
	luzes(m, cf, 6.2, -7.3, 4.6, 7.2)
	for _, z in ipairs({ -4.6, 4.6 }) do
		for _, s in ipairs({ -1, 1 }) do roda(m, cf, s * 3.4, 2.2, z, 4.4, 1.6) end
	end
	C.Parte(m, "Placa", Vector3.new(2.2, 0.7, 0.1), cf * CFrame.new(0, 3.2, 7.6), Color3.fromRGB(240, 240, 230), PLAS, { CanCollide = false })
	return m
end

-- Carro de passeio
function VE.Carro(pai, cf, cor)
	local m = modelo(pai, "Carro")
	cor = cor or Color3.fromRGB(230, 230, 228)
	C.Parte(m, "Chassi", Vector3.new(6, 1.4, 15), cf * CFrame.new(0, 2.2, 0), cor, PLAS)
	C.Parte(m, "Capo", Vector3.new(5.8, 1.2, 4.2), cf * CFrame.new(0, 3.2, -5.2), cor, PLAS)
	C.Parte(m, "Porta-malas", Vector3.new(5.8, 1.4, 3.6), cf * CFrame.new(0, 3.3, 5.6), cor, PLAS)
	C.Parte(m, "Cabine", Vector3.new(5.6, 2.2, 6.4), cf * CFrame.new(0, 4.6, 0.4), VIDRO, Enum.Material.Glass, { Transparency = 0.25 })
	C.Parte(m, "Teto", Vector3.new(5.4, 0.3, 5.2), cf * CFrame.new(0, 5.8, 0.4), cor, PLAS)
	luzes(m, cf, 6, -7.3, 3.2, 7.3)
	for _, z in ipairs({ -4.6, 4.8 }) do
		for _, s in ipairs({ -1, 1 }) do roda(m, cf, s * 3, 1.5, z, 3, 1.2) end
	end
	return m
end

-- Onibus de transporte de pessoal
function VE.Onibus(pai, cf)
	local m = modelo(pai, "Onibus")
	C.Parte(m, "Carroceria", Vector3.new(8.4, 8.6, 38), cf * CFrame.new(0, 6, 0), Color3.fromRGB(240, 240, 236), PLAS)
	C.Parte(m, "FaixaAzul", Vector3.new(8.6, 1.6, 38.1), cf * CFrame.new(0, 3.9, 0), Color3.fromRGB(24, 52, 110), PLAS)
	C.Parte(m, "FaixaVerde", Vector3.new(8.6, 0.5, 38.1), cf * CFrame.new(0, 5.2, 0), Color3.fromRGB(0, 151, 57), PLAS)
	for _, s in ipairs({ -1, 1 }) do
		C.Parte(m, "Janelas", Vector3.new(0.3, 3, 30), cf * CFrame.new(s * 4.25, 7.8, 1.5), VIDRO, Enum.Material.Glass, { Transparency = 0.3 })
	end
	C.Parte(m, "Parabrisa", Vector3.new(7.4, 4.4, 0.3), cf * CFrame.new(0, 8, -19.1), VIDRO, Enum.Material.Glass, { Transparency = 0.3 })
	C.Parte(m, "Letreiro", Vector3.new(6, 1, 0.3), cf * CFrame.new(0, 10.8, -19.15), Color3.fromRGB(255, 160, 30), Enum.Material.Neon, { CanCollide = false })
	C.Parte(m, "Para-choque", Vector3.new(8.6, 1, 0.8), cf * CFrame.new(0, 2.6, -19.2), PRETO, MET)
	C.Parte(m, "Ar", Vector3.new(5, 1, 8), cf * CFrame.new(0, 10.8, 6), Color3.fromRGB(200, 200, 200), MET)
	luzes(m, cf, 8.4, -19.2, 3.6, 19.2)
	for _, z in ipairs({ -12, 11, 15 }) do
		for _, s in ipairs({ -1, 1 }) do roda(m, cf, s * 4.3, 2.6, z, 5.2, 1.8) end
	end
	return m
end

-- Ambulancia
function VE.Ambulancia(pai, cf)
	local m = modelo(pai, "Ambulancia")
	C.Parte(m, "Chassi", Vector3.new(7, 1, 18), cf * CFrame.new(0, 2.6, 0), PRETO, MET)
	C.Parte(m, "Cabine", Vector3.new(6.8, 5, 5.5), cf * CFrame.new(0, 5.5, -5.2), Color3.fromRGB(244, 244, 240), PLAS)
	C.Parte(m, "Baú", Vector3.new(7, 6.4, 10), cf * CFrame.new(0, 6.2, 3.6), Color3.fromRGB(244, 244, 240), PLAS)
	C.Parte(m, "Parabrisa", Vector3.new(6, 2.6, 0.3), cf * CFrame.new(0, 6.4, -8) * CFrame.Angles(math.rad(-12), 0, 0), VIDRO, Enum.Material.Glass, { Transparency = 0.3 })
	for _, s in ipairs({ -1, 1 }) do
		C.Parte(m, "FaixaVermelha", Vector3.new(0.2, 1, 14), cf * CFrame.new(s * 3.55, 5.4, 0), Color3.fromRGB(200, 30, 30), PLAS, { CanCollide = false })
		C.Parte(m, "CruzV", Vector3.new(0.2, 3.2, 0.9), cf * CFrame.new(s * 3.55, 7, 4.4), Color3.fromRGB(200, 30, 30), PLAS, { CanCollide = false })
		C.Parte(m, "CruzH", Vector3.new(0.2, 0.9, 3.2), cf * CFrame.new(s * 3.55, 7, 4.4), Color3.fromRGB(200, 30, 30), PLAS, { CanCollide = false })
	end
	local g = C.Parte(m, "Giroflex", Vector3.new(5, 0.6, 1.2), cf * CFrame.new(0, 9.1, -5.2), Color3.fromRGB(255, 40, 40), Enum.Material.Neon, { CanCollide = false })
	C.Parte(m, "GiroflexAzul", Vector3.new(2, 0.6, 1.2), cf * CFrame.new(0, 9.1, -5.2), Color3.fromRGB(40, 80, 255), Enum.Material.Neon, { CanCollide = false })
	luzes(m, cf, 7, -8, 4.2, 8.6)
	for _, z in ipairs({ -5.4, 5.4 }) do
		for _, s in ipairs({ -1, 1 }) do roda(m, cf, s * 3.6, 2.2, z, 4.4, 1.6) end
	end
	return m
end

-- Caminhao-tanque de abastecimento de aeronaves
function VE.Tanque(pai, cf)
	local m = modelo(pai, "CaminhaoTanque")
	C.Parte(m, "Chassi", Vector3.new(7, 1, 30), cf * CFrame.new(0, 2.6, 0), PRETO, MET)
	C.Parte(m, "Cabine", Vector3.new(7.2, 6, 6), cf * CFrame.new(0, 6, -11.5), Color3.fromRGB(240, 240, 236), PLAS)
	C.Parte(m, "FaixaCabine", Vector3.new(7.3, 1.2, 6.1), cf * CFrame.new(0, 4.2, -11.5), Color3.fromRGB(24, 52, 110), PLAS)
	C.Parte(m, "Parabrisa", Vector3.new(6.2, 3, 0.3), cf * CFrame.new(0, 7.2, -14.6), VIDRO, Enum.Material.Glass, { Transparency = 0.3 })
	C.Cilindro(m, "Tanque", 7.6, 18, cf * CFrame.new(0, 7.6, 5) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(246, 246, 242), MET)
	C.Parte(m, "FaixaTanque", Vector3.new(7.8, 1.2, 18.1), cf * CFrame.new(0, 7.6, 5), Color3.fromRGB(24, 52, 110), PLAS, { CanCollide = false })
	C.Parte(m, "FaixaAmarela", Vector3.new(7.9, 0.5, 18.2), cf * CFrame.new(0, 8.6, 5), Color3.fromRGB(240, 200, 30), PLAS, { CanCollide = false })
	C.Parte(m, "Escotilha", Vector3.new(2.2, 0.5, 2.2), cf * CFrame.new(0, 11.6, 5), Color3.fromRGB(150, 152, 156), MET)
	C.Parte(m, "CaixaMangueira", Vector3.new(7.4, 2.6, 4), cf * CFrame.new(0, 3.6, 14.6), Color3.fromRGB(200, 200, 196), MET)
	C.Tubo(m, "Mangueira", (cf * CFrame.new(3.4, 4, 14)).Position, (cf * CFrame.new(3.4, 1.6, 17)).Position, 0.5, Color3.fromRGB(240, 200, 30), BORR)
	luzes(m, cf, 7.2, -14.6, 3.4, 16.2)
	for _, z in ipairs({ -11, 4, 9 }) do
		for _, s in ipairs({ -1, 1 }) do roda(m, cf, s * 3.7, 2.6, z, 5.2, 1.8) end
	end
	return m
end

-- Trator de reboque de aeronaves
function VE.Trator(pai, cf)
	local m = modelo(pai, "TratorReboque")
	C.Parte(m, "Corpo", Vector3.new(7, 3.4, 13), cf * CFrame.new(0, 3.2, 0), Color3.fromRGB(86, 94, 62), PLAS)
	C.Parte(m, "Cabine", Vector3.new(6, 4.4, 5), cf * CFrame.new(0, 7.2, 0.8), Color3.fromRGB(86, 94, 62), PLAS)
	C.Parte(m, "VidroCabine", Vector3.new(6.1, 3, 4.2), cf * CFrame.new(0, 7.5, 0.8), VIDRO, Enum.Material.Glass, { Transparency = 0.45 })
	C.Parte(m, "Teto", Vector3.new(6.6, 0.4, 5.6), cf * CFrame.new(0, 9.6, 0.8), Color3.fromRGB(70, 76, 50), PLAS)
	C.Parte(m, "Contrapeso", Vector3.new(7, 2, 2.4), cf * CFrame.new(0, 3.6, 7), Color3.fromRGB(60, 62, 56), MET)
	C.Parte(m, "BarraReboque", Vector3.new(1.2, 1.2, 6), cf * CFrame.new(0, 3.4, -9.5), Color3.fromRGB(240, 200, 30), MET)
	C.Parte(m, "Giroflex", Vector3.new(2, 0.6, 1), cf * CFrame.new(0, 10, 0.8), Color3.fromRGB(255, 170, 30), Enum.Material.Neon, { CanCollide = false })
	for _, z in ipairs({ -3.6, 3.6 }) do
		for _, s in ipairs({ -1, 1 }) do roda(m, cf, s * 3.8, 2.4, z, 4.8, 2) end
	end
	return m
end

-- Unidade de energia de solo (GPU)
function VE.GPU(pai, cf)
	local m = modelo(pai, "GPU")
	C.Parte(m, "Corpo", Vector3.new(4.4, 4.6, 7), cf * CFrame.new(0, 3.6, 0), Color3.fromRGB(240, 200, 30), PLAS)
	C.Parte(m, "Painel", Vector3.new(4.5, 1.8, 0.3), cf * CFrame.new(0, 4.6, -3.55), Color3.fromRGB(40, 42, 46), PLAS, { CanCollide = false })
	C.Parte(m, "Timão", Vector3.new(0.5, 0.5, 4), cf * CFrame.new(0, 2.4, -5.4), PRETO, MET)
	C.Tubo(m, "Cabo", (cf * CFrame.new(2.2, 3, 3.2)).Position, (cf * CFrame.new(5, 0.5, 6)).Position, 0.4, PRETO, BORR)
	for _, s in ipairs({ -1, 1 }) do roda(m, cf, s * 2.4, 1.6, 2, 3.2, 1) end
	return m
end

-- Escada de embarque (para cacas)
function VE.Escada(pai, cf)
	local m = modelo(pai, "EscadaEmbarque")
	C.Parte(m, "Plataforma", Vector3.new(4, 0.4, 4), cf * CFrame.new(0, 9, 0), Color3.fromRGB(240, 200, 30), MET)
	for i = 0, 8 do
		C.Parte(m, "Degrau", Vector3.new(4, 0.3, 1.4), cf * CFrame.new(0, 0.6 + i * 1, 2.6 + (8 - i) * 1.3), Color3.fromRGB(200, 200, 196), Enum.Material.DiamondPlate)
	end
	for _, s in ipairs({ -1, 1 }) do
		C.Tubo(m, "Corrimao", (cf * CFrame.new(s * 2, 10.6, 0)).Position, (cf * CFrame.new(s * 2, 1.6, 13)).Position, 0.3, Color3.fromRGB(240, 200, 30), MET)
	end
	for _, s in ipairs({ -1, 1 }) do roda(m, cf, s * 2.2, 0.8, 8, 1.6, 0.6) end
	return m
end

function VE.Construir(N, Mapa, raiz)
	local Y = MD.Plato
	local pasta = Mapa.Pasta
	local v = pasta("Viaturas", raiz)
	local rng = Random.new(77)
	local function cf(x, z, giro)
		return CFrame.new(x, Y + 0.3, z) * CFrame.Angles(0, math.rad(giro or 0), 0)
	end

	-- patio de aeronaves: apoio de solo na borda leste e na borda oeste
	for i, z in ipairs({ -1500, -1100, -700, -300, 100, 500, 900, 1300 }) do
		VE.GPU(v, cf(1690, z, 180 + rng:NextInteger(-10, 10)))
	end
	for _, z in ipairs({ -1650, -200, 700 }) do
		VE.Trator(v, cf(1680, z, 90))
	end
	VE.Tanque(v, cf(1665, -950, 90))
	VE.Tanque(v, cf(1665, 1250, 90))
	VE.Ambulancia(v, cf(1670, 1650, 90))
	for _, z in ipairs({ -1800, 0, 1000 }) do
		VE.Jipe(v, cf(780, z, 90))
	end
	VE.Escada(v, cf(1160, -1010, 90))
	VE.Escada(v, cf(1160, 1270, 90))

	-- portao das armas, comando e area de ensino
	VE.Jipe(v, cf(4290, 40, 0), Color3.fromRGB(86, 94, 62))
	VE.Jipe(v, cf(4290, 10, 0), Color3.fromRGB(86, 94, 62))
	VE.Onibus(v, cf(3500 + 140, 70, 90))
	VE.Onibus(v, cf(3500 + 190, 70, 90))
	VE.Carro(v, cf(3500 + 280, 40, 90))
	VE.Carro(v, cf(3500 + 280, 8, 90), Color3.fromRGB(40, 52, 76))
	VE.Ambulancia(v, cf(3410, -2490 - 40, 180))
	VE.Ambulancia(v, cf(3410 - 40, -2490 - 40, 180))

	-- estacionamento do hospital e da vila
	local cores = {
		Color3.fromRGB(230, 230, 228), Color3.fromRGB(40, 52, 76), Color3.fromRGB(120, 124, 128),
		Color3.fromRGB(150, 36, 36), Color3.fromRGB(30, 30, 32), Color3.fromRGB(196, 190, 176),
	}
	for k = 0, 8 do
		if rng:NextInteger(1, 3) > 1 then
			VE.Carro(v, cf(3500 - 70 + k * 18, -2600 + 92, 0), cores[rng:NextInteger(1, #cores)])
		end
	end
	for _, z in ipairs({ 2700, 2920, 3140 }) do
		for x = 2930, 4130, 200 do
			if rng:NextInteger(1, 2) == 1 then
				VE.Carro(v, cf(x + rng:NextNumber(-20, 20), z + 7, 90 + (rng:NextInteger(0, 1) * 180)), cores[rng:NextInteger(1, #cores)])
			end
		end
	end
	-- jipes do batalhao de guarda na cerca
	VE.Jipe(v, cf(780, 40, 90))
end

return VE
