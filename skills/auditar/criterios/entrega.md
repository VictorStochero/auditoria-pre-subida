# Critérios — Entrega

Vale para toda stack. Mede se a branch entrega **o que foi pedido, sem efeito colateral e com prova de que funciona**. Cada achado cita o item (`entrega § E1`) e diz o que o pedido (issue, pedido original do pacote) afirma e o que o diff faz de diferente. O auditor é só leitura: não abre navegador nem roda teste — confere a **evidência** que o pacote traz (relatório, prints, saída do teste); item que exige prova e não a tem no pacote é achado.

## E1 — Escopo
Percorra o diff arquivo a arquivo e ligue cada trecho a um item pedido (issue, pedido original e critério de pronto do pacote). Trecho sem item é achado: remoção ou mudança sem relação com o pedido (componente, coluna, campo, botão, aba, filtro, rota) volta para fora da branch.
- Como verificar: `git diff --stat` e o `diff.patch`; para cada arquivo, qual item do pedido o justifica; Grep pelo que foi removido (nome da coluna, da rota, do botão) para ver quem ainda o usava.

## E2 — Comportamento preservado em refatoração
Quando o pacote diz que a tarefa é refatoração sem pedido de mudança, o comportamento só muda para corrigir erro ou quando a issue ou o dono pedem. Unificar telas pode; remover ou bloquear ação já usada não — a tela que fica herda tudo o que cada uma permitia, **inclusive a quem permitia** (perfil, permissão, escopo de dados). Diferença de comportamento sem pedido é achado a restaurar, não "decisão do dono".
- Como verificar: para cada tela/rota/ação removida ou fundida, liste o que ela permitia e a quem (Policy, permissão, filtro) e confira que a que ficou permite o mesmo; compare consulta, validação, efeito colateral (e-mail, evento, log) antes × depois.

## E3 — Sintaxe e estática
Linter/`php -l`, formatador, análise estática, rotas, compilação de views e listagem da suíte. A etapa 2 da skill (Validação da stack) já roda isso nos arquivos tocados; este critério só aponta o que ela **não cobriu**: view tocada que não compila, rota que não lista, teste novo que a suíte não descobre, arquivo de tipo que a etapa 2 não alcança.
- Como verificar: confira a saída da etapa 2 no pacote contra os tipos de arquivo do diff (Blade/Jinja/JSX, rotas, config, testes); lacuna é achado.

## E4 — Navegador
Toda tela tocada foi validada com **perfil real (nunca administrador)**, comparada com a mesma tela na base (mesmo banco, código antes × depois) e **exercitando a ação** (gravar, não só ver o botão). Tela que não monta no ambiente local não justifica pular: monta-se o dado. O auditor não abre navegador: confere a evidência no pacote (relatório e prints da sessão principal).
- Como verificar: liste as telas tocadas (view, componente, página, rota que renderiza) e procure a evidência de cada uma — perfil usado, antes × depois, ação exercitada. Tela tocada sem evidência, evidência só com administrador ou só olhando a tela sem a ação é achado.

## E5 — Integração externa testada de verdade
Mudança em integração externa (e-mail, pagamento, API de terceiro, webhook) só sobe com teste local de **todo o fluxo** com credenciais reais — fora do `.env` versionado; e-mail só para endereços do dono. `Http::fake`/mock não basta: prova o código, não a integração.
- Como verificar: Grep no diff por client HTTP, Mail/Notification, SDK, webhook e config de serviço; procure no pacote a evidência do teste real (o que foi chamado, resposta obtida). Sem evidência é achado.
