# RTS Mobile — protótipo jogável (Fase 1) + kit de assets

Você (azul) contra 1 bot (vermelho), em partidas de 5 a 10 minutos.
Todos os modelos 3D foram gerados por scripts Python, sem Blender e sem arte manual.

## Jogar no celular

Abra **https://alexlazevedo.github.io/rts-prototipo/** no Safari ou no Chrome do celular, deitado. No iPhone: Compartilhar → Adicionar à Tela de Início, para abrir em tela cheia como app.

## Jogar no computador (Godot)

1. Instale o Godot 4.7 (versão padrão, não a .NET).
2. No Godot, use **Importar** e escolha `project.godot`.
3. Aperte **F5** e escolha a dificuldade: Fácil, Normal ou Difícil. "Assistir bot x bot" mostra dois bots jogando.

No computador, o mouse imita o dedo: clique = toque, segurar = segurar, arrastar = arrastar, roda = zoom.

**Controles (toque):**

| Onde | Gesto | O que faz |
| --- | --- | --- |
| Barra de 10 no topo | toque | seleciona 1 unidade |
| Barra de 10 no topo | arrastar sobre vários | seleciona o grupo |
| Barra de 10 no topo | 2 toques rápidos | seleciona todas |
| Barra de 10 no topo | segurar | seleciona e leva a câmera até a unidade |
| Chão | toque | mover atacando o que encontrar |
| Chão | segurar | só mover, sem parar para lutar (recuar) |
| Inimigo | toque | atacar esse alvo |
| Prédio seu | toque | abre o painel de produção |
| Mapa | arrastar / pinça | move a câmera / zoom |
| Minimapa | toque ou arrastar | leva a câmera até o ponto |
| Botão Construir | toque | Fábrica, Hangar ou Torre; toque no mapa para posicionar e depois Confirmar |

**Regras do protótipo:**
- Coletores trabalham sozinhos e não entram na barra (máximo de 6).
- Unidades de combate: máximo de 10.
- Ciclo de contra-ataque: buggy (leve) > antiaéreo > VTOL (aérea) > tanque (pesada) > buggy.
- Aos 8 minutos as Bases perdem a blindagem e passam a levar dano em dobro.
- Aos 10 minutos vence quem tiver mais pontos. Perder a Base central elimina o jogador.

## Como o código está organizado

| Arquivo | Papel |
| --- | --- |
| `scripts/sim/` | **Simulação determinística**: só inteiros, 10 ticks/s, sem dependência de tela. `defs.gd` concentra todos os números de balanceamento. `world.gd` tem as regras. `bot.gd` é o bot, que usa os mesmos comandos do jogador. |
| `scripts/game/` | **Apresentação**: `view.gd` desenha (interpolação, tiros, explosões), `hud.gd` é a interface, `game.gd` cuida do toque e liga tudo. |
| `tests/test_sim.gd` | Testa sem gráficos: determinismo, os 4 duelos do ciclo de contra-ataque e 15 partidas bot x bot (duração e vencedor). |
| `tests/autotest_input.gd` | Teste de ponta a ponta com toques simulados: 18 verificações, do menu ao combate. |

Rodar os testes:

```bash
godot --headless --path . -s res://tests/test_sim.gd
godot --path . -- --autotest
```

**O que o protótipo ainda não tem (de propósito):** névoa de guerra (o bot enxerga o mapa todo), busca de caminho (o mapa é plano e as unidades contornam os prédios), multiplayer, a facção Energia jogável e o Núcleo/laboratório. A construção não precisa de coletor.

## O que tem aqui

| Pasta | Conteúdo |
| --- | --- |
| raiz do repositório | Projeto Godot 4.7: o jogo (`scenes/game.tscn`), a demo de assets (`scenes/demo_assets.tscn`), os 24 modelos `.glb` e os testes |
| `gerador/` | Os scripts que geram os modelos (`kit.py` = kit de estilo; `militar.py`, `energia.py`, `recursos.py` = assets; `build_all.py` = gera tudo) |
| `previews/` | Imagens de conferência: catálogos por facção, cena de batalha em tamanho de celular, captura do próprio Godot |

## Assets (24)

- **Militar (10):** caminhão minerador, buggy de assalto, tanque de cerco, VTOL de ataque, veículo de mísseis antiaéreo; base, fábrica, hangar, torre, laboratório
- **Energia (10):** drone extrator, sentinela flutuante, obelisco de cerco, lâmina aérea, prisma de defesa; base, fábrica, hangar, torre, laboratório
- **Neutros (4):** campo de minério, nó de Núcleo, platô 16×16 m, rampa

Entre 80 e 2.800 triângulos por modelo, de 20 a 270 KB cada.

## Abrir no Godot

1. Instale o Godot 4.7 (versão padrão, não a .NET).
2. No Godot, use **Importar** e escolha `project.godot`.
3. Aperte **F5**. A demonstração monta duas bases, recursos e os dois exércitos.
   - No computador: arraste com o botão esquerdo para mover a câmera; use a roda do mouse para zoom.
   - No celular: arraste com um dedo para mover; faça pinça para zoom.

**Celular:** Android exporta direto pelo Godot. Para iPhone, é preciso exportar no Mac com Xcode. Para testar no seu próprio aparelho, basta um Apple ID gratuito (o app precisa ser reinstalado a cada 7 dias).

## Convenções dos modelos (para quem for programar o jogo)

- Unidades: metros. Y é para cima, e a frente aponta para **-Z** (padrão do Godot).
- **Materiais com nome fixo** que o jogo troca em tempo de execução (`scripts/team_color.gd`):
  - `TeamColor`: cor do time (azul, vermelho, amarelo, verde).
  - `Glow`, `CoreGlow`, `Ore`: emissivos que alimentam o efeito de brilho.
- **Grupos com pivô próprio**, prontos para animar por código (`scripts/asset_animator.gd`):
  - `Turret`: torres giratórias (buggy, tanque, antiaéreo, torres de defesa).
  - `Rotor_L` / `Rotor_R`: rotores do VTOL.
  - `Ring`, `Orbit`, `Shards`: anéis e cristais da Energia.
  - `Float`: cristal do Núcleo.
- Unidades aéreas já vêm na altitude de voo (6 m) dentro do modelo.
- Peças do mesmo material ficam numa única malha, para gerar poucas chamadas de desenho no celular.

## Regerar os modelos

```bash
pip install trimesh pillow numpy
cd gerador
python3 build_all.py ../assets/models
```

As cores das facções, as cores de time, o minério (âmbar) e o Núcleo (magenta) ficam no topo de `kit.py`.

## Limitações conhecidas

- O estilo é low-poly limpo, com textura procedural de painéis e sujeira. Ele não tem o acabamento pintado das imagens de conceito.
- Não há animação de corpo. Por isso nenhuma unidade tem pernas: o "mech de cerco" do GDD virou tanque de cerco.
- A captura do Godot em `previews/` foi feita sem placa de vídeo (OpenGL por software). No celular, com o renderizador Mobile, luz e cor ficam um pouco diferentes. Vale conferir no aparelho antes de fechar a iluminação.

## Versão web

A pasta `docs/` é o jogo exportado para navegador (Godot Web, sem threads, renderizador de compatibilidade) e é publicada pelo GitHub Pages. Para atualizar: exporte o preset **Web** para `build/web/` e copie o conteúdo para `docs/`.
