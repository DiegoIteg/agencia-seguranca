---
name: "ferramenta_testssl_headers"
description: "Verificação de TLS/HTTPS e cabeçalhos de segurança com testssl.sh e verificadores de cabeçalhos. Usar para endurecer o servidor do Diego."
---
# testssl.sh + cabeçalhos de segurança — Íris

**O que é:** `testssl.sh` é a ferramenta livre mais usada para auditar TLS/HTTPS. Para cabeçalhos, há Mozilla Observatory e verificadores simples.

## TLS/HTTPS
```bash
# baixar e correr (não precisa instalar)
git clone --depth 1 https://github.com/drwetter/testssl.sh
./testssl.sh/testssl.sh --severity LOW -oH testssl.html https://exemplo-do-diego.pt
```
Verifica: versões de TLS (desligar 1.0/1.1), cifras fracas, certificado, HSTS, renegociação, vulnerabilidades (Heartbleed, etc.).

## Cabeçalhos de segurança
```bash
curl -sI https://exemplo-do-diego.pt | grep -iE 'strict-transport|content-security|x-content-type|x-frame|referrer-policy|permissions-policy'
```
Deve ter: `Strict-Transport-Security` (HSTS), `Content-Security-Policy`, `X-Content-Type-Options: nosniff`, `X-Frame-Options`, `Referrer-Policy`. Cookies com `Secure; HttpOnly; SameSite`.
Alternativa com relatório: Mozilla Observatory (observatory.mozilla.org) — colar o domínio do Diego.

## Entrega
Lista do que falta e a configuração a aplicar (no servidor/Virtualmin ou no código). Aplicar só com o "sim" e com forma de reverter.
