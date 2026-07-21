# Busca de pacotes

A busca textual permite abrir um pacote sem percorrer o mapa manualmente.

## Ativação

- clique na caixa de busca no cabeçalho;
- pressione `/`;
- pressione `Ctrl+F`.

Os atalhos de câmera e comandos globais ficam suspensos enquanto a busca está ativa, evitando que a digitação altere a visualização.

## Controles

| Entrada | Ação |
|---|---|
| Digitação | Atualizar a consulta e os resultados |
| `↑` / `↓` | Mover a seleção |
| `Tab` | Avançar para o próximo resultado |
| `Enter` | Abrir o pacote selecionado |
| `Backspace` | Remover o último caractere |
| Clique em resultado | Abrir diretamente |
| Clique fora | Fechar a caixa |
| `Esc` | Fechar a busca |

A consulta permanece guardada ao fechar pelo clique ou por `Esc`. Abrir com `/` ou `Ctrl+F` inicia uma nova consulta limpa.

## Classificação de relevância

A busca não diferencia maiúsculas e minúsculas. Os resultados são ordenados nesta sequência:

1. nome exato;
2. prefixo do nome completo;
3. prefixo de um segmento separado por ponto;
4. trecho contínuo;
5. subsequência de caracteres.

Exemplos para `MEU-APP.RENDER`:

```text
MEU-APP.RENDER   correspondência exata
MINHA              prefixo
RENDER             segmento
APP.REN            trecho contínuo
MRE                subsequência
```

Nomes mais curtos e ordem alfabética são usados como desempate estável.

## Relação com filtros

A busca consulta todos os pacotes presentes no instantâneo, não somente os visíveis no filtro atual. Ao abrir um resultado, o filtro permanece inalterado, mas o pacote selecionado continua visível por regra da interface.

Use `V` depois da busca para mostrar apenas a vizinhança direta do pacote aberto.

## Entrada Unicode e IME

O Malkuth usa os eventos `SDL_EVENT_TEXT_INPUT`, que entregam texto UTF-8 confirmado pelo sistema operacional. Isso oferece suporte a layouts de teclado internacionais e métodos de composição. O aplicativo informa ao SDL3 a posição da caixa para que janelas de sugestões sejam posicionadas próximas ao cursor.

## Consulta inicial

```bash
MALKUTH_INITIAL_SEARCH='MEU-APP.CORE' sbcl --script run.lisp
```

A interface abre com a busca preenchida e os resultados disponíveis.

## API programática

```lisp
(asdf:load-system "malkuth/core")

(defparameter *instantaneo*
  (malkuth.model:build-snapshot))

(malkuth.model:search-nodes
 *instantaneo*
 "render"
 :limit 10)
```

O argumento opcional `:predicate` restringe os candidatos:

```lisp
(malkuth.model:search-nodes
 *instantaneo*
 "app"
 :predicate (lambda (node)
              (eq (malkuth.model:node-kind node) :user)))
```
