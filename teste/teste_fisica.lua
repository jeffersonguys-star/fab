-- Testes do modelo de voo fora do Roblox (texlua)
package.path = "src/ReplicatedStorage/FAB/?.lua;" .. package.path
local F = dofile("src/ReplicatedStorage/FAB/Fisica.lua")
local A = dofile("src/ReplicatedStorage/FAB/Aeronaves.lua")
math.randomseed(1)

local function kt(v) return v * 1.943844 end
local function ft(m) return m * 3.28084 end

local function pista(x, z)
	if math.abs(x) < 22 and math.abs(z) < 1500 then return 0, "pista" end
	return 0, "grama"
end

local function linha(s, rotulo)
	print(string.format("%s t=%5.1f alt=%6.0fft IAS=%5.1fkt M=%.2f arf=%6.1f inc=%6.1f rumo=%5.1f a=%5.1f b=%5.1f G=%5.2f VS=%6.0ffpm N=%.2f %s",
		rotulo or "", s.Tempo, ft(s.Altitude), kt(s.IAS), s.Mach, s.Arfagem, s.Inclinacao, s.Rumo, s.AlfaGraus, s.BetaGraus, s.Nz, s.VS * 196.85, s.N,
		s.Destruido and ("DESTRUIDO: " .. tostring(s.Colisao)) or (s.EmSolo and "SOLO" or "")))
end

local function rodar(s, seg, f, passo, imprimir)
	local dt = 1 / 60
	local t = 0
	local prox = 0
	while t < seg do
		local e = f(s, t)
		F.Passo(s, dt, e)
		t = t + dt
		if imprimir and t >= prox then linha(s); prox = prox + (passo or 5) end
		if s.Destruido then linha(s, "!!") break end
	end
end

local qual = arg[1] or "todos"

-- 1. Cruzeiro sem mexer nos comandos
local function cruzeiro(id, v, alt, manete, trim)
	print("== cruzeiro " .. id)
	local P = A[id]
	local s = F.Novo(P, { Y = alt, Velocidade = v, Arfagem = 2, Manete = manete, Trem = 0, Trim = trim or 0 })
	s.Solo = pista
	rodar(s, 90, function() return { Manete = manete, Trem = false } end, 10, true)
end

-- 2. Decolagem: manete total, puxa na VR
local function decolagem(id, pos)
	print("== decolagem " .. id)
	local P = A[id]
	local s = F.Novo(P, { Y = P.AlturaTrem - 0.05, Z = 1300, Velocidade = 0, Manete = 0, Trim = P.TrimDecolagem or 0 })
	s.Solo = pista
	local rodouEm
	rodar(s, 60, function(s, t)
		local puxa = 0
		if s.IAS > P.VR then
			-- segura cerca de 10 graus de atitude
			puxa = math.max(-0.5, math.min(1, (10 - s.Arfagem) * 0.08 - s.wx * 0.5))
			if not rodouEm then rodouEm = 1300 - s.pz; print(string.format("   rotacao apos %.0f m", rodouEm)) end
		end
		-- leme para manter o eixo (contra o torque)
		local leme = math.max(-1, math.min(1, -(s.px) * 0.05 - (s.Rumo > 180 and s.Rumo - 360 or s.Rumo) * 0.08))
		return { Manete = 1, Pos = pos, Arfagem = puxa, Leme = leme, Trem = true }
	end, 3, true)
end

-- 3. Velocidade de estol (desacelera nivelado)
local function estol(id, flap)
	print("== estol " .. id .. " flap " .. tostring(flap))
	local P = A[id]
	local s = F.Novo(P, { Y = 2000, Velocidade = P.VCruzeiro * 0.8, Manete = 0, Trem = 0 })
	s.Solo = pista
	local alt0 = 2000
	local estolou = false
	rodar(s, 120, function(s, t)
		local erro = (alt0 - s.Altitude) * 0.01 - s.VS * 0.04
		local puxa = math.max(-1, math.min(1, erro - s.wx * 0.5))
		if s.Estol and not estolou then
			estolou = true
			print(string.format("   ESTOL a %.1f kt (alfa %.1f, G %.2f)", kt(s.IAS), s.AlfaGraus, s.Nz))
		end
		if estolou then puxa = 1 end
		return { Manete = 0.0, Arfagem = puxa, Flap = flap, Trem = false }
	end, 5, true)
end

-- 4. Curva de alto G
local function curvaG(id, v, alt, manete, pos)
	print("== curva G " .. id)
	local P = A[id]
	local s = F.Novo(P, { Y = alt, Velocidade = v, Manete = manete, Trem = 0, Arfagem = 1 })
	s.Solo = pista
	rodar(s, 30, function(s, t)
		local rol = 0
		if t < 6 then
			rol = math.max(-1, math.min(1, (75 - s.Inclinacao) * 0.03))
		else
			rol = math.max(-1, math.min(1, (80 - s.Inclinacao) * 0.03))
		end
		local puxa = t > 1.5 and 1 or 0
		return { Manete = manete, Pos = pos, Arfagem = puxa, Rolagem = rol, Trem = false }
	end, 1, true)
end

-- 5. Taxa de rolagem
local function rolagem(id, v, alt, manete)
	print("== rolagem " .. id)
	local P = A[id]
	local s = F.Novo(P, { Y = alt, Velocidade = v, Manete = manete, Trem = 0 })
	s.Solo = pista
	local ant = s.Inclinacao
	rodar(s, 3, function(s, t)
		return { Manete = manete, Rolagem = 1, Trem = false }
	end, 0.25, true)
	print(string.format("   taxa final %.0f graus/s", math.deg(-s.wz)))
end

-- 6. Velocidade maxima nivelada
local function vmax(id, alt, pos)
	print("== vmax " .. id)
	local P = A[id]
	local s = F.Novo(P, { Y = alt, Velocidade = P.VCruzeiro, Manete = 1, Trem = 0 })
	s.Solo = pista
	rodar(s, 240, function(s, t)
		local erro = (alt - s.Altitude) * 0.004 - s.VS * 0.02
		local puxa = math.max(-1, math.min(1, erro - s.wx * 0.3))
		return { Manete = 1, Pos = pos, Arfagem = puxa, Trem = false, Trim = 0 }
	end, 30, true)
end

-- 7. Pouso: aproximacao estabilizada a 3 graus
local function pouso(id)
	print("== pouso " .. id)
	local P = A[id]
	local dist = 2500
	local alt = dist * math.tan(math.rad(3))
	local s = F.Novo(P, { Y = alt + P.AlturaTrem, Z = 1300 + dist, Velocidade = P.VAprox * 1.05, Manete = 0.4, Trem = 1, Flap = 1, Arfagem = 0 })
	s.Solo = pista
	local manete = 0.4
	rodar(s, 90, function(s, t)
		local distAtual = s.pz - 1250
		local altAlvo = math.max(0, distAtual * math.tan(math.rad(3)))
		local puxa
		if s.AGL > 6 then
			local erroAlt = (altAlvo - s.AGL)
			local vsAlvo = -s.V * math.sin(math.rad(3)) + erroAlt * 0.15
			puxa = (vsAlvo - s.VS) * 0.06 - s.wx * 0.8 + 0.1
			manete = math.max(0, math.min(1, manete + (P.VAprox - s.IAS) * 0.02 * (1 / 60)))
		else
			-- arredondamento
			puxa = (-0.8 - s.VS) * 0.12 - s.wx * 0.5 + 0.25
			manete = 0
		end
		if s.EmSolo then puxa = 0 end
		return { Manete = manete, Arfagem = math.max(-1, math.min(1, puxa)), Flap = 1, Trem = true, Freio = s.EmSolo and 0.6 or 0, AeroFreio = s.EmSolo }
	end, 5, true)
	if s.Toque then print(string.format("   toque: afundamento %.2f m/s (%.0f fpm)", s.Toque.Afundamento, s.Toque.Afundamento * 196.85)) end
end

if qual == "cruzeiro" or qual == "todos" then
	cruzeiro("T25", 57, 600, 0.6)
	cruzeiro("T27", 105, 1500, 0.55)
	cruzeiro("A29", 140, 2000, 0.6)
	cruzeiro("F5", 230, 3000, 0.75)
	cruzeiro("F39", 250, 5000, 0.7)
end
if qual == "decolagem" or qual == "todos" then
	decolagem("T25")
	decolagem("T27")
	decolagem("A29")
	decolagem("F5", true)
	decolagem("F39", true)
end
if qual == "estol" or qual == "todos" then
	estol("T25", 0) estol("T25", 1)
	estol("T27", 0)
	estol("F5", 0)
	estol("F39", 0)
end
if qual == "curva" or qual == "todos" then
	curvaG("T25", 60, 1000, 1)
	curvaG("F5", 230, 3000, 1, true)
	curvaG("F39", 230, 3000, 1, true)
end
if qual == "rolagem" or qual == "todos" then
	rolagem("T25", 57, 1000, 0.6)
	rolagem("T27", 100, 1000, 0.6)
	rolagem("F5", 180, 3000, 0.8)
	rolagem("F39", 200, 3000, 0.8)
end
if qual == "vmax" or qual == "todos" then
	vmax("T25", 300)
	vmax("F5", 11000, true)
	vmax("F39", 11000, true)
end
if qual == "pouso" or qual == "todos" then
	pouso("T25") pouso("T27") pouso("F5") pouso("F39")
end
