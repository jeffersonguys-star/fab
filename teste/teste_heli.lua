-- Testes do helicoptero. Uso: texlua teste/teste_heli.lua
package.path = "src/ReplicatedStorage/FAB/?.lua;" .. package.path
local F = dofile("src/ReplicatedStorage/FAB/Fisica.lua")
local A = dofile("src/ReplicatedStorage/FAB/Aeronaves.lua")
math.randomseed(3)
local falhas = 0
local function ok(c, m) print((c and "OK   " or "FALHA ") .. m) if not c then falhas = falhas + 1 end end
local P = A.H60
local function solo0() return 0, "pista" end

-- controlador de coletivo (mantem uma razao de subida alvo)
local function rodar(s, seg, f)
	local t = 0
	while t < seg and not s.Destruido do F.Passo(s, 1 / 60, f(s, t)); t = t + 1 / 60 end
end
local function mantemAltura(alvoVS)
	local c, i = 0.6, 0
	return function(s, t, extra)
		i = i + (alvoVS - s.vy) * (1 / 60) * 0.02
		c = math.max(0, math.min(1, 0.62 + 0.08 * (alvoVS - s.vy) + i))
		local e = { Manete = c, Freio = 0 }
		if extra then for k, v in pairs(extra) do e[k] = v end end
		return e
	end
end

-- 1. pairado a 100 m
local s = F.Novo(P, { Y = 100, Velocidade = 0 })
s.Solo = solo0
local ctl = mantemAltura(0)
local col
rodar(s, 40, function(s2, t) local e = ctl(s2, t); col = e.Manete; return e end)
print(string.format("  pairado: alt %.1f vs %.2f rotor %.0f%% coletivo %.2f arf %.1f rol %.1f vel %.2f rY %.3f",
	s.py, s.vy, s.N * 100, col or 0, s.Arfagem, s.Inclinacao, s.VelSolo, -s.wy))
ok(not s.Destruido, "pairado sem destruir")
ok(math.abs(s.py - 100) < 6 and s.VelSolo < 1.5, "pairado estavel (posicao e velocidade)")
ok(col > 0.4 and col < 0.85, "coletivo de pairado plausivel")
ok(s.N > 0.95 and s.N < 1.05, "rotor em 95 a 105% no pairado")
ok(math.abs(s.Arfagem) < 4 and math.abs(s.Inclinacao) < 4, "atitude quase nivelada")
ok(s.Empuxo > P.Massa * 9.8 * 0.9 and s.Empuxo < (P.Massa + P.Combustivel) * 9.8 * 1.1, "empuxo igual ao peso")
local pot = s.PotRotor / 1e6
print(string.format("  potencia pairado %.2f MW", pot))
ok(pot > 0.8 and pot < 2.4, "potencia de pairado plausivel")

-- 2. pairado com vento e turbulencia
s = F.Novo(P, { Y = 100, Velocidade = 0 })
s.Solo = solo0
F.DefinirVento(s, 0, 8, 1)
ctl = mantemAltura(0)
rodar(s, 40, function(s2, t) return ctl(s2, t) end)
ok(not s.Destruido and math.abs(s.Inclinacao) < 15 and math.abs(s.Arfagem) < 15, "pairado com vento 8 m/s e turbulencia")

-- 3. voo a frente: empurrar o ciclico
s = F.Novo(P, { Y = 150, Velocidade = 0 })
s.Solo = solo0
ctl = mantemAltura(0)
rodar(s, 50, function(s2, t) return ctl(s2, t, { Arfagem = -0.7 }) end)
print(string.format("  frente: vel %.1f IAS %.1f alt %.0f arf %.1f rotor %.0f%% pot %.2f MW", s.VelSolo, s.IAS, s.py, s.Arfagem, s.N * 100, s.PotRotor / 1e6))
ok(not s.Destruido, "voo a frente sem destruir")
ok(s.VelSolo > 30 and s.VelSolo < 85, "acelera ate velocidade de cruzeiro")
ok(s.Arfagem < -1, "nariz abaixado em cruzeiro")
-- subida e curva
rodar(s, 15, function(s2, t) return ctl(s2, t, { Arfagem = -0.5, Rolagem = 0.4 }) end)
ok(not s.Destruido and math.abs(s.Inclinacao) > 5, "inclina para a direita na curva")
-- retorno ao pairado
local v0 = s.VelSolo
rodar(s, 60, function(s2, t) return ctl(s2, t) end)
print(string.format("  frenagem: vel %.1f", s.VelSolo))
ok(not s.Destruido and s.VelSolo < v0 * 0.8, "ao soltar o ciclico o helicoptero desacelera")

-- 4. pedal gira o nariz
s = F.Novo(P, { Y = 100, Velocidade = 0, Rumo = 0 })
s.Solo = solo0
ctl = mantemAltura(0)
rodar(s, 6, function(s2, t) return ctl(s2, t, { Leme = 0.8 }) end)
print(string.format("  pedal: rumo %.0f taxa %.2f", s.Rumo, -s.wy))
ok(s.Rumo > 20 and s.Rumo < 330 and -s.wy > 0.2, "pedal direito gira para a direita")

-- 5. autorrotacao: motor falha, coletivo minimo
s = F.Novo(P, { Y = 400, Velocidade = 35, Arfagem = -3 })
s.Solo = solo0
rodar(s, 5, function(s2, t) return ctl(s2, t, { Arfagem = -0.3 }) end)
s.FalhaMotor = true
local minN = 9
rodar(s, 25, function(s2, t) minN = math.min(minN, s2.N) return { Manete = 0.05, Arfagem = -0.15 } end)
print(string.format("  autorrotacao: VS %.1f vel %.1f rotor %.0f%% (min %.0f%%) alt %.0f", s.vy, s.VelSolo, s.N * 100, minN * 100, s.py))
ok(not s.Destruido, "autorrotacao sem destruir")
ok(s.N > 0.7 and s.N < 1.25, "rotor se mantem em autorrotacao")
ok(s.vy < -3 and s.vy > -25, "razao de descida em autorrotacao plausivel")
-- sem reduzir o coletivo o rotor desacelera
s = F.Novo(P, { Y = 400, Velocidade = 35, Arfagem = -3 })
s.Solo = solo0
rodar(s, 3, function(s2, t) return ctl(s2, t, { Arfagem = -0.3 }) end)
s.FalhaMotor = true
rodar(s, 20, function() return { Manete = 0.9, Arfagem = -0.15 } end)
ok(s.Destruido or s.N < 0.6, "coletivo alto apos falha derruba a rotacao do rotor")

-- 6. decolagem do solo e pouso suave
s = F.Novo(P, { Y = 1.9, Velocidade = 0 })
s.Solo = solo0
rodar(s, 3, function() return { Manete = 0.0, Freio = 1 } end)
ok(not s.Destruido and s.EmSolo, "parado no solo com rotor girando")
F.DefinirVento(s, 0, 4, 1)
rodar(s, 12, function(s2, t) return { Manete = math.min(0.78, t * 0.12), Freio = 0 } end)
print(string.format("  decolagem: alt %.1f vs %.2f emSolo %s", s.py, s.vy, tostring(s.EmSolo)))
ok(not s.Destruido and s.py > 8, "decola do solo")
-- descer devagar
ctl = mantemAltura(-1.2)
rodar(s, 120, function(s2, t)
	local e = ctl(s2, t)
	if s2.AGL < 6 then e = mantemAltura(-0.4)(s2, t) end
	return e
end)
print(string.format("  pouso: alt %.2f vs %.2f destruido %s %s", s.py, s.vy, tostring(s.Destruido), tostring(s.Colisao)))
ok(not s.Destruido, "pouso vertical suave sem destruir")

-- 7. queda livre sem potencia: destroi ao bater
s = F.Novo(P, { Y = 30, Velocidade = 0 })
s.Solo = solo0
s.FalhaMotor = true
rodar(s, 30, function() return { Manete = 0.9 } end)
ok(s.Destruido, "queda sem autorrotacao destroi a aeronave")

print(falhas == 0 and "\nTodos os testes passaram." or ("\n" .. falhas .. " falha(s)."))
os.exit(falhas == 0 and 0 or 1)
