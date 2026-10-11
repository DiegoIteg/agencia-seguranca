---
name: "dependencias"
description: "Como inventariar bibliotecas (composer, npm) e encontrar versões com falhas conhecidas (CVE) ou em fim de vida."
---
# Dependencias

## Passos
1. Inventário: `composer.lock`/`composer.json`, `package-lock.json`/`package.json`, versões de PHP/servidor/base de dados.
2. Falhas conhecidas: `composer audit`, `npm audit`, bases públicas de CVE.
3. Fim de vida: versões sem suporte de segurança.
4. Priorizar: o que atualizar primeiro e o risco de partir algo.

## Aplicar
Atualizações testadas (Afonso + equipa de testes) antes de produção.
