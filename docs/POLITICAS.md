# Políticas arquiteturais

As políticas permitem transformar decisões de arquitetura em regras versionadas junto ao projeto. O arquivo é uma S-expression lida com `*READ-EVAL*` desativado.

## Ativação

```bash
MALKUTH_POLICY_FILE="$PWD/malkuth-politicas.sexp" sbcl --script run.lisp
```

Na interface:

- `L` abre o painel;
- `7` mostra somente pacotes envolvidos em violações;
- anéis vermelhos indicam violações;
- `F5` reavalia as regras;
- `X` exporta `malkuth-politicas.md` e `malkuth-politicas.json`.

## Formato

```lisp
(:malkuth-policy t
 :format-version 1
 :label "Políticas do projeto"
 :rules (...))
```

Cada regra possui `:id`, `:type`, `:severity` e campos específicos. Severidades aceitas: `:info`, `:warning` e `:error`.

## Padrões

Nomes aceitam `*` para qualquer sequência e `?` para um caractere. A comparação não diferencia maiúsculas de minúsculas.

```text
MEU-APP.*
MEU-APP.DOMINIO*
MEU-APP.?PI
```

## Tipos de regra

### Dependência proibida

```lisp
(:id "dominio-sem-ui"
 :type :forbid-dependency
 :severity :error
 :from "MEU-APP.DOMINIO*"
 :to "MEU-APP.UI*")
```

### Dependência obrigatória

Cada pacote correspondente a `:from` deve usar diretamente ao menos um pacote correspondente a `:to`.

```lisp
(:id "aplicacao-usa-dominio"
 :type :require-dependency
 :severity :warning
 :from "MEU-APP.APLICACAO*"
 :to "MEU-APP.DOMINIO*")
```

### Limites

```lisp
(:id "fanout" :type :max-fan-out :package "MEU-APP.*" :value 8)
(:id "fanin" :type :max-fan-in :package "MEU-APP.*" :value 20)
(:id "risco" :type :max-risk :package "MEU-APP.*" :value 45)
(:id "tamanho" :type :max-symbols :package "MEU-APP.*" :value 1000)
```

### Ciclos proibidos

```lisp
(:id "dominio-sem-ciclos"
 :type :forbid-cycle
 :severity :error
 :package "MEU-APP.DOMINIO*")
```

### Ordem de camadas

Camadas anteriores são fundamentais. Elas não podem depender de camadas posteriores. Dependências da interface para aplicação ou domínio são permitidas; dependências do domínio para a interface não são.

```lisp
(:id "camadas"
 :type :layer-order
 :severity :error
 :layers ("MEU-APP.DOMINIO*"
          "MEU-APP.APLICACAO*"
          "MEU-APP.UI*"))
```

## CI

```bash
MALKUTH_POLICY_FILE="$PWD/malkuth-politicas.sexp" \
MALKUTH_FAIL_ON_POLICY=true \
sbcl --script analyze.lisp
```

Somente violações `:error` reprovam a política. Avisos continuam nos relatórios.

## API

```lisp
(defparameter *regras*
  (malkuth.policy:load-policy-file #P"malkuth-politicas.sexp"))

(defparameter *relatorio*
  (malkuth.policy:evaluate-policies instantaneo *regras*))

(malkuth.policy:policy-report-summary *relatorio*)
(malkuth.policy:violating-package-names *relatorio*)
```
