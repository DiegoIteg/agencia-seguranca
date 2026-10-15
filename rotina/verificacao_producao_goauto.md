# Diretriz — Verificação de Segurança e Saúde (Go Auto em produção)

> Equipa: Vítor (coordena), Nádia (web/exposição), Íris (servidor/cabeçalhos), Paulo (config).
> Natureza: **defensiva e de leitura**. Encontrar é livre; **corrigir só com o "sim" do Diego e com rollback**.

## Quando usar
- Depois de **qualquer deploy** do Go Auto (código novo, migração, hotfix).
- Em **auditoria periódica** (recomendado: mensal) do ambiente de produção.
- Sempre que o Diego pedir "está seguro e a funcionar?".

## Ferramenta
`ferramentas/verificacao_goauto.sh` — script único, **não altera nada**. Corre no servidor, como utilizador do site.

```
# no Terminal do servidor (Virtualmin → Terminal):
DOM=goauto.iteg4business.com ROOT=/home/goauto/public_html bash verificacao_goauto.sh
```

## O que verifica (e porquê, em risco de negócio)
1. **Ficheiros sensíveis na raiz da web** — backups (`.sql/.tgz/.zip`), notas de dev, `.db`, `.git`.
   *Risco:* qualquer pessoa descarrega o teu código/dados pelo browser.
2. **Acesso web ao que não deve abrir** — `app/config/application.ini` (segredos: BD, Stripe, chaves), `log.php`, bases SQLite, `install.php`.
   *Risco:* fuga de segredos = acesso total.
3. **Cabeçalhos de segurança HTTPS** (HSTS, X-Frame-Options, CSP, etc.) — objetivo **A+**.
   *Risco:* clickjacking, downgrade de ligação, injeção.
4. **Hardening** — `debug` desligado, `display_errors`/`expose_php` off, ficheiros graváveis por todos, `.htaccess`.
   *Risco:* mostrar erros/caminhos a atacantes.
5. **Saúde/funcionamento** — site responde 200, PHP + extensões, tabelas de log SQLite, pastas graváveis, espaço em disco, sobras do deploy.

## Classificação (igual ao resto da Agência)
`Crítico` (corrigir hoje) · `Alto` (esta semana) · `Médio` (próximo ciclo) · `Baixo` (melhoria).
O script dá no fim um **veredicto**: NÃO EXPOR / corrigir ALTOS / seguro.

## Depois de correr
1. Ler o output com o Diego, em linguagem de gestão.
2. Registar achados em `projetos/go_auto/achados.md`.
3. Plano de correção (Vítor) → **Diego valida** → Afonso corrige com rollback → reteste.
4. Memória.
