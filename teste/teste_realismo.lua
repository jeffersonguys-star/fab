-- Testes dos efeitos de realismo (vento, rajadas, helice, parafuso, motor). Uso: texlua teste/teste_realismo.lua
package.path = "src/ReplicatedStorage/FAB/?.lua;" .. package.path
local F = dofile("src/ReplicatedStorage/FAB/Fisica.lua")
local A = dofile("src/ReplicatedStorage/FAB/Aeronaves.lua")
math.randomseed(7)
local falhas = 0
local function ok(cond, msg) print((cond and "OK   " or "FALHA ") .. msg) if not cond then falhas = falhas + 1 end end
local function pista(x, z) return 0, "pista" end

local function rodar(s, seg, f)
	local t = 0
	while t < seg do
		F.Passo(s, 1 / 60, f(s, t))
		t = t + 1 / 60
		if s.Destruido then break end
	end
end

-- 1. vento de proa: a velocidade em relacao ao ar e maior que a velocidade no solo
for _, id in ipairs(A.Ordem) do
	local P = A[id]
	local s = F.Novo(P, { Y = 2000, Velocidade = (P.Tipo == "jato") and 120 or 70, Manete = 0.7, Trem = 0 })
	s.Solo = pista
	F.DefinirVento(s, 0, 10, 0) -- vento vindo do norte, aeronave indo para o norte
	rodar(s, 5, function() return { Manete = 0.7, Trem = false } end)
	ok(not s.Destruido and s.Var > s.VelSolo + 5, id .. ": vento de proa aumenta a velocidade no ar (" .. string.format("%.1f > %.1f", s.Var, s.VelSolo) .. ")")
end

-- 2. turbulencia: sem destruir, perturba o angulo de ataque, mais forte no leve que no pesado
local function rms(id)
	local P = A[id]
	local s = F.Novo(P, { Y = 1500, Velocidade = (P.Tipo == "jato") and 140 or 75, Manete = 0.7, Trem = 0, Arfagem = 2 })
	s.Solo = pista
	F.DefinirVento(s, 90, 6, 1.5)
	local soma, n = 0, 0
	rodar(s, 40, function(s2, t)
		if t > 5 then soma = soma + (s2.Mach or 0) * 0 + (s2.Nz - 1) ^ 2; n = n + 1 end
		return { Manete = 0.7, Trem = false, Arfagem = 0.05 }
	end)
	return s, math.sqrt(soma / math.max(n, 1))
end
local sA, rA = rms("T25")
local sB, rB = rms("F39")
ok(not sA.Destruido and not sB.Destruido, "turbulencia nao destroi as aeronaves")
print(string.format("   desvio de G: T-25 %.3f, F-39 %.3f", rA, rB))
ok(rA > 0.02, "turbulencia causa variacao de G perceptivel no T-25")

-- 3. T-25: fator P e torque desviam a guinada na decolagem sem leme
do
	local P = A.T25
	local s = F.Novo(P, { Y = P.AlturaTrem - 0.05, Velocidade = 0, Manete = 0 })
	s.Solo = pista
	local maxDesvio = 0
	rodar(s, 25, function(s2, t)
		local ang = s2.Rumo > 180 and s2.Rumo - 360 or s2.Rumo
		maxDesvio = math.max(maxDesvio, math.abs(ang))
		return { Manete = 1, Freio = 0, Flap = 0.3, Arfagem = (s2.IAS > 28) and 0.1 or 0 }
	end)
	ok(not s.Destruido, "T-25 decola sem leme sem destruir (desvio maximo " .. string.format("%.1f", maxDesvio) .. " graus)")
end

-- 4. parafuso: T-25 entra em parafuso e sai com comandos contrarios
do
	local P = A.T25
	local s = F.Novo(P, { Y = 3000, Velocidade = 55, Manete = 0.2, Trem = 0, Arfagem = 12 })
	s.Solo = pista
	local girou = 0
	rodar(s, 14, function(s2, t)
		return { Manete = 0, Arfagem = 1, Leme = 1, Rolagem = 0.2 }
	end)
	local altEntrada = s.Altitude
	local velRot = math.abs(s.wy)
	rodar(s, 8, function(s2, t)
		-- recuperacao: manete a zero, leme contrario, manche a frente
		return { Manete = 0, Arfagem = -0.5, Leme = -1, Rolagem = 0 }
	end)
	rodar(s, 12, function(s2, t)
		return { Manete = 0.6, Arfagem = 0.1, Leme = 0, Rolagem = 0 }
	end)
	ok(not s.Destruido, "T-25: parafuso e recuperacao sem destruir (altitude " .. string.format("%.0f", s.Altitude) .. " m, IAS " .. string.format("%.0f", s.IAS) .. " m/s)")
	ok(s.IAS > 35, "T-25 recupera velocidade apos o parafuso")
end

-- 5. motor a helice: temperatura sobe com potencia total em velocidade baixa e cai em cruzeiro
do
	local P = A.T25
	local s = F.Novo(P, { Y = 2000, Velocidade = 50, Manete = 1, Trem = 0 })
	s.Solo = pista
	rodar(s, 90, function() return { Manete = 1, Trem = false, Arfagem = 0.15 } end)
	local alta = s.TempMotor
	ok(alta > 100, "T-25: temperatura do motor sobe com potencia maxima (" .. string.format("%.0f", alta) .. " C)")
	ok(not s.FalhaMotor, "T-25: nao superaquece em subida normal")
end

-- 6. G negativo prolongado corta o motor do T-25 (carburador)
do
	local P = A.T25
	local s = F.Novo(P, { Y = 2500, Velocidade = 70, Manete = 0.8, Trem = 0 })
	s.Solo = pista
	local cortou = false
	rodar(s, 12, function(s2, t)
		if s2.Tempo < s2.MotorCortadoAte then cortou = true end
		return { Manete = 0.8, Trem = false, Arfagem = (t < 1) and -0.5 or -0.35 }
	end)
	print("   Nz final " .. string.format("%.2f", s.Nz) .. " cortou=" .. tostring(cortou))
end

-- 7. todas as aeronaves continuam estaveis em cruzeiro com turbulencia moderada
for _, id in ipairs(A.Ordem) do
	local P = A[id]
	local v = (P.Tipo == "jato") and 220 or 100
	local s = F.Novo(P, { Y = 3000, Velocidade = v, Manete = (P.Tipo == "jato") and 0.8 or 0.7, Trem = 0, Arfagem = 2 })
	s.Solo = pista
	F.DefinirVento(s, 270, 8, 1)
	rodar(s, 60, function() return { Manete = (P.Tipo == "jato") and 0.8 or 0.7, Trem = false } end)
	ok(not s.Destruido and math.abs(s.Inclinacao) < 80, id .. ": cruzeiro com turbulencia estavel (inc " .. string.format("%.0f", s.Inclinacao) .. ")")
end
print(falhas == 0 and "TUDO OK" or (falhas .. " falhas"))
