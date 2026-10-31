# ANDREWS VS BALOG — NEON FIGHT ALPHA 0.2

Atualização direta da Alpha 0.1 em Godot 4 Standard, sem plugins nem bibliotecas externas.

## Como abrir

1. Extraia o ZIP.
2. Abra a Godot 4 Standard (não .NET).
3. Clique em **Importar** e selecione `project.godot`.
4. Aguarde a importação inicial das imagens e pressione **F5**.
5. `1` = contra computador; `2` = dois jogadores; `Enter` ou `Start` = iniciar.

## Controles

| Ação | Andrews | Balog | Controle Xbox/compatível |
|---|---|---|---|
| Andar | A/D | ← / → | Analógico esquerdo/D-pad |
| Pular | W | ↑ | A / D-pad cima |
| Agachar | S | ↓ | D-pad baixo |
| Golpe leve | F (soco d'água) | J (facada) | X |
| Golpe pesado | G (sarrada) | K (tiro) | Y |
| Especial | H (tsunami) | L (caos) | B |
| Defender | Shift | I | RB |
| Pausar | P/Esc | P/Esc | Start |
| Reiniciar | R | R | - |
| Colisões (debug) | F3 | F3 | - |

Um controle vale para Andrews contra IA. Em modo dois jogadores, com dois controles, o segundo joga como Balog. Também funciona com os dois jogadores no mesmo teclado.

## Melhorias de design da 0.2

- O HUD aprovado do projeto foi incluído como imagens transparentes para molduras, nomes, perfis e medidores.
- Vida, medidores SUPER, timer, resultados e rounds são elementos **dinâmicos** do jogo.
- A vida esvazia e mantém uma trilha dourada temporária quando sofre dano.
- Letreiros ilustrados de estética urbana e numerais do cronômetro pré-renderizados em PNG (sem arquivos de fonte ou logotipos oficiais de Street Fighter).
- Palco novo em cidade portuária iluminada por néon, com chuva/reflexos e contraste azul/vermelho.
- Menu usa a arte aprovada; o palco de luta não tem lutadores nem HUD pintados no fundo.
- Balog recebeu novos recortes ilustrados de movimento, agachamento, pulo, facada, tiro, bloqueio e reação, escolhidos a partir da prancha aprovada.
- O código mantém o sistema da Alpha 0.1 para controles, IA, colisão, vida, dano, rounds e especiais.

## Estrutura

- `scripts/main.gd` — estados da partida, input, projéteis, efeitos, renderização e HUD.
- `scripts/fighter.gd` — atributos, física, ações, dano e bloqueio.
- `assets/scenes` — imagens do palco, tela inicial e artes de interface.
- `assets/fighters` — poses e retratos.
- `assets/fighters/balog_animated` — poses de Balog em arquivos PNG independentes.
- `assets/ui` — atlas PNG dos numerais do cronômetro (sem fontes distribuídas).
- `assets/audio` — efeitos de áudio.

## Limitações conhecidas

O palco é **arte cinematográfica semi-realista composta a partir de artes do projeto**, não uma fotografia nem um cenário 3D. As animações têm poses distintas, mas não são animações clássicas completas de dezenas de quadros como em Skullgirls. Algumas transições ainda usam poses corrigidas por composição. **Não foi possível executar a Godot neste ambiente**: a integração foi revisada por arquivos, mas o teste de execução deve ser feito na instalação do usuário.

## Próximos passos

Revisar em Godot a escala dos sprites, alinhar as bordas das barras e testar cada controle em partidas completas. A arte dos personagens deve, mais tarde, ser redibujada quadro a quadro para evitar pequenas variações entre poses e produzir uma animação fluida de qualidade comercial.
