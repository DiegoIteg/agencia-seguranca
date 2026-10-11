---
name: "segredos_e_rgpd"
description: "Como encontrar segredos no código, avaliar encriptação, retenção e consentimento, e cumprir o RGPD, sem extrair dados reais."
---
# Segredos E Rgpd

## Segredos
- Procurar chaves/senhas/tokens no código e na configuração (com o Paulo). **Não copiar o valor.**
- Recomendar: rodar o segredo, mover para variável de ambiente/configuração fora do código e fora do controlo de versões.

## RGPD / dados
- Minimização: só o necessário.
- Palavras-passe com hash forte; dados sensíveis cifrados; TLS no transporte.
- Retenção e apagamento a pedido do titular.
- Consentimento (cookies), política de privacidade, base legal, registo de tratamentos.
- Qualquer dado real sai do servidor já anonimizado.
