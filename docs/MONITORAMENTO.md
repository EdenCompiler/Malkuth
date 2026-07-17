# Monitoramento contínuo

O módulo `malkuth.monitor` observa mudanças ocorridas dentro da mesma imagem Lisp. Ele não cria threads automaticamente e pode ser integrado ao mecanismo de concorrência já usado pela aplicação.

## Inicializador

```bash
MALKUTH_BOOTSTRAP_FILE="$PWD/iniciar-meu-app.lisp" \
MALKUTH_SCOPE_PREFIXES='MEU-APP' \
MALKUTH_OUTPUT_DIR="$PWD/build/malkuth-monitor/" \
MALKUTH_WATCH_INTERVAL=10 \
sbcl --script watch.lisp
```

Quando a impressão digital muda, o monitor:

1. valida o novo instantâneo;
2. salva o estado anterior no histórico;
3. calcula a comparação arquitetural;
4. exporta o pacote corrente e a comparação;
5. atualiza seu último estado válido.

## Variáveis

| Variável | Padrão | Uso |
|---|---:|---|
| `MALKUTH_BOOTSTRAP_FILE` | ausente | Arquivo que carrega a aplicação monitorada |
| `MALKUTH_WATCH_INTERVAL` | `5` | Segundos entre leituras |
| `MALKUTH_WATCH_ITERATIONS` | infinito | Limite útil para testes e automação |
| `MALKUTH_EXPORT_ON_CHANGE` | `true` | Exporta relatórios ao detectar alteração |
| `MALKUTH_HISTORY_RETENTION` | `50` | Quantidade de estados anteriores |
| `MALKUTH_SCOPE_PREFIXES` | ausente | Escopo do monitor |

## API cooperativa

```lisp
(defparameter *monitor*
  (malkuth.monitor:make-architecture-monitor
   :snapshot-builder (lambda ()
                       (malkuth.model:build-snapshot))
   :output-directory #P"build/monitor/"))

(malkuth.monitor:monitor-poll! *monitor*)
```

Laço opcional:

```lisp
(malkuth.monitor:run-monitor
 *monitor*
 :interval 5
 :on-poll
 (lambda (monitor mudou-p diferenca instantaneo)
   (declare (ignore monitor diferenca instantaneo))
   (when mudou-p
     (format t "Arquitetura alterada.~%"))))
```

Encerramento cooperativo:

```lisp
(malkuth.monitor:stop-monitor! *monitor*)
```

## Uso com threads

O monitor pode ser executado por `bt:make-thread`, `sb-thread:make-thread` ou outra abstração escolhida pelo projeto. Essa dependência não faz parte do núcleo para manter portabilidade.

## Limitação importante

Um processo Malkuth separado não consegue observar o heap de outro processo. O monitor deve estar na própria imagem da aplicação ou carregar a aplicação por `MALKUTH_BOOTSTRAP_FILE`.
