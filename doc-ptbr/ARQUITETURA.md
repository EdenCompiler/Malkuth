# Arquitetura interna

## Visão geral

O Malkuth separa aquisição de dados, análise, governança, visualização, persistência e operação. A interface SDL3, o executor sem interface e o monitor contínuo usam as mesmas estruturas públicas do núcleo.

```text
imagem Common Lisp
        │
        ▼
malkuth.model ── reflexão, busca, relações, caminhos e validação
        │
        ├────────► malkuth.analysis ── métricas, ciclos, regressões e tendências
        ├────────► malkuth.policy ── regras arquiteturais declarativas
        ├────────► malkuth.history ── linha de base e histórico seguro
        ├────────► malkuth.layout ── posições 3D e projeção
        ├────────► malkuth.svg ── documento visual
        ├────────► malkuth.export ── relatórios e formatos de máquina
        └────────► malkuth.monitor ── detecção cooperativa de mudanças
                              │
                              ├── analyze.lisp
                              ├── watch.lisp
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
- consultar dependências, dependentes e vizinhança direta;
- buscar pacotes por nome com classificação de relevância;
- encontrar o menor caminho por busca em largura;
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
- diferenças entre dois instantâneos;
- comparação arquitetural com saúde, ciclos e variações de risco;
- séries temporais construídas a partir do histórico persistido.

Os avisos e a saúde podem ser restritos por tipo de nó. Em execuções com prefixos de usuário, bibliotecas e implementação não dominam a pontuação do projeto.

## `malkuth.policy`

Carrega, valida e avalia regras arquiteturais declarativas. O formato é uma S-expression segura com `*READ-EVAL*` desativado. O mecanismo aceita padrões glob, severidades e regras para:

- dependência proibida ou obrigatória;
- fan-in e fan-out máximos;
- risco e tamanho máximos;
- ciclos proibidos;
- ordem de camadas.

O relatório é independente da interface e pode reprovar uma execução de CI.

## `malkuth.history`

Serializa somente a estrutura necessária para análise histórica: nomes, tipos, contagens, arestas, metadados e totais. Referências a objetos `PACKAGE`, posições gráficas e estado executável não são persistidos.

A leitura desativa `*READ-EVAL*`, verifica a versão do formato, exige identificadores densos e executa `validate-snapshot`. O histórico rotativo remove arquivos antigos depois de uma gravação bem-sucedida.

## `malkuth.monitor`

Mantém o último instantâneo válido e executa verificações cooperativas. Quando a impressão digital muda, salva o estado anterior, calcula a diferença e opcionalmente exporta relatórios. O módulo não cria threads automaticamente; a aplicação hospedeira escolhe seu modelo de concorrência.

## `malkuth.layout`

O arranjo tridimensional combina:

- repulsão entre pacotes;
- molas para relações de `USE-PACKAGE`;
- gravidade central fraca;
- Euler semi-implícito;
- amortecimento e limite de velocidade.

As posições iniciais derivam de hashes estáveis dos nomes. Isso melhora a comparação visual entre execuções semelhantes.

## `malkuth.svg`

Gera um painel autocontido com visão geral, saúde, legenda, mapa, pacote selecionado e lista inicial de símbolos. O SVG usa texto nativo e recorte do painel central para evitar invasão das barras laterais.

## `malkuth.export`

Centraliza formatos de máquina e documentação. Além do pacote global, gera:

- dossiês Markdown e DOT por pacote;
- comparação contra linha de base;
- políticas em Markdown e JSON;
- caminhos em Markdown e DOT;
- tendências em CSV, JSON e Markdown;
- tabelas CSV de pacotes e relações.

A gravação usa arquivo temporário vizinho seguido de substituição atômica.

## `malkuth.app`

A interface mantém estado explícito para instantâneo, análise, políticas, linha de base, comparação, tendência, rota, seleção, câmera, filtros, abas, favoritos e mensagens. A atualização por `F5` recompõe dados derivados sem duplicar as regras do núcleo.

## `malkuth.sdl3`

É uma ponte CFFI deliberadamente pequena. O Lisp controla modelo, física, câmera, seleção, entrada textual e desenho; SDL3 fornece janela, eventos e primitivas aceleradas em duas dimensões.

## Fonte vetorial

A interface inclui uma fonte 5x7 sem arquivos externos. Letras acentuadas são normalizadas para o glifo-base correspondente, preservando legibilidade e compatibilidade do renderizador.

## Decisões de compatibilidade

Permanecem em inglês por serem interfaces técnicas estáveis:

- sistemas, pacotes e funções públicas Lisp;
- variáveis de ambiente;
- chaves de esquemas JSON;
- atributos e palavras reservadas de SVG, DOT e ASDF;
- nomes da API SDL3.

Textos humanos, comentários, docstrings, mensagens, relatórios e documentação estão em pt-BR.
