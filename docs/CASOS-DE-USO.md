# Casos de uso

## Serviços Common Lisp de longa duração

Uma imagem pode permanecer ativa por dias, receber recompilações, correções e plugins. O Malkuth observa o processo real, não somente o estado do repositório.

Fluxo recomendado:

1. carregue uma configuração próxima da produção;
2. carregue o Malkuth no mesmo processo;
3. aplique o escopo do serviço;
4. exporte antes e depois de uma alteração;
5. revise pacotes e dependências inesperados.

## Revisão de limites entre pacotes

Entrada alta indica contrato central. Saída alta indica conhecimento amplo de outras partes. Ciclos mostram subsistemas que não possuem direção clara de dependência. Esses dados ajudam a conduzir a conversa arquitetural.

## Motores de jogos e editores

É especialmente útil em projetos com pacotes separados para:

```text
MOTOR.ECS
MOTOR.RENDERIZACAO
MOTOR.EDITOR
MOTOR.RECURSOS
MOTOR.SCRIPTING
MOTOR.FISICA
MOTOR.AUDIO
```

O mapa pode revelar dependências indevidas do tempo de execução em ferramentas do editor, ou um pacote central que acumulou responsabilidades demais.

## Sistemas de plugins

Capture um instantâneo antes e outro depois do carregamento. A atualização mostra novos pacotes e mudanças de contagem; o grafo mostra quais contratos do hospedeiro foram usados.

## Integração de bibliotecas

Ao carregar um sistema do Quicklisp, o Malkuth ajuda a visualizar os pacotes que realmente apareceram e suas relações `USE-PACKAGE`. Ele complementa, mas não substitui, a inspeção das dependências ASDF.

## Onboarding

O SVG e o relatório Markdown dão a novos colaboradores uma visão inicial de fronteiras, centros, tamanhos e riscos sem exigir leitura completa do sistema.

## Documentação e decisões de arquitetura

Anexe o SVG e o relatório a registros de decisão arquitetural, revisões de projeto e mudanças importantes. Use o JSON para acompanhar métricas ao longo do tempo.

## Situações inadequadas

O Malkuth não substitui:

- perfil de CPU ou alocação;
- grafo de chamadas por função;
- depurador;
- análise de vulnerabilidades;
- verificador de tipos;
- prova de segurança concorrente;
- análise completa de todas as formas de acoplamento.

## Investigação focada de um pacote

Use o filtro de risco para encontrar candidatos, marque os mais importantes como favoritos e abra a aba de dependências. O modo de vizinhança remove ruído do restante da imagem; o comando `C` produz um dossiê pequeno o suficiente para anexar a uma revisão de código ou decisão arquitetural.
