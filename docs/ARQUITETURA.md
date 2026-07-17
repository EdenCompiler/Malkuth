# Arquitetura interna

## Visão geral

O Malkuth separa aquisição de dados, análise, visualização e operação. A interface SDL3 e o executor sem interface usam as mesmas estruturas públicas do núcleo.

```text
imagem Common Lisp
        │
        ▼
malkuth.model ── validação e impressão digital
        │
        ├────────► malkuth.analysis ── métricas, ciclos, saúde e diferenças
        │
        ├────────► malkuth.layout ── posições 3D e projeção
        │
        ├────────► malkuth.svg ── documento visual
        │
        └────────► malkuth.export ── JSON, DOT, Markdown e manifesto
                              │
                              ├── analyze.lisp
                              └── malkuth.app + SDL3
```

## `malkuth.model`

Responsável por:

- enumerar os pacotes da imagem;
- aplicar predicados de escopo e propriedade;
- incluir dependências diretas de fronteira;
- contar símbolos internos e externos;
- classificar funções, genéricas, macros, classes e variáveis;
- construir nós e arestas;
- consultar dependências, dependentes e vizinhança direta por identificador ou nó;
- validar consistência de identificadores, arestas e totais;
- gerar uma impressão digital FNV-1a de 64 bits.

A impressão digital é determinística para a mesma topologia e contagens. Ela serve para detectar mudanças, não para segurança criptográfica.

## `malkuth.analysis`

Calcula:

- entrada e saída por nó;
- grau total;
- componentes fortemente conexos pelo algoritmo de Tarjan;
- ciclos de dependência;
- centros de conectividade;
- pacotes isolados;
- avisos heurísticos;
- pontuação de saúde;
- diferenças entre dois instantâneos.

Os avisos e a saúde podem ser restritos por tipo de nó. Em execuções com prefixos de usuário, bibliotecas e implementação não dominam a pontuação do projeto.

## `malkuth.layout`

O arranjo tridimensional combina:

- repulsão entre pacotes;
- molas para relações de `USE-PACKAGE`;
- gravidade central fraca;
- Euler semi-implícito;
- amortecimento e limite de velocidade.

As posições iniciais derivam de hashes estáveis dos nomes dos pacotes. Isso melhora a comparação visual entre execuções semelhantes.

## `malkuth.svg`

Gera um painel autocontido com:

- visão geral;
- saúde da arquitetura;
- legenda de cores;
- mapa de pacotes;
- pacote selecionado;
- lista inicial de símbolos.

O SVG usa texto nativo do navegador e recorte do painel central para evitar invasão das barras laterais.

## `malkuth.export`

Centraliza formatos de máquina e documentação. Além do pacote global, gera dossiês Markdown e grafos DOT focados em um pacote e sua vizinhança direta. A gravação usa um arquivo temporário vizinho seguido de substituição atômica. Dessa forma, uma interrupção não deixa um relatório parcial com nome definitivo.

## `malkuth.app`

A interface mantém um estado explícito com instantâneo, análise, seleção, câmera, filtros, aba e deslocamento do inspetor, favoritos e status. Favoritos são persistidos por nome em uma S-expression lida com `*READ-EVAL*` desativado. A aplicação pode atualizar a imagem ativa, comparar instantâneos, isolar vizinhanças e exportar sem duplicar as regras do núcleo.

## `malkuth.sdl3`

É uma ponte CFFI deliberadamente pequena. O Lisp controla modelo, física, câmera, seleção e desenho; SDL3 fornece janela, entrada e primitivas aceleradas em duas dimensões.

## Fonte vetorial

A interface inclui uma fonte 5x7 sem arquivos externos. Letras acentuadas são normalizadas para o glifo-base correspondente, preservando legibilidade e compatibilidade do renderizador.

## Decisões de compatibilidade

Os seguintes nomes permanecem em inglês por serem interfaces técnicas estáveis:

- nomes de sistemas e pacotes Lisp;
- variáveis de ambiente;
- chaves do esquema JSON;
- atributos e palavras reservadas de SVG, DOT e ASDF;
- nomes da API SDL3.

Textos humanos, comentários, docstrings, mensagens, relatórios e documentação estão em pt-BR.
