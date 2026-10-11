# Segurança e acessos

* **Login sempre pelo Diego.** A equipa nunca introduz credenciais. Para testar com sessão iniciada, o Diego inicia a sessão.
* **Segredos nunca na conversa nem em ficheiros.** Se a equipa encontrar uma palavra-passe, chave ou token no código, **não o copia**: refere o sítio ("ficheiro X, linha Y, uma chave de API exposta") e recomenda rodá-la.
* **Go Auto:** acesso ao Webmin/Virtualmin e à base de dados pelo navegador, login do Diego; alterações só em ambiente de testes; a instalação de correções é feita pelo Diego (SQL + zip pelo Webmin).
* **Dados reais** de clientes são anonimizados antes de sair do servidor (RGPD).
* **Ambiente de testes** para tudo o que é intrusivo. Produção só para leitura e verificação não-intrusiva.
