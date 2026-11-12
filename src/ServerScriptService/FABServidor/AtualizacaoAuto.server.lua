--[[
	FAB - Atualizacao automatica dos servidores.
	O Roblox so aplica uma versao nova em servidores novos. Este script consulta a data da ultima
	publicacao do lugar; se ela mudar, avisa os jogadores e os remove com uma mensagem, e o
	servidor velho fecha. Ao entrar de novo, o jogador cai num servidor com a versao nova.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

if RunService:IsStudio() or game.PlaceId == 0 then return end

local function atualizadoEm()
	local ok, info = pcall(function() return MarketplaceService:GetProductInfo(game.PlaceId) end)
	if ok and info then return info.Updated end
	return nil
end

local inicial = atualizadoEm()
if not inicial then return end

while true do
	task.wait(45)
	local agora = atualizadoEm()
	if agora and agora ~= inicial then
		for s = 20, 1, -5 do
			workspace:SetAttribute("AvisoAtualizacao", "Nova versão publicada. Reentrando em " .. s .. " s...")
			task.wait(5)
		end
		for _, j in ipairs(Players:GetPlayers()) do
			j:Kick("Uma nova versão do jogo foi publicada. Entre novamente para carregar as novidades.")
		end
		break
	end
end
