---
name: "ferramenta_trivy_osv"
description: "Verificação de dependências e configuração com falhas conhecidas (CVE) usando Trivy e OSV-Scanner, mais npm audit e composer audit. Usar para saber que bibliotecas do Diego têm vulnerabilidades."
---
# Trivy + OSV-Scanner (dependências e CVE) — Clara

**O que é:** Trivy (Aqua) e OSV-Scanner (Google) são os verificadores de vulnerabilidades mais usados para dependências, contentores e configuração.

## Instalar
```bash
brew install trivy                     # ou binário de github.com/aquasecurity/trivy
go install github.com/google/osv-scanner/cmd/osv-scanner@latest  # ou binário
```

## Usar
```bash
# Trivy: sistema de ficheiros do projeto (deteta composer.lock, package-lock.json, etc.)
trivy fs --scanners vuln,secret,misconfig --severity HIGH,CRITICAL -f json -o trivy.json .

# OSV-Scanner: cruza os lockfiles com a base OSV
osv-scanner scan --lockfile=composer.lock --lockfile=package-lock.json --format table

# Nativos (rápidos, por ecossistema)
composer audit          # PHP
npm audit --omit=dev    # JS
```

## No Go Auto
Correr Trivy e OSV sobre a raiz; listar PHP/bibliotecas com CVE e as que estão em fim de vida. Priorizar CRITICAL/HIGH.

## Entrega
Tabela: biblioteca, versão, CVE, gravidade, versão que corrige, risco de atualizar. As atualizações são testadas (Afonso + equipa de testes) antes de produção.
