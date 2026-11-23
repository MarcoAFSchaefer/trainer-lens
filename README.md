# Trainer Lens

Painéis de informação para Pokémon FireRed/LeafGreen no Gen1Recomp. Feitos para ficar nas docas do Trainer Desk, mas também abrem em janelas próprias sem ele.

Só leem o jogo, com duas exceções explícitas: o painel Ferramentas usa itens e golpes de campo pelo próprio jogo quando você clica, e a Equipe troca a ordem dos Pokémon pela troca do jogo.

## Painéis

- **Pokémon da área:** quem aparece no mapa, por método, nível e chance; capturados com Poké Ball; clique para a ficha da espécie.
- **Equipe:** HP, nível, status e item; clique em dois para trocar de lugar.
- **Oponente** e **Meu Pokémon:** ficha completa com teia de atributos, IV e EV (EV só no seu).
- **Golpes:** tipo, categoria, poder, precisão, PP, descrição e efetividade contra o oponente.
- **Radar de itens:** itens visíveis e ocultos do mapa.
- **Ferramentas:** um clique para bicicleta, golpes de campo, varas, VS Seeker, repels e Escape Rope; Auto Repel opcional. Mostra só o que dá para usar agora.
- **Treinador:** dinheiro, tempo, insígnias, Pokédex e contadores do save.
- **Progresso:** espécies capturadas por área.
- **Mapa da área** (tiles do jogo) e **Mapa da região** (Town Map do jogo).
- **Pokédex:** grade navegável e ficha de cada espécie.
- **Mochila**, **Day-Care**, **Contador** de encontros e **Avisos**.
- **PC:** as caixas do PC e a ficha de cada Pokémon, só para ver.

Todos os painéis se redesenham no espaço que têm e seguem o tema do Trainer Desk.

## Instalação

Copie a pasta `trainer_lens` para a pasta de mods do jogo:

```
%APPDATA%\pokemon-love2d\mods\trainer_lens
```

## Testes

Rodam no Linux com LÖVE 11.5 e um X virtual, junto com o Trainer Desk:

```
DOCK_MOD=/caminho/trainer-desk/trainer_desk PP_MOD=$PWD/trainer_lens \
  xvfb-run -a love tests
```

O resultado esperado é `ALL DOCK CHECKS PASSED`.

## Histórico

Até a versão 2.8.0 se chamava PokePanels (id `poke_panels`).
