---
name: "hardening_servidor"
description: "Como verificar e endurecer um servidor/alojamento do Diego: TLS, cabeçalhos, permissões, serviços expostos, cópias de segurança."
---
# Hardening Servidor

## Verificar (sobretudo não-intrusivo, login do Diego)
- TLS: certificado válido, renovação, redireccionar HTTP→HTTPS, desligar TLS antigo.
- Cabeçalhos: HSTS, CSP, X-Content-Type-Options, X-Frame-Options; cookies Secure/HttpOnly/SameSite.
- Serviços: portas abertas desnecessárias; Webmin/phpMyAdmin não expostos à internet; versões atualizadas.
- Ficheiros: nada 777; configurações não legíveis; donos corretos.
- Cópias de segurança: existem, testadas, fora do servidor.
- Registos: erros não vão para o ecrã; há registo de acessos.

## Aplicar
Só com o "sim" e com forma de reverter. No Go Auto, instalação pelo Diego.
