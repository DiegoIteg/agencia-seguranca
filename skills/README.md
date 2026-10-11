# Skills da Agência de Segurança

Métodos reutilizáveis por tipo de auditoria. Cada skill é defensiva e só se aplica a alvos autorizados do Diego, em ambiente de testes.

- `auditoria_web` — vulnerabilidades OWASP numa aplicação ou API.
- `revisao_de_codigo` — padrões perigosos no código.
- `hardening_servidor` — endurecer servidor e alojamento.
- `segredos_e_rgpd` — segredos no código, encriptação e RGPD.
- `dependencias` — bibliotecas com falhas conhecidas.

## Ferramentas de topo (2026-10-11)
- `ferramenta_semgrep` — análise estática de segurança (SAST), o motor mais usado.
- `ferramenta_gitleaks` — segredos no código e no histórico (Gitleaks + TruffleHog).
- `ferramenta_trivy_osv` — dependências com CVE (Trivy + OSV-Scanner + npm/composer audit).
- `ferramenta_zap` — scanner web (DAST) OWASP ZAP, só em alvos autorizados.
- `ferramenta_nuclei` — verificação rápida por templates, só em ativos do Diego.
- `ferramenta_testssl_headers` — TLS/HTTPS e cabeçalhos de segurança.
- `ferramenta_phpstan_psalm` — análise estática de PHP com taint (Go Auto).
