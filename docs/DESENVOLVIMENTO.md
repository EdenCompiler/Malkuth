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
make test       # testes do núcleo e exportações
make analyze    # relatório sem interface
make smoke      # teste curto da interface em X virtual
make validate   # test + analyze + smoke
make clean      # remove artefatos gerados
make package    # cria o arquivo de distribuição
```

## Convenções

- Comentários, docstrings, mensagens humanas e documentação devem ser escritos em pt-BR.
- Identificadores públicos existentes permanecem em inglês para compatibilidade.
- Arquivos de código usam UTF-8.
- O núcleo não deve depender da interface.
- Novas exportações devem usar escrita atômica quando gerarem arquivos finais.
- Métricas heurísticas devem ser documentadas como heurísticas.
- Alterações no esquema JSON exigem atualização de `schemaVersion` e da documentação.

## Testes

A suíte principal verifica:

- validade de um instantâneo real;
- estabilidade da impressão digital;
- detecção de ciclo sintético;
- identificação de pacote isolado;
- comparação de instantâneos idênticos;
- consultas de dependências, dependentes e vizinhança;
- geração de SVG, JSON, DOT, Markdown e manifesto;
- geração de Markdown e DOT focados em um pacote;
- presença de campos essenciais nos relatórios.

O teste SDL3 abre a aplicação por poucos quadros em um servidor X virtual.

## Adicionar uma nova regra de análise

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
5. Documente estabilidade e finalidade do formato.

## Localização

A fonte vetorial possui conjunto limitado de glifos. `base-glyph-character` normaliza acentos para letras-base. Não remova essa etapa enquanto a interface depender da fonte 5x7.

## Comentários no código

Cada módulo começa com um cabeçalho que explica sua responsabilidade e suas restrições. Comentários internos devem registrar decisões, invariantes, riscos e motivos — não repetir literalmente a forma do código. Funções públicas ou comportamentos não óbvios devem possuir docstrings em pt-BR. Termos técnicos estáveis podem permanecer em inglês quando correspondem a nomes de API ou identificadores.
