--[[
	FAB - Perfis das aeronaves do simulador (ModuleScript)

	Dados aproximados das aeronaves reais, ajustados para o modelo de voo
	(Fisica.lua). Massas em kg, areas em m2, distancias em m, tracao em N,
	potencia em W, angulos em radianos e velocidades em m/s.

	Rodas: { x, y, z, rigidez da mola, amortecimento, compressao maxima, bequilha, freio }
	Estrutura: { x, y, z, mensagem da colisao, "barriga" = so conta com o trem recolhido }
]]

local Aeronaves = {}

Aeronaves.Ordem = { "T25", "T27", "A29", "F5", "F39" }

Aeronaves.T25 = {
	Id = "T25", Nome = "T-25 Universal", Funcao = "Instrução primária",
	Tipo = "helice", Cabine = "analogica", Assentos = "lado",
	Olho = { -0.34, 0.78, -0.35 },
	Massa = 1200, Combustivel = 200,
	Area = 17.2, Envergadura = 11.0, Corda = 1.6,
	Irolagem = 1800, Iarfagem = 2600, Iguinada = 4000,
	CL0 = 0.25, CLa = 4.8, AlfaEstol = math.rad(15), AlfaEstolNeg = math.rad(12),
	CLFlap = 0.55, AlfaFlap = math.rad(2), CmFlap = -0.03,
	CD0 = 0.034, CDFlap = 0.05, K = 0.065, CYb = -0.5,
	MachCritico = 0.6, ArrastoOnda = 0.05,
	Cm0 = 0.029, Cma = -0.9, Cmq = -14, Cmde = 0.5, CmEstol = 0.1,
	Clb = -0.08, Clp = -0.47, Clr = 0.1, Clda = 0.075, QuedaAsa = 0.035,
	Cnb = 0.07, Cnr = -0.12, Cndr = 0.055, Cnda = -0.008,
	Potencia = 224000, TracaoEstatica = 4500, EficienciaHelice = 0.8, TempoMotor = 1.2,
	-- realismo: rajadas, helice, parafuso, motor
	SensibilidadeRajada = 1.4, FatorP = 0.16, TorqueRolagem = 0.03, Giroscopio = 230, Parafuso = 0.25,
	TempCabecote = 175, TempMaxMotor = 250, CarburadorNegG = 3,
	Consumo = 0.0167, TorqueHelice = 0.06, SoproHelice = 0.35, ArrastoHelice = 0.015,
	ExpoenteAltitude = 0.85,
	TremRetratil = false, TempoFlap = 5, DirecaoBequilha = 0.5,
	AlturaTrem = 1.45,
	Rodas = {
		{ 0, -1.45, -1.9, 40000, 4500, 0.4, true, false },
		{ -1.6, -1.45, 0.35, 75000, 9000, 0.4, false, true },
		{ 1.6, -1.45, 0.35, 75000, 9000, 0.4, false, true },
	},
	Estrutura = {
		{ 0, -0.95, -3.9, "A hélice tocou o solo" },
		{ 0, -0.7, 4.6, "A cauda tocou o solo" },
		{ 5.4, -0.55, 0.2, "A ponta da asa direita tocou o solo" },
		{ -5.4, -0.55, 0.2, "A ponta da asa esquerda tocou o solo" },
		{ 0, 0.9, 0, "A aeronave capotou" },
	},
	GLimite = 4.4, GNegLimite = -2.2, VNE = 85, LimitePouso = 3.8, VelocidadeMaxGrama = 45,
	MargemAvisoEstol = 4,
	-- velocidades de referencia (indicadas, m/s)
	VR = 30, VAprox = 36, VCruzeiro = 57, VMaxFlap = 51,
}

Aeronaves.T27 = {
	Id = "T27", Nome = "T-27 Tucano", Funcao = "Instrução básica e acrobacia",
	Tipo = "helice", Cabine = "analogica", Assentos = "tandem",
	Olho = { 0, 0.95, -0.9 },
	Massa = 2350, Combustivel = 400,
	Area = 19.4, Envergadura = 11.14, Corda = 1.8,
	Irolagem = 7000, Iarfagem = 9500, Iguinada = 15000,
	CL0 = 0.2, CLa = 5.0, AlfaEstol = math.rad(15.5), AlfaEstolNeg = math.rad(12.5),
	CLFlap = 0.6, AlfaFlap = math.rad(2), CmFlap = -0.03,
	CD0 = 0.024, CDFlap = 0.05, CDTrem = 0.018, K = 0.06, CYb = -0.55,
	MachCritico = 0.68, ArrastoOnda = 0.05,
	Cm0 = 0.012, Cma = -0.9, Cmq = -15, Cmde = 0.55, CmEstol = 0.1,
	Clb = -0.07, Clp = -0.45, Clr = 0.1, Clda = 0.08, QuedaAsa = 0.035,
	Cnb = 0.08, Cnr = -0.13, Cndr = 0.06, Cnda = -0.008,
	Potencia = 560000, TracaoEstatica = 10500, EficienciaHelice = 0.82, TempoMotor = 2.5,
	SensibilidadeRajada = 1.1, FatorP = 0.14, TorqueRolagem = 0.025, Giroscopio = 650, Parafuso = 0.28,
	TempCabecote = 160, TempMaxMotor = 260,
	Consumo = 0.055, TorqueHelice = 0.05, SoproHelice = 0.3, ArrastoHelice = 0.012,
	ExpoenteAltitude = 0.7,
	TremRetratil = true, TempoTrem = 6, TempoFlap = 5, DirecaoBequilha = 0.45,
	AlturaTrem = 1.6,
	Rodas = {
		{ 0, -1.6, -2.4, 70000, 7000, 0.4, true, false },
		{ -1.85, -1.6, 0.35, 150000, 18800, 0.4, false, true },
		{ 1.85, -1.6, 0.35, 150000, 18800, 0.4, false, true },
	},
	Estrutura = {
		{ 0, -1.1, -4.6, "A hélice tocou o solo" },
		{ 0, -0.8, 5.4, "A cauda tocou o solo" },
		{ 5.5, -0.5, 0.3, "A ponta da asa direita tocou o solo" },
		{ -5.5, -0.5, 0.3, "A ponta da asa esquerda tocou o solo" },
		{ 0, -1.0, 0, "Pouso de barriga: o trem de pouso estava recolhido", "barriga" },
		{ 0, -0.95, -2.6, "Pouso de barriga: o trem de pouso estava recolhido", "barriga" },
		{ 0, 1.2, 0, "A aeronave capotou" },
	},
	GLimite = 6, GNegLimite = -3, VNE = 145, LimitePouso = 3.8, VelocidadeMaxGrama = 40,
	MargemAvisoEstol = 4,
	VR = 41, VAprox = 51, VCruzeiro = 105, VMaxFlap = 72, VMaxTrem = 80,
}

Aeronaves.A29 = {
	Id = "A29", Nome = "A-29 Super Tucano", Funcao = "Ataque leve e treinamento avançado",
	Tipo = "helice", Cabine = "vidro", Assentos = "tandem", HUD = true,
	Olho = { 0, 1.0, -1.1 },
	Massa = 3900, Combustivel = 500,
	Area = 19.4, Envergadura = 11.14, Corda = 1.8,
	Irolagem = 11000, Iarfagem = 17000, Iguinada = 26000,
	CL0 = 0.2, CLa = 5.0, AlfaEstol = math.rad(16), AlfaEstolNeg = math.rad(12.5),
	CLFlap = 0.6, AlfaFlap = math.rad(2), CmFlap = -0.03,
	CD0 = 0.028, CDFlap = 0.05, CDTrem = 0.018, K = 0.06, CYb = -0.55,
	MachCritico = 0.68, ArrastoOnda = 0.05,
	Cm0 = 0.01, Cma = -0.9, Cmq = -16, Cmde = 0.55, CmEstol = 0.1,
	Clb = -0.07, Clp = -0.45, Clr = 0.1, Clda = 0.075, QuedaAsa = 0.035,
	Cnb = 0.08, Cnr = -0.13, Cndr = 0.06, Cnda = -0.008,
	Potencia = 1194000, TracaoEstatica = 19000, EficienciaHelice = 0.82, TempoMotor = 2.5,
	SensibilidadeRajada = 0.9, FatorP = 0.12, TorqueRolagem = 0.02, Giroscopio = 800, Parafuso = 0.15,
	TempCabecote = 160, TempMaxMotor = 270,
	Consumo = 0.1, TorqueHelice = 0.05, SoproHelice = 0.3, ArrastoHelice = 0.012,
	ExpoenteAltitude = 0.7,
	TremRetratil = true, TempoTrem = 6, TempoFlap = 5, DirecaoBequilha = 0.45,
	AlturaTrem = 1.65,
	Rodas = {
		{ 0, -1.65, -2.5, 110000, 11000, 0.4, true, false },
		{ -1.95, -1.65, 0.4, 230000, 29300, 0.4, false, true },
		{ 1.95, -1.65, 0.4, 230000, 29300, 0.4, false, true },
	},
	Estrutura = {
		{ 0, -1.15, -5.0, "A hélice tocou o solo" },
		{ 0, -0.8, 5.9, "A cauda tocou o solo" },
		{ 5.5, -0.5, 0.3, "A ponta da asa direita tocou o solo" },
		{ -5.5, -0.5, 0.3, "A ponta da asa esquerda tocou o solo" },
		{ 0, -1.05, 0, "Pouso de barriga: o trem de pouso estava recolhido", "barriga" },
		{ 0, -1.0, -2.7, "Pouso de barriga: o trem de pouso estava recolhido", "barriga" },
		{ 0, 1.3, 0, "A aeronave capotou" },
	},
	GLimite = 7, GNegLimite = -3.5, VNE = 165, LimitePouso = 3.8, VelocidadeMaxGrama = 40,
	MargemAvisoEstol = 4,
	VR = 46, VAprox = 56, VCruzeiro = 140, VMaxFlap = 77, VMaxTrem = 90,
}

Aeronaves.F5 = {
	Id = "F5", Nome = "F-5EM Tiger II", Funcao = "Caça de superioridade aérea",
	Tipo = "jato", Cabine = "vidro", Assentos = "unico", HUD = true,
	Olho = { 0, 0.95, -3.2 },
	Massa = 5200, Combustivel = 2000,
	Area = 17.28, Envergadura = 8.13, Corda = 2.36,
	Irolagem = 4500, Iarfagem = 50000, Iguinada = 54000,
	CL0 = 0.02, CLa = 3.4, AlfaEstol = math.rad(24), AlfaEstolNeg = math.rad(17),
	CLFlap = 0.35, AlfaFlap = 0, CmFlap = -0.01,
	CD0 = 0.021, CDFlap = 0.04, CDTrem = 0.025, CDAeroFreio = 0.07, K = 0.17, CYb = -0.9,
	MachCritico = 0.87, ArrastoOnda = 0.027,
	Cm0 = 0.0246, Cma = -0.45, Cmq = -8, Cmde = 0.24, CmEstol = 0.06,
	Clb = -0.06, Clp = -0.32, Clr = 0.08, Clda = 0.03, QuedaAsa = 0.02,
	Cnb = 0.12, Cnr = -0.3, Cndr = 0.045, Cnda = -0.004,
	SensibilidadeRajada = 0.7, Parafuso = 0.12,
	TracaoMil = 31000, TracaoPos = 44400, TSFC = 1.0, TSFCPos = 2.13, TempoMotor = 3.5,
	AmortecedorGuinada = 1.0,
	TremRetratil = true, TempoTrem = 5, TempoFlap = 3, TemAeroFreio = true, DirecaoBequilha = 0.35,
	AlturaTrem = 1.4,
	Rodas = {
		{ 0, -1.4, -4.5, 150000, 15900, 0.45, true, false },
		{ -1.3, -1.4, 0.6, 330000, 45300, 0.45, false, true },
		{ 1.3, -1.4, 0.6, 330000, 45300, 0.45, false, true },
	},
	Estrutura = {
		{ 0, -0.3, -7.5, "O nariz tocou o solo" },
		{ 0, -0.4, 6.2, "Os bocais tocaram o solo" },
		{ 4.06, -0.3, 1.0, "A ponta da asa direita tocou o solo" },
		{ -4.06, -0.3, 1.0, "A ponta da asa esquerda tocou o solo" },
		{ 0, -0.9, 0, "Pouso de barriga: o trem de pouso estava recolhido", "barriga" },
		{ 0, -0.85, -4.0, "Pouso de barriga: o trem de pouso estava recolhido", "barriga" },
		{ 0, 1.3, 0, "A aeronave capotou" },
	},
	GLimite = 7.33, GNegLimite = -3, VNE = 365, LimitePouso = 4.0, VelocidadeMaxGrama = 15,
	MargemAvisoEstol = 5,
	VR = 78, VAprox = 80, VCruzeiro = 230, VMaxFlap = 125, VMaxTrem = 135,
}

Aeronaves.F39 = {
	Id = "F39", Nome = "F-39E Gripen", Funcao = "Caça multimissão",
	Tipo = "jato", Cabine = "vidro", Assentos = "unico", HUD = true, FBW = true,
	Olho = { 0, 1.0, -3.6 },
	Massa = 8600, Combustivel = 2600,
	Area = 30, Envergadura = 8.6, Corda = 3.5,
	Irolagem = 18000, Iarfagem = 95000, Iguinada = 105000,
	CL0 = 0.0, CLa = 3.5, Vortice = 2.5, AlfaEstol = math.rad(30), AlfaEstolNeg = math.rad(20),
	CLFlap = 0, AlfaFlap = 0, CmFlap = 0,
	CD0 = 0.019, CDFlap = 0, CDTrem = 0.022, CDAeroFreio = 0.06, K = 0.19, CYb = -0.8,
	MachCritico = 0.9, ArrastoOnda = 0.03,
	Cm0 = 0.0, Cma = -0.25, Cmq = -6, Cmde = 0.35, CmEstol = 0.05,
	Clb = -0.05, Clp = -0.28, Clr = 0.06, Clda = 0.04, QuedaAsa = 0.01,
	Cnb = 0.1, Cnr = -0.3, Cndr = 0.04, Cnda = -0.004,
	SensibilidadeRajada = 0.5, Parafuso = 0,
	TracaoMil = 57800, TracaoPos = 98000, TSFC = 0.84, TSFCPos = 1.85, TempoMotor = 3.0,
	GMax = 9, GMin = -3, AlfaMaxFBW = math.rad(26), RolagemMaxFBW = math.rad(250),
	TremRetratil = true, TempoTrem = 4, TempoFlap = 3, TemAeroFreio = true, DirecaoBequilha = 0.35,
	AlturaTrem = 1.55,
	Rodas = {
		{ 0, -1.55, -4.3, 250000, 26600, 0.45, true, false },
		{ -1.2, -1.55, 0.5, 520000, 73400, 0.45, false, true },
		{ 1.2, -1.55, 0.5, 520000, 73400, 0.45, false, true },
	},
	Estrutura = {
		{ 0, -0.4, -7.3, "O nariz tocou o solo" },
		{ 0, -0.25, 6.6, "O bocal tocou o solo" },
		{ 4.3, -0.5, 2.0, "A ponta da asa direita tocou o solo" },
		{ -4.3, -0.5, 2.0, "A ponta da asa esquerda tocou o solo" },
		{ 0, -0.95, 0, "Pouso de barriga: o trem de pouso estava recolhido", "barriga" },
		{ 0, -0.9, -3.8, "Pouso de barriga: o trem de pouso estava recolhido", "barriga" },
		{ 0, 1.3, 0, "A aeronave capotou" },
	},
	GLimite = 9, GNegLimite = -3, VNE = 420, LimitePouso = 4.5, VelocidadeMaxGrama = 15,
	MargemAvisoEstol = 4,
	VR = 78, VAprox = 75, VCruzeiro = 250, VMaxTrem = 135,
}

return Aeronaves
