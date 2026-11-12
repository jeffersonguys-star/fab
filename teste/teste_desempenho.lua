-- Compara o desempenho do simulador com dados publicados das aeronaves reais.
-- Uso: texlua teste/teste_desempenho.lua
package.path = "src/ReplicatedStorage/FAB/?.lua;" .. package.path
local F = dofile("src/ReplicatedStorage/FAB/Fisica.lua")
local A = dofile("src/ReplicatedStorage/FAB/Aeronaves.lua")
local function pista() return 0, "pista" end
local function clamp(x, a, b) return math.max(a, math.min(b, x)) end

-- Fontes: T-25 (Jane's 1976-77): vmax 300 km/h, subida 6,66 m/s, decolagem ate 15 m 510 m, teto 6100 m, peso 1150/1700 kg.
-- T-27/EMB-312: vmax ~411 km/h, subida 11,3 m/s, decolagem 374 m, teto 9100 m, peso 1810/3175 kg.
-- F-5E/EM: Mach 1,6 a 11 km, subida ate 175 m/s, teto 15800 m, peso 4410/11190 kg.
local REAL = {
	T25 = { vmax = 300 / 3.6, subida = 6.66, decolagem = 510, teto = 6100, vmaxAlt = 0 },
	T27 = { vmax = 411 / 3.6, subida = 11.3, decolagem = 374, teto = 9100, vmaxAlt = 0 },
	F5 = { mach = 1.6, subida = 175, teto = 15800 },
}
-- A-29: vmax 590 km/h, teto 10668 m, vazio 3200 / MTOW 5400 kg. F-39E: Mach 2+, teto ~15240 m, vazio ~8000 / MTOW 16500 kg, empuxo 98 kN com pos-combustor.
REAL.A29 = { vmax = 590 / 3.6, teto = 10668 }
REAL.F39 = { mach = 2.0, teto = 15240 }
local falhas = 0
local function compara(nome, sim, real, tol, un)
	local err = (sim - real) / real
	local ok = math.abs(err) <= tol
	if not ok then falhas = falhas + 1 end
	print(string.format("  %-28s sim %8.1f  real %8.1f %s  (%+.0f%%)  %s", nome, sim, real, un, err * 100, ok and "OK" or "FORA"))
end

local function rodar(s, seg, f)
	local t = 0
	while t < seg and not s.Destruido do F.Passo(s, 1 / 60, f(s, t)); t = t + 1 / 60 end
end

-- piloto automatico: mantem a velocidade indicada com a atitude (malha externa lenta, interna rapida)
local function mantemVel(s, v)
	local th = clamp(6 + (s.IAS - v) * 0.9, -8, 30)
	return clamp((th - s.Arfagem) * 0.05 - s.wx * 0.5, -1, 1)
end

-- piloto automatico de altitude: velocidade vertical desejada -> atitude (com integrador) -> profundor
local function mantemAlt(s, alt, est)
	local vyCmd = clamp((alt - s.py) * 0.05, -4, 4)
	est.th = clamp((est.th or 2) + (vyCmd - s.vy) * (1 / 60) * 0.25, -5, 25)
	local thCmd = clamp(est.th + (vyCmd - s.vy) * 0.4, -10, 30)
	return clamp((thCmd - s.Arfagem) * 0.05 - s.wx * 0.5, -1, 1)
end

-- velocidade maxima nivelada na altitude alt (manete total, mantem altitude com profundor)
local function vmax(id, alt, pos)
	local P = A[id]
	if alt < 300 then alt = 300 end
	local s = F.Novo(P, { Y = alt, Velocidade = P.VCruzeiro, Manete = 1, Trem = 0 })
	s.Solo = pista
	local est = {}
	rodar(s, 240, function(s2)
		return { Manete = 1, Pos = pos, Arfagem = mantemAlt(s2, alt, est), Trem = false }
	end)
	return s
end

-- excesso de potencia especifico (razao de subida) em voo nivelado a velocidade V: acha a atitude em que a
-- sustentacao iguala o peso (Nz = 1) e mede a variacao da energia em um unico passo
local function ps(P, alt, V, pos)
	local function passo(th)
		local s = F.Novo(P, { Y = alt, Velocidade = V, Manete = 1, Trem = 0, Arfagem = th })
		s.Solo = pista
		s.vx, s.vy, s.vz = 0, 0, -V
		s.Var = V
		if pos then s.PosCombustor = 1 end
		F.Passo(s, 1 / 240, { Manete = 1, Pos = pos, Trem = false })
		return s
	end
	local lo, hi = -4, 24
	for _ = 1, 30 do
		local mid = (lo + hi) / 2
		if passo(mid).Nz > 1 then hi = mid else lo = mid end
	end
	local s = passo((lo + hi) / 2)
	local v2 = s.vx * s.vx + s.vy * s.vy + s.vz * s.vz
	return s.vy + (math.sqrt(v2) - V) * 240 * V / 9.80665, (lo + hi) / 2
end

-- melhor razao de subida na altitude alt e a velocidade em que ocorre
local function subida(id, alt, pos)
	local P = A[id]
	local melhor, vel = -1e9, 0
	local vmin = (P.VAprox or P.VR) * 0.85
	for v = vmin, (P.VNE or 100) * 0.75, 3 do
		local r, th = ps(P, alt, v, pos)
		if th < 14 and r > melhor then melhor, vel = r, v end
	end
	return melhor, vel
end

-- distancia de decolagem ate 15 m
local function decolagem(id, flap)
	local P = A[id]
	local z0 = 1300
	local s = F.Novo(P, { Y = P.AlturaTrem - 0.05, Z = z0, Velocidade = 0, Manete = 0, Trim = P.TrimDecolagem or 0 })
	s.Solo = pista
	local dist, roda
	rodar(s, 90, function(s2, t)
		local puxa = 0
		if s2.IAS > P.VR then puxa = clamp((10 - s2.Arfagem) * 0.08 - s2.wx * 0.5, -0.5, 1) end
		if not roda and not s2.EmSolo and s2.Tempo > 2 then roda = z0 - s2.pz end
		if not dist and s2.AGL > 15 then dist = z0 - s2.pz end
		local leme = clamp(-s2.px * 0.05 - (s2.Rumo > 180 and s2.Rumo - 360 or s2.Rumo) * 0.08, -1, 1)
		return { Manete = 1, Pos = true, Arfagem = puxa, Leme = leme, Trem = true, Flap = flap or 0 }
	end)
	return dist or math.huge, roda or math.huge
end

-- teto de servico: altitude em que a subida cai abaixo de 0,5 m/s
local function teto(id, vsub, altIni)
	local P = A[id]
	local s = F.Novo(P, { Y = altIni, Velocidade = vsub, Manete = 1, Trem = 0, Arfagem = 4 })
	s.Solo = pista
	local alt = altIni
	rodar(s, 1200, function(s2, t)
		return { Manete = 1, Pos = true, Arfagem = mantemVel(s2, vsub), Trem = false }
	end)
	return s.py, s
end

print("== T-25 Universal")
local s = vmax("T25", 0)
compara("velocidade maxima nivelada", s.VelSolo, REAL.T25.vmax, 0.12, "m/s")
local vs = subida("T25", 300)
compara("razao de subida (nivel do mar)", vs, REAL.T25.subida, 0.25, "m/s")
compara("decolagem ate 15 m", (decolagem("T25", 0.3)), REAL.T25.decolagem, 0.3, "m")
local v3 = subida("T25", 3000)
compara("teto (extrapolado)", 300 + (vs - 0.5) / math.max((vs - v3) / 2700, 1e-6), REAL.T25.teto, 0.25, "m")

print("== T-27 Tucano")
s = vmax("T27", 0)
compara("velocidade maxima nivelada", s.VelSolo, REAL.T27.vmax, 0.12, "m/s")
vs = subida("T27", 300)
compara("razao de subida (nivel do mar)", vs, REAL.T27.subida, 0.25, "m/s")
compara("corrida de decolagem (solo)", select(2, decolagem("T27", 0.3)), REAL.T27.decolagem, 0.3, "m")
v3 = subida("T27", 3000)
compara("teto (extrapolado)", 300 + (vs - 0.5) / math.max((vs - v3) / 2700, 1e-6), REAL.T27.teto, 0.3, "m")

print("== F-5EM")
s = vmax("F5", 11000, true)
compara("Mach maximo a 11 km", s.Mach, REAL.F5.mach, 0.1, "")
vs = subida("F5", 300, true)
compara("razao de subida (nivel do mar)", vs, REAL.F5.subida, 0.35, "m/s")

print("== A-29 Super Tucano")
s = vmax("A29", 3000)
compara("velocidade maxima a 3000 m", s.VelSolo, REAL.A29.vmax, 0.12, "m/s")
vs = subida("A29", 300)
local v3 = subida("A29", 3000)
print(string.format("  razao de subida a 300 m: %.1f m/s", vs))
compara("teto (extrapolado)", 300 + (vs - 0.5) / math.max((vs - v3) / 2700, 1e-6), REAL.A29.teto, 0.25, "m")

print("== F-39E Gripen")
s = vmax("F39", 11000, true)
compara("Mach maximo a 11 km", s.Mach, REAL.F39.mach, 0.12, "")
vs = subida("F39", 300, true)
print(string.format("  razao de subida a 300 m: %.1f m/s", vs))

print(falhas == 0 and "\nTudo dentro da tolerancia." or ("\n" .. falhas .. " item(ns) fora da tolerancia."))
