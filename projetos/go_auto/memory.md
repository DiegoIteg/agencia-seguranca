# Memória — Auditoria Go Auto

- 2026-10-11 | Correção | Achado estrutural de isolamento SaaS corrigido (hotfix 26): o cálculo de preços usava ids fixos por filial (GrupoVendas::PRODUTOS/SERVICOS/HORAS, SetorEmpresa::COMERCIAL). Substituído por resolvedor por empresa+filial (ModeloNegocioService::linhaId/tipoDaLinha/setorComercialId), com escopo create_unit+tenant_id explícito. Prova de isolamento: log26/test_isolamento.php (3 empresas, 15 testes). | ModeloNegocioService.php
