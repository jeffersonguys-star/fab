# Prompt das animações do jogo da FAB

Envie este texto ao projeto de animações junto com os arquivos citados no fim.

---

Crie as animações das posturas do jogo da Força Aérea Brasileira (Roblox, personagens R6). As animações devem seguir o modelo do sistema AnimacaoMovimento: dados de quadros-chave em tabela, aplicados por código no `Motor6D.Transform`, sem IDs de animação. Use interpolação suave entre quadros e mistura com peso entre animações. A qualidade deve ser a mesma do "Ultimate R6 Movement System": quadros a cada 16,7 ms, loops que fecham perfeitamente, movimento secundário em todos os eixos e respiração no idle (0,03 stud no tronco, 1° no tronco, 2° na cabeça, 3 a 5° nos braços, ciclo de 1,9 s). Nenhuma pose pode ficar congelada.

## Como o jogo pede a animação

O servidor define o atributo `PoseFAB` (texto) no modelo do personagem. Um texto vazio significa "sem pose" (volta ao movimento normal). O script de animação deve observar `personagem:GetAttributeChangedSignal("PoseFAB")`, fazer a transição de 0,25 s para a nova pose e manter o loop de respiração dela.

## Posturas

1. **Sentido**: corpo ereto, calcanhares unidos, pontas dos pés afastadas cerca de 45°, braços estendidos ao lado do corpo, mãos fechadas com o polegar ao longo da costura da calça, queixo levemente recolhido, olhar à frente. Respiração quase imperceptível.
2. **Descansar**: pés afastados na largura dos ombros, mãos às costas na altura da cintura (mão direita sobre a esquerda), tronco ereto e peso distribuído.
3. **AVontade**: como Descansar, com o corpo mais relaxado: pequena oscilação de peso entre as pernas (ciclo de 4 s), cabeça girando até 5°.
4. **Continencia**: posição de Sentido com a mão direita espalmada, dedos unidos, ponta do dedo médio na altura da sobrancelha direita, antebraço a 45°, cotovelo na linha do ombro. Subida da mão em 0,4 s com leve ultrapassagem e acomodação.
5. **FlexaoCima** e **FlexaoBaixo**: prancha com o corpo reto da cabeça aos calcanhares, mãos sob os ombros. Em "Cima", braços estendidos. Em "Baixo", o peito a um palmo do chão. A transição entre as duas leva 0,4 s, com o quadril acompanhando o tronco e a cabeça neutra. Como o R6 não tem cotovelo, simule a flexão com a translação dos braços.
6. **AbdominalDeitado** e **AbdominalSentado**: deitado de costas, joelhos flexionados (pernas inclinadas, pés no chão), braços cruzados sobre o peito. "Sentado" eleva o tronco até os cotovelos tocarem as coxas, em 0,45 s.
7. **QuedaLivre**: posição arqueada (arch): ventre para baixo, quadril à frente, braços abertos a 90° com os cotovelos a 90°, pernas afastadas e joelhos levemente flexionados. Tremor do vento nos braços e nas pernas (oscilação rápida de 1 a 2°, 8 Hz). O servidor já inclina o personagem 75° à frente; a animação cuida só dos membros.
8. **Paraquedas**: suspenso pelo arnês, com os braços para cima segurando os batoques e as pernas juntas e soltas, balançando levemente. Ao frear (flare), os dois braços descem até a cintura.
9. **Sentado**: sentado em cadeira (sala de aula, câmara hipobárica e centrífuga), mãos sobre as coxas, costas retas.
10. **SentadoCabine**: sentado no assento ejetável, encosto inclinado 12°, mão direita no manche entre as pernas e mão esquerda na manete à esquerda, pés nos pedais.

## Arquivos que serão alterados

- O LocalScript de animação do personagem (o seu sistema baseado no AnimacaoMovimento), que passa a ler o atributo `PoseFAB`.
- Nenhum script do jogo precisa mudar: todos os sistemas da FAB já definem `PoseFAB` nos momentos certos.
