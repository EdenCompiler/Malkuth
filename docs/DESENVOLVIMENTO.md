# Desenvolvimento

## Sistemas ASDF

```lisp
(asdf:load-system "malkuth/core")
(asdf:load-system "malkuth")
(asdf:test-system "malkuth/tests")
```

O núcleo deve permanecer independente de SDL3 e CFFI.

## Comandos

```bash
make test        # testes do núcleo e exportações
make analyze     # relatório sem interface
make watch-smoke # uma iteração do monitor
make smoke       # testes curtos da interface em X virtual
make validate    # todos os testes anteriores
make clean       # remove artefatos gerados
make package     # cria o arquivo de distribuição
```

## Convenções

- Comentários, docstrings, mensagens humanas e documentação devem ser escritos em pt-BR.
- Identificadores públicos existentes permanecem em inglês para compatibilidade.
- Arquivos de código usam UTF-8.
- O núcleo não depende da interface.
- Novas exportações usam escrita atômica.
- Métricas heurísticas são documentadas como heurísticas.
- Alterações de esquema exigem atualização da versão e da documentação.
- Leitura de S-expressions persistidas deve usar `*READ-EVAL*` desativado e validação estrutural.
- Recursos contínuos devem ser cooperativos por padrão, sem impor uma biblioteca de threads.

## Cobertura da suíte

A suíte principal verifica:

- validade e impressão digital de instantâneos;
- ciclos sintéticos e pacotes isolados;
- comparação e regressão arquitetural;
- consultas de dependência e busca textual;
- menor caminho orientado e não orientado;
- avaliação e round-trip seguro de políticas;
- histórico, tendências e retenção;
- detecção de mudanças pelo monitor;
- SVG, JSON, DOT, Markdown, CSV e manifesto;
- dossiês focados, políticas, caminhos e tendências;
- campos essenciais e versões de esquema.

Os testes SDL3 exercitam abertura da interface e entrada textual Unicode em um servidor X virtual.

## Adicionar uma regra de política

1. Defina o contrato e os campos aceitos.
2. Valide tipos, severidade, padrões e limites.
3. Implemente a avaliação sem depender da interface.
4. Produza violações com identificação estável e pacotes envolvidos.
5. Acrescente serialização nos relatórios Markdown e JSON.
6. Crie testes sintéticos de aprovação e reprovação.
7. Documente o formato em `docs/POLITICAS.md`.

## Adicionar uma regra heurística de análise

1. Calcule a evidência a partir de `snapshot` e `node-metrics`.
2. Restrinja avisos ao código controlado pelo usuário quando apropriado.
3. Crie um `analysis-warning` com severidade, código, pacote e mensagem.
4. Defina claramente a penalidade na saúde, se houver.
5. Acrescente teste sintético.
6. Atualize a documentação e o relatório Markdown.

## Adicionar uma exportação

1. Implemente a função no núcleo.
2. Use `atomic-write-file` ou estratégia equivalente.
3. Inclua o arquivo no manifesto somente depois de gravá-lo com sucesso.
4. Acrescente teste de existência e conteúdo mínimo.
5. Documente estabilidade, esquema e finalidade do formato.

## Adicionar um painel à interface

1. Inclua o estado mínimo em `app-state`.
2. Mantenha cálculo e regras no núcleo.
3. Defina atalhos que não conflitem com a busca textual.
4. Ajuste a ajuda integrada e a documentação.
5. Teste em 1600×900 e no tamanho mínimo 1280×760.
6. Evite texto abaixo da escala mínima da fonte vetorial.

## Localização

A fonte vetorial possui conjunto limitado de glifos. `base-glyph-character` normaliza acentos para letras-base. Não remova essa etapa enquanto a interface depender da fonte 5x7.

## Comentários no código

Cada módulo começa com um cabeçalho que explica responsabilidade e restrições. Comentários internos devem registrar decisões, invariantes, riscos e motivos — não repetir literalmente a forma do código. Funções públicas ou comportamentos não óbvios devem possuir docstrings em pt-BR.
