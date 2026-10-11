---
name: "ferramenta_nuclei"
description: "Verificação rápida por modelos (templates) com Nuclei: milhares de testes de vulnerabilidades e más configurações conhecidas. Usar só em ativos autorizados do Diego."
---
# Nuclei (verificação por templates) — Nádia / Íris

**O que é:** o motor de templates da ProjectDiscovery, muito usado para procurar vulnerabilidades e más configurações **conhecidas** depressa, com uma enorme biblioteca comunitária.

## ATENÇÃO (âmbito)
Só contra **domínios/servidores do Diego**, autorizados, de preferência em staging. Nunca terceiros.

## Instalar
```bash
go install -v github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest  # ou binário
nuclei -update-templates
```

## Usar
```bash
# exposições e más configurações (menos intrusivo)
nuclei -u https://staging.exemplo-do-diego.pt -tags exposure,misconfig,ssl -severity medium,high,critical -o nuclei.txt

# CVEs conhecidos nas tecnologias detetadas
nuclei -u https://staging.exemplo-do-diego.pt -tags cve -severity high,critical
```

## Entrega
Cada achado confirmado em `achados.md`. Usar para apanhar o "fruto baixo" (painéis expostos, versões vulneráveis, TLS fraco) — complementa o ZAP e o Trivy.
