# Memória — Paulo (Revisor de Código (Análise Estática / SAST))

> Formato: `- AAAA-MM-DD | Tipo | Descrição | Projeto/Ficheiros`.

- 2026-10-11 | Aprendizagem | Agente criado. Âmbito defensivo: só projetos do Diego, com autorização; nunca contra terceiros; nada se altera sem o "sim" | `CLAUDE.md`
- 2026-10-17 | Aprendizagem | Ao investigar dados desaparecidos, rever também scripts SQL de limpeza/migração fora do código (dbwork/*.sql): o incidente grupo_pessoa veio de um DELETE por tenant com FOREIGN_KEY_CHECKS=0, não da aplicação. Testar o caminho do ecrã numa cópia SQLite com TConnection::setConfigPath. | go_auto/achados.md (R5)
- 2026-10-20 | Aprendizagem | Contagens de limite têm de usar exatamente a mesma regra do login (ex.: UPPER(active) <> 'N'), senão um valor «estranho» enviado à mão contorna o limite. Verificações de BD no construtor de um TPage correm sem transação. Em InnoDB, para contar «vagas» sem corrida: bloqueio como 1.ª instrução da transação (a leitura consistente só começa depois). | go_auto v40
