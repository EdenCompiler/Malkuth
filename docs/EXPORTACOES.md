# Exportações

## Pacote completo

`malkuth.export:export-bundle` e `X` produzem:

```text
malkuth.svg
malkuth.json
malkuth.dot
malkuth-report.md
malkuth-manifest.txt
```

## Dossiê do pacote

`malkuth.export:export-package-bundle` e `C` produzem dois arquivos com nome normalizado:

```text
pacote-<nome>.md
pacote-<nome>.dot
```

O Markdown reúne conteúdo, métricas, risco, participação em ciclos, dependências, dependentes e até 200 símbolos próprios. O DOT contém somente a seleção e sua vizinhança direta.

## JSON

O esquema atual é `1.1`. As chaves permanecem em inglês para compatibilidade:

```json
{
  "schemaVersion": "1.1",
  "generatedAt": "...",
  "fingerprint": "...",
  "implementation": "...",
  "summary": {},
  "health": {},
  "packages": [],
  "dependencies": [],
  "cycles": [],
  "orphans": [],
  "warnings": []
}
```

## Escrita atômica

Artefatos são escritos em arquivos temporários vizinhos e depois substituem o destino. Isso reduz o risco de consumidores lerem resultados incompletos.

## API

```lisp
(malkuth.export:export-bundle instantaneo #P"build/malkuth/")
(malkuth.export:export-package-bundle
 instantaneo pacote #P"build/malkuth/" :analysis analise)
```
