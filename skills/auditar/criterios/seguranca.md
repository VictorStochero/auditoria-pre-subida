# Critérios — Segurança

Vale para toda stack. Projeto com Filament e a skill `filament-security-audit` instalada (`.ai/skills/` ou `.claude/skills/`): leia-a inteira e aplique ao diff, somada a estes itens. Cada achado cita o item (`seguranca § S3`) e traz o **caminho concreto de exploração**: quem (perfil real, nunca administrador), por qual chamada (rota, método público, endpoint, evento), com que entrada, e o que obtém. Sem caminho que feche, não é P0 nem P1. Os sinais por stack são onde procurar, não a lista inteira.

- Os itens seguem o OWASP Top 10:2025 (<https://owasp.org/Top10/2025/>); o código entre parênteses no título é a categoria. O S16 segue o OWASP Top 10 for LLM Applications 2025 (`LLM01`…).
- **Pista não é achado**: padrão perigoso (`DB::raw`, `eval`…) ou saída de scanner só vira achado quando o caminho fecha, seta a seta, em `arquivo:linha`.
- **Defesa em profundidade**: se uma camada do caminho já barra o ataque (middleware, Policy, escopo global, validação, Form Request), a falta de outra camada é reforço — **P3 com "Decisão do dono: sim"**, citando a camada que barra; nunca P0–P2.

## S1 — Autorização no servidor em toda entrada que grava ou lê dado restrito (A01:2025)
Toda rota, controller, endpoint de API, método público de componente, ação de formulário/tabela e job disparado pelo usuário pergunta à regra de permissão do projeto (Policy, Gate, permission class, middleware) **no servidor**. Esconder botão, desabilitar campo ou filtrar menu não protege.
- Laravel: `authorize()`/`Gate`/`can` no controller ou Form Request; Livewire: **todo método público** é chamável pelo console (`$wire.call('metodo')`), inclusive os que a tela não mostra; Filament: `->action()`, `->visible()` não substitui `->authorize()`, páginas custom sem `canAccess()`.
- Python: views sem `@login_required`/`permission_classes`/`Depends(...)`; `IsAuthenticated` onde precisava de permissão por objeto.
- JS/Node: rota sem middleware de auth; Server Action/API Route do Next sem checar sessão e dono do recurso; checagem só no cliente.

## S2 — Objeto do outro (IDOR) e estado vindo do cliente (A01:2025)
Id, caminho, tipo ou dono que vem do cliente (URL, query string, corpo, propriedade pública de componente, campo oculto, evento) é fixado pelo servidor ou rechecado contra a permissão **a cada request que muda estado**, não só ao abrir a tela. Troque o id mentalmente pelo de outro usuário/cliente/tenant e siga o código.
- Livewire: propriedade pública sem `#[Locked]` que define o registro, a pasta ou o dono; `mount()` autoriza mas `render()`/ação não reconfere.
- Multi-tenant: consulta sem o escopo do tenant; `find($id)` onde devia ser `$tenant->relacao()->find($id)`.
- Python/JS: `get(pk=request.data['id'])` sem filtrar por dono; `findById(req.params.id)` sem `userId`.

## S3 — Listas, contadores, exports e relatórios cortam pelo mesmo predicado (A01:2025)
O que a tela de detalhe esconde não aparece em lista, busca, contador, autocomplete, export (CSV/Excel/PDF), relatório, notificação ou API. Mesma regra, não cópia dela.

## S4 — Injeção (A05:2025; desserialização A08:2025; XXE A02:2025)
- SQL: interpolação ou concatenação em `whereRaw`/`DB::raw`/`selectRaw`/`orderByRaw`, `cursor.execute(f"...")`, `raw()`/`extra()` do Django, template string em query do Node. Nome de coluna/ordenação vindo do cliente sem lista permitida.
- Comando: `exec`/`shell_exec`/`proc_open`/`subprocess(..., shell=True)`/`child_process.exec` com entrada do usuário.
- Caminho: arquivo montado com entrada (`../`), `Storage::path($input)`, `open(user_path)`.
- Desserialização: `unserialize`, `pickle.loads`, `yaml.load` sem `SafeLoader`, `eval`/`new Function` em dado externo.
- Template/LDAP/NoSQL: operador `$where`/`$regex` vindo do corpo; template montado com entrada.
- XXE: parser XML com entidades externas habilitadas — `LIBXML_NOENT` (PHP), `libxml_disable_entity_loader` ausente em PHP antigo, `lxml` sem `resolve_entities=False`, `xml2js`/`libxmljs` com `noent` (CWE-611).

## S5 — XSS e saída sem escape (A05:2025)
Saída crua com dado que o usuário controla: Blade `{!! !!}`, `->html()`/`HtmlString`, `v-html`, `dangerouslySetInnerHTML`, `|safe`/`mark_safe`, `innerHTML`. Sanitização caseira por regex não vale: use o sanitizador da plataforma (ex.: `symfony/html-sanitizer`, DOMPurify, bleach). Atributo `href`/`src` com `javascript:`.

## S6 — Atribuição em massa e validação na fronteira (A08:2025)
- Laravel: model sem `$fillable`/`$guarded`, `$request->all()` em `create`/`update`/`fill` (use `validated()`).
- Django/DRF: serializer com `fields = '__all__'` em escrita; FastAPI/Pydantic aceitando campo de privilégio.
- Node: `Model.create(req.body)`, spread do corpo em update.
- Toda entrada externa é validada no servidor (tipo, faixa, tamanho, formato) antes de usar.

## S7 — Upload e arquivos (A06:2025)
Valida tipo pelo conteúdo (MIME) e extensão, limita tamanho, gera o nome no servidor, grava fora da raiz pública ou com acesso controlado, e o download confere permissão. Caminho/nome do arquivo vindo do cliente não decide onde grava (sobrescrita, IDOR em bucket/R2/S3). SVG e HTML enviados não são servidos inline.

## S8 — Segredos e dados sensíveis (A02, A04, A07, A09:2025)
- Segredo, token, senha ou chave no código, no teste, no seed, no front-end ou em log; `.env` versionado; `env()` fora de `config/` (Laravel).
- Dado pessoal ou sensível em log, mensagem de erro, URL ou resposta de API além do necessário; stack trace/debug ligado em produção (`APP_DEBUG`, `DEBUG=True`).
- Campo sensível no banco sem criptografia quando o projeto exige (`encrypted` cast, campo cifrado).

## S9 — Sessão, autenticação e CSRF (A07, A01:2025)
CSRF desligado ou rota POST fora da proteção sem motivo (webhook assinado é exceção, e a assinatura é conferida); rota de login/reset/OTP sem limite de tentativas (`throttle`, rate limit); token previsível (`rand`, `Math.random`, `uniqid` em vez de gerador criptográfico); comparação de segredo sem tempo constante (`hash_equals`, `hmac.compare_digest`, `timingSafeEqual`); link assinado sem expiração.
- Sessão não regenerada no login (fixação, CWE-384: Laravel `session()->regenerate()`, Django `cycle_key`); sessão e tokens não invalidados no logout, na troca de senha ou na remoção de acesso; id de sessão ou token em URL.
- MFA que dá para pular pelo fluxo (rota pós-login acessível antes do segundo fator); credencial padrão ou fixa no código (CWE-798).

## S10 — Requisições para fora e redirecionamento (A01:2025)
SSRF: URL vinda do usuário chamada pelo servidor sem lista permitida; redirect aberto (`redirect($request->input('next'))`); chamada HTTP externa sem timeout; webhook recebido sem validar assinatura.

## S11 — Dependências e configuração (A03, A02:2025)
Dependência nova sem necessidade (ver `ponytail § P6`) ou com vulnerabilidade conhecida (`composer audit`, `pip-audit`, `npm audit` quando disponíveis); CORS aberto (`*` com credenciais); cabeçalhos de segurança removidos; permissão de arquivo/bucket público por engano.
- Cookie de sessão sem `Secure`/`HttpOnly`/`SameSite` (CWE-614/1004); conta padrão, rota de exemplo ou listagem de diretório ativas.
- Cadeia de suprimentos: GitHub Actions/CI referenciando ação por tag em vez de SHA completo; script de instalação novo vindo de dependência (`postinstall`, `scripts` do composer); dependência nova por URL git sem versão fixa; lockfile alterado sem a mudança correspondente no manifesto.

## S12 — Integridade de dado (A10:2025)
Escrita de dado de negócio sem transação; corrida de "checa e grava" (dois requests ao mesmo tempo); exclusão em cascata que apaga dado de outro dono; migration que destrói dado sem cópia; erro engolido (`catch` vazio) que esconde falha de gravação.

## S13 — Lógica de negócio e estado (A06:2025)
- Pular, repetir ou voltar etapa de fluxo: aprovar o já aprovado, pagar duas vezes, replay de callback ou de link de uso único.
- Transição de estado sem conferir o estado atual (`update` por id sem `where status = …`; ação de tela que o servidor aceita em qualquer estado).
- Valor negativo, zero ou no limite em quantidade, preço, desconto, parcela; coerção de tipo (`"0"`, `[]`, `null`, `==` frouxo, string numérica em comparação).
- Fronteira de expiração e fuso: `<` × `<=`, data local × UTC, trial/convite/token que vence à meia-noite.
- Postura insegura quando configuração ou feature flag falta: `config('x')` nulo que libera, `env` ausente que desliga a checagem.

## S14 — Enumeração e oráculos (A07, A01:2025)
- Mensagem, tempo ou tamanho de resposta que revela existência: login, reset de senha, convite, cadastro ("e-mail já cadastrado", 404 × 403, caminho que consulta o banco só quando o usuário existe).
- Busca, filtro ou ordenação sobre campo que o perfil não vê (ordenar por salário e deduzir o valor; filtro por coluna restrita).
- Id sequencial exposto onde a contagem ou a adivinhação importa (pedidos, clientes, faturas).

## S15 — Uso posterior, lote e restauração (A01, A05:2025)
- Dado salvo com segurança e usado depois cru em outro contexto: nome que vira caminho de arquivo, campo que vira SQL, HTML, comando ou cabeçalho em job, export, e-mail ou PDF.
- Restaurar, desfazer exclusão (`restore`, lixeira), importar ou duplicar sem reaplicar dono, tenant e permissão atuais; registro restaurado volta para o tenant errado.
- Lote, import e export sem permissão por item: a ação em massa checa uma vez e age em ids vindos do cliente.
- Caminho alternativo para a mesma mudança de estado com permissão mais fraca (API × tela, ação em massa × individual, comando × rota).
- Sinais — Laravel: `withTrashed()->find($id)->restore()`, `Model::replicate()`, `Excel::import`, `whereIn('id', $request->ids)` sem escopo; Python: `bulk_update(...)` e `loaddata` com id do cliente; JS: `updateMany({ id: { $in: ids } })`.

## S16 — Superfícies de LLM e MCP (LLM01, LLM02, LLM05, LLM06, LLM07, LLM08, LLM10)
- Ferramenta MCP ou tool de LLM que lê ou grava dado sem a mesma autorização da tela (por usuário **e** por tenant); a ferramenta roda com credencial de serviço e ignora quem pergunta.
- LLM01 — injeção de prompt, direta e indireta: texto de terceiros (formulário público, e-mail, documento, página web) que chega ao modelo como instrução e aciona ferramenta que grava ou envia para fora.
- LLM02 — vazamento de dado sensível pelo modelo: segredo ou dado de outro tenant no contexto (prompt de sistema, RAG sem filtro de tenant, histórico compartilhado) que a resposta pode revelar.
- LLM05 — saída do modelo usada crua em HTML, SQL, comando, caminho ou URL (trate-a como entrada do cliente: S4, S5, S10).
- LLM06 — autonomia excessiva: ferramenta com mais permissão ou alcance do que a tarefa exige; ação que grava, envia ou apaga sem confirmação humana.
- LLM07 — vazamento do prompt de sistema: segredo, regra de autorização ou dado interno colocado no prompt como se ele fosse protegido.
- LLM08 — ingestão para RAG sem controle de acesso por documento (só com sinal concreto no diff).
- LLM10 — consumo sem limite: sem teto de tokens, chamadas ou custo por usuário/tenant (laço de ferramentas, contexto sem teto, rate limit ausente).

## S17 — Criptografia (A04:2025)
- Hash de senha rápido ou sem salt (md5/sha1/sha256 puro) em vez de bcrypt/argon2: Laravel `Hash`, Django `make_password`, `bcrypt`/`argon2` no Node.
- Verificação de TLS desligada: `Http::withoutVerifying()`, `'verify' => false`, `CURLOPT_SSL_VERIFYPEER => false`, `verify=False` no `requests`, `rejectUnauthorized: false`, `NODE_TLS_REJECT_UNAUTHORIZED=0`.
- Criptografia caseira, modo ECB, IV/nonce fixo ou reutilizado, cifra sem autenticação (use AEAD); chave derivada de senha sem KDF.
- Dado sensível trafegando por `http://`; caminho de erro que cai para "sem criptografia".

## S18 — Log e alerta de segurança (A09:2025)
- Evento de segurança sem registro — falha de login, acesso negado, troca de senha, permissão ou papel, export ou download em massa, ação administrativa — quando o projeto tem trilha de auditoria ou log de segurança (siga o padrão dele; sem padrão, P3).
- Entrada do usuário gravada no log sem neutralizar quebra de linha (injeção em log, CWE-117).
- Segredo ou dado pessoal no log é S8: referencie, não duplique.

## S19 — Falha aberta e condições excepcionais (A10:2025)
- Exceção, timeout ou serviço fora do ar na checagem de permissão, assinatura ou limite que **libera** em vez de negar: `catch` que devolve `true`, `?? true`, `rescue(fn, true)`, fallback permissivo.
- Retorno de função de segurança não conferido (CWE-252).
- Recurso (lock, arquivo, conexão, transação) não liberado no caminho de erro.
- Erro detalhado (SQL, caminho, stack) devolvido ao usuário; stack trace em produção é S8: referencie.
