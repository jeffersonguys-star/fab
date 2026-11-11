--[[
	FAB - Inicializacao do cliente (LocalScript)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UI = require(ReplicatedStorage:WaitForChild("FAB"):WaitForChild("UI"))

UI.Iniciar()

local pasta = script.Parent
for _, nome in ipairs({ "OrdemUnida", "TACF", "Salto", "Sobrevivencia", "Teoria", "Fisiologico", "Instrutor", "Simulador" }) do
	local ok, erro = pcall(function()
		require(pasta:WaitForChild(nome)).Iniciar(UI)
	end)
	if not ok then warn("[FAB] Falha ao iniciar " .. nome .. ": " .. tostring(erro)) end
end
