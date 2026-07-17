# Malkuth 0.6.0

**Observatório da imagem Common Lisp, analisador de arquitetura por pacotes e monitor de regressões.**

O Malkuth examina o processo Lisp em execução e transforma seus pacotes em um mapa navegável. Cada pacote vira um nó; relações de `USE-PACKAGE` viram arestas; símbolos, funções, macros, classes e variáveis são classificados. A mesma fotografia alimenta a interface SDL3, análises arquiteturais, políticas declarativas, histórico e relatórios para CI.

![Interface do Malkuth](docs/imagens/interface.png)

## Novidades da versão 0.6.0

- políticas arquiteturais declarativas em S-expression segura;
- regras de dependência proibida ou obrigatória, limites de acoplamento, risco e tamanho;
- ordem de camadas e proibição de ciclos por padrão de pacote;
- painel de políticas, filtro `7` e marcação visual das violações;
- menor caminho entre dois pacotes, destacado diretamente no grafo;
- filtro `8`, painel de rota e exportação do caminho em Markdown e DOT;
- série temporal do histórico com saúde, pacotes, ligações, símbolos, ciclos e avisos;
- exportação da tendência em CSV, JSON e Markdown;
- monitor cooperativo para detectar mudanças em imagens Lisp de longa duração;
- inicializador `watch.lisp` para serviços e sistemas que carregam plugins dinamicamente;
- pacote completo `X` agora inclui tendências e políticas quando disponíveis.

## Capacidades principais

- reflexão sobre a imagem Common Lisp em execução;
- mapa tridimensional de pacotes e dependências;
- busca textual Unicode e seleção direta de pacotes;
- inspeção de símbolos e relações diretas;
- métricas de entrada, saída, conectividade e risco;
- detecção de ciclos por componentes fortemente conexos;
- linha de base, histórico rotativo e comparação de regressões;
- políticas arquiteturais versionáveis para interface e CI;
- menor caminho de conectividade entre pacotes;
- monitoramento contínuo da própria imagem Lisp;
- escopo por prefixos de pacotes;
- exportações atômicas SVG, JSON, DOT, Markdown e CSV;
- núcleo utilizável sem SDL3 e CFFI.

## Requisitos

Para o núcleo, monitor e relatórios: Common Lisp com ASDF, preferencialmente SBCL.

Para a interface: CFFI e SDL3 3.2 ou mais recente.

```bash
sudo apt install sbcl cl-cffi libsdl3-0 libsdl3-dev graphviz
```

## Execução rápida

```bash
sbcl --script run.lisp
```

Análise sem interface:

```bash
sbcl --script analyze.lisp
```

Monitor contínuo:

```bash
MALKUTH_SCOPE_PREFIXES='MEU-APP' \
MALKUTH_WATCH_INTERVAL=5 \
sbcl --script watch.lisp
```

Somente SVG:

```bash
sbcl --script render-svg.lisp
```

## Controles

| Entrada | Ação |
|---|---|
| Apontar / clicar | Pré-visualizar ou selecionar pacote |
| `/` ou `Ctrl+F` | Ativar a busca de pacotes |
| `↑ / ↓`, `Tab`, `Enter` | Navegar e abrir resultados |
| `1` | Mostrar todos os pacotes |
| `2` | Mostrar código do projeto |
| `3` | Mostrar pacotes acima do limiar de risco |
| `4` | Mostrar favoritos |
| `5` ou `V` | Mostrar a vizinhança direta |
| `6` | Mostrar pacotes alterados desde a linha de base |
| `7` | Mostrar pacotes que violam políticas |
| `8` | Mostrar somente a rota arquitetural ativa |
| `F` | Adicionar ou remover favorito |
| `M` | Marcar o pacote atual como origem do caminho |
| `N` | Calcular a menor rota até o pacote selecionado |
| `Z` | Limpar a rota |
| `U` | Exportar a rota em Markdown e DOT |
| `L` | Abrir ou fechar o painel de políticas |
| `B` | Capturar o estado atual como linha de base |
| `T` | Abrir ou fechar o painel de evolução |
| `Y` | Exportar a comparação com a linha de base |
| `I` | Alternar símbolos e dependências no inspetor |
| `C` | Exportar dossiê do pacote selecionado |
| `F5` | Reconstruir, reavaliar e comparar a imagem |
| `G` | Alternar diagnósticos |
| `X` | Exportar o pacote completo |
| `P` | Exportar rapidamente o SVG |
| `J / K` | Pacote anterior / próximo no filtro atual |
| `Page Up / Page Down` | Rolar a aba ativa do inspetor |
| `W A S D` | Orbitar câmera |
| `Q / E` | Afastar / aproximar |
| `Espaço` | Pausar ou retomar o arranjo |
| `R` | Reorganizar o grafo |
| `O` | Alternar órbita automática |
| `H` | Ajuda |
| `Esc` | Fechar busca/ajuda; depois encerrar |

## Políticas arquiteturais

Copie o exemplo e adapte os padrões:

```bash
cp malkuth-politicas.exemplo.sexp malkuth-politicas.sexp
```

Abra a interface com as regras:

```bash
MALKUTH_SCOPE_PREFIXES='MEU-APP' \
MALKUTH_USER_PREFIXES='MEU-APP' \
MALKUTH_POLICY_FILE="$PWD/malkuth-politicas.sexp" \
sbcl --script run.lisp
```

Exemplo de regra:

```lisp
(:id "dominio-sem-ui"
 :type :forbid-dependency
 :severity :error
 :from "MEU-APP.DOMINIO*"
 :to "MEU-APP.UI*"
 :message "A camada de domínio não pode depender da interface.")
```

Tipos disponíveis:

```text
:forbid-dependency  :require-dependency
:max-fan-out        :max-fan-in
:max-risk           :max-symbols
:forbid-cycle       :layer-order
```

Consulte [Políticas arquiteturais](docs/POLITICAS.md).

## Caminhos entre pacotes

1. Selecione a origem e pressione `M`.
2. Localize ou selecione o destino.
3. Pressione `N` para calcular a menor rota de conectividade.
4. Use `8` para isolar a rota e `U` para exportá-la.

A rota interativa usa conectividade não orientada para responder “como estes subsistemas estão ligados?”. A API também suporta caminhos orientados de saída e entrada.

Consulte [Caminhos de dependência](docs/CAMINHOS.md).

## Histórico e tendências

`F5` salva o instantâneo anterior em `output/historico/`. O pacote completo exporta:

```text
malkuth-tendencia.csv
malkuth-tendencia.json
malkuth-tendencia.md
```

A série registra saúde, pacotes, ligações, símbolos, ciclos e avisos. Consulte [Histórico e comparação](docs/HISTORICO-E-COMPARACAO.md).

## Monitor contínuo

`watch.lisp` observa a própria imagem Lisp e exporta uma comparação sempre que a impressão digital muda. Ele é especialmente adequado a servidores que carregam plugins, recompilam módulos ou aplicam correções em tempo de execução.

```bash
MALKUTH_BOOTSTRAP_FILE="$PWD/iniciar-meu-app.lisp" \
MALKUTH_SCOPE_PREFIXES='MEU-APP' \
MALKUTH_OUTPUT_DIR="$PWD/build/malkuth-monitor/" \
MALKUTH_WATCH_INTERVAL=10 \
sbcl --script watch.lisp
```

Consulte [Monitoramento contínuo](docs/MONITORAMENTO.md).

## Integração contínua

```bash
MALKUTH_SCOPE_PREFIXES='MEU-APP' \
MALKUTH_USER_PREFIXES='MEU-APP' \
MALKUTH_OUTPUT_DIR="$PWD/build/malkuth/" \
MALKUTH_POLICY_FILE="$PWD/malkuth-politicas.sexp" \
MALKUTH_FAIL_ON_POLICY=true \
MALKUTH_BASELINE_FILE="$PWD/ci/malkuth-baseline.sexp" \
MALKUTH_FAIL_ON_NEW_CYCLES=true \
MALKUTH_MAX_HEALTH_REGRESSION=5 \
MALKUTH_SAVE_HISTORY=true \
MALKUTH_EXPORT_TRENDS=true \
sbcl --script analyze.lisp
```

Códigos de saída: `0` sucesso, `1` erro operacional e `2` política violada.

## API programática

```lisp
(asdf:load-system "malkuth/core")

(defparameter *instantaneo* (malkuth.model:build-snapshot))
(defparameter *analise* (malkuth.analysis:analyze-snapshot *instantaneo*))

(malkuth.model:shortest-dependency-path
 *instantaneo* "MEU-APP.UI" "MEU-APP.DOMINIO"
 :direction :either)

(defparameter *regras*
  (malkuth.policy:load-policy-file #P"malkuth-politicas.sexp"))

(defparameter *politicas*
  (malkuth.policy:evaluate-policies
   *instantaneo* *regras* :analysis *analise*))

(malkuth.export:export-policy-bundle *politicas* #P"build/malkuth/")
```

Monitor embutido:

```lisp
(defparameter *monitor*
  (malkuth.monitor:make-architecture-monitor
   :output-directory #P"build/monitor/"))

(malkuth.monitor:monitor-poll! *monitor*)
```

## Estrutura

```text
src/model.lisp        reflexão, busca, relações, caminhos e validação
src/analysis.lisp     métricas, ciclos, comparação e tendências
src/history.lisp      persistência e retenção de instantâneos
src/policy.lisp       regras arquiteturais declarativas
src/export.lisp       relatórios globais, focados, políticas, rotas e tendências
src/monitor.lisp      monitoramento cooperativo da imagem
src/layout.lisp       arranjo tridimensional determinístico
src/svg.lisp          painel SVG autocontido
src/vector-font.lisp  fonte vetorial 5x7 embutida
src/sdl3.lisp         ponte CFFI mínima para SDL3
src/app.lisp          interface, busca, filtros, políticas e rotas
analyze.lisp          execução sem interface e políticas de CI
watch.lisp            monitor contínuo sem interface
run.lisp              inicializador da interface
```

## Validação

```bash
make test
make analyze
make smoke
make validate
```

## Limitações

- O grafo representa `USE-PACKAGE`; referências totalmente qualificadas não geram arestas.
- A rota no modo `:either` mostra conectividade e pode atravessar uma aresta no sentido inverso.
- O risco, a saúde e as políticas são auxiliares de revisão, não provas de correção ou segurança.
- O monitor observa alterações ocorridas dentro da mesma imagem Lisp; ele não inspeciona outro processo.
- Relatórios e históricos contêm nomes internos de pacotes e símbolos.
- O Linux é a principal plataforma de validação desta versão.

A documentação completa está em [docs/INDICE.md](docs/INDICE.md).

## Licença

MIT. O texto jurídico oficial permanece em inglês em [LICENSE](LICENSE).
