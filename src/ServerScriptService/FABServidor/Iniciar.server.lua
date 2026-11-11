--[[
	FAB - Inicializacao do servidor (Script)

	Ordem: nucleo (dados e remotos) > mapa > sistemas de instrucao > simulador > instrutor.
]]

local pasta = script.Parent
local N = require(pasta:WaitForChild("Nucleo"))

local function iniciar(nome, ...)
	local ok, erro = pcall(function(...)
		local modulo = require(pasta:WaitForChild(nome))
		if modulo.Construir then modulo.Construir(N, ...) end
		if modulo.Iniciar then modulo.Iniciar(N, ...) end
	end, ...)
	if not ok then
		warn("[FAB] Falha ao iniciar " .. nome .. ": " .. tostring(erro))
	end
end

iniciar("Mapa")
iniciar("OrdemUnida")
iniciar("TACF")
iniciar("Salto")
iniciar("Sobrevivencia")
iniciar("Instrucao")
iniciar("Maquina")
iniciar("Instrutor")

print("[FAB] Base Aérea de Instrução pronta.")
