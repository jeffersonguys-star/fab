# FAB — Base Aérea de Instrução (Roblox)

Jogo de roleplay da Força Aérea Brasileira. O place inteiro é montado a partir deste repositório: o GitHub Actions usa o Rojo para gerar o place e publica no Roblox pela Open Cloud. Tudo o que for editado direto no Studio é substituído na próxima publicação.

## Mapa

- Oceano de cerca de 28.000 × 28.000 studs, com uma ilha de cerca de 13.600 × 20.800 studs no centro (escala do personagem: 1 stud = 0,28 m). O terreno é gerado por código.
- Base aérea: pista 18/36 de 3.000 m com marcações, luzes de borda e de cabeceira, ALS com sequenciais e PAPI. Também tem pista de táxi com ligações e marcas de espera, pátio de aeronaves, 5 hangares, abrigos reforçados (HAS), torre de controle, seção contra incêndio, parque de combustível, radar e cerca patrimonial.
- Área de ensino: portão das armas, comando da base, pátio de formatura, quadro das esquadrilhas, alojamentos, rancho, pista de corrida, área de exercícios, sala de instrução, medicina aeroespacial, centro de simulação e área de salto. A mata de sobrevivência fica a oeste da pista, e o farol fica na ponta norte.

## Formação do cadete

1. **Adaptação militar**: ordem unida, TACF (corrida, flexões e abdominais), salto de emergência e sobrevivência na selva.
2. **Instrução teórica**: aerodinâmica, navegação, meteorologia e regulamentos (7 questões, 5 acertos para aprovar).
3. **Instrução fisiológica**: câmara hipobárica (hipóxia) e centrífuga (tolerância a G).
4. **Simulador**: 18 lições em T-25, T-27, A-29, F-5EM e F-39E. Os cheques finais do T-25 e do F-39 são aprovados por um instrutor.

As notas e o progresso ficam salvos no DataStore. As esquadrilhas (Aquila, Centaurus, Leo e Orion) ganham pontos a cada aprovação.

## Simulador

- O modelo de voo tem 6 graus de liberdade (`src/ReplicatedStorage/FAB/Fisica.lua`) e inclui:
  - atmosfera padrão;
  - aerodinâmica com estol, queda de asa e arrasto de onda;
  - motor a hélice e a jato com pós-combustor;
  - trem de pouso com amortecedores;
  - fly-by-wire no F-39.
- O teste fora do Roblox fica em `teste/teste_fisica.lua` e roda no Actions a cada publicação.
- A máquina tem plataforma de movimento de 6 atuadores, que acompanha a atitude da aeronave. A cabine é interativa (interruptores clicáveis), e a estação do instrutor tem telemetria ao vivo.
- O voo acontece sobre a própria ilha, em escala real.

## Configuração

Os instrutores são definidos em `src/ReplicatedStorage/FAB/Config.lua` (`Instrutores`, `GrupoId` e `RankInstrutor`). O dono do jogo sempre é instrutor. Para testar sem os requisitos, use `ExigirRequisitos = false`.

Para publicar, o repositório precisa ter:

- o segredo `ROBLOX_API_KEY`, com permissão universe-places Write no jogo;
- as variáveis `UNIVERSE_ID` e `PLACE_ID`.

Em Game Settings > Avatar, deixe o tipo de avatar em R6.

## Animações

Os sistemas definem o atributo `PoseFAB` no personagem. O prompt das animações está em `PROMPT-ANIMACOES.md`.
