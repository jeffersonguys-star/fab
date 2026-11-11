--[[
	FAB - Controles do simulador (cliente)

	Celular: manche virtual (esquerda), manete deslizante (direita) e botoes de
	trem, flape, freios, freio aerodinamico, leme, compensador, manobra anti-G e respiracao.
	Arrastar na area livre da tela movimenta a cabeca (olhar ao redor); um toque
	rapido aciona o interruptor da cabine que estiver sob o dedo.

	Teclado: W/S arfagem (S puxa), A/D rolagem, Q/E leme, Shift/Ctrl manete,
	F pos-combustor, G trem, X flape, B freios (segurar), V freio aerodinamico,
	T/Y compensador, Espaco manobra anti-G (segurar), R respirar, C centralizar a visao.
	Botao direito do mouse arrastado: olhar ao redor. Clique: interruptores.
]]

local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local CTRL = {}

function CTRL.Criar(UI, P, opcoes)
	local COR = UI.Cor
	local obj = {
		Entradas = { Arfagem = 0, Rolagem = 0, Leme = 0, Manete = opcoes.Manete or 0, Pos = false, Freio = 0, Flap = opcoes.Flap or 0,
			Trem = opcoes.Trem ~= false, AeroFreio = false },
		Trim = 0, AGSM = false, OlharYaw = 0, OlharPitch = 0,
		AoAcao = opcoes.AoAcao or function() end,
		AoToque = opcoes.AoToque or function() end,
	}
	local E = obj.Entradas
	local tela = UI.Novo("ScreenGui", { Name = "FABSimControles", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 8,
		Parent = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui") })
	obj.Tela = tela
	local conexoes = {}
	local teclas = {}
	local toqueManche, toqueManete, toqueOlhar
	local mancheX, mancheY = 0, 0

	-- MANCHE VIRTUAL --------------------------------------------------------------
	local base = UI.Novo("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 28, 1, -24), Size = UDim2.fromOffset(160, 160),
		BackgroundColor3 = COR.Fundo, BackgroundTransparency = 0.45, Parent = tela })
	UI.Canto(base, 80)
	UI.Contorno(base, 0.6)
	UI.Novo("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, -20, 0, 1), BackgroundColor3 = COR.Branco, BackgroundTransparency = 0.8, Parent = base })
	UI.Novo("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0, 1, 1, -20), BackgroundColor3 = COR.Branco, BackgroundTransparency = 0.8, Parent = base })
	local polegar = UI.Novo("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(62, 62),
		BackgroundColor3 = COR.Branco, BackgroundTransparency = 0.1, Parent = base })
	UI.Canto(polegar, 31)

	-- MANETE ----------------------------------------------------------------------
	local trilho = UI.Novo("Frame", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -24, 1, -24), Size = UDim2.fromOffset(74, 200),
		BackgroundColor3 = COR.Fundo, BackgroundTransparency = 0.45, Parent = tela })
	UI.Canto(trilho, 18)
	UI.Contorno(trilho, 0.6)
	local jato = P.Tipo == "jato" and P.TracaoPos ~= nil
	if jato then
		local zonaPos = UI.Novo("Frame", { Size = UDim2.new(1, 0, 0.12, 0), BackgroundColor3 = COR.Branco, BackgroundTransparency = 0.82, Parent = trilho })
		UI.Canto(zonaPos, 18)
		UI.Rotulo(zonaPos, "PÓS", 11, { Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), AutomaticSize = Enum.AutomaticSize.None })
	end
	local alca = UI.Novo("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 1), Size = UDim2.new(1, -10, 0, 30),
		BackgroundColor3 = COR.Branco, Parent = trilho })
	UI.Canto(alca, 10)
	local txtManete = UI.Rotulo(alca, "", 12, { Font = Enum.Font.GothamBold, TextColor3 = COR.Fundo, TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1), AutomaticSize = Enum.AutomaticSize.None })
	local valorManete = E.Manete
	local function aplicarManete(v)
		v = math.clamp(v, 0, 1)
		valorManete = v
		if jato then
			E.Pos = v > 0.9
			E.Manete = math.min(v / 0.88, 1)
		else
			E.Pos = false
			E.Manete = v
		end
		alca.Position = UDim2.new(0.5, 0, 1 - v, 0)
		txtManete.Text = E.Pos and "PÓS" or (math.floor(E.Manete * 100) .. "%")
	end
	if jato and E.Manete >= 0.999 then valorManete = 0.88 end
	aplicarManete(jato and E.Manete * 0.88 or E.Manete)

	-- BOTOES ----------------------------------------------------------------------
	local grade = UI.Novo("Frame", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -110, 1, -24), Size = UDim2.fromOffset(222, 210),
		BackgroundTransparency = 1, Parent = tela })
	UI.Novo("UIGridLayout", { CellSize = UDim2.fromOffset(70, 44), CellPadding = UDim2.fromOffset(6, 6), HorizontalAlignment = Enum.HorizontalAlignment.Right,
		VerticalAlignment = Enum.VerticalAlignment.Bottom, SortOrder = Enum.SortOrder.LayoutOrder, Parent = grade })
	local botoes = {}
	local function botao(id, texto, ordem, segurar, fnDown, fnUp)
		local b = UI.Botao(grade, texto, "secundario", nil, { TextSize = 11, LayoutOrder = ordem })
		b.BackgroundTransparency = 0.25
		if segurar then
			b.MouseButton1Down:Connect(fnDown)
			b.MouseButton1Up:Connect(fnUp)
			b.MouseLeave:Connect(fnUp)
		else
			b.Activated:Connect(fnDown)
		end
		botoes[id] = b
		return b
	end
	local function marcar(id, ativo)
		local b = botoes[id]
		if not b then return end
		b.BackgroundColor3 = ativo and COR.Branco or COR.Cartao
		b.TextColor3 = ativo and COR.Fundo or COR.Branco
	end
	obj.Marcar = marcar
	botao("LemeE", "◄ LEME", 1, true, function() teclas.LemeE = true end, function() teclas.LemeE = false end)
	botao("LemeD", "LEME ►", 2, true, function() teclas.LemeD = true end, function() teclas.LemeD = false end)
	botao("Freio", "FREIOS", 3, true, function() teclas.Freio = true end, function() teclas.Freio = false end)
	if P.TremRetratil then botao("Trem", "TREM", 4, false, function() obj.AoAcao("Trem") end) end
	botao("Flape", "FLAPE", 5, false, function() obj.AoAcao("Flape") end)
	if P.TemAeroFreio then botao("AeroFreio", "FREIO AR", 6, false, function() obj.AoAcao("AeroFreio") end) end
	if not P.FBW then
		botao("TrimC", "TRIM ▲", 7, true, function() teclas.TrimC = true end, function() teclas.TrimC = false end)
		botao("TrimB", "TRIM ▼", 8, true, function() teclas.TrimB = true end, function() teclas.TrimB = false end)
	end
	botao("AGSM", "ANTI-G", 9, true, function() obj.AGSM = true end, function() obj.AGSM = false end)
	botao("Respirar", "RESPIRAR", 10, false, function() obj.AoAcao("Respirar") end)

	-- topo: menu e vista
	local topo = UI.Novo("Frame", { Position = UDim2.new(0, 16, 0, 14), Size = UDim2.fromOffset(0, 36), AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1, Parent = tela })
	UI.Novo("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), Parent = topo })
	UI.Botao(topo, "MENU", "secundario", function() obj.AoAcao("Menu") end, { Size = UDim2.fromOffset(84, 36), TextSize = 12 })
	UI.Botao(topo, "VISTA", "secundario", function() obj.OlharYaw, obj.OlharPitch = 0, 0 end, { Size = UDim2.fromOffset(84, 36), TextSize = 12 })
	UI.Botao(topo, "DADOS", "secundario", function() obj.AoAcao("Dados") end, { Size = UDim2.fromOffset(84, 36), TextSize = 12 })

	-- ENTRADA POR TOQUE ----------------------------------------------------------------
	local function dentro(frame, pos)
		local p, s = frame.AbsolutePosition, frame.AbsoluteSize
		return pos.X >= p.X and pos.X <= p.X + s.X and pos.Y >= p.Y and pos.Y <= p.Y + s.Y
	end
	local function atualizarManche(pos)
		local c = base.AbsolutePosition + base.AbsoluteSize / 2
		local raio = base.AbsoluteSize.X / 2
		local d = Vector2.new(pos.X, pos.Y) - c
		if d.Magnitude > raio then d = d.Unit * raio end
		mancheX = d.X / raio
		mancheY = d.Y / raio
		polegar.Position = UDim2.new(0.5, d.X, 0.5, d.Y)
	end
	local inicioToque = {}
	table.insert(conexoes, UserInputService.InputBegan:Connect(function(input, processado)
		if input.UserInputType == Enum.UserInputType.Touch then
			local pos = input.Position
			if dentro(base, pos) then
				toqueManche = input
				atualizarManche(pos)
			elseif dentro(trilho, pos) then
				toqueManete = input
				local rel = 1 - (pos.Y - trilho.AbsolutePosition.Y) / trilho.AbsoluteSize.Y
				aplicarManete(rel)
			elseif not processado then
				toqueOlhar = input
				inicioToque[input] = { Pos = pos, Tempo = os.clock(), Moveu = false }
			end
		elseif input.UserInputType == Enum.UserInputType.MouseButton1 and not processado then
			obj.AoToque(input.Position)
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
			teclas.Olhar = true
		elseif input.UserInputType == Enum.UserInputType.Keyboard and not processado then
			local k = input.KeyCode
			teclas[k] = true
			if k == Enum.KeyCode.G then obj.AoAcao("Trem")
			elseif k == Enum.KeyCode.X then obj.AoAcao("Flape")
			elseif k == Enum.KeyCode.V then obj.AoAcao("AeroFreio")
			elseif k == Enum.KeyCode.R then obj.AoAcao("Respirar")
			elseif k == Enum.KeyCode.C then obj.OlharYaw, obj.OlharPitch = 0, 0
			elseif k == Enum.KeyCode.F and jato then aplicarManete(valorManete > 0.9 and 0.88 or 1)
			elseif k == Enum.KeyCode.Space then obj.AGSM = true
			elseif k == Enum.KeyCode.Escape or k == Enum.KeyCode.M then obj.AoAcao("Menu") end
		end
	end))
	table.insert(conexoes, UserInputService.InputChanged:Connect(function(input)
		if input == toqueManche then
			atualizarManche(input.Position)
		elseif input == toqueManete then
			local rel = 1 - (input.Position.Y - trilho.AbsolutePosition.Y) / trilho.AbsoluteSize.Y
			aplicarManete(rel)
		elseif input == toqueOlhar then
			local ini = inicioToque[input]
			if ini and (input.Position - ini.Pos).Magnitude > 12 then ini.Moveu = true end
			obj.OlharYaw = math.clamp(obj.OlharYaw - input.Delta.X * 0.3, -150, 150)
			obj.OlharPitch = math.clamp(obj.OlharPitch - input.Delta.Y * 0.3, -60, 75)
		elseif input.UserInputType == Enum.UserInputType.MouseMovement and teclas.Olhar then
			obj.OlharYaw = math.clamp(obj.OlharYaw - input.Delta.X * 0.25, -150, 150)
			obj.OlharPitch = math.clamp(obj.OlharPitch - input.Delta.Y * 0.25, -60, 75)
		end
	end))
	table.insert(conexoes, UserInputService.InputEnded:Connect(function(input)
		if input == toqueManche then
			toqueManche = nil
			mancheX, mancheY = 0, 0
			polegar.Position = UDim2.fromScale(0.5, 0.5)
		elseif input == toqueManete then
			toqueManete = nil
		elseif input == toqueOlhar then
			local ini = inicioToque[input]
			if ini and not ini.Moveu and os.clock() - ini.Tempo < 0.35 then obj.AoToque(input.Position) end
			inicioToque[input] = nil
			toqueOlhar = nil
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
			teclas.Olhar = false
		elseif input.UserInputType == Enum.UserInputType.Keyboard then
			teclas[input.KeyCode] = false
			if input.KeyCode == Enum.KeyCode.Space then obj.AGSM = false end
		end
	end))

	-- MISTURA DAS ENTRADAS -------------------------------------------------------------
	local tecArf, tecRol, tecLeme = 0, 0, 0
	local function rampa(atual, alvo, dt, taxa)
		local d = alvo - atual
		local passo = taxa * dt
		if math.abs(d) <= passo then return alvo end
		return atual + passo * (d > 0 and 1 or -1)
	end
	local function expo(x) return (x >= 0 and 1 or -1) * math.abs(x) ^ 1.5 end
	table.insert(conexoes, RunService.RenderStepped:Connect(function(dt)
		local K = Enum.KeyCode
		local alvoArf = 0
		if teclas[K.S] or teclas[K.Down] then alvoArf = alvoArf + 1 end
		if teclas[K.W] or teclas[K.Up] then alvoArf = alvoArf - 1 end
		local alvoRol = 0
		if teclas[K.D] or teclas[K.Right] then alvoRol = alvoRol + 1 end
		if teclas[K.A] or teclas[K.Left] then alvoRol = alvoRol - 1 end
		local alvoLeme = 0
		if teclas[K.E] or teclas.LemeD then alvoLeme = alvoLeme + 1 end
		if teclas[K.Q] or teclas.LemeE then alvoLeme = alvoLeme - 1 end
		tecArf = rampa(tecArf, alvoArf, dt, alvoArf == 0 and 4 or 1.8)
		tecRol = rampa(tecRol, alvoRol, dt, alvoRol == 0 and 5 or 2.5)
		tecLeme = rampa(tecLeme, alvoLeme, dt, 3)
		E.Arfagem = math.clamp(expo(mancheY) + tecArf, -1, 1)
		E.Rolagem = math.clamp(expo(mancheX) + tecRol, -1, 1)
		E.Leme = tecLeme
		E.Freio = (teclas[K.B] or teclas.Freio) and 1 or 0
		if teclas[K.LeftShift] then aplicarManete(valorManete + dt * 0.45) end
		if teclas[K.LeftControl] then aplicarManete(valorManete - dt * 0.45) end
		if teclas[K.T] or teclas.TrimC then obj.Trim = math.clamp(obj.Trim + dt * 0.25, -1, 1) end
		if teclas[K.Y] or teclas.TrimB then obj.Trim = math.clamp(obj.Trim - dt * 0.25, -1, 1) end
		marcar("Freio", E.Freio > 0)
		marcar("AGSM", obj.AGSM)
		marcar("Trem", E.Trem)
		marcar("AeroFreio", E.AeroFreio)
		marcar("Flape", E.Flap > 0)
	end))

	function obj.DefinirManete(v)
		aplicarManete(jato and v * 0.88 or v)
	end

	function obj.Destruir()
		for _, c in ipairs(conexoes) do c:Disconnect() end
		tela:Destroy()
	end

	return obj
end

return CTRL
