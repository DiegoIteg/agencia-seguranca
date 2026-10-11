---
name: "ferramenta_semgrep"
description: "Análise estática de segurança do código (SAST) com Semgrep — a mais usada: milhares de regras para PHP, JS, Python e mais. Usar para varrer o código do Diego à procura de padrões vulneráveis."
---
# Semgrep (SAST) — Paulo

**O que é:** o motor de análise estática de segurança mais usado. Regras prontas para OWASP, injeção, XSS, segredos, e taint analysis (segue a entrada do utilizador até ao sítio perigoso).

## Instalar
```bash
pipx install semgrep   # ou: pip install --user semgrep ; ou: brew install semgrep
semgrep --version
```

## Usar (no código do Diego, em cópia)
```bash
# varrimento completo com o conjunto automático (escolhe regras pela linguagem)
semgrep scan --config auto --severity ERROR --severity WARNING --json -o semgrep.json .

# focado em segurança web (OWASP) e segredos
semgrep scan --config p/owasp-top-ten --config p/secrets --config p/php --config p/javascript .
```
- `--config auto` deteta as linguagens e aplica o Registry.
- `p/php`, `p/javascript`, `p/owasp-top-ten`, `p/secrets`, `p/sql-injection`, `p/xss` são conjuntos oficiais.
- Taint: muitas regras já seguem `$_GET`/`$_POST` até `query()`/`echo`.

## No Go Auto (PHP/Adianti)
Correr `--config p/php --config p/owasp-top-ten` sobre `app/`. Confirmar à mão cada achado (há falsos positivos). Registar em `achados.md` com ficheiro:linha e gravidade.

## Regra de ouro
Só no código do Diego. Não enviar o código para serviços externos sem o "sim" (o `scan` corre localmente; evitar `--config` de URLs não oficiais).
