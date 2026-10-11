---
name: "ferramenta_gitleaks"
description: "Procura de segredos (chaves, senhas, tokens) no código e no histórico do Git com Gitleaks e TruffleHog. Usar para encontrar credenciais expostas antes que alguém as apanhe."
---
# Gitleaks + TruffleHog (segredos) — Gonçalo

**O que é:** as duas ferramentas mais usadas para caçar segredos no código e no **histórico** do Git.

## Instalar
```bash
# Gitleaks (Go)
brew install gitleaks   # ou baixar o binário de github.com/gitleaks/gitleaks/releases
# TruffleHog (verifica se o segredo ainda é válido)
pipx install trufflehog # ou binário de github.com/trufflesecurity/trufflehog
```

## Usar
```bash
# varrer a árvore atual e TODO o histórico de commits
gitleaks detect --source . --report-path gitleaks.json --redact
# TruffleHog: além de encontrar, tenta validar se a credencial está viva
trufflehog git file://. --only-verified
```
- `--redact` **não imprime o valor** do segredo (importante: nunca copiar segredos).
- O histórico conta: um segredo apagado num commit antigo continua exposto.

## Depois de encontrar
1. **Nunca copiar o valor** — referir ficheiro:linha/commit.
2. Recomendar ao Diego: **rodar** o segredo (criar novo, invalidar o antigo) e mover para variável de ambiente/configuração fora do controlo de versões.
3. Se já esteve num repositório público, considerar o segredo comprometido.

## Regra de ouro
Só em repositórios do Diego. O relatório vai **redigido** (sem valores).
