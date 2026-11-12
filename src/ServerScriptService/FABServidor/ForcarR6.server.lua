--[[
	FAB - Converte todo jogador para R6 ao entrar (e a cada renascimento).
	O corpo R6 e o que o simulador usa na cabine; se o avatar vier em R15, e trocado por um R6
	com a mesma aparencia, na mesma posicao.
]]

local Players = game:GetService("Players")

local convertendo = {}

local function paraR6(jogador, char)
	if convertendo[jogador] then return end
	local hum = char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid", 10)
	if not hum or hum.RigType == Enum.HumanoidRigType.R6 then return end
	convertendo[jogador] = true
	local ok, novo = pcall(function()
		local desc = hum:GetAppliedDescription()
		desc.LeftArm, desc.RightArm, desc.LeftLeg, desc.RightLeg, desc.Torso = 0, 0, 0, 0, 0 -- braco de pacote/efeito (ex.: gelo) nao existe em R6: usa o braco padrao
		return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R6)
	end)
	if not ok or not novo then
		warn("[FAB] Nao foi possivel converter " .. jogador.Name .. " para R6: " .. tostring(novo))
		convertendo[jogador] = nil
		return
	end
	local raiz = char:FindFirstChild("HumanoidRootPart")
	local cf = raiz and raiz.CFrame or CFrame.new(0, 10, 0)
	novo.Name = jogador.Name
	novo:PivotTo(cf)
	jogador.Character = novo
	novo.Parent = workspace
	char:Destroy()
	convertendo[jogador] = nil
end

local function entrou(jogador)
	jogador.CharacterAdded:Connect(function(char)
		task.defer(paraR6, jogador, char)
	end)
	if jogador.Character then task.defer(paraR6, jogador, jogador.Character) end
end

Players.PlayerAdded:Connect(entrou)
for _, j in ipairs(Players:GetPlayers()) do entrou(j) end
Players.PlayerRemoving:Connect(function(j) convertendo[j] = nil end)
