--[[
	FAB - HUD e paineis de tela do simulador (cliente)

	HUD (A-29, F-5EM e F-39E): escada de arfagem, horizonte, marcador de trajetoria
	(FPM), referencia do eixo da aeronave, velocidade, altitude, rumo, G, Mach, angulo
	de ataque, altimetro radar, alertas e designador de alvo. A simbologia e projetada
	a partir da camera, como um HUD colimado no infinito.

	Para todas as aeronaves: faixa de dados (preto e branco), objetivos da licao,
	cronometro e mensagens do instrutor.
]]

local HUD = {}

local VERDE = Color3.fromRGB(60, 255, 130)

local function linha(pai, w, h)
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Size = UDim2.fromOffset(w, h)
	f.BackgroundColor3 = VERDE
	f.BorderSizePixel = 0
	f.Parent = pai
	return f
end

local function texto(pai, t, tam, alinh)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Text = t or ""
	l.TextSize = tam or 16
	l.Font = Enum.Font.Code
	l.TextColor3 = VERDE
	l.TextXAlignment = alinh or Enum.TextXAlignment.Center
	l.Size = UDim2.fromOffset(120, 22)
	l.AnchorPoint = Vector2.new(0.5, 0.5)
	l.Parent = pai
	return l
end

function HUD.Criar(UI, P)
	local COR = UI.Cor
	local obj = {}
	local tela = UI.Novo("ScreenGui", { Name = "FABSimHUD", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 7,
		Parent = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui") })
	obj.Tela = tela

	-- HUD -----------------------------------------------------------------------
	local temHUD = P.HUD == true
	local ok, caixa = pcall(function() return Instance.new("CanvasGroup") end)
	if not ok then caixa = Instance.new("Frame") caixa.ClipsDescendants = true end
	caixa.Name = "HUD"
	caixa.AnchorPoint = Vector2.new(0.5, 0.5)
	caixa.Position = UDim2.fromScale(0.5, 0.45)
	caixa.Size = UDim2.fromScale(0.5, 0.7)
	caixa.BackgroundTransparency = 1
	caixa.Visible = temHUD
	caixa.Parent = tela
	if caixa:IsA("CanvasGroup") then caixa.GroupTransparency = 0.05 end
	local escada = {}
	for i = 1, 13 do
		local l = Instance.new("Frame")
		l.AnchorPoint = Vector2.new(0.5, 0.5)
		l.Size = UDim2.fromOffset(220, 16)
		l.BackgroundTransparency = 1
		l.Parent = caixa
		local esq = linha(l, 80, 2)
		esq.Position = UDim2.new(0, 40, 0.5, 0)
		local dir = linha(l, 80, 2)
		dir.Position = UDim2.new(1, -40, 0.5, 0)
		local tE = texto(l, "", 13)
		tE.Position = UDim2.new(0, -18, 0.5, 0)
		tE.Size = UDim2.fromOffset(30, 16)
		local tD = texto(l, "", 13)
		tD.Position = UDim2.new(1, 18, 0.5, 0)
		tD.Size = UDim2.fromOffset(30, 16)
		local pernaE = linha(l, 2, 8)
		pernaE.Position = UDim2.new(0, 1, 0.5, 4)
		local pernaD = linha(l, 2, 8)
		pernaD.Position = UDim2.new(1, -1, 0.5, 4)
		escada[i] = { Quadro = l, E = esq, D = dir, TE = tE, TD = tD, PE = pernaE, PD = pernaD }
	end
	-- marcador de trajetoria (FPM)
	local fpm = Instance.new("Frame")
	fpm.AnchorPoint = Vector2.new(0.5, 0.5)
	fpm.Size = UDim2.fromOffset(16, 16)
	fpm.BackgroundTransparency = 1
	fpm.Parent = caixa
	local anel = Instance.new("UIStroke")
	anel.Color = VERDE
	anel.Thickness = 2
	anel.Parent = fpm
	local cfpm = Instance.new("UICorner")
	cfpm.CornerRadius = UDim.new(1, 0)
	cfpm.Parent = fpm
	local asaE = linha(fpm, 14, 2)
	asaE.Position = UDim2.new(0, -8, 0.5, 0)
	local asaD = linha(fpm, 14, 2)
	asaD.Position = UDim2.new(1, 8, 0.5, 0)
	local cauda = linha(fpm, 2, 8)
	cauda.Position = UDim2.new(0.5, 0, 0, -5)
	-- referencia do eixo (W)
	local eixo = texto(caixa, "-^-", 18)
	-- caixas de velocidade, altitude e rumo
	local vel = texto(caixa, "", 20)
	vel.Position = UDim2.fromScale(0.12, 0.5)
	local mach = texto(caixa, "", 14)
	mach.Position = UDim2.fromScale(0.12, 0.58)
	local gTxt = texto(caixa, "", 14)
	gTxt.Position = UDim2.fromScale(0.12, 0.66)
	local aoa = texto(caixa, "", 14)
	aoa.Position = UDim2.fromScale(0.12, 0.74)
	local alt = texto(caixa, "", 20)
	alt.Position = UDim2.fromScale(0.88, 0.5)
	local radar = texto(caixa, "", 14)
	radar.Position = UDim2.fromScale(0.88, 0.58)
	local vsTxt = texto(caixa, "", 14)
	vsTxt.Position = UDim2.fromScale(0.88, 0.42)
	local rumo = texto(caixa, "", 18)
	rumo.Position = UDim2.fromScale(0.5, 0.06)
	local alerta = texto(caixa, "", 22)
	alerta.Position = UDim2.fromScale(0.5, 0.82)
	alerta.Size = UDim2.fromOffset(260, 28)
	local estado = texto(caixa, "", 14)
	estado.Position = UDim2.fromScale(0.5, 0.9)
	estado.Size = UDim2.fromOffset(300, 20)
	-- designador de alvo
	local alvo = Instance.new("Frame")
	alvo.AnchorPoint = Vector2.new(0.5, 0.5)
	alvo.Size = UDim2.fromOffset(34, 34)
	alvo.BackgroundTransparency = 1
	alvo.Visible = false
	alvo.Parent = tela
	local cAlvo = Instance.new("UIStroke")
	cAlvo.Color = VERDE
	cAlvo.Thickness = 2
	cAlvo.Parent = alvo
	local txtAlvo = texto(alvo, "", 14)
	txtAlvo.Position = UDim2.new(0.5, 0, 1, 14)
	-- ponto de navegacao
	local wp = Instance.new("Frame")
	wp.AnchorPoint = Vector2.new(0.5, 0.5)
	wp.Size = UDim2.fromOffset(16, 16)
	wp.Rotation = 45
	wp.BackgroundTransparency = 1
	wp.Visible = false
	wp.Parent = tela
	local cWp = Instance.new("UIStroke")
	cWp.Color = Color3.fromRGB(255, 255, 255)
	cWp.Thickness = 2
	cWp.Parent = wp

	-- FAIXA DE DADOS (preto e branco) --------------------------------------------------
	local faixa = UI.Novo("TextLabel", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -16), Size = UDim2.fromOffset(0, 30),
		AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = COR.Fundo, BackgroundTransparency = 0.3, Text = "", TextSize = 13,
		Font = Enum.Font.GothamMedium, TextColor3 = COR.Branco, Parent = tela })
	UI.Novo("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14), Parent = faixa })
	UI.Canto(faixa, 15)
	obj.Faixa = faixa

	-- OBJETIVOS E MENSAGENS --------------------------------------------------------------
	local painelObj = UI.Novo("Frame", { Position = UDim2.new(0, 16, 0, 60), Size = UDim2.fromOffset(250, 0), AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = COR.Fundo, BackgroundTransparency = 0.3, Parent = tela })
	UI.Canto(painelObj, 14)
	UI.Novo("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10), Parent = painelObj })
	UI.Novo("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = painelObj })
	local tituloObj = UI.Rotulo(painelObj, "OBJETIVOS", 10, { Font = Enum.Font.GothamBold, TextColor3 = COR.Sub, LayoutOrder = 0 })
	local linhasObj = {}
	local relogio = UI.Novo("TextLabel", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 14), Size = UDim2.fromOffset(0, 30),
		AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = COR.Fundo, BackgroundTransparency = 0.3, Text = "", TextSize = 13,
		Font = Enum.Font.GothamBold, TextColor3 = COR.Branco, Parent = tela })
	UI.Novo("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14), Parent = relogio })
	UI.Canto(relogio, 15)
	local msg = UI.Novo("TextLabel", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 52), Size = UDim2.fromOffset(0, 34),
		AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = COR.Branco, Text = "", TextSize = 15, Font = Enum.Font.GothamBold,
		TextColor3 = COR.Fundo, Visible = false, Parent = tela })
	UI.Novo("UIPadding", { PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16), Parent = msg })
	UI.Canto(msg, 17)
	local idMsg = 0

	function obj.Objetivos(lista)
		for _, l in ipairs(linhasObj) do l:Destroy() end
		linhasObj = {}
		for i, t in ipairs(lista) do
			linhasObj[i] = UI.Rotulo(painelObj, "○  " .. t, 13, { LayoutOrder = i })
		end
	end
	function obj.Marcar(i, feito, textoNovo)
		local l = linhasObj[i]
		if not l then return end
		local t = textoNovo or l.Text:sub(4)
		if textoNovo == nil then
			-- remove o simbolo atual (3 bytes UTF-8 + 2 espacos)
			t = l.Text:gsub("^[^%s]+%s%s", "")
		end
		l.Text = (feito and "●  " or "○  ") .. t
		l.TextColor3 = feito and COR.Sub or COR.Texto
	end
	function obj.Relogio(t) relogio.Text = t end
	function obj.Mensagem(t, duracao)
		idMsg = idMsg + 1
		local meu = idMsg
		msg.Text = t
		msg.Visible = true
		task.delay(duracao or 2.5, function()
			if idMsg == meu then msg.Visible = false end
		end)
	end
	local alvoMundo, wpMundo
	function obj.Alvo(pos, rotuloAlvo) alvoMundo = pos txtAlvo.Text = rotuloAlvo or "" end
	function obj.Ponto(pos) wpMundo = pos end
	function obj.AlternarDados() faixa.Visible = not faixa.Visible end

	-- ATUALIZACAO --------------------------------------------------------------------------
	local piscar = 0
	function obj.Atualizar(s, cam, cfAeronave, olhando, extra, dt)
		piscar = piscar + dt
		local kt = (s.IAS or 0) * 1.943844
		local ft = (s.Altitude or 0) * 3.28084
		local fpmv = (s.VS or 0) * 196.85
		local agl = (s.AGL or 0) * 3.28084
		faixa.Text = string.format("IAS %d kt   ALT %s ft   VS %+d   RUMO %03d   G %.1f   %s %d%%%s",
			math.floor(kt + 0.5), tostring(math.floor(ft / 10 + 0.5) * 10), math.floor(fpmv / 10 + 0.5) * 10,
			math.floor((s.Rumo or 0) + 0.5) % 360, s.Nz or 1, s.P.Tipo == "jato" and "N2" or "MOTOR",
			math.floor(((s.P.Tipo == "jato") and (s.N or 0) or (s.FracaoMotor or 0)) * 100),
			s.AvisoEstol and "   ESTOL" or "")
		-- designador e ponto de navegacao (valem para todas as aeronaves)
		local function projetar(pMundo)
			local v, naTela = cam:WorldToViewportPoint(pMundo)
			return Vector2.new(v.X, v.Y), naTela and v.Z > 0
		end
		if alvoMundo then
			local p, vis = projetar(alvoMundo)
			alvo.Visible = vis
			alvo.Position = UDim2.fromOffset(p.X, p.Y)
		else
			alvo.Visible = false
		end
		if wpMundo then
			local p, vis = projetar(wpMundo)
			wp.Visible = vis
			wp.Position = UDim2.fromOffset(p.X, p.Y)
		else
			wp.Visible = false
		end
		if not temHUD then return end
		caixa.Visible = not olhando
		if olhando then return end
		local origem = cam.CFrame.Position
		local abs = caixa.AbsolutePosition
		local function local2(pMundo)
			local v = cam:WorldToViewportPoint(pMundo)
			return Vector2.new(v.X - abs.X, v.Y - abs.Y), v.Z > 0
		end
		local frente = cfAeronave.LookVector
		local horiz = Vector3.new(frente.X, 0, frente.Z)
		if horiz.Magnitude < 0.05 then horiz = Vector3.new(-cfAeronave.UpVector.X, 0, -cfAeronave.UpVector.Z) * math.sign(frente.Y) end
		horiz = horiz.Unit
		local cima = Vector3.new(0, 1, 0)
		local inc = s.Inclinacao or 0
		local arf = s.Arfagem or 0
		local base5 = math.floor(arf / 5 + 0.5) * 5
		for i, l in ipairs(escada) do
			local ang = base5 + (i - 7) * 5
			if ang < -90 or ang > 90 then
				l.Quadro.Visible = false
			else
				local r = math.rad(ang)
				local dir = horiz * math.cos(r) + cima * math.sin(r)
				local p, vis = local2(origem + dir * 5000)
				l.Quadro.Visible = vis
				l.Quadro.Position = UDim2.fromOffset(p.X, p.Y)
				l.Quadro.Rotation = -inc
				local horizonte = ang == 0
				l.E.Size = UDim2.fromOffset(horizonte and 160 or 80, 2)
				l.D.Size = UDim2.fromOffset(horizonte and 160 or 80, 2)
				l.E.Position = UDim2.new(0, horizonte and 0 or 40, 0.5, 0)
				l.D.Position = UDim2.new(1, horizonte and 0 or -40, 0.5, 0)
				-- linhas negativas tracejadas (so a transparencia muda)
				l.E.BackgroundTransparency = ang < 0 and 0.45 or 0
				l.D.BackgroundTransparency = ang < 0 and 0.45 or 0
				l.TE.Text = horizonte and "" or tostring(math.abs(ang))
				l.TD.Text = l.TE.Text
				l.PE.Visible = not horizonte
				l.PD.Visible = not horizonte
				l.PE.Position = UDim2.new(0, 1, 0.5, ang > 0 and 4 or -4)
				l.PD.Position = UDim2.new(1, -1, 0.5, ang > 0 and 4 or -4)
			end
		end
		-- FPM e eixo
		local velMundo = Vector3.new(s.vx or 0, s.vy or 0, s.vz or 0) * (extra and extra.Escala or 1)
		if velMundo.Magnitude > 5 then
			local p = local2(origem + velMundo.Unit * 5000)
			fpm.Position = UDim2.fromOffset(p.X, p.Y)
			fpm.Visible = true
		else
			fpm.Visible = false
		end
		local pe = local2(origem + frente * 5000)
		eixo.Position = UDim2.fromOffset(pe.X, pe.Y)
		-- textos
		vel.Text = tostring(math.floor(kt + 0.5))
		vsTxt.Text = string.format("%+d", math.floor(fpmv / 10 + 0.5) * 10)
		mach.Text = string.format("M %.2f", s.Mach or 0)
		gTxt.Text = string.format("G %.1f", s.Nz or 1)
		aoa.Text = string.format("α %.1f", s.AlfaGraus or 0)
		alt.Text = tostring(math.floor(ft / 10 + 0.5) * 10)
		radar.Text = agl < 1500 and string.format("R %d", math.floor(agl / 10 + 0.5) * 10) or ""
		rumo.Text = string.format("%03d", math.floor((s.Rumo or 0) + 0.5) % 360)
		local alertaTxt = ""
		if s.AvisoEstol then alertaTxt = "ESTOL"
		elseif agl < 500 and fpmv < -2500 then alertaTxt = "PUXE"
		elseif (s.Nz or 1) > (s.P.GLimite or 9) * 0.95 then alertaTxt = "LIMITE DE G" end
		alerta.Text = alertaTxt
		alerta.Visible = alertaTxt ~= "" and (math.floor(piscar * 3) % 2 == 0)
		local est = {}
		if (s.Trem or 0) > 0.98 and s.P.TremRetratil then table.insert(est, "TREM") end
		if (s.PosCombustor or 0) > 0.5 then table.insert(est, "PÓS") end
		if (s.AeroFreio or 0) > 0.5 then table.insert(est, "FREIO AR") end
		if extra and extra.Estado then table.insert(est, extra.Estado) end
		estado.Text = table.concat(est, "   ")
	end

	function obj.Destruir()
		tela:Destroy()
	end

	return obj
end

return HUD
