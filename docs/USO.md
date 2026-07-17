# Uso

## Fluxo recomendado

1. Carregue a aplicação e suas dependências no mesmo processo Lisp.
2. Defina o escopo dos pacotes do projeto.
3. Abra o Malkuth ou execute a análise sem interface.
4. Pressione `/` ou `Ctrl+F` para localizar diretamente um pacote pelo nome.
5. Use `2` para observar o projeto e `3` para localizar risco.
6. Selecione um pacote e use `I` para alternar símbolos e dependências.
7. Use `V` para isolar sua vizinhança e `F` para guardar pontos de interesse.
8. Exporte `C` para um dossiê focado ou `X` para o pacote completo.
9. Após recarregar código ou plugins, pressione `F5`.

## Regiões da interface

### Visão geral

Mostra contagens globais, saúde, ciclos, isolados, avisos, quantidade visível e favoritos.

### Busca

A caixa superior permite procurar todos os pacotes do instantâneo. Clique nela ou use `/` ou `Ctrl+F`. Os resultados aparecem enquanto o texto é digitado. Use as setas ou `Tab` para navegar e `Enter` para abrir. `Esc` fecha a busca sem encerrar o aplicativo.

### Mapa

Cada nó representa um pacote e cada aresta representa `USE-PACKAGE`. A barra superior informa o filtro e a quantidade de pacotes visíveis.

### Inspetor

A aba **Símbolos** lista conteúdo próprio classificado. A aba **Dependências** separa relações de saída (`USA`) e entrada (`USADO POR`) e mostra o risco local de cada pacote relacionado.

## Atualização

`F5` reconstrói o instantâneo, preserva a seleção pelo nome e informa pacotes adicionados, removidos e alterados.

## Exportações interativas

- `P`: `malkuth-live.svg`;
- `X`: pacote global SVG, JSON, DOT, Markdown e manifesto;
- `C`: Markdown e DOT focados no pacote selecionado.

## Paginação

`Page Up` e `Page Down` rolam a aba ativa. `J`, `K` e `Tab` navegam somente pelos pacotes aceitos pelo filtro atual.

Consulte [Busca de pacotes](BUSCA.md) e [Filtros, foco e favoritos](FILTROS-E-FAVORITOS.md) para detalhes.
