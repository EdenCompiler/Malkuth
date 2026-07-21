# Changelog / Histórico de alterações

## 0.7.0 — Impacto transitivo e integrações de produção

### Adicionado
- Travessia transitiva de dependências e dependentes entre pacotes.
- Limite opcional de profundidade para consultas transitivas do grafo.
- APIs públicas para dependências transitivas, dependentes transitivos e alcançabilidade genérica.
- Métrica de **raio de impacto** por pacote para estimar o alcance potencial de uma alteração.
- Métrica de **instabilidade** por pacote derivada de fan-in e fan-out.
- Ranking de pacotes críticos por impacto transitivo.
- Filtro visual `9` para pacotes de alto impacto.
- Configuração `MALKUTH_IMPACT_THRESHOLD` para o filtro de impacto.
- Exportação SARIF 2.1.0 para avisos arquiteturais e violações de políticas declarativas.
- Exportação no formato de exposição do Prometheus com métricas globais e por pacote.
- Exportação Mermaid do grafo de dependências para documentação Markdown.
- Relatório Markdown dedicado ao impacto transitivo.
- Dossiês de pacote ampliados com dependências transitivas, dependentes transitivos, raio de impacto e instabilidade.
- Inspetor SVG ampliado com métricas de impacto.
- Esquema JSON do instantâneo atualizado para `1.2`.
- Novos campos JSON para contagens transitivas, raio de impacto e instabilidade.
- Novas colunas CSV para métricas de impacto transitivo.
- Pacote completo de relatórios ampliado com SARIF, Prometheus, Mermaid e ranking de impacto.

## 0.6.1 — Documentação bilíngue e limpeza da distribuição

### Adicionado
- Árvore completa de documentação em inglês em `doc-en/`.
- Árvore completa de documentação em português do Brasil em `doc-ptbr/`.
- README raiz bilíngue com metades completas em inglês e pt-BR.
- Diretório compartilhado `assets/` para recursos da documentação.
- Índices paralelos de documentação nos dois idiomas.

### Melhorado
- Cobertura documental alinhada entre os dois idiomas.
- Comentários do código-fonte auditados e mantidos em pt-BR.
- Links locais e estrutura do pacote revisados.

### Removido
- Árvore antiga `docs/`.
- Duplicações da imagem da interface entre árvores de idioma.
- Inicializador redundante de teste de fumaça SDL.
- Artefatos gerados de `output/` e `build/` da distribuição.

## 0.6.0 — Políticas arquiteturais, caminhos, tendências e monitoramento

### Adicionado
- Motor declarativo de políticas arquiteturais usando S-expressions analisadas com segurança.
- Regras para:
  - dependências proibidas;
  - dependências obrigatórias;
  - fan-out máximo;
  - fan-in máximo;
  - risco local máximo;
  - quantidade máxima de símbolos;
  - ciclos proibidos;
  - ordem de camadas.
- Painel de políticas na interface SDL.
- Anéis visuais para pacotes envolvidos em violações.
- Filtro `7` para pacotes envolvidos em violações de políticas.
- Análise do menor caminho de dependência entre dois pacotes.
- Direções `:outgoing`, `:incoming` e `:either`.
- Fluxo de seleção de origem/destino por atalhos.
- Filtro `8` para isolar a rota atual.
- Destaque das arestas pertencentes ao caminho.
- Exportação de caminhos em Markdown e Graphviz DOT.
- Análise de tendências baseada no histórico persistido.
- Exportação de tendências em CSV, JSON e Markdown.
- Módulo cooperativo `malkuth.monitor`.
- Inicializador `watch.lisp` para monitoramento contínuo dentro de uma imagem Lisp de longa duração.
- Exportação automática de comparações quando a arquitetura monitorada muda.
- Avaliação de políticas integrada ao `analyze.lisp`.
- Falha de CI por violações de políticas declarativas.
- Tendências integradas à análise sem interface e ao pacote completo de relatórios.
- Testes para políticas, caminhos, tendências, monitoramento e exportações correspondentes.

## 0.5.0 — Linhas de base, histórico, regressões e exportações CSV

### Adicionado
- Formato seguro de persistência de instantâneos estruturais.
- Suporte a linha de base arquitetural persistente.
- Captura interativa da linha de base com `B`.
- Histórico rotativo de instantâneos.
- Retenção configurável por `MALKUTH_HISTORY_RETENTION`.
- Captura automática do histórico antes das atualizações da imagem.
- Painel de evolução acessado por `T`.
- Métricas de evolução para:
  - variação da pontuação de saúde;
  - pacotes adicionados;
  - pacotes removidos;
  - pacotes alterados;
  - ciclos novos;
  - ciclos resolvidos;
  - variação de avisos;
  - aumentos de risco.
- Filtro `6` para pacotes alterados em relação à linha de base.
- Marcação visual de pacotes alterados.
- Exportação de comparação com `Y`.
- Relatórios de comparação em Markdown e JSON.
- Exportação CSV de métricas por pacote.
- Exportação CSV das arestas de dependência.
- API pública `malkuth.history`.
- API de análise `compare-architectures`.
- Portões de CI para:
  - ciclos introduzidos recentemente;
  - regressão da pontuação de saúde;
  - aumentos excessivos de risco.
- Atualização opcional da linha de base após análise sem interface aprovada.
- Painel inicial configurável através de `MALKUTH_INITIAL_PANEL`.
- Testes de round-trip dos instantâneos, comparações, CSV e artefatos de regressão.

## 0.4.1 — Busca textual interativa de pacotes

### Adicionado
- Campo permanente de busca de pacotes na interface SDL.
- Ativação da busca por clique, `/` ou `Ctrl+F`.
- Entrada textual nativa do SDL3 por `SDL_EVENT_TEXT_INPUT`.
- Tratamento de entrada UTF-8.
- Posicionamento da área de IME/entrada textual.
- Resultados de busca em tempo real.
- Classificação por relevância priorizando:
  - correspondência exata;
  - prefixo do nome completo;
  - prefixo de segmento do pacote;
  - trecho contínuo;
  - subsequência de caracteres.
- Navegação por teclado com setas, `Tab`, `Enter`, `Backspace` e `Esc`.
- Seleção de resultados pelo mouse.
- Busca em todo o instantâneo mesmo quando filtros visuais escondem pacotes.
- API pública `search-nodes` no núcleo portátil.
- Consulta inicial opcional via `MALKUTH_INITIAL_SEARCH`.
- Testes de regressão para busca exata, prefixo, segmento, busca aproximada e ausência de resultados.
- Cobertura de teste nativo da entrada textual SDL.

## 0.4.0 — Filtros, favoritos, inspeção de dependências e dossiês focados

### Adicionado
- Filtro visual `1`: todos os pacotes.
- Filtro visual `2`: pacotes do projeto.
- Filtro visual `3`: pacotes acima do limiar de risco.
- Filtro visual `4`: favoritos.
- Filtro visual `5`: vizinhança direta da seleção.
- Atalho `V` para alternar o foco na vizinhança.
- Favoritos persistentes com `F`.
- Armazenamento seguro de favoritos em S-expression validada com `*READ-EVAL*` desativado.
- Anéis visuais para favoritos.
- Duas abas no inspetor:
  - símbolos;
  - dependências.
- Visualização de relações de entrada e saída.
- Dossiês focados por pacote em Markdown.
- Exportação Graphviz DOT focada por pacote.
- Atalho `C` para gerar o dossiê focado.
- APIs públicas para:
  - IDs de dependências;
  - IDs de dependentes;
  - IDs de vizinhos;
  - nós de dependência;
  - nós dependentes;
  - nós vizinhos.
- Limiar visual de risco configurável por `MALKUTH_RISK_THRESHOLD`.
- Esquema de instantâneo `1.1`.
- Testes ampliados para relações do grafo e exportações focadas.

### Melhorado
- Comentários e docstrings ampliados em português do Brasil.
- Tratamento de imagens vazias e comportamento do inspetor endurecidos.
- Documentação ampliada sobre filtros, favoritos e investigação de pacotes.

## 0.3.1 — Localização pt-BR e revisão completa da documentação

### Adicionado
- README completo em português do Brasil.
- Guias dedicados em pt-BR para:
  - instalação;
  - uso;
  - arquitetura;
  - configuração;
  - exportações;
  - integração contínua;
  - desenvolvimento;
  - casos de uso;
  - solução de problemas.
- Cobertura do `.gitignore` para FASLs, relatórios, builds e temporários.
- Normalização de acentos na fonte vetorial embutida.

### Melhorado
- Comentários do código-fonte traduzidos e padronizados em pt-BR.
- Docstrings traduzidas e padronizadas em pt-BR.
- Interface, mensagens operacionais, relatórios e inicializadores localizados para pt-BR.
- Estrutura documental reorganizada para melhor manutenção.

### Removido
- Capturas geradas e artefatos temporários de relatório da distribuição.
- Documentação de migração obsoleta.
- Inicializadores de teste duplicados.
- Diretórios de exemplos vazios.

## 0.3.0 — Análise arquitetural orientada a produção

### Adicionado
- Metadados de esquema do instantâneo.
- Validação estrutural de instantâneos.
- Impressão digital determinística.
- Métrica de fan-in.
- Métrica de fan-out.
- Grau/conectividade total.
- Detecção de centros arquiteturais.
- Detecção de pacotes isolados.
- Diagnóstico de pacotes excessivamente grandes.
- Diagnóstico de fan-out elevado.
- Pontuação heurística de saúde arquitetural.
- Detecção de componentes fortemente conexos com o algoritmo de Tarjan.
- Detecção de ciclos de dependência.
- Métricas locais de risco.
- Comparação de instantâneos e diferenças da imagem ativa.
- Atualização ao vivo com `F5` e comparação com o estado anterior.
- Alternância do painel de diagnósticos com `G`.
- Exportação do pacote completo com `X`.
- Navegação paginada de símbolos.
- Escopo por prefixos com `MALKUTH_SCOPE_PREFIXES`.
- Marcação de propriedade do projeto com `MALKUTH_USER_PREFIXES`.
- Inclusão opcional de dependências diretas de fronteira.
- Análise sem interface através de `analyze.lisp`.
- Controles de CI para saúde, ciclos e quantidade de avisos.
- Códigos de saída estáveis para sucesso, erro operacional e falha arquitetural.
- Escrita atômica de relatórios através de temporários e substituição.
- Pacote completo contendo:
  - SVG;
  - JSON;
  - Graphviz DOT;
  - relatório Markdown;
  - manifesto.
- Testes do núcleo e da análise integrados ao ASDF.
- Cobertura de teste de fumaça SDL3.

### Melhorado
- Diagnósticos concentrados nos pacotes do projeto para reduzir ruído do runtime e bibliotecas.
- Confiabilidade das exportações melhorada para evitar arquivos parciais tratados como relatórios válidos.
- Escopo adaptado ao uso real com aplicações em vez de sempre mapear toda a implementação Lisp.

## 0.2.1 — Legibilidade e layout responsivo

### Adicionado
- Tamanho mínimo da janela de 1280×760.
- Layout compacto de controles para janelas menores.
- Medição de texto por largura e tratamento com reticências.
- Densidade adaptativa de rótulos no mapa.
- Posicionamento responsivo dos rótulos dos nós.

### Melhorado
- Escala mínima da fonte vetorial aumentada para eliminar glifos subpixel.
- Títulos, métricas, linhas do inspetor, badges, tooltips e ajuda ampliados.
- Nomes longos recortados pela largura real em pixels em vez da contagem bruta de caracteres.
- Rótulos do mapa confinados ao painel correto.
- Saída SVG ampliada e recortada corretamente.
- Layout melhorado tanto em resoluções grandes quanto na resolução mínima suportada.

## 0.2.0 — Identidade Malkuth e grande reformulação da interface

### Adicionado
- Identidade completa do projeto como **Malkuth**.
- Sistemas ASDF `malkuth` e `malkuth/core`.
- Espaço de nomes de pacotes `MALKUTH.*`.
- Arquivos, mensagens de inicialização e variáveis de ambiente padronizados para Malkuth.
- Interface organizada em três regiões:
  - visão geral/status;
  - mapa central de pacotes;
  - inspetor do pacote.
- Cartões de estatísticas e hierarquia visual mais clara.
- Destaque por hover e tooltips resumidos.
- Ênfase nas relações do pacote selecionado.
- Badges de papel/tipo e linhas alternadas no inspetor.
- Colunas separadas para tipo e nome do símbolo.
- Tela de ajuda orientada por tarefas.
- Exportador SVG redesenhado para combinar com a nova interface.

### Melhorado
- Tipografia, espaçamento, contraste, hierarquia visual e usabilidade geral.
- Inspeção de pacotes mais acessível para usuários que ainda não conhecem a imagem carregada.
- Consistência de nomenclatura em código, sistemas, pacotes, interface, documentação, testes e artefatos exportados.

## 0.1.1 — Bootstrap de dependências no modo script

### Adicionado
- Bootstrap automático do Quicklisp em execuções com `sbcl --script`.
- Detecção prévia de CFFI pelo ASDF.
- Carregamento alternativo a partir de locais comuns do `quicklisp/setup.lisp`.
- Suporte a caminho personalizado através de `QUICKLISP_SETUP`.
- Quickload explícito do CFFI quando necessário.
- Diagnóstico mais claro quando CFFI não pode ser localizado.

### Corrigido
- Falha de inicialização em que CFFI estava instalado, mas invisível porque `sbcl --script` não carregava os arquivos de inicialização do usuário/sistema.
- Descoberta de dependências em ambientes que carregavam Quicklisp apenas pelo `.sbclrc`.

## 0.1.0 — Primeiro observatório vivo de Common Lisp

### Adicionado
- Primeiro observatório executável da imagem viva de Common Lisp.
- Introspecção em tempo de execução dos pacotes carregados.
- Descoberta e classificação de:
  - pacotes;
  - símbolos;
  - funções;
  - macros;
  - funções genéricas;
  - classes;
  - variáveis.
- Extração das relações `USE-PACKAGE`.
- Arranjo tridimensional determinístico por forças para o grafo de pacotes.
- Constelação navegável de pacotes renderizada com SDL3.
- Controles de órbita e zoom da câmera.
- Seleção de pacotes com mouse.
- Navegação de pacotes por teclado.
- Corona animada de símbolos em torno do pacote selecionado.
- Classificação visual dos símbolos no inspetor.
- Interface vetorial em modo imediato.
- Fonte vetorial 5×7 embutida e sem dependências externas.
- Camada direta e estreita de bindings SDL3/CFFI.
- Núcleo portátil separado do frontend gráfico.
- Exportador SVG autossuficiente sem interface gráfica.
- Geração reproduzível de mapas estáticos de pacotes.
- Arquitetura amigável ao REPL e à redefinição viva de funções.
- Testes de fumaça do núcleo e execução SDL3 com limite de quadros.
