# Casos de uso

## Serviços Common Lisp de longa duração

Uma imagem pode permanecer ativa por dias, receber recompilações, correções e plugins. O Malkuth observa o processo real, não somente o estado do repositório. O monitor cooperativo pode registrar mudanças automaticamente dentro da própria aplicação.

## Governança de arquitetura

Versione `malkuth-politicas.sexp` junto ao código para transformar decisões em verificações executáveis. Exemplos:

- domínio não depende da interface;
- infraestrutura não é usada diretamente por módulos de apresentação;
- plugins não acessam pacotes internos do hospedeiro;
- pacotes de domínio não formam ciclos;
- fan-out de adaptadores permanece abaixo de um limite.

## Investigação de dependências transitivas

Marque uma origem com `M`, selecione o destino e pressione `N`. A rota ajuda a responder por que dois subsistemas aparentemente distantes estão conectados e quais arestas precisam ser removidas durante uma refatoração.

## Revisão de limites entre pacotes

Entrada alta indica contrato central. Saída alta indica conhecimento amplo. Ciclos mostram subsistemas sem direção clara. O filtro de violações e os dossiês focados reduzem o mapa a evidências revisáveis.

## Motores de jogos e editores

É especialmente útil em projetos separados em:

```text
MOTOR.ECS
MOTOR.RENDERIZACAO
MOTOR.EDITOR
MOTOR.RECURSOS
MOTOR.SCRIPTING
MOTOR.FISICA
MOTOR.AUDIO
```

Políticas de camadas podem impedir dependências do tempo de execução em ferramentas do editor. O histórico mostra se novas funcionalidades aumentam gradualmente o acoplamento do núcleo.

## Sistemas de plugins

Capture uma linha de base antes do carregamento. Depois use `F5`, o filtro `6` ou `watch.lisp` para identificar novos pacotes, dependências e ciclos. Políticas podem restringir quais contratos do hospedeiro cada plugin pode usar.

## Integração de bibliotecas

Ao carregar um sistema do Quicklisp, o Malkuth mostra os pacotes que realmente apareceram e suas relações `USE-PACKAGE`. Ele complementa, mas não substitui, a inspeção das dependências ASDF.

## Onboarding

O SVG, o relatório Markdown e os caminhos focados dão a novos colaboradores uma visão inicial de fronteiras, centros, tamanhos e fluxos entre subsistemas.

## Tendência e auditoria

Preserve os CSVs e JSONs de tendência em CI para acompanhar saúde, ciclos e crescimento do grafo. Isso permite discutir trajetória, não apenas uma fotografia isolada.

## Situações inadequadas

O Malkuth não substitui:

- perfil de CPU ou alocação;
- grafo de chamadas por função;
- depurador;
- análise de vulnerabilidades;
- verificador de tipos;
- prova de segurança concorrente;
- análise completa de referências totalmente qualificadas.
