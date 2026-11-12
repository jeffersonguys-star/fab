--[[
	FAB - Simulador de voo (cliente)

	Fluxo: ao entrar na maquina o piloto ja esta na cabine, em voo livre, no solo de uma pista
	virtual (sem menu). O botao MENU abre as licoes e a saida. Licao > briefing > voo > resultado,
	e depois volta ao voo livre.
	Durante o voo, a fisica (Fisica.lua) roda a 240 Hz, a camera fica no olho do
	piloto dentro da cabine 3D, sobre o mapa real da ilha, e a atitude da aeronave
	e enviada ao servidor para mover a plataforma da maquina.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local SIM = {}

function SIM.Iniciar(UI)
	local COR = UI.Cor
	local FAB = ReplicatedStorage:WaitForChild("FAB")
	local Fisica = require(FAB:WaitForChild("Fisica"))
	local Aeronaves = require(FAB:WaitForChild("Aeronaves"))
	local MD = require(FAB:WaitForChild("MapaDados"))
	local Fisiologia = require(FAB:WaitForChild("Fisiologia"))
	local pasta = script.Parent
	local CAB = require(pasta:WaitForChild("SimCabine"))
	local CORPO = require(pasta:WaitForChild("SimCorpo"))
	local CTRL = require(pasta:WaitForChild("SimControles"))
	local HUD = require(pasta:WaitForChild("SimHUD"))
	local CEN = require(pasta:WaitForChild("SimCenario"))
	local PV = require(pasta:WaitForChild("SimPistaVirtual"))
	local LIC = require(pasta:WaitForChild("SimLicoes"))
	local E = MD.StudPorMetro
	local camera = workspace.CurrentCamera
	local telemetria = ReplicatedStorage:WaitForChild("FABRemotos"):WaitForChild("Telemetria")

	local voo -- sessao atual
	local noSimulador = false
	local listaLicoes -- ultima lista enviada pelo servidor
	local aeronaveLivre = nil
	local iniciarVoo, iniciarLivre

	local function solo(xm, zm)
		local h, tipo = MD.Altura(xm * E, zm * E)
		if tipo == "praia" then tipo = "grama" end
		return h / E, tipo
	end

	local function encerrarVoo()
		if not voo then return end
		local v = voo
		voo = nil
		RunService:UnbindFromRenderStep("FABSimulador")
		pcall(function() v.Ctrl.Destruir() end)
		pcall(function() v.Hud.Destruir() end)
		pcall(function() if v.Corpo then v.Corpo.Destruir() end end)
		pcall(function() v.Cab.Destruir() end)
		pcall(function() v.Cen.Destruir() end)
		if v.Navegacao then v.Navegacao:Destroy() end
		Fisiologia.Limpar()
		camera.CameraType = Enum.CameraType.Custom
		camera.FieldOfView = 70
		local char = Players.LocalPlayer.Character
		if char then camera.CameraSubject = char:FindFirstChildOfClass("Humanoid") end
		if UI.BarraSuperior then UI.BarraSuperior.Visible = true end
	end

	-- MENU (so quando o piloto pede, pelo botao MENU) --------------------------------------
	local function aeronavesLiberadas(p)
		local lista, vistos = {}, {}
		for _, l in ipairs(p.Licoes) do
			if not vistos[l.Aeronave] then
				vistos[l.Aeronave] = { Id = l.Aeronave, Nome = l.NomeAeronave, Liberada = false }
				table.insert(lista, vistos[l.Aeronave])
			end
			if l.Liberado then vistos[l.Aeronave].Liberada = true end
		end
		return lista
	end

	local function abrirMenu(p, aoFechar)
		while UI.ModalAberto() do task.wait(0.2) end
		local m = UI.Modal({ Titulo = "Simulador " .. string.format("%02d", p.Maquina or 1), Sobretitulo = "Centro de Simulação de Voo",
			Largura = 600, Altura = 640 })
		UI.Rotulo(m.Conteudo, string.format("Horas de simulador: %.1f  ·  Cheques são avaliados por um instrutor.", (p.Horas or 0) / 3600), 13,
			{ TextColor3 = COR.Sub, LayoutOrder = 0 })
		local ordem = 1
		UI.Secao(m.Conteudo, "Voo livre  ·  pista virtual", ordem)
		for _, a in ipairs(aeronavesLiberadas(p)) do
			ordem = ordem + 1
			UI.Item(m.Conteudo, a.Nome, a.Id == aeronaveLivre and "Em uso" or (a.Liberada and "Toque para trocar de aeronave" or "Conclua uma lição desta aeronave"),
				a.Liberada and (a.Id == aeronaveLivre and "Em uso" or "Disponível") or "Bloqueado", function()
					if not a.Liberada then return end
					m.Fechar()
					aeronaveLivre = a.Id
					iniciarLivre()
				end, ordem)
		end
		ordem = ordem + 1
		UI.Item(m.Conteudo, "Reposicionar na cabeceira", "Volta ao início da pista, com a aeronave parada", "Disponível", function()
			m.Fechar()
			iniciarLivre()
		end, ordem)
		local atual
		for _, l in ipairs(p.Licoes) do
			if l.Aeronave ~= atual then
				atual = l.Aeronave
				ordem = ordem + 1
				local P = Aeronaves[l.Aeronave]
				UI.Secao(m.Conteudo, "Lições  ·  " .. l.NomeAeronave .. "  ·  " .. P.Funcao, ordem)
			end
			ordem = ordem + 1
			local estado = l.Aprovado and "Aprovado" or (l.Pendente and "Aguardando" or (l.Liberado and "Disponível" or "Bloqueado"))
			local sub = (l.Cheque and "Cheque  ·  " or "") .. (l.Nota and string.format("Nota %.1f", l.Nota) or (l.Liberado and "Toque para voar" or "Conclua a lição anterior"))
			UI.Item(m.Conteudo, l.Nome, sub, estado, function()
				if not l.Liberado then return end
				m.Fechar()
				UI.Enviar("Sim_Iniciar", { Id = l.Id })
			end, ordem)
		end
		UI.Botao(m.Rodape, "Sair do simulador", "secundario", function()
			m.Fechar()
			noSimulador = false
			encerrarVoo()
			UI.Enviar("Sim_Sair")
		end, { Size = UDim2.fromOffset(180, 42), LayoutOrder = 1 })
		UI.Botao(m.Rodape, "Continuar", "primario", function() m.Fechar() end, { Size = UDim2.fromOffset(130, 42), LayoutOrder = 2 })
		local fechar = m.Fechar
		m.Fechar = function()
			if aoFechar then aoFechar() end
			fechar()
		end
		return m
	end

	-- o servidor manda a lista ao entrar, ao sair de uma licao e ao cancelar um briefing:
	-- em todos os casos o piloto volta ao voo livre, sem menu
	UI.Registrar("Sim_Menu", function(p)
		listaLicoes = p
		noSimulador = true
		task.spawn(iniciarLivre)
	end)

	local DEF_LIVRE = {
		Nome = "Voo livre",
		Objetivos = {},
		Inicio = function(P) return PV.Inicio(P) end,
		Atualizar = function() end,
	}

	function iniciarLivre()
		local p = listaLicoes
		if not p then return end
		if not aeronaveLivre then
			for _, a in ipairs(aeronavesLiberadas(p)) do
				if a.Liberada then aeronaveLivre = a.Id break end
			end
			aeronaveLivre = aeronaveLivre or "T25"
		end
		iniciarVoo({ Id = "LIVRE", Aeronave = aeronaveLivre, Nome = "Voo livre" }, DEF_LIVRE)
	end

	-- VOO --------------------------------------------------------------------------------
	function iniciarVoo(p, defLivre)
		encerrarVoo()
		local P = Aeronaves[p.Aeronave]
		local def = defLivre or LIC.Definicoes[p.Id]
		if not P or not def then return end
		local livre = defLivre ~= nil
		local ini = def.Inicio(P)
		local s = Fisica.Novo(P, ini)
		s.Solo = livre and function(xm, zm) local h, t = PV.Solo(xm, zm) return h, t end or solo
		Fisica.Calcular(s)
		if def.MotorDesligado then
			s.MotorLigado = false
			s.N = 0
		end
		local cen = CEN.Criar()
		if livre then cen.Pista = PV.Criar(cen.Pasta) end
		local cab = CAB.Criar(P, cen.Pasta)
		for id in pairs(cab.Interruptores) do
			if id ~= "Trem" and id ~= "Flape" then
				local ligado = not def.MotorDesligado and id ~= "FreioEst" and id ~= "Partida"
				cab.DefinirInterruptor(id, ligado)
			end
		end
		local okC, corpo = pcall(CORPO.Criar, P, cen.Pasta)
		if not okC then warn("[FAB] Corpo do piloto: " .. tostring(corpo)) corpo = nil end
		local hud = HUD.Criar(UI, P)
		hud.Objetivos(def.Objetivos or {})
		local piloto = Fisiologia.NovoPiloto(4.4)
		piloto.Traje = (P.Tipo == "jato") and 1.0 or 0
		local v = { P = P, Def = def, S = s, Cab = cab, Corpo = corpo, Hud = hud, Cen = cen, Piloto = piloto, Id = p.Id, Nome = p.Nome, Livre = livre,
			Fim = false, UltimaTele = 0, VelAnterior = s.V }
		voo = v
		local ctx = { Dados = {}, T = 0, Cen = cen, Interruptores = cab.Estados }
		v.Ctx = ctx

		local ctrl
		local partidaMotor
		local function acao(nome)
			if not voo or v.Fim then return end
			local e = ctrl.Entradas
			if corpo and (nome == "Trem" or nome == "Flape" or nome == "AeroFreio" or nome == "Motor") then
				pcall(corpo.Alcancar, nome, cab)
			end
			if nome == "Trem" and P.TremRetratil then
				if s.EmSolo and e.Trem then hud.Mensagem("Trem travado: a aeronave está no solo") return end
				e.Trem = not e.Trem
			elseif nome == "Flape" then
				if e.Flap < 0.25 then e.Flap = 0.5 elseif e.Flap < 0.75 then e.Flap = 1 else e.Flap = 0 end
				hud.Mensagem("Flape " .. math.floor(e.Flap * 100) .. "%", 1.2)
			elseif nome == "AeroFreio" then
				e.AeroFreio = not e.AeroFreio
			elseif nome == "Respirar" then
				Fisiologia.Respirar(piloto)
			elseif nome == "Motor" then
				local jatoM = P.Tipo == "jato"
				if s.MotorLigado then
					s.MotorLigado = false
					for _, id in ipairs({ "Magnetos", "Ignicao", "Mistura", "Bomba" }) do
						if cab.Interruptores[id] then cab.DefinirInterruptor(id, false) end
					end
					hud.Mensagem("Motor cortado", 1.5)
				elseif not s.Partindo then
					if s.Combustivel <= 0 then hud.Mensagem("Sem combustível") return end
					for _, id in ipairs({ "Bateria", "Bomba", "Ignicao", "Mistura", "Magnetos" }) do
						if cab.Interruptores[id] then cab.DefinirInterruptor(id, true) end
					end
					e.Manete = math.min(e.Manete, jatoM and 0.1 or 0.2)
					if ctrl.DefinirManete then ctrl.DefinirManete(e.Manete) end
					if cab.Interruptores.Partida then cab.DefinirInterruptor("Partida", true) end
					partidaMotor()
				end
			elseif nome == "Dados" then
				hud.AlternarDados()
			elseif nome == "Menu" then
				if v.Livre then
					if v.Pausado then return end
					v.Pausado = true
					abrirMenu(listaLicoes or { Licoes = {}, Maquina = 1 }, function() v.Pausado = false end)
					return
				end
				local m = UI.Modal({ Titulo = v.Nome or "Lição", Sobretitulo = "Simulador em pausa", Largura = 440, Altura = 300 })
				v.Pausado = true
				UI.Rotulo(m.Conteudo, "A simulação está congelada. Você pode continuar ou encerrar a lição sem nota e voltar ao voo livre.", 14, { TextColor3 = COR.Sub })
				UI.Botao(m.Rodape, "Encerrar lição", "secundario", function()
					m.Fechar()
					encerrarVoo()
					UI.Enviar("Sim_Resultado", { Id = p.Id, Cancelado = true })
				end, { Size = UDim2.fromOffset(150, 42), LayoutOrder = 1 })
				UI.Botao(m.Rodape, "Continuar", "primario", function() m.Fechar() end, { Size = UDim2.fromOffset(130, 42), LayoutOrder = 2 })
				local fechar = m.Fechar
				m.Fechar = function() v.Pausado = false fechar() end
			end
		end

		local function partida()
			if s.Partindo or s.MotorLigado then return end
			local I = cab.Estados
			local jato = P.Tipo == "jato"
			local pronto = I.Bateria and I.Bomba and ((jato and I.Ignicao) or (not jato and I.Mistura and I.Magnetos))
			local m = ctrl.Entradas.Manete
			local maneteOk = jato and m < 0.25 or (m >= 0.1 and m <= 0.35)
			s.Partindo = true
			hud.Mensagem("Partida...", 1.5)
			task.delay(jato and 4 or 2.5, function()
				if voo ~= v then return end
				s.Partindo = false
				cab.DefinirInterruptor("Partida", false)
				if pronto and maneteOk then
					s.MotorLigado = true
					s.N = jato and 0.25 or 0.2
					hud.Mensagem("Motor acionado")
				else
					hud.Mensagem(pronto and "A partida falhou: posição da manete incorreta" or "A partida falhou: confira bateria, combustível e ignição")
				end
			end)
		end

		partidaMotor = partida

		local function interruptor(id)
			if v.Fim then return end
			if id == "Trem" or id == "Flape" then acao(id) return end
			local novo = not cab.Estados[id]
			if id == "Partida" then novo = true end
			if def.Interruptor and not def.Interruptor(ctx, id, novo) then return end
			cab.DefinirInterruptor(id, novo)
			if id == "Partida" then partida() end
			-- cortar ignicao, mistura ou combustivel desliga o motor
			if not novo and (id == "Magnetos" or id == "Ignicao" or id == "Mistura" or id == "Bomba") then
				s.MotorLigado = false
			end
		end

		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = cab.PartesInterativas
		local function toque(pos)
			if not voo or v.Pausado then return end
			local raio = camera:ViewportPointToRay(pos.X, pos.Y)
			local r = workspace:Raycast(raio.Origin, raio.Direction * 25, params)
			if r and r.Instance:GetAttribute("Interruptor") then
				if corpo then pcall(corpo.Apertar, r.Position, cab) end
				interruptor(r.Instance:GetAttribute("Interruptor"))
			end
		end

		ctrl = CTRL.Criar(UI, P, { Manete = ini.Manete or 0, Flap = ini.Flap or 0, Trem = (ini.Trem or 1) > 0.5, AoAcao = acao, AoToque = toque })
		v.Ctrl = ctrl

		-- funcoes oferecidas as licoes
		function ctx.Mensagem(t, d) hud.Mensagem(t, d) end
		function ctx.Marcar(i, feito) hud.Marcar(i, feito) end
		function ctx.Destacar(id) cab.Destacar(id) end
		function ctx.Estado(t) ctx.EstadoTxt = t ~= "" and t or nil end
		function ctx.Alvo(pos, rot)
			hud.Alvo(pos, rot)
			cab.AlvoMapa = pos and { X = pos.X / E, Z = pos.Z / E } or nil
		end
		local marcadorAtual, chaveMarcador
		function ctx.Navegacao(texto, pos)
			if not v.Navegacao then
				v.Navegacao = UI.Chip("", UDim2.new(0.5, 0, 0, 52))
				v.Navegacao.Parent = hud.Tela
			end
			v.Navegacao.Text = texto
			local chave = math.floor(pos.X) .. ":" .. math.floor(pos.Z)
			if chave ~= chaveMarcador then
				chaveMarcador = chave
				if marcadorAtual then marcadorAtual:Destroy() end
				marcadorAtual = cen.Marcador(Vector3.new(pos.X, MD.Plato, pos.Z))
				hud.Ponto(pos)
				cab.AlvoMapa = { X = pos.X / E, Z = pos.Z / E }
			end
		end
		function ctx.Concluir(nota, aprovado, linhas)
			if v.Fim then return true end
			v.Fim = true
			if v.Livre then
				hud.Mensagem("ACIDENTE: " .. tostring(s.Colisao), 3)
				task.delay(3, function()
					if voo == v then iniciarLivre() end
				end)
				return true
			end
			nota = math.clamp(nota or 0, 0, 10)
			hud.Mensagem(s.Destruido and ("ACIDENTE: " .. tostring(s.Colisao)) or "Lição concluída", 3)
			task.delay(s.Destruido and 3 or 2.5, function()
				if voo ~= v then return end
				encerrarVoo()
				UI.Enviar("Sim_Resultado", { Id = p.Id, Nota = nota, Aprovado = aprovado, Linhas = linhas })
			end)
			return true
		end
		if def.Iniciar then def.Iniciar(ctx) end

		-- camera e interface
		if UI.BarraSuperior then UI.BarraSuperior.Visible = false end
		camera.CameraType = Enum.CameraType.Scriptable
		camera.FieldOfView = 72
		local apagao = 0

		RunService:BindToRenderStep("FABSimulador", Enum.RenderPriority.Camera.Value + 1, function(dt)
			if voo ~= v then return end
			if dt > 0.1 then dt = 0.1 end
			local e = ctrl.Entradas
			if not v.Pausado and not v.Fim then
				-- entradas efetivas (freio de estacionamento, perda de consciencia)
				local ef = { Arfagem = e.Arfagem, Rolagem = e.Rolagem, Leme = e.Leme, Manete = e.Manete, Pos = e.Pos,
					Freio = cab.Estados.FreioEst and 1 or e.Freio, Flap = e.Flap, Trem = e.Trem, AeroFreio = e.AeroFreio }
				if piloto.GLOC then ef.Arfagem, ef.Rolagem, ef.Leme = 0, 0, 0 end
				s.Trim = ctrl.Trim
				piloto.Contraindo = ctrl.AGSM
				Fisica.Passo(s, dt, ef)
				local efeitos = Fisiologia.AtualizarG(piloto, s.NzFiltrado or s.Nz or 1, dt)
				ctx.GLOC = efeitos.GLOC
				if efeitos.GLOC then ctx.GLOCs = (ctx.GLOCs or 0) + dt end
				Fisiologia.Definir(efeitos)
				ctx.T = ctx.T + dt
				if s.Destruido then
					ctx.Concluir(0, false, { "Acidente: " .. tostring(s.Colisao) .. "." })
				else
					local ok, erro = pcall(def.Atualizar, ctx, s, dt, e)
					if not ok then warn("[FAB] Lição " .. p.Id .. ": " .. tostring(erro)) end
					if not v.Fim and def.Limite and ctx.T > def.Limite then
						ctx.Concluir(0, false, { "O tempo da lição terminou antes de cumprir os objetivos." })
					end
				end
			end
			-- aeronave, cabeca do piloto e tremores
			local cf = CFrame.new(s.px * E, s.py * E, s.pz * E, Fisica.Matriz(s))
			local amp = 0
			local P2 = s.P
			if s.AvisoEstol then amp = amp + 0.003 + 0.02 * math.clamp(((s.Alfa or 0) - (P2.AlfaEstol - math.rad(4))) / math.rad(4), 0, 1) end
			if (s.Mach or 0) > 0.95 and (s.Mach or 0) < 1.08 then amp = amp + 0.008 end
			if s.EmSolo then amp = amp + 0.0006 * math.clamp((s.V or 0) / 40, 0, 1) end
			-- ruido filtrado (suave), nao um sorteio novo a cada quadro
			ctx.RuidoA = (ctx.RuidoA or 0) + ((math.random() - 0.5) * 2 - (ctx.RuidoA or 0)) * math.min(1, dt * 6)
			ctx.RuidoB = (ctx.RuidoB or 0) + ((math.random() - 0.5) * 2 - (ctx.RuidoB or 0)) * math.min(1, dt * 6)
			local tremor = CFrame.Angles(ctx.RuidoA * amp * 0.5, ctx.RuidoB * amp * 0.5, 0)
			local cabeca = CFrame.Angles(-math.clamp(((s.NzFiltrado or 1) - 1) * 0.004, -0.02, 0.04), 0, 0)
			local dc = corpo and corpo.Desloc or Vector3.zero
			local gc = corpo and corpo.Giro or CFrame.new()
			local olho = cf * CFrame.new(dc) * CFrame.new(P2.Olho[1] * E, P2.Olho[2] * E, P2.Olho[3] * E) * gc
				* CFrame.Angles(0, math.rad(ctrl.OlharYaw), 0) * CFrame.Angles(math.rad(ctrl.OlharPitch), 0, 0) * cabeca * tremor
			camera.CFrame = olho
			cab.Atualizar(cf, s, e, dt)
			if corpo then pcall(corpo.Atualizar, cf, e, dt) end
			cen.Atualizar(olho.Position)
			local olhando = math.abs(ctrl.OlharYaw) > 20 or math.abs(ctrl.OlharPitch) > 15
			hud.Atualizar(s, camera, cf, olhando, { Estado = ctx.EstadoTxt }, dt)
			hud.Relogio(string.format("%s  ·  %d:%02d", v.Nome or "", math.floor(ctx.T / 60), math.floor(ctx.T % 60)))
			-- telemetria para a plataforma de movimento e o instrutor
			v.UltimaTele = v.UltimaTele + dt
			if v.UltimaTele >= 0.15 then
				local ax = ((s.V or 0) - v.VelAnterior) / v.UltimaTele / 9.81
				v.VelAnterior = s.V or 0
				v.UltimaTele = 0
				telemetria:FireServer({
					Arf = s.Arfagem, Inc = s.Inclinacao, Rumo = s.Rumo, Alt = s.Altitude * 3.28084, IAS = s.IAS * 1.943844,
					M = s.Mach, VS = s.VS * 196.85, G = s.Nz, AoA = s.AlfaGraus, N = s.N, PC = (s.PosCombustor or 0) > 0.5,
					Trem = (s.Trem or 0) > 0.98, Flap = s.Flap, Comb = s.Combustivel, Lic = v.Nome, Anv = P2.Nome,
					Est = s.Destruido and "ACIDENTE" or (s.EmSolo and "SOLO" or "EM VOO"),
					Tmp = string.format("%d:%02d", math.floor(ctx.T / 60), math.floor(ctx.T % 60)),
					Ax = ax, Tremor = amp * 40,
					X = s.px, Y = s.py, Z = s.pz, AnvId = P2.Id, Virt = v.Livre == true,
				})
			end
		end)
	end

	UI.Registrar("Sim_Licao", function(p)
		local def = LIC.Definicoes[p.Id]
		local P = Aeronaves[p.Aeronave]
		if not def or not P then return end
		local controles = "Manche: esquerda da tela (ou W/S/A/D). Manete: direita da tela (ou Shift/Ctrl). Leme: Q/E. Freios: B. "
			.. (P.TremRetratil and "Trem: G. " or "") .. "Flape: X. "
			.. (P.TracaoPos and "Pós-combustor: topo da manete (ou F). " or "")
			.. (P.TemAeroFreio and "Freio aerodinâmico: V. " or "")
			.. "Anti-G: Espaço (segurar) e R para respirar. Arraste a tela para olhar ao redor; toque nos interruptores da cabine para acioná-los."
		UI.Briefing({
			Titulo = p.Nome, Sobretitulo = P.Nome .. (p.Cheque and "  ·  Cheque" or ""),
			Descricao = def.Descricao, Itens = def.Itens, Controles = controles, Botao = "Voar",
			AoCancelar = function() UI.Enviar("Sim_Menu") end,
			AoConfirmar = function() iniciarVoo(p) end,
		})
	end)

	UI.Registrar("Sim_Fim", function()
		noSimulador = false
		encerrarVoo()
	end)
end

return SIM
