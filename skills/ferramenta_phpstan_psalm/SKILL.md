---
name: "ferramenta_phpstan_psalm"
description: "Análise estática de PHP com PHPStan e Psalm (com taint analysis) para o Go Auto: apanha erros e caminhos de dados do utilizador até sítios perigosos. Usar no código PHP do Diego."
---
# PHPStan + Psalm (PHP, com taint) — Paulo

**O que é:** as duas ferramentas de análise estática de PHP mais usadas. O **Psalm** tem *taint analysis* de segurança (segue `$_GET`/`$_POST` até SQL/echo). O **PHPStan** apanha erros e bugs que viram falhas.

## Instalar (no projeto PHP, em cópia)
```bash
composer require --dev phpstan/phpstan vimeo/psalm
```

## Usar
```bash
# PHPStan: qualidade e bugs (nível 0..9; subir aos poucos)
vendor/bin/phpstan analyse app --level=5

# Psalm: segurança — taint analysis
vendor/bin/psalm --init          # cria psalm.xml
vendor/bin/psalm --taint-analysis # mostra injeção de SQL/XSS por caminho de dados
```

## No Go Auto
Correr o Psalm `--taint-analysis` sobre `app/` para apanhar SQL concatenado e saída sem escape que o Semgrep possa falhar. Complementa o `ferramenta_semgrep`. Confirmar à mão; registar em `achados.md`.

## Nota
Não altera o código; só analisa. As correções seguem o fluxo normal (plano → "sim" → Afonso).
