# Rotina de auditoria de segurança

1. **Âmbito e autorização** (Vítor) → `projetos/<projeto>/autorizacao.md`. Sem isto, parar.
2. **Reconhecimento:** mapa de páginas, APIs, formulários, uploads, parâmetros, login (`ambito.md`).
3. **Análise** em paralelo com `checklist_owasp.md`:
   - Nádia (web/API), Paulo (código), Íris (servidor), Gonçalo (dados/segredos), Clara (dependências).
4. **Triagem:** Vítor classifica cada achado (Crítico/Alto/Médio/Baixo) em risco de negócio.
5. **Plano de correção** priorizado → Docs → **Diego valida**.
6. **Correção** (Afonso) em ambiente de testes → **reteste** → entrega no formato do projeto.
7. **Memórias** e marcação de cada achado como Resolvido / Risco aceite / Pendente.

**Periodicidade sugerida:** auditoria completa por projeto a cada trimestre; teste de fumo de segurança depois de cada alteração grande; verificação de dependências mensal.
