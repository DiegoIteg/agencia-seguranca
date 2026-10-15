# Memória — Agência de Segurança

> Decisões gerais, gostos do Diego e aprendizagens transversais. Formato: `- AAAA-MM-DD | Tipo | Descrição | Projeto/Ficheiros`.

- 2026-10-11 | Decisão | Agência de Segurança criada: equipa defensiva de 7 agentes que audita e corrige os projetos do Diego (Go Auto, Agência Digital, clientes da iTEG). Só projetos do Diego, com autorização; nunca contra terceiros | `CLAUDE.md`
- 2026-10-11 | Decisão | Correções entregam-se no formato do projeto. No Go Auto: SQL idempotente + zip + LEIA-ME (ONDE e COMO) + reverter + testes, instalação pelo Diego no Webmin | `go_auto/CLAUDE.md`
- 2026-10-11 | Preferência | Diego não é programador: cada achado é explicado em risco de negócio e com linguagem simples, não só técnica | geral
- 2026-10-11 | Aprendizagem | Skills de ferramentas de topo adicionadas: Semgrep (SAST), Gitleaks/TruffleHog (segredos), Trivy+OSV (CVE), OWASP ZAP (DAST), Nuclei, testssl.sh+cabeçalhos, PHPStan/Psalm (PHP taint). Todas defensivas, só alvos autorizados, em ambiente de testes | `skills/`
- 2026-10-12 | Decisão | Primeira auditoria completa ao Go Auto concluída; parecer+plano de correção em 4 fases entregues ao Diego para validar. | projetos/go_auto/
- 2026-10-15 | Decisão | Criada diretriz + ferramenta de verificação pós-deploy do Go Auto: ferramentas/verificacao_goauto.sh (read-only) + rotina/verificacao_producao_goauto.md. Verifica exposição web (backups, app/config, bases SQLite, install.php, .git), cabeçalhos de segurança (A+), hardening (debug/display_errors/expose_php/permissões/.htaccess) e saúde (HTTP 200, PHP+extensões, tabelas de log, espaço). Dá veredicto classificado. Correr após cada deploy e em auditoria periódica. | ferramentas/verificacao_goauto.sh
- 2026-10-15 | Achado | Deploy de produção do Go Auto trouxe ficheiros de dev para a raiz da web (backups .tgz/.tar.gz/.zip, LEIA-ME*, COLAR*.css) — potencial descarga pública de código/dados. A confirmar pela verificação e a mover para fora da web (com "sim" do Diego). | projetos/go_auto
