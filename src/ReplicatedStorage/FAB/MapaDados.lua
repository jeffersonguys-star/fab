--[[
	FAB - Dados do mapa (ModuleScript)

	Escala do mundo: 1 stud = 0,28 m (escala do personagem do Roblox).
	O mapa e um oceano com uma ilha grande no meio. A ilha tem um plato a 20 studs
	acima do mar, praias nas bordas e serras no lado oeste. A base aerea fica no plato.

	Este modulo e usado pelo servidor (para gerar o terreno e a base) e pelo simulador
	(para saber a altura do solo e o tipo de superficie em qualquer ponto).
]]

local M = {}

M.MetroPorStud = 0.28
M.StudPorMetro = 1 / 0.28

M.NivelMar = 0
M.Plato = 20
M.ProfundidadeMar = 24
M.Limite = 14000          -- o oceano vai de -Limite a +Limite em X e Z
M.LarguraPraia = 380

M.Ilha = { RaioX = 6800, RaioZ = 10400 }

-- Pista 18/36 ao longo do eixo Z (norte = -Z). 3.000 m x 45 m.
M.Pista = {
	X = 0, Z = 0,
	Comprimento = 3000 * M.StudPorMetro,
	Largura = 45 * M.StudPorMetro,
	Zona = 600 * M.StudPorMetro, -- area de escape (stopway) em cada ponta
}
M.Pista.MeioComp = M.Pista.Comprimento / 2
M.Pista.MeiaLarg = M.Pista.Largura / 2
-- cabeceira 36 (pousos para o norte) fica no sul (+Z); cabeceira 18 no norte (-Z)
M.Cabeceira36 = Vector3.new(0, M.Plato, M.Pista.MeioComp)
M.Cabeceira18 = Vector3.new(0, M.Plato, -M.Pista.MeioComp)

M.TaxiX = 640
M.TaxiLargura = 23 * M.StudPorMetro
M.Ligacoes = { -4800, -2400, 0, 2400, 4800 }
M.Patio = { X1 = 760, X2 = 1720, Z1 = -1900, Z2 = 1900 }

-- Serras (lado oeste): perfil h(d) = H * (1 - d/R)^2
M.Morros = {
	{ X = -4300, Z = -3600, R = 1500, H = 430 },
	{ X = -4700, Z = 2800, R = 1300, H = 360 },
	{ X = -3100, Z = 7000, R = 1000, H = 260 },
	{ X = -3200, Z = -7600, R = 1000, H = 300 },
	{ X = -5400, Z = -300, R = 900, H = 220 },
}

-- Borda do plato (sem a praia) na coordenada z: devolve xEsquerda, xDireita
function M.Borda(z)
	local t = z / M.Ilha.RaioZ
	if t <= -1 or t >= 1 then return 0, 0 end
	local base = M.Ilha.RaioX * math.sqrt(1 - t * t)
	local dir = base * (1 + 0.07 * math.sin(z / 900) + 0.04 * math.sin(z / 330 + 1.3))
	local esq = base * (1 + 0.06 * math.sin(z / 760 + 2.1) + 0.05 * math.sin(z / 410 + 0.4))
	return -esq, dir
end

local function alturaMorros(x, z)
	local h = 0
	for _, m in ipairs(M.Morros) do
		local dx, dz = x - m.X, z - m.Z
		local d = math.sqrt(dx * dx + dz * dz)
		if d < m.R then
			local v = m.H * (1 - d / m.R) ^ 2
			if v > h then h = v end
		end
	end
	return h
end
M.AlturaMorros = alturaMorros

-- Superficies pavimentadas (pista, taxi, patio e area de escape)
function M.Pavimentado(x, z)
	local P = M.Pista
	if math.abs(x - P.X) <= P.MeiaLarg and math.abs(z - P.Z) <= P.MeioComp + P.Zona then return true end
	if math.abs(x - M.TaxiX) <= M.TaxiLargura / 2 and math.abs(z) <= P.MeioComp then return true end
	for _, lz in ipairs(M.Ligacoes) do
		if x >= P.MeiaLarg - 2 and x <= M.TaxiX and math.abs(z - lz) <= M.TaxiLargura / 2 + 20 then return true end
	end
	local pa = M.Patio
	if x >= pa.X1 and x <= pa.X2 and z >= pa.Z1 and z <= pa.Z2 then return true end
	return false
end

-- Altura do solo (studs) e tipo de superficie: "pista", "grama", "praia" ou "agua"
function M.Altura(x, z)
	if math.abs(z) >= M.Ilha.RaioZ + M.LarguraPraia then return M.NivelMar, "agua" end
	local esq, dir = M.Borda(z)
	if esq == dir then
		return M.NivelMar, "agua"
	end
	if x >= esq and x <= dir then
		local h = M.Plato + alturaMorros(x, z)
		if M.Pavimentado(x, z) then return M.Plato, "pista" end
		return h, "grama"
	end
	local d
	if x > dir then d = x - dir else d = esq - x end
	if d < M.LarguraPraia then
		local h = M.Plato - (M.Plato + M.ProfundidadeMar) * d / M.LarguraPraia
		if h > M.NivelMar then return h, "praia" end
	end
	return M.NivelMar, "agua"
end

return M
