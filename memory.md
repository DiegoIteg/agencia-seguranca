# Memória — Agência de Segurança

> Decisões gerais, gostos do Diego e aprendizagens transversais. Formato: `- AAAA-MM-DD | Tipo | Descrição | Projeto/Ficheiros`.

- 2026-10-11 | Decisão | Agência de Segurança criada: equipa defensiva de 7 agentes que audita e corrige os projetos do Diego (Go Auto, Agência Digital, clientes da iTEG). Só projetos do Diego, com autorização; nunca contra terceiros | `CLAUDE.md`
- 2026-10-11 | Decisão | Correções entregam-se no formato do projeto. No Go Auto: SQL idempotente + zip + LEIA-ME (ONDE e COMO) + reverter + testes, instalação pelo Diego no Webmin | `go_auto/CLAUDE.md`
- 2026-10-11 | Preferência | Diego não é programador: cada achado é explicado em risco de negócio e com linguagem simples, não só técnica | geral
- 2026-10-11 | Aprendizagem | Skills de ferramentas de topo adicionadas: Semgrep (SAST), Gitleaks/TruffleHog (segredos), Trivy+OSV (CVE), OWASP ZAP (DAST), Nuclei, testssl.sh+cabeçalhos, PHPStan/Psalm (PHP taint). Todas defensivas, só alvos autorizados, em ambiente de testes | `skills/`
