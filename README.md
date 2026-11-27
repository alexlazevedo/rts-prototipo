# RTS Mobile — MVP (Fase 2)

RTS futurista para celular, com partidas de 5 a 10 minutos. Você joga contra 3 bots, todos contra todos, nas facções **Militar** ou **Energia**.
Todos os modelos 3D foram gerados por código (Python), sem Blender e sem arte manual.

## Jogar no celular

Abra **https://alexlazevedo.github.io/rts-prototipo/** no Safari ou no Chrome do celular, com o aparelho deitado.
No iPhone, use Compartilhar → **Adicionar à Tela de Início** para abrir em tela cheia, como um app.

## Jogar no computador (Godot 4.7)

Importe `project.godot` no Godot 4.7 e aperte **F5**. O mouse imita o dedo: clique, segurar e arrastar funcionam como no toque, e a roda faz o zoom.

## Controles

| Onde | Gesto | O que faz |
| --- | --- | --- |
| Barra de 10 no topo | toque | seleciona 1 unidade |
| Barra de 10 no topo | arrastar sobre vários | seleciona o grupo |
| Barra de 10 no topo | 2 toques rápidos | seleciona todas |
| Barra de 10 no topo | segurar | seleciona e leva a câmera até a unidade |
| Chão | toque | mover atacando o que encontrar |
| Chão | segurar | só mover, sem parar para lutar (recuar) |
| Inimigo | toque | atacar esse alvo |
| Prédio seu | toque | painel de produção (no laboratório, painel de pesquisas) |
| Mapa | arrastar / pinça | move a câmera / zoom |
| Minimapa | toque ou arrastar | leva a câmera até o ponto |
| Botão Construir | toque | Fábrica, Hangar, Torre ou Laboratório; toque no mapa para posicionar e depois Confirmar |

## Regras

- **Mapa:** 280 × 280 m, com 4 bases em platôs nos cantos, cada uma com uma rampa. Há minério na base e 4 campos de expansão no chão. O Núcleo fica no centro.
- **Facções:**

| Facção | Estilo |
| --- | --- |
| Militar | mais vida, mais lenta, prédios mais resistentes |
| Energia | menos vida e mais velocidade; escudo que se recupera depois de 5 s sem levar dano |

- **Ciclo de contra-ataque:** leve > antiaéreo > aérea > pesada > leve.
- **Núcleo:** quem tiver unidades de combate sozinho na zona central ganha 1 Núcleo por segundo. Se houver mais de um jogador na zona, ninguém ganha.
- **Laboratório:**
  - **Nível 2** (100 de minério + 25 de Núcleo) libera as unidades pesadas: tanque e obelisco.
  - **Armas +20%** (100 de minério + 40 de Núcleo) aumenta o dano.
- **Limites:** até 6 coletores (trabalham sozinhos e não entram na barra) e até 10 unidades de combate.
- **Névoa de guerra:** você e os bots só veem o que suas unidades e prédios veem. Prédios inimigos já vistos ficam no mapa.
- **Fim da partida:** perder a Base central elimina o jogador. Aos 8 minutos as Bases passam a levar dano em dobro. Aos 10 minutos vence quem tiver mais pontos.
- **Bots:** fácil, normal ou difícil, cada um com uma personalidade: agressivo, defensivo ou focado no Núcleo. Eles usam os mesmos comandos que você e não recebem recursos extras.

## Código

| Arquivo | Papel |
| --- | --- |
| `scripts/sim/defs.gd` | **Todos os números do jogo.** Balancear = mudar aqui e rodar os testes |
| `scripts/sim/world.gd` | Simulação determinística: só inteiros, 10 ticks/s. Inclui terreno, busca de caminho (A* em grade de 2 m), névoa, Núcleo e pesquisas |
| `scripts/sim/bot.gd` | Bot: economia, construção, produção pelo ciclo de contra-ataque, ataques em onda, defesa, Núcleo, foco de fogo (difícil) |
| `scripts/game/` | Tela e interface: `view.gd` (modelos, terreno, névoa, efeitos), `hud.gd` (interface), `game.gd` (toque) |
| `tests/test_sim.gd` | Testes sem gráficos: determinismo, ciclo de contra-ataque nas duas facções, equilíbrio entre facções, caminho pela rampa, névoa, Núcleo e laboratório, partidas de 4 bots |
| `tests/autotest_input.gd` | Teste de ponta a ponta com toques simulados: 20 verificações |
| `gerador/` | Scripts Python que geram os 24 modelos `.glb` |
| `docs/` | Versão web publicada pelo GitHub Pages (exportação do preset **Web**) |

```bash
godot --headless --path . -s res://tests/test_sim.gd     # simulação
godot --path . -- --autotest                              # toque de ponta a ponta
```

**Ainda não tem:** multiplayer online, as facções Industrial e Orgânica, mais mapas e unidades de nível 3.
