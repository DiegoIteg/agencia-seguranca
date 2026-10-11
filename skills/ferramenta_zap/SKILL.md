---
name: "ferramenta_zap"
description: "Teste dinâmico de segurança (DAST) de sites e APIs com OWASP ZAP — o scanner web livre mais usado. Usar SÓ em alvos autorizados do Diego, em ambiente de testes."
---
# OWASP ZAP (DAST) — Nádia

**O que é:** o scanner de segurança de aplicações web livre mais usado. Percorre o site e testa injeção, XSS, cabeçalhos, cookies, configuração.

## ATENÇÃO (âmbito)
ZAP **ataca** a aplicação. Só se corre contra **alvos autorizados do Diego**, em **ambiente de testes/staging**, nunca em produção com dados reais nem contra terceiros. Confirmar `projetos/<projeto>/autorizacao.md` antes.

## Instalar / correr (via Docker, mais simples)
```bash
# Baseline (passivo + testes leves) — bom primeiro passo, pouco intrusivo
docker run --rm -v $(pwd):/zap/wrk ghcr.io/zaproxy/zaproxy:stable \
  zap-baseline.py -t https://staging.exemplo-do-diego.pt -r zap_baseline.html

# Full scan (ativo, intrusivo) — só com autorização e em staging
docker run --rm -v $(pwd):/zap/wrk ghcr.io/zaproxy/zaproxy:stable \
  zap-full-scan.py -t https://staging.exemplo-do-diego.pt -r zap_full.html
```
Para API: `zap-api-scan.py -t openapi.json -f openapi`.

## Com login
A sessão é iniciada pelo Diego; passar o contexto/autenticação ao ZAP (ou usar o modo com o navegador controlado). Nunca gravar as credenciais.

## Entrega
Alertas do ZAP (Alto/Médio/Baixo) → confirmar à mão os importantes → `achados.md` com risco de negócio.
