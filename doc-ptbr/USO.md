# Uso

## Fluxo recomendado

1. Carregue a aplicação e suas dependências no mesmo processo Lisp.
2. Defina o escopo e os prefixos pertencentes ao projeto.
3. Opcionalmente carregue um arquivo de políticas arquiteturais.
4. Abra o Malkuth ou execute a análise sem interface.
5. Pressione `/` ou `Ctrl+F` para localizar diretamente um pacote.
6. Use os filtros `2`, `3`, `7` e `9` para localizar código próprio, risco, violações e alto impacto transitivo.
7. Selecione um pacote e use `I` para alternar símbolos e dependências.
8. Use `V` para isolar sua vizinhança e `F` para guardar pontos de interesse.
9. Para explicar conectividade, marque uma origem com `M`, selecione o destino e pressione `N`.
10. Pressione `B` para guardar uma linha de base antes de uma mudança.
11. Após recarregar código ou plugins, pressione `F5`, abra `T` e use `6` para isolar alterações.
12. Exporte `C` para um dossiê focado, `U` para a rota, `Y` para a comparação ou `X` para o pacote completo.

## Regiões da interface

### Visão geral

Mostra contagens globais, saúde, ciclos, isolados, avisos, quantidade visível e favoritos.

### Busca

A caixa superior permite procurar todos os pacotes do instantâneo. Clique nela ou use `/` ou `Ctrl+F`. Os resultados aparecem enquanto o texto é digitado. Use as setas ou `Tab` para navegar e `Enter` para abrir. `Esc` fecha a busca sem encerrar o aplicativo.

### Mapa

Cada nó representa um pacote e cada aresta representa `USE-PACKAGE`. A barra superior informa o filtro e a quantidade de pacotes visíveis. Anéis adicionais comunicam estado:

- dourado: favorito;
- magenta: pacote alterado desde a linha de base;
- vermelho: pacote envolvido em violação de política;
- rosa: pacote pertencente à rota arquitetural ativa.

### Inspetor

A aba **Símbolos** lista conteúdo próprio classificado. A aba **Dependências** separa relações de saída (`USA`) e entrada (`USADO POR`) e mostra o risco local de cada pacote relacionado.

### Painel de políticas

`L` abre o resumo das regras carregadas, severidades e violações. `7` restringe o mapa aos pacotes envolvidos em violações.

### Painel de caminho

`M` registra o pacote selecionado como origem. Depois selecione o destino e pressione `N`. `8` mostra somente os nós da rota e `Z` limpa a investigação.

### Painel de evolução

`T` mostra a comparação com a linha de base e a tendência histórica: saúde, ciclos, avisos, pacotes e maiores aumentos de risco.

## Atualização da imagem

`F5`:

1. salva o estado anterior no histórico;
2. reconstrói o instantâneo;
3. reavalia as políticas;
4. recalcula tendências;
5. recompõe a rota por nome, quando possível;
6. preserva a seleção;
7. informa pacotes adicionados, removidos e alterados.

## Exportações interativas

- `P`: `malkuth-live.svg`;
- `X`: pacote global SVG, JSON, DOT, Markdown, manifesto, CSV, políticas e tendências disponíveis;
- `Y`: comparação Markdown e JSON contra a linha de base;
- `C`: Markdown e DOT focados no pacote selecionado;
- `U`: Markdown e DOT da rota arquitetural ativa.

## Paginação e navegação

`Page Up` e `Page Down` rolam a aba ativa. `J`, `K` e `Tab` navegam somente pelos pacotes aceitos pelo filtro atual. O filtro `9` isola pacotes cujo raio de impacto alcança `MALKUTH_IMPACT_THRESHOLD`.

Consulte [Políticas](POLITICAS.md), [Caminhos](CAMINHOS.md), [Histórico](HISTORICO-E-COMPARACAO.md), [Busca](BUSCA.md) e [Filtros](FILTROS-E-FAVORITOS.md).
