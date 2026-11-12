--[[
	FAB - Fisica de voo (ModuleScript)

	Modelo de corpo rigido com 6 graus de liberdade, usado pelo simulador.
	Unidades SI (metros, quilogramas, segundos, radianos). No mundo do simulador,
	1 stud = 1 metro.

	O que e simulado:
	- Atmosfera padrao ISA (densidade, temperatura e velocidade do som por altitude)
	- Sustentacao, arrasto e forca lateral calculados por coeficientes aerodinamicos,
	  com angulo de ataque, derrapagem, estol, queda de asa e regime pos-estol
	- Arrasto induzido, efeito solo, flapes, trem de pouso, freio aerodinamico
	  e arrasto de onda (transonico e supersonico)
	- Momentos de arfagem, rolagem e guinada com estabilidade estatica,
	  amortecimento e efetividade das superficies (inclusive o sopro da helice)
	- Motor a helice (potencia, tracao estatica, torque, helice em molinete) e motor
	  a jato (aceleracao da turbina, pos-combustor, perda de tracao com altitude)
	- Consumo de combustivel e apagamento do motor
	- Trem de pouso com mola e amortecedor em cada roda, atrito de rolagem, freios,
	  atrito lateral e direcao da bequilha
	- Controle fly-by-wire (comando de G e taxa de rolagem, limitadores de G e de
	  angulo de ataque) para as aeronaves que tem esse sistema
	- Colisoes da estrutura com o solo, pouso duro, sobrecarga e excesso de velocidade

	O modulo nao usa nenhuma funcao do Roblox, por isso pode ser testado fora do jogo.

	Eixos do corpo (iguais aos do Roblox): X = direita, Y = cima, Z = tras.
	O nariz aponta para -Z.
]]

local Fisica = {}

local sqrt, sin, cos, abs, exp, floor = math.sqrt, math.sin, math.cos, math.abs, math.exp, math.floor
local atan2 = math.atan2 or function(y, x) return math.atan(y, x) end
local asin = math.asin
local G0 = 9.80665
local PASSO = 1 / 240

local function limitar(x, a, b)
	if x < a then return a end
	if x > b then return b end
	return x
end
Fisica.Limitar = limitar

local function normalizar(x, y, z)
	local m = sqrt(x * x + y * y + z * z)
	if m < 1e-9 then return 0, 0, 0, 0 end
	return x / m, y / m, z / m, m
end

local function cruz(ax, ay, az, bx, by, bz)
	return ay * bz - az * by, az * bx - ax * bz, ax * by - ay * bx
end

-- Atmosfera padrao ISA. Retorna densidade (kg/m3), velocidade do som (m/s),
-- temperatura (K) e pressao (Pa).
function Fisica.Atmosfera(h)
	if h < 0 then h = 0 end
	local T, p
	if h < 11000 then
		T = 288.15 - 0.0065 * h
		p = 101325 * (T / 288.15) ^ 5.25588
	else
		T = 216.65
		p = 22632.1 * exp(-(h - 11000) / 6341.62)
	end
	return p / (287.053 * T), sqrt(401.874 * T), T, p
end

-- Coeficiente de sustentacao em funcao do angulo de ataque (com estol e pos-estol)
local function coefSustentacao(P, alfa, flap)
	local cl0 = P.CL0 + P.CLFlap * flap
	local estolPos = P.AlfaEstol - (P.AlfaFlap or 0) * flap
	local estolNeg = P.AlfaEstolNeg
	local linear = cl0 + P.CLa * alfa
	-- sustentacao de vortice (asas em delta), formula de Polhamus
	if P.Vortice then
		local sa = sin(alfa)
		linear = linear + P.Vortice * sa * abs(sa) * cos(alfa)
	end
	if alfa <= estolPos and alfa >= -estolNeg then
		return linear, 0
	end
	local sinal, excesso, clMax
	if alfa > 0 then
		sinal = 1
		excesso = alfa - estolPos
		clMax = cl0 + P.CLa * estolPos
		if P.Vortice then clMax = clMax + P.Vortice * sin(estolPos) ^ 2 * cos(estolPos) end
	else
		sinal = -1
		excesso = -alfa - estolNeg
		clMax = cl0 - P.CLa * estolNeg
	end
	-- quebra do estol: perde cerca de 30% da sustentacao em 4 graus
	local quebra = limitar(excesso / 0.07, 0, 1)
	local cl = clMax * (1 - 0.3 * quebra)
	-- regime de placa plana em angulos muito altos
	local placa = 1.1 * sin(2 * alfa)
	local mistura = limitar((excesso - 0.07) / 0.45, 0, 1)
	cl = cl * (1 - mistura) + placa * mistura
	return cl, quebra * sinal
end

-- Arrasto de onda (compressibilidade)
local function arrastoOnda(P, M)
	local mc = P.MachCritico or 0.75
	if M <= mc then return 0 end
	local pico = P.ArrastoOnda or 0.03
	if M < 1.05 then
		local t = (M - mc) / (1.05 - mc)
		return pico * t * t * (3 - 2 * t)
	end
	return pico * (1.05 / M) ^ 0.8
end

-- Cria o estado inicial. ini: X, Y, Z (m), Rumo, Arfagem, Inclinacao (graus),
-- Velocidade (m/s), MotorLigado, Flap (0-1), Trem (0-1), Manete (0-1)
function Fisica.Novo(P, ini)
	ini = ini or {}
	local s = { P = P }
	s.px, s.py, s.pz = ini.X or 0, ini.Y or 0, ini.Z or 0
	local h = math.rad(ini.Rumo or 0)
	local th = math.rad(ini.Arfagem or 0)
	local ph = math.rad(ini.Inclinacao or 0)
	local fx, fy, fz = sin(h) * cos(th), sin(th), -cos(h) * cos(th)
	local ax, ay, az = normalizar(cruz(fx, fy, fz, 0, 1, 0))
	if ax == 0 and ay == 0 and az == 0 then ax, ay, az = 1, 0, 0 end
	local bx, by, bz = cruz(ax, ay, az, fx, fy, fz)
	local c, sn = cos(ph), sin(ph)
	s.ax, s.ay, s.az = ax * c - bx * sn, ay * c - by * sn, az * c - bz * sn
	s.bx, s.by, s.bz = bx * c + ax * sn, by * c + ay * sn, bz * c + az * sn
	s.cx, s.cy, s.cz = -fx, -fy, -fz
	local v = ini.Velocidade or 0
	s.vx, s.vy, s.vz = fx * v, fy * v, fz * v
	s.wx, s.wy, s.wz = 0, 0, 0
	s.MotorLigado = ini.MotorLigado ~= false
	s.FalhaMotor = false
	s.N = s.MotorLigado and (P.Tipo == "jato" and limitar(ini.Manete or 0.7, 0, 1) or limitar(0.2 + 0.8 * (ini.Manete or 0.6), 0, 1)) or 0
	s.PosCombustor = 0
	s.Combustivel = ini.Combustivel or P.Combustivel
	s.Flap = ini.Flap or 0
	s.Trem = ini.Trem or 1
	if not P.TremRetratil then s.Trem = 1 end
	s.AeroFreio = 0
	s.Trim = ini.Trim or 0
	s.FbwI = 0
	s.LadoEstol = 1
	s.Tempo = 0
	s.ContatoRoda = {}
	s.EmSolo = false
	s.Destruido = false
	s.Colisao = nil
	s.Toque = nil
	s.NzFiltrado = 1
	s.Solo = function() return 0, "grama" end
	-- deflexoes atuais das superficies (para animar a cabine e os comandos)
	s.De, s.Da, s.Dr = 0, 0, 0
	Fisica.Calcular(s)
	return s
end

-- Converte forca no mundo para torque no corpo
local function torqueCorpo(s, rx, ry, rz, fx, fy, fz)
	local tx, ty, tz = cruz(rx, ry, rz, fx, fy, fz)
	return tx * s.ax + ty * s.ay + tz * s.az,
		tx * s.bx + ty * s.by + tz * s.bz,
		tx * s.cx + ty * s.cy + tz * s.cz
end

local function falhar(s, motivo)
	if s.Destruido then return end
	s.Destruido = true
	s.Colisao = motivo
	s.vx, s.vy, s.vz = 0, 0, 0
	s.wx, s.wy, s.wz = 0, 0, 0
end
Fisica.Falhar = falhar

-- Um subpasso de integracao
local function subpasso(s, dt, e)
	local P = s.P
	local m = P.Massa + s.Combustivel

	-- atuadores (flape, trem, freio aerodinamico)
	local alvoFlap = limitar(e.Flap or 0, 0, 1)
	if s.Flap < alvoFlap then s.Flap = math.min(alvoFlap, s.Flap + dt / (P.TempoFlap or 4))
	elseif s.Flap > alvoFlap then s.Flap = math.max(alvoFlap, s.Flap - dt / (P.TempoFlap or 4)) end
	if P.TremRetratil then
		local alvoTrem = e.Trem == false and 0 or 1
		if s.EmSolo then alvoTrem = 1 end -- interruptor de peso nas rodas
		if s.Trem < alvoTrem then s.Trem = math.min(1, s.Trem + dt / P.TempoTrem)
		elseif s.Trem > alvoTrem then s.Trem = math.max(0, s.Trem - dt / P.TempoTrem) end
	end
	local alvoAF = (e.AeroFreio and P.TemAeroFreio) and 1 or 0
	if s.AeroFreio < alvoAF then s.AeroFreio = math.min(1, s.AeroFreio + dt * 1.5)
	elseif s.AeroFreio > alvoAF then s.AeroFreio = math.max(0, s.AeroFreio - dt * 1.5) end

	-- atmosfera e velocidades
	local rho, somV = Fisica.Atmosfera(s.py)
	local sigma = rho / 1.225
	local vx, vy, vz = s.vx, s.vy, s.vz
	local V = sqrt(vx * vx + vy * vy + vz * vz)
	local vbx = vx * s.ax + vy * s.ay + vz * s.az
	local vby = vx * s.bx + vy * s.by + vz * s.bz
	local vbz = vx * s.cx + vy * s.cy + vz * s.cz
	local u = -vbz
	local alfa, beta = 0, 0
	if V > 2 then
		alfa = atan2(-vby, u)
		beta = asin(limitar(vbx / V, -1, 1))
	end
	local M = V / somV
	local qd = 0.5 * rho * V * V
	local Vd = math.max(V, 5)

	-- taxas angulares na convencao aeronautica
	local pR = -s.wz -- rolagem para a direita
	local qP = s.wx  -- arfagem para cima
	local rY = -s.wy -- guinada para a direita

	-- motor
	local tracao = 0
	local alvoN = 0
	local ligado = s.MotorLigado and not s.FalhaMotor and s.Combustivel > 0
	local manete = limitar(e.Manete or 0, 0, 1)
	local fracao = 0
	if P.Tipo == "jato" then
		if ligado then alvoN = manete end
		local tau = P.TempoMotor
		if alvoN < s.N then tau = tau * 0.6 end
		s.N = s.N + (alvoN - s.N) * math.min(1, dt / tau)
		local alvoPC = 0
		if ligado and e.Pos and P.TracaoPos and s.N > 0.93 then alvoPC = 1 end
		if s.PosCombustor < alvoPC then s.PosCombustor = math.min(1, s.PosCombustor + dt / 1.2)
		elseif s.PosCombustor > alvoPC then s.PosCombustor = math.max(0, s.PosCombustor - dt / 0.5) end
		local perda = sigma ^ 0.75 * (1 + 0.25 * math.min(M, 2))
		local seco = P.TracaoMil * (0.04 + 0.96 * s.N * s.N)
		if not ligado then seco = 0 end
		local extra = P.TracaoPos and (P.TracaoPos - P.TracaoMil) * s.PosCombustor or 0
		tracao = (seco + extra) * perda
		if ligado then
			s.Combustivel = math.max(0, s.Combustivel - (P.TSFC * seco + (P.TSFCPos or 0) * extra) * perda / G0 / 3600 * dt)
		end
		fracao = s.N
	else
		local marcha = 0.2
		if ligado then alvoN = marcha + (1 - marcha) * manete end
		s.N = s.N + (alvoN - s.N) * math.min(1, dt / P.TempoMotor)
		fracao = limitar((s.N - marcha) / (1 - marcha), 0, 1)
		if ligado then
			local pot = P.Potencia * (0.04 + 0.96 * fracao ^ 1.3) * sigma ^ (P.ExpoenteAltitude or 0.8)
			local estatica = P.TracaoEstatica * (0.04 + 0.96 * fracao ^ 1.3) * sigma ^ (P.ExpoenteAltitude or 0.8)
			tracao = math.min(estatica, P.EficienciaHelice * pot / math.max(V, 1))
			s.Combustivel = math.max(0, s.Combustivel - P.Consumo * (0.12 + 0.88 * fracao) * dt)
		else
			fracao = 0
		end
	end
	s.Tracao = tracao
	s.FracaoMotor = fracao

	-- comandos (direto ou fly-by-wire)
	local cArf = limitar(e.Arfagem or 0, -1, 1)
	local cRol = limitar(e.Rolagem or 0, -1, 1)
	local cLem = limitar(e.Leme or 0, -1, 1)
	local de, da, dr
	if P.FBW and not s.EmSolo and V > 40 then
		local nCmd
		if cArf >= 0 then nCmd = 1 + cArf * (P.GMax - 1) else nCmd = 1 + cArf * (1 - P.GMin) end
		-- componente da gravidade no eixo vertical do corpo
		local nGrav = s.by
		local qCmd = G0 * (nCmd - nGrav) / Vd
		-- limitador de angulo de ataque
		local margem = P.AlfaMaxFBW - alfa
		qCmd = math.min(qCmd, margem * 3.0)
		qCmd = math.max(qCmd, (-P.AlfaMaxFBW * 0.5 - alfa) * 3.0)
		-- limitador de G
		qCmd = math.min(qCmd, G0 * (P.GMax - nGrav) / Vd + (P.GMax - s.NzFiltrado) * 0.08)
		qCmd = math.max(qCmd, G0 * (P.GMin - nGrav) / Vd + (P.GMin - s.NzFiltrado) * 0.08)
		local escala = limitar(25000 / math.max(qd, 1500), 0.15, 8)
		local erro = qCmd - qP
		s.FbwI = limitar(s.FbwI + erro * 2.5 * escala * dt, -1, 1)
		de = limitar(s.FbwI + erro * 1.6 * escala, -1, 1)
		-- rolagem: comando de taxa
		local reducao = limitar(1 - (alfa - 0.25) / 0.3, 0.35, 1)
		local pCmd = cRol * P.RolagemMaxFBW * reducao
		local ganho = (P.Clda ~= 0) and (abs(P.Clp) / P.Clda) * P.Envergadura / (2 * Vd) or 0
		da = limitar(pCmd * ganho + (pCmd - pR) * 0.6 * escala, -1, 1)
		-- guinada: coordenacao automatica e amortecedor
		dr = limitar(cLem + beta * 6 - rY * 0.8 * escala, -1, 1)
	else
		de = limitar(cArf + s.Trim * 0.35, -1, 1)
		da = cRol
		dr = cLem
		if P.AmortecedorGuinada and V > 40 then
			dr = limitar(dr - rY * P.AmortecedorGuinada, -1, 1)
		end
		s.FbwI = 0
	end
	-- os comandos nao se movem instantaneamente
	local vel = (P.FBW and 12 or 8) * dt
	s.De = s.De + limitar(de - s.De, -vel, vel)
	s.Da = s.Da + limitar(da - s.Da, -vel, vel)
	s.Dr = s.Dr + limitar(dr - s.Dr, -vel, vel)
	de, da, dr = s.De, s.Da, s.Dr

	-- forcas e momentos aerodinamicos
	local Fx, Fy, Fz = 0, 0, 0
	local Tx, Ty, Tz = 0, 0, 0
	local cl, estol = coefSustentacao(P, alfa, s.Flap)
	local intensidadeEstol = abs(estol)
	if intensidadeEstol > 0 and not s.EstavaEmEstol then
		s.LadoEstol = (math.random() < 0.5) and -1 or 1
	end
	s.EstavaEmEstol = intensidadeEstol > 0.05
	if V > 2 then
		local S, b, c = P.Area, P.Envergadura, P.Corda
		-- efeito solo (reduz o arrasto induzido perto do chao)
		local hSolo = s.AGL or 100
		local efeitoSolo = 1
		if hSolo < b then
			local k = (16 * hSolo / b) ^ 2
			efeitoSolo = k / (1 + k)
		end
		local cd = P.CD0 + P.CDFlap * s.Flap + (P.CDTrem or 0) * s.Trem + (P.CDAeroFreio or 0) * s.AeroFreio
			+ P.K * efeitoSolo * cl * cl + arrastoOnda(P, M)
		local aa = abs(alfa)
		if aa > P.AlfaEstol then cd = cd + 1.1 * (sin(aa) ^ 2 - sin(P.AlfaEstol) ^ 2) end
		if P.Tipo ~= "jato" and ligado == false then cd = cd + (P.ArrastoHelice or 0) end
		local cy = P.CYb * beta
		local L, D, Y = qd * S * cl, qd * S * cd, qd * S * cy
		local ux, uy, uz = vx / V, vy / V, vz / V
		local lx, ly, lz = normalizar(cruz(s.ax, s.ay, s.az, ux, uy, uz))
		Fx = Fx + lx * L - ux * D + s.ax * Y
		Fy = Fy + ly * L - uy * D + s.ay * Y
		Fz = Fz + lz * L - uz * D + s.az * Y

		-- pressao dinamica na cauda (inclui o sopro da helice)
		local qCauda = qd
		if P.Tipo ~= "jato" then qCauda = qd + tracao * (P.SoproHelice or 0.3) / S end
		local fatorCauda = qCauda / math.max(qd, 1)
		local fatorMach = 1
		if M > 0.95 then fatorMach = 1 / (1 + 0.7 * (M - 0.95)) end

		local ph, qh, rh = pR * b / (2 * Vd), qP * c / (2 * Vd), rY * b / (2 * Vd)
		local cma = P.Cma
		if M > 0.95 then cma = cma * (1 + 1.2 * math.min(M - 0.95, 1)) end
		local cm = P.Cm0 + cma * alfa + P.Cmde * de * fatorCauda * fatorMach + P.Cmq * qh
			- (P.CmEstol or 0.08) * estol + (P.CmFlap or 0) * s.Flap
		local amortRol = 1 - 0.6 * intensidadeEstol
		local clR = P.Clb * beta + P.Clp * ph * amortRol + P.Clr * rh + P.Clda * da * fatorMach
			+ (P.QuedaAsa or 0.04) * intensidadeEstol * s.LadoEstol
		local cn = P.Cnb * beta + P.Cnr * rh + P.Cndr * dr * fatorCauda + P.Cnda * da
		local Lr = qd * S * b * clR
		local Mp = qd * S * c * cm
		local Nr = qd * S * b * cn
		-- torque e fator P da helice (puxa o nariz para a esquerda)
		if P.Tipo ~= "jato" and P.TorqueHelice then
			Nr = Nr - P.TorqueHelice * tracao * limitar(1 - V / 90, 0.25, 1)
		end
		Tx, Ty, Tz = Tx + Mp, Ty - Nr, Tz - Lr
	end

	-- tracao ao longo do nariz
	Fx, Fy, Fz = Fx - s.cx * tracao, Fy - s.cy * tracao, Fz - s.cz * tracao

	-- trem de pouso
	local emSolo = false
	local wwx = s.wx * s.ax + s.wy * s.bx + s.wz * s.cx
	local wwy = s.wx * s.ay + s.wy * s.by + s.wz * s.cy
	local wwz = s.wx * s.az + s.wy * s.bz + s.wz * s.cz
	local freio = limitar(e.Freio or 0, 0, 1)
	local fhx, fhz = -s.cx, -s.cz
	local mh = sqrt(fhx * fhx + fhz * fhz)
	if mh < 1e-6 then fhx, fhz = 0, -1 else fhx, fhz = fhx / mh, fhz / mh end
	local rhx, rhz = -fhz, fhx
	local afundamentoMax = 0
	local superficieAtual = nil
	if s.Trem > 0.98 then
		for i, roda in ipairs(P.Rodas) do
			local ox, oy, oz = roda[1], roda[2], roda[3]
			local rx = s.ax * ox + s.bx * oy + s.cx * oz
			local ry = s.ay * ox + s.by * oy + s.cy * oz
			local rz = s.az * ox + s.bz * oy + s.cz * oz
			local wpx, wpy, wpz = s.px + rx, s.py + ry, s.pz + rz
			local hs, tipo = s.Solo(wpx, wpz)
			local comp = hs - wpy
			if comp > 0 then
				emSolo = true
				superficieAtual = tipo
				local cvx, cvy, cvz = cruz(wwx, wwy, wwz, rx, ry, rz)
				cvx, cvy, cvz = vx + cvx, vy + cvy, vz + cvz
				if not s.ContatoRoda[i] then
					s.ContatoRoda[i] = true
					if -cvy > afundamentoMax then afundamentoMax = -cvy end
				end
				local k, cAmort = roda[4], roda[5]
				local Fn = k * comp - cAmort * cvy
				if Fn < 0 then Fn = 0 end
				if comp > (roda[6] or 0.45) then
					falhar(s, "O trem de pouso colapsou")
					return
				end
				-- direcao da roda (a bequilha esterça)
				local dx, dz, sx, sz = fhx, fhz, rhx, rhz
				if roda[7] then
					local ang = limitar(dr + cRol * 0.5, -1, 1) * P.DirecaoBequilha * limitar(1 - (V - 8) / 35, 0.15, 1)
					local ca, sa = cos(ang), sin(ang)
					dx, dz = fhx * ca + rhx * sa, fhz * ca + rhz * sa
					sx, sz = rhx * ca - fhx * sa, rhz * ca - fhz * sa
				end
				local vLong = cvx * dx + cvz * dz
				local vLat = cvx * sx + cvz * sz
				local muRol = (tipo == "pista") and 0.018 or 0.07
				local muFreio = (tipo == "pista") and 0.55 or 0.3
				local fLong = -muRol * Fn * limitar(vLong / 0.5, -1, 1)
				if roda[8] then fLong = fLong - muFreio * freio * Fn * limitar(vLong / 0.1, -1, 1) end
				local fLat = -0.85 * Fn * limitar(vLat / 0.3, -1, 1)
				local gx = dx * fLong + sx * fLat
				local gz = dz * fLong + sz * fLat
				Fx, Fy, Fz = Fx + gx, Fy + Fn, Fz + gz
				local tx, ty, tz = torqueCorpo(s, rx, ry, rz, gx, Fn, gz)
				Tx, Ty, Tz = Tx + tx, Ty + ty, Tz + tz
				if tipo == "agua" then falhar(s, "A aeronave caiu na água") return end
			else
				s.ContatoRoda[i] = false
			end
		end
	else
		for i = 1, #P.Rodas do s.ContatoRoda[i] = false end
	end
	if afundamentoMax > 0 and not s.EmSolo then
		s.Toque = { Afundamento = afundamentoMax, Tempo = s.Tempo, Superficie = superficieAtual,
			X = s.px, Z = s.pz, Inclinacao = s.Inclinacao or 0, Velocidade = V }
		if afundamentoMax > P.LimitePouso then
			falhar(s, "Pouso duro: o trem de pouso não suportou o impacto")
			return
		end
	end
	s.EmSolo = emSolo
	s.Superficie = superficieAtual
	if emSolo and superficieAtual == "grama" and V > (P.VelocidadeMaxGrama or 40) then
		falhar(s, "A aeronave saiu da pista em alta velocidade")
		return
	end

	-- pontos da estrutura que nao podem tocar o chao
	for _, pt in ipairs(P.Estrutura) do
		local ox, oy, oz = pt[1], pt[2], pt[3]
		if pt[5] ~= "barriga" or s.Trem < 0.98 then
			local wy = s.py + s.ay * ox + s.by * oy + s.cy * oz
			local wx = s.px + s.ax * ox + s.bx * oy + s.cx * oz
			local wz = s.pz + s.az * ox + s.bz * oy + s.cz * oz
			local hs, tipo = s.Solo(wx, wz)
			if wy < hs - 0.03 then
				if tipo == "agua" then falhar(s, "A aeronave caiu na água")
				else falhar(s, pt[4]) end
				return
			end
		end
	end

	-- forca especifica (fator de carga) sem a gravidade
	s.Nz = (Fx * s.bx + Fy * s.by + Fz * s.bz) / (m * G0)
	s.NzFiltrado = s.NzFiltrado + (s.Nz - s.NzFiltrado) * math.min(1, dt * 12)

	-- integracao translacional
	Fy = Fy - m * G0
	s.vx, s.vy, s.vz = vx + Fx / m * dt, vy + Fy / m * dt, vz + Fz / m * dt
	s.px, s.py, s.pz = s.px + s.vx * dt, s.py + s.vy * dt, s.pz + s.vz * dt

	-- integracao rotacional (inercia diagonal, eixos do Roblox)
	local Ixx, Iyy, Izz = P.Iarfagem, P.Iguinada, P.Irolagem
	local wx, wy, wz = s.wx, s.wy, s.wz
	local gx, gy, gz = cruz(wx, wy, wz, Ixx * wx, Iyy * wy, Izz * wz)
	wx = wx + (Tx - gx) / Ixx * dt
	wy = wy + (Ty - gy) / Iyy * dt
	wz = wz + (Tz - gz) / Izz * dt
	s.wx, s.wy, s.wz = wx, wy, wz
	local Wx = wx * s.ax + wy * s.bx + wz * s.cx
	local Wy = wx * s.ay + wy * s.by + wz * s.cy
	local Wz = wx * s.az + wy * s.bz + wz * s.cz
	local dax, day, daz = cruz(Wx, Wy, Wz, s.ax, s.ay, s.az)
	local dbx, dby, dbz = cruz(Wx, Wy, Wz, s.bx, s.by, s.bz)
	local dcx, dcy, dcz = cruz(Wx, Wy, Wz, s.cx, s.cy, s.cz)
	local ax, ay, az = s.ax + dax * dt, s.ay + day * dt, s.az + daz * dt
	local bx, by, bz = s.bx + dbx * dt, s.by + dby * dt, s.bz + dbz * dt
	local cx, cy, cz = normalizar(s.cx + dcx * dt, s.cy + dcy * dt, s.cz + dcz * dt)
	ax, ay, az = normalizar(cruz(bx, by, bz, cx, cy, cz))
	bx, by, bz = cruz(cx, cy, cz, ax, ay, az)
	s.ax, s.ay, s.az, s.bx, s.by, s.bz, s.cx, s.cy, s.cz = ax, ay, az, bx, by, bz, cx, cy, cz

	s.Tempo = s.Tempo + dt
	s.Alfa, s.Beta, s.Mach, s.Rho = alfa, beta, M, rho
end

-- Calcula as grandezas de saida (instrumentos)
function Fisica.Calcular(s)
	local rho, somV = Fisica.Atmosfera(s.py)
	local V = sqrt(s.vx * s.vx + s.vy * s.vy + s.vz * s.vz)
	s.V = V
	s.IAS = V * sqrt(rho / 1.225)
	s.Mach = V / somV
	s.Altitude = s.py
	local hs = s.Solo(s.px, s.pz)
	s.AGL = s.py - hs - (s.P.AlturaTrem or 1.5)
	s.VS = s.vy
	local fx, fy, fz = -s.cx, -s.cy, -s.cz
	s.Arfagem = math.deg(asin(limitar(fy, -1, 1)))
	local rumo = math.deg(atan2(fx, -fz))
	if rumo < 0 then rumo = rumo + 360 end
	s.Rumo = rumo
	s.Inclinacao = math.deg(atan2(-s.ay, s.by))
	s.AlfaGraus = math.deg(s.Alfa or 0)
	s.BetaGraus = math.deg(s.Beta or 0)
	local P = s.P
	s.Estol = (s.Alfa or 0) > P.AlfaEstol and not s.EmSolo
	s.AvisoEstol = (s.Alfa or 0) > P.AlfaEstol - math.rad(P.MargemAvisoEstol or 4) and not s.EmSolo and V > 10
	s.Nz = s.Nz or 1
end

-- Avanca a simulacao. e = entradas do piloto.
function Fisica.Passo(s, dt, e)
	if s.Destruido then return end
	if dt > 0.1 then dt = 0.1 end
	local n = math.max(1, math.ceil(dt / PASSO - 1e-6))
	local h = dt / n
	for _ = 1, n do
		subpasso(s, h, e)
		if s.Destruido then break end
	end
	if not s.Destruido then
		local P = s.P
		Fisica.Calcular(s)
		if s.Nz > P.GLimite * 1.5 or s.Nz < P.GNegLimite * 1.5 then
			falhar(s, "Sobrecarga estrutural: limite de G ultrapassado")
		elseif s.IAS > P.VNE * 1.2 then
			falhar(s, "Dano estrutural por excesso de velocidade")
		end
	end
end

-- Matriz de rotacao para montar um CFrame no Roblox:
-- CFrame.new(x, y, z, Fisica.Matriz(s))
function Fisica.Matriz(s)
	return s.ax, s.bx, s.cx, s.ay, s.by, s.cy, s.az, s.bz, s.cz
end

return Fisica
