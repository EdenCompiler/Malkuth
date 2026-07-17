# Caminhos de dependência

O Malkuth encontra a menor rota entre dois pacotes por busca em largura.

## Interface

1. Selecione a origem e pressione `M`.
2. Selecione ou pesquise o destino.
3. Pressione `N`.
4. Use `8` para ocultar o restante do mapa.
5. Use `U` para exportar a rota.
6. Pressione `Z` para limpar.

Nós da rota recebem anel rosa; arestas da rota ficam mais espessas e destacadas.

## Direções da API

- `:outgoing`: segue `USE-PACKAGE` da origem para as dependências;
- `:incoming`: percorre dependentes na direção inversa;
- `:either`: trata a topologia como não orientada.

```lisp
(malkuth.model:shortest-dependency-path
 instantaneo "MEU-APP.UI" "MEU-APP.DOMINIO"
 :direction :outgoing)
```

Para trabalhar somente com identificadores:

```lisp
(malkuth.model:shortest-dependency-path-ids
 instantaneo origem destino :direction :either)
```

## Exportação

`U` ou `malkuth.export:export-path-bundle` produz:

```text
malkuth-caminho.md
malkuth-caminho.dot
```

O DOT mantém a direção real das arestas e usa uma indicação invertida quando a rota `:either` atravessa a relação ao contrário.

## Usos

- explicar como dois subsistemas estão conectados;
- investigar dependências transitivas inesperadas;
- encontrar o elo entre UI, domínio, infraestrutura e plugins;
- criar diagramas pequenos para revisão de código;
- orientar a remoção progressiva de acoplamento.
