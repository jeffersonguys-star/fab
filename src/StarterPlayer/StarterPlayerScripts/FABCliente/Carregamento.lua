--[[
	FAB - Tela de carregamento (cliente)

	Cobre a tela ate o terreno e os modelos 3D estarem prontos (ou ate 90 s), mostrando o
	progresso e, se algum modelo falhar, o nome dele (para diagnostico).
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local CAR = {}

function CAR.Iniciar(UI)
	local jogador = Players.LocalPlayer
	local gui = Instance.new("ScreenGui")
	gui.Name = "FABCarregamento"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 1000
	gui.Parent = jogador:WaitForChild("PlayerGui")

	local fundo = Instance.new("Frame")
	fundo.Size = UDim2.fromScale(1, 1)
	fundo.BackgroundColor3 = Color3.fromRGB(8, 8, 9)
	fundo.BorderSizePixel = 0
	fundo.Active = true
	fundo.Parent = gui

	local function texto(tam, y, txt, cor, fonte)
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.AnchorPoint = Vector2.new(0.5, 0.5)
		t.Position = UDim2.fromScale(0.5, y)
		t.Size = UDim2.new(0.9, 0, 0, tam + 6)
		t.Font = fonte or Enum.Font.GothamBold
		t.TextSize = tam
		t.TextColor3 = cor or Color3.new(1, 1, 1)
		t.Text = txt
		t.Parent = fundo
		return t
	end
	texto(34, 0.36, "FORÇA AÉREA BRASILEIRA")
	texto(14, 0.43, "BASE AÉREA DE INSTRUÇÃO", Color3.fromRGB(170, 170, 170), Enum.Font.Gotham)
	local trilho = Instance.new("Frame")
	trilho.AnchorPoint = Vector2.new(0.5, 0.5)
	trilho.Position = UDim2.fromScale(0.5, 0.56)
	trilho.Size = UDim2.new(0.4, 0, 0, 6)
	trilho.BackgroundColor3 = Color3.fromRGB(40, 40, 42)
	trilho.BorderSizePixel = 0
	trilho.Parent = fundo
	local barra = Instance.new("Frame")
	barra.Size = UDim2.fromScale(0, 1)
	barra.BackgroundColor3 = Color3.new(1, 1, 1)
	barra.BorderSizePixel = 0
	barra.Parent = trilho
	local status = texto(13, 0.62, "Carregando...", Color3.fromRGB(200, 200, 200), Enum.Font.Gotham)
	local falhas = texto(11, 0.68, "", Color3.fromRGB(230, 170, 90), Enum.Font.Gotham)

	local inicio = os.clock()
	local suave = 0
	local conn
	conn = RunService.RenderStepped:Connect(function(dt)
		local terrenoOk = workspace:GetAttribute("TerrenoPronto") == true
		local malhasOk = workspace:GetAttribute("MalhasPronto") == true
		local prog = workspace:GetAttribute("TerrenoProg") or 0
		local total = workspace:GetAttribute("MalhasTotal") or 0
		local ok = workspace:GetAttribute("MalhasOk") or 0
		local frac = (prog * 0.6) + ((total > 0 and ok / total or (malhasOk and 1 or 0)) * 0.4)
		suave = suave + (frac - suave) * math.min(1, dt * 4)
		barra.Size = UDim2.fromScale(math.clamp(suave, 0, 1), 1)
		status.Text = string.format("Terreno %d%%  ·  Modelos 3D %d/%d", math.floor(prog * 100), ok, total)
		local f = workspace:GetAttribute("MalhasFalhas")
		falhas.Text = (f and f ~= "") and ("Não carregaram: " .. f) or ""
		local pronto = terrenoOk and malhasOk
		if (pronto and os.clock() - inicio > 2) or os.clock() - inicio > 90 then
			conn:Disconnect()
			local info = TweenInfo.new(0.6)
			TweenService:Create(fundo, info, { BackgroundTransparency = 1 }):Play()
			for _, d in ipairs(fundo:GetDescendants()) do
				if d:IsA("TextLabel") then TweenService:Create(d, info, { TextTransparency = 1 }):Play() end
				if d:IsA("Frame") then TweenService:Create(d, info, { BackgroundTransparency = 1 }):Play() end
			end
			task.delay(0.7, function() gui:Destroy() end)
		end
	end)
end

return CAR
