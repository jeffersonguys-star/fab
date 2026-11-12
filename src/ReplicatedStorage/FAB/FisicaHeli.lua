--[[
	FAB - Fisica de helicoptero (ModuleScript, usado por Fisica.lua)

	Helicoptero de rotor principal unico e rotor de cauda. Corpo rigido com 6 graus de liberdade,
	mesmos eixos e mesmo estado do modelo de aviao (X direita, Y cima, Z tras, nariz em -Z), por isso
	a cabine, o HUD e o simulador continuam funcionando sem mudancas.

	O que e simulado:
	- Rotor principal por teoria de momento com elemento de pa simplificado: o coeficiente de
	  empuxo vem do coletivo, da velocidade do ar e do fluxo induzido (iterado). Cobre pairado,
	  subida, translacao (sustentacao translacional), descida, efeito solo e anel de vortices
	- Potencia induzida, de perfil e parasita; limite de potencia do motor, regulador de rotacao,
	  queda de rotacao com excesso de coletivo e autorrotacao com o motor parado
	- Inclinacao do disco com atraso (batimento), rigidez do cubo e refluxo
	- Torque de reacao do motor e rotor de cauda (antitorque, translacao lateral e momento de rolagem)
	- Fuselagem com arrasto por eixo, estabilizador horizontal e deriva vertical
	- Trem de pouso com molas, amortecedores, atrito e freios; colisoes da estrutura
	- Sistema de aumento de estabilidade: o ciclico comanda atitude (com retencao de velocidade
	  em pairado), o pedal comanda taxa de guinada e o coletivo comanda o passo das pas

	Entradas (as mesmas do aviao): Arfagem (puxar = nariz para cima), Rolagem, Leme (pedais),
	Manete (coletivo, 0 a 1), Freio.
]]

local Heli = {}

local sqrt, sin, cos, abs, exp = math.sqrt, math.sin, math.cos, math.abs, math.exp
local atan2 = math.atan2 or function(y, x) return math.atan(y, x) end
local G0 = 9.80665

local function limitar(x, a, b)
	if x < a then return a elseif x > b then return b end
	return x
end

local function cruz(ax, ay, az, bx, by, bz)
	return ay * bz - az * by, az * bx - ax * bz, ax * by - ay * bx
end

local function normalizar(x, y, z)
	local m = sqrt(x * x + y * y + z * z)
	if m < 1e-12 then return 0, 0, 0 end
	return x / m, y / m, z / m
end

local function gauss()
	return (math.random() + math.random() + math.random() + math.random() - 2) * 1.732
end

-- estado extra do helicoptero (chamado por Fisica.Novo)
function Heli.Iniciar(s)
	local P = s.P
	s.Rotor = s.MotorLigado and P.RotacaoNominal or 0 -- rad/s
	s.MotorDisp = s.MotorLigado and 1 or 0
	s.TiltS, s.TiltC = 0, 0 -- inclinacao do disco: para a frente e para a direita (rad)
	s.Empuxo, s.PotRotor, s.TorqueMotor, s.TracaoCauda = P.Massa * G0, 0, 0, 0
	s.Coletivo, s.Vortice, s.AlturaRotor = 0, 0, 0
	s.N = s.MotorLigado and 1 or 0
	s.FracaoMotor = s.N
end

function Heli.Subpasso(s, dt, e, Fisica)
	local P = s.P
	local R = P.RaioRotor
	local A = math.pi * R * R
	local OM0 = P.RotacaoNominal
	local rho, somV, Tar = Fisica.Atmosfera(s.py)
	local m = P.Massa + s.Combustivel
	local vx, vy, vz = s.vx, s.vy, s.vz
	local Vsolo = sqrt(vx * vx + vy * vy + vz * vz)

	-- vento com cisalhamento e rajadas filtradas
	local hv = math.max(s.py - (P.AlturaTrem or 1.5), 0)
	local perfil = limitar((math.max(hv, 2) / 10) ^ 0.14, 0.7, 1.6)
	local sigG = (s.Turbulencia or 0) * (P.SensibilidadeRajada or 1) * limitar(0.35 + hv / 600, 0.35, 1.2)
	local kf = exp(-dt / 2.5)
	local rr = sqrt(1 - kf * kf) * sigG
	s.Gx = s.Gx * kf + rr * gauss()
	s.Gy = s.Gy * kf + rr * 0.6 * gauss()
	s.Gz = s.Gz * kf + rr * gauss()
	local wvx, wvy, wvz = s.VentoX * perfil + s.Gx, s.Gy, s.VentoZ * perfil + s.Gz
	local vrx, vry, vrz = vx - wvx, vy - wvy, vz - wvz
	local V = sqrt(vrx * vrx + vry * vry + vrz * vrz)
	s.Var = V
	-- velocidade do ar no corpo: X direita, Y cima, Z tras
	local vbx = vrx * s.ax + vry * s.ay + vrz * s.az
	local vby = vrx * s.bx + vry * s.by + vrz * s.bz
	local vbz = vrx * s.cx + vry * s.cy + vrz * s.cz
	local u = -vbz

	-- atitude e taxas
	local arfAtual = math.asin(limitar(-s.cy, -1, 1))
	local rolAtual = atan2(-s.ay, s.by)
	local qP, pR, rY = s.wx, -s.wz, -s.wy

	-- comandos do piloto
	local cArf = limitar(e.Arfagem or 0, -1, 1)
	local cRol = limitar(e.Rolagem or 0, -1, 1)
	local cLem = limitar(e.Leme or 0, -1, 1)
	local colet = limitar(e.Manete or 0, 0, 1)
	s.Coletivo = colet

	-- motor (disponibilidade de potencia)
	local ligado = s.MotorLigado and not s.FalhaMotor and s.Combustivel > 0
	if ligado then
		s.MotorDisp = math.min(1, s.MotorDisp + dt / (P.TempoMotor or 12))
	else
		s.MotorDisp = math.max(0, s.MotorDisp - dt / 1.5)
	end

	-- ciclico: comando de atitude com retencao de velocidade perto do pairado
	local OM = s.Rotor
	local OMR = math.max(OM, 1) * R
	local vFrente = -(vx * s.cx + vy * s.cy + vz * s.cz)
	local vDireita = vx * s.ax + vy * s.ay + vz * s.az
	local Vh = sqrt(vFrente * vFrente + vDireita * vDireita)
	local tiltMax = P.InclinacaoMaxDisco or 0.2
	local hM, zM = P.AlturaMastro, P.PosicaoMastro or 0
	local T0 = s.Empuxo
	local Ap = math.max((hM * T0 + (P.RigidezCuboArf or 0)) / P.Iarfagem, 2.5)
	local Ar = math.max((hM * T0 + (P.RigidezCuboRol or 0)) / P.Irolagem, 6)
	local arfCmd = (cArf >= 0) and (cArf * math.rad(P.ArfagemMaxCima or 15)) or (cArf * math.rad(P.ArfagemMaxBaixo or 8))
	local rolCmd = cRol * math.rad(P.RolagemMax or 30)
	local mantem = limitar(1 - (abs(cArf) + abs(cRol)) * 5, 0, 1) * limitar(1 - Vh / 45, 0, 1)
	local kv = P.GanhoVelocidade or 0.04
	arfCmd = arfCmd + mantem * kv * limitar(vFrente, -10, 10)
	rolCmd = rolCmd - mantem * kv * limitar(vDireita, -10, 10)
	local wn, zeta = P.FrequenciaAtitude or 2.4, 0.85
	local erroP, erroR = arfCmd - arfAtual, rolCmd - rolAtual
	-- integrador de atitude: elimina o erro permanente causado pelo rotor de cauda, arrasto e momentos da fuselagem
	local naoSolo = not (s.EmSolo and T0 < m * G0 * 0.92)
	if naoSolo then
		s.IntP = limitar((s.IntP or 0) + erroP * dt * 0.6, -0.2, 0.2)
		s.IntR = limitar((s.IntR or 0) + erroR * dt * 0.6, -0.25, 0.25)
	else
		s.IntP, s.IntR = 0, 0
	end
	local alP = wn * wn * (erroP + s.IntP) - 2 * zeta * wn * qP
	local alR = wn * wn * (erroR + s.IntR) - 2 * zeta * wn * pR
	local cmdS = limitar(-alP / Ap, -tiltMax, tiltMax)
	local cmdC = limitar(alR / Ar, -tiltMax, tiltMax)
	-- no solo sem sustentacao suficiente o disco fica neutro
	if not naoSolo then cmdS, cmdC = 0, 0 end
	local lag = math.min(1, dt / (P.AtrasoDisco or 0.1))
	s.TiltS = s.TiltS + (cmdS - s.TiltS) * lag
	s.TiltC = s.TiltC + (cmdC - s.TiltC) * lag
	local tiltF = s.TiltS + (P.InclinacaoMastro or 0)
	local nx, ny, nz = normalizar(sin(s.TiltC), 1, -sin(tiltF))

	-- rotor principal: fluxo induzido e empuxo
	local Vc = vbx * nx + vby * ny + vbz * nz
	local Vph = sqrt(math.max(V * V - Vc * Vc, 0))
	local mu = Vph / OMR
	local lamC = Vc / OMR
	local th0 = (P.ColetivoMin or 0.02) + colet * ((P.ColetivoMax or 0.22) - (P.ColetivoMin or 0.02))
	local sol, a = P.Solidez, P.InclinacaoCL or 5.7
	local lamI = 0.05
	local Ct = 0
	for _ = 1, 10 do
		local lam = lamC + lamI
		Ct = sol * a * ((th0 / 6) * (1 + 1.5 * mu * mu) - lam / 4)
		if Ct < 0 then Ct = 0 end
		local novo = Ct / math.max(2 * sqrt(mu * mu + lam * lam), 0.012)
		lamI = lamI + (novo - lamI) * 0.6
	end
	lamI = limitar(lamI, 0, 0.3)
	-- efeito solo: altura do disco acima do chao
	local hsolo = s.Solo(s.px, s.pz)
	local altRotor = math.max(s.py - hsolo - (P.AlturaTrem or 1.5) + hM, 0.3)
	s.AlturaRotor = altRotor
	local fSolo = limitar(1 / (1 + (R / (4 * altRotor)) ^ 2), 0.55, 1)
	lamI = lamI * fSolo
	-- anel de vortices: descida quase vertical a velocidade proxima da induzida de pairado
	local lamH = sqrt(math.max(Ct / 2, 1e-5))
	local rel = -lamC / lamH
	local vort = 0
	if rel > 0.3 and rel < 2.2 and mu < 0.1 then
		vort = exp(-((rel - 1.1) / 0.5) ^ 2) * (1 - mu / 0.1)
	end
	s.Vortice = vort
	local Tmax = P.TracaoMaxima or m * G0 * 1.6
	local T = limitar(Ct * (1 - 0.4 * vort) * rho * A * OMR * OMR, 0, Tmax)
	s.Empuxo = T

	-- potencia, regulador e rotacao do rotor
	local kappa = P.FatorInduzido or 1.15
	local viMs = lamI * OMR
	local pPerfil = sol * (P.CD0Pa or 0.011) / 8 * rho * A * OMR ^ 3 * (1 + 4.65 * mu * mu)
	local Prot = T * (Vc + kappa * viMs) + pPerfil
	s.PotRotor = Prot
	local Ir = P.InerciaRotor or 8500
	local OMg = math.max(OM, 0.3 * OM0)
	local Pmax = (P.PotenciaMotor or 2.4e6) * s.MotorDisp * limitar(rho / 1.225 + 0.1, 0.3, 1)
	local Peng = 0
	if ligado then
		Peng = limitar(Prot + Ir * OMg * 4 * (OM0 - OM), 0, Pmax)
	end
	local dOM = (Peng - Prot) / (OMg * Ir)
	if OM > OM0 * 1.1 then dOM = dOM - (OM - OM0 * 1.1) * 3 end
	s.Rotor = math.max(0, OM + dOM * dt)
	local Qeng = Peng / math.max(s.Rotor, 0.3 * OM0)
	s.TorqueMotor = Qeng
	s.N = s.Rotor / OM0
	s.FracaoMotor = s.N
	if Peng > 0 then s.Combustivel = math.max(0, s.Combustivel - Peng * (P.ConsumoEspecifico or 1e-7) * dt) end
	if s.Rotor > OM0 * 1.3 then Fisica.Falhar(s, "Sobrevelocidade do rotor") return end

	-- rotor de cauda: antitorque + comando de guinada
	local ltr = P.BracoCauda
	local rCmd = cLem * (P.TaxaGuinadaMax or 0.7)
	local pedal = Qeng / (ltr * P.TracaoCaudaMax) + limitar((rY - rCmd) * (P.GanhoGuinada or 0.9), -1, 1)
	pedal = limitar(pedal, -0.4, 1)
	local fr = limitar(s.Rotor / OM0, 0, 1.1)
	local Ttr = pedal * P.TracaoCaudaMax * fr * fr
	s.TracaoCauda = Ttr

	-- forcas no corpo (X direita, Y cima, Z tras) e momentos (Tx arfagem + nariz para cima, Ty = -guinada direita, Tz = -rolagem direita)
	local fbx, fby, fbz = nx * T + Ttr, ny * T, nz * T
	local Tx = hM * (nz * T) - zM * (ny * T) - (P.RigidezCuboArf or 0) * s.TiltS
	local Ty = zM * (nx * T) - Qeng + ltr * Ttr
	local Tz = -hM * (nx * T) - (P.AlturaCauda or 1.8) * Ttr - (P.RigidezCuboRol or 0) * s.TiltC

	-- fuselagem: arrasto por eixo
	local qv = 0.5 * rho * V
	fbx = fbx - qv * (P.AreaLateral or 6) * vbx
	fby = fby - qv * (P.AreaVertical or 5) * vby
	fbz = fbz - qv * (P.AreaPlana or 2.4) * vbz
	-- estabilizador horizontal e deriva vertical
	local vt = math.max(abs(u), 3)
	local lh, lv = P.BracoEstab or 8.5, P.BracoDeriva or 8.5
	local Fh = -0.5 * rho * vt * (P.AreaEstab or 3.5) * 3.5 * (vby - qP * lh)
	local Fv = -0.5 * rho * vt * (P.AreaDeriva or 3.0) * 3.0 * (vbx - rY * lv)
	fby, fbx = fby + Fh, fbx + Fv
	Tx = Tx - lh * Fh
	Ty = Ty + lv * Fv
	-- amortecimento aerodinamico da fuselagem e do rotor nos tres eixos
	local amort = (P.AmortRotor or 0.04) * (0.5 * rho * OMR * OMR * A * R)
	Tx = Tx - amort * qP * 2.5
	Tz = Tz + amort * pR * 0.6
	Ty = Ty + (P.AmortGuinada or 4000) * rY

	-- para o mundo
	local Fx = s.ax * fbx + s.bx * fby + s.cx * fbz
	local Fy = s.ay * fbx + s.by * fby + s.cy * fbz
	local Fz = s.az * fbx + s.bz * fby + s.cz * fbz

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
	local afundMax = 0
	local superficie = nil
	for i, roda in ipairs(P.Rodas) do
		local ox, oy, oz = roda[1], roda[2], roda[3]
		local rx = s.ax * ox + s.bx * oy + s.cx * oz
		local ry = s.ay * ox + s.by * oy + s.cy * oz
		local rz = s.az * ox + s.bz * oy + s.cz * oz
		local hs, tipo = s.Solo(s.px + rx, s.pz + rz)
		local comp = hs - (s.py + ry)
		if comp > 0 then
			emSolo = true
			superficie = tipo
			local cvx, cvy, cvz = cruz(wwx, wwy, wwz, rx, ry, rz)
			cvx, cvy, cvz = vx + cvx, vy + cvy, vz + cvz
			if not s.ContatoRoda[i] then
				s.ContatoRoda[i] = true
				if -cvy > afundMax then afundMax = -cvy end
			end
			if comp > (roda[6] or 0.45) then Fisica.Falhar(s, "O trem de pouso colapsou") return end
			local Fn = math.max(roda[4] * comp - roda[5] * cvy, 0)
			local vLong = cvx * fhx + cvz * fhz
			local vLat = cvx * rhx + cvz * rhz
			local muRol = (tipo == "pista") and 0.02 or 0.08
			local muFreio = (tipo == "pista") and 0.55 or 0.35
			local fLong = -muRol * Fn * limitar(vLong / 0.5, -1, 1)
			if roda[8] then fLong = fLong - muFreio * freio * Fn * limitar(vLong / 0.1, -1, 1) end
			-- roda de cauda livre (roda[7]) quase nao resiste lateralmente
			local fLat = -(roda[7] and 0.05 or 0.85) * Fn * limitar(vLat / 0.3, -1, 1)
			local gx = fhx * fLong + rhx * fLat
			local gz = fhz * fLong + rhz * fLat
			Fx, Fy, Fz = Fx + gx, Fy + Fn, Fz + gz
			local tx, ty, tz = cruz(rx, ry, rz, gx, Fn, gz)
			Tx = Tx + tx * s.ax + ty * s.ay + tz * s.az
			Ty = Ty + tx * s.bx + ty * s.by + tz * s.bz
			Tz = Tz + tx * s.cx + ty * s.cy + tz * s.cz
			if tipo == "agua" then Fisica.Falhar(s, "A aeronave caiu na água") return end
		else
			s.ContatoRoda[i] = false
		end
	end
	if afundMax > 0 and not s.EmSolo then
		s.Toque = { Afundamento = afundMax, Tempo = s.Tempo, Superficie = superficie,
			X = s.px, Z = s.pz, Inclinacao = s.Inclinacao or 0, Velocidade = Vsolo }
		if afundMax > P.LimitePouso then
			Fisica.Falhar(s, "Pouso duro: o trem de pouso não suportou o impacto")
			return
		end
	end
	s.EmSolo = emSolo
	s.Superficie = superficie
	if emSolo and superficie == "grama" and Vsolo > (P.VelocidadeMaxGrama or 25) then
		Fisica.Falhar(s, "A aeronave saiu da pista em alta velocidade")
		return
	end

	-- estrutura que nao pode tocar o chao
	for _, pt in ipairs(P.Estrutura) do
		local ox, oy, oz = pt[1], pt[2], pt[3]
		local wx = s.px + s.ax * ox + s.bx * oy + s.cx * oz
		local wy = s.py + s.ay * ox + s.by * oy + s.cy * oz
		local wz = s.pz + s.az * ox + s.bz * oy + s.cz * oz
		local hs, tipo = s.Solo(wx, wz)
		if wy < hs - 0.03 then
			if tipo == "agua" then Fisica.Falhar(s, "A aeronave caiu na água") else Fisica.Falhar(s, pt[4]) end
			return
		end
	end

	-- fator de carga (forca especifica no eixo vertical do corpo)
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
	s.Alfa, s.Beta, s.Mach, s.Rho = 0, 0, V / somV, rho
	-- vibracao: anel de vortices e rotor baixo
	s.Buffet = math.min(1.5, vort * 1.2 + limitar((0.9 - s.N) * 4, 0, 1)) * limitar(1, 0, 1)
	-- temperatura da turbina (EGT) proporcional a potencia
	local frac = limitar(Peng / (P.PotenciaMotor or 2.4e6), 0, 1.2)
	s.EGT = s.EGT + ((300 + 520 * frac) - s.EGT) * math.min(1, dt / 8)
	s.TempMotor = s.TempMotor + ((60 + 40 * frac) - s.TempMotor) * math.min(1, dt / 30)
end

return Heli
