# Processo de trabalho — Agência de Segurança

1. **Âmbito e autorização** (Vítor): confirmar que o alvo é do Diego, registar a autorização e o ambiente (sempre cópia/testes). Sem isto, não se começa.
2. **Reconhecimento defensivo:** mapa da aplicação e das superfícies de entrada (páginas, formulários, APIs, uploads, parâmetros, login). Nada que toque em terceiros.
3. **Análise em paralelo** pelos especialistas, cada achado registado com prova contida e reprodutível no ambiente do Diego.
4. **Classificação do risco** (Crítico/Alto/Médio/Baixo) em linguagem de negócio.
5. **Plano de correção** → Diego valida.
6. **Correção + reteste** → entrega → memória.

**Regra de ouro do processo:** encontrar é livre dentro do âmbito; **mudar qualquer coisa exige o "sim" do Diego e forma de voltar atrás**.
