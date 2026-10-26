# Critérios — Segurança

Vale para toda stack. Cada achado cita o item (`seguranca § S3`) e traz o **caminho concreto de exploração**: quem (perfil real, nunca administrador), por qual chamada (rota, método público, endpoint, evento), com que entrada, e o que obtém. Sem caminho que feche, não é P0. Os sinais por stack são onde procurar, não a lista inteira.

## S1 — Autorização no servidor em toda entrada que grava ou lê dado restrito
Toda rota, controller, endpoint de API, método público de componente, ação de formulário/tabela e job disparado pelo usuário pergunta à regra de permissão do projeto (Policy, Gate, permission class, middleware) **no servidor**. Esconder botão, desabilitar campo ou filtrar menu não protege.
- Laravel: `authorize()`/`Gate`/`can` no controller ou Form Request; Livewire: **todo método público** é chamável pelo console (`$wire.call('metodo')`), inclusive os que a tela não mostra; Filament: `->action()`, `->visible()` não substitui `->authorize()`, páginas custom sem `canAccess()`.
- Python: views sem `@login_required`/`permission_classes`/`Depends(...)`; `IsAuthenticated` onde precisava de permissão por objeto.
- JS/Node: rota sem middleware de auth; Server Action/API Route do Next sem checar sessão e dono do recurso; checagem só no cliente.

## S2 — Objeto do outro (IDOR) e estado vindo do cliente
Id, caminho, tipo ou dono que vem do cliente (URL, query string, corpo, propriedade pública de componente, campo oculto, evento) é fixado pelo servidor ou rechecado contra a permissão **a cada request que muda estado**, não só ao abrir a tela. Troque o id mentalmente pelo de outro usuário/cliente/tenant e siga o código.
- Livewire: propriedade pública sem `#[Locked]` que define o registro, a pasta ou o dono; `mount()` autoriza mas `render()`/ação não reconfere.
- Multi-tenant: consulta sem o escopo do tenant; `find($id)` onde devia ser `$tenant->relacao()->find($id)`.
- Python/JS: `get(pk=request.data['id'])` sem filtrar por dono; `findById(req.params.id)` sem `userId`.

## S3 — Listas, contadores, exports e relatórios cortam pelo mesmo predicado
O que a tela de detalhe esconde não aparece em lista, busca, contador, autocomplete, export (CSV/Excel/PDF), relatório, notificação ou API. Mesma regra, não cópia dela.

## S4 — Injeção
- SQL: interpolação ou concatenação em `whereRaw`/`DB::raw`/`selectRaw`/`orderByRaw`, `cursor.execute(f"...")`, `raw()`/`extra()` do Django, template string em query do Node. Nome de coluna/ordenação vindo do cliente sem lista permitida.
- Comando: `exec`/`shell_exec`/`proc_open`/`subprocess(..., shell=True)`/`child_process.exec` com entrada do usuário.
- Caminho: arquivo montado com entrada (`../`), `Storage::path($input)`, `open(user_path)`.
- Desserialização: `unserialize`, `pickle.loads`, `yaml.load` sem `SafeLoader`, `eval`/`new Function` em dado externo.
- Template/LDAP/NoSQL: operador `$where`/`$regex` vindo do corpo; template montado com entrada.

## S5 — XSS e saída sem escape
Saída crua com dado que o usuário controla: Blade `{!! !!}`, `->html()`/`HtmlString`, `v-html`, `dangerouslySetInnerHTML`, `|safe`/`mark_safe`, `innerHTML`. Sanitização caseira por regex não vale: use o sanitizador da plataforma (ex.: `symfony/html-sanitizer`, DOMPurify, bleach). Atributo `href`/`src` com `javascript:`.

## S6 — Atribuição em massa e validação na fronteira
- Laravel: model sem `$fillable`/`$guarded`, `$request->all()` em `create`/`update`/`fill` (use `validated()`).
- Django/DRF: serializer com `fields = '__all__'` em escrita; FastAPI/Pydantic aceitando campo de privilégio.
- Node: `Model.create(req.body)`, spread do corpo em update.
- Toda entrada externa é validada no servidor (tipo, faixa, tamanho, formato) antes de usar.

## S7 — Upload e arquivos
Valida tipo pelo conteúdo (MIME) e extensão, limita tamanho, gera o nome no servidor, grava fora da raiz pública ou com acesso controlado, e o download confere permissão. Caminho/nome do arquivo vindo do cliente não decide onde grava (sobrescrita, IDOR em bucket/R2/S3). SVG e HTML enviados não são servidos inline.

## S8 — Segredos e dados sensíveis
- Segredo, token, senha ou chave no código, no teste, no seed, no front-end ou em log; `.env` versionado; `env()` fora de `config/` (Laravel).
- Dado pessoal ou sensível em log, mensagem de erro, URL ou resposta de API além do necessário; stack trace/debug ligado em produção (`APP_DEBUG`, `DEBUG=True`).
- Campo sensível no banco sem criptografia quando o projeto exige (`encrypted` cast, campo cifrado).

## S9 — Sessão, autenticação e CSRF
CSRF desligado ou rota POST fora da proteção sem motivo (webhook assinado é exceção, e a assinatura é conferida); rota de login/reset/OTP sem limite de tentativas (`throttle`, rate limit); token previsível (`rand`, `Math.random`, `uniqid` em vez de gerador criptográfico); comparação de segredo sem tempo constante (`hash_equals`, `hmac.compare_digest`, `timingSafeEqual`); link assinado sem expiração.

## S10 — Requisições para fora e redirecionamento
SSRF: URL vinda do usuário chamada pelo servidor sem lista permitida; redirect aberto (`redirect($request->input('next'))`); chamada HTTP externa sem timeout; webhook recebido sem validar assinatura.

## S11 — Dependências e configuração
Dependência nova sem necessidade (ver `ponytail § P6`) ou com vulnerabilidade conhecida (`composer audit`, `pip-audit`, `npm audit` quando disponíveis); CORS aberto (`*` com credenciais); cabeçalhos de segurança removidos; permissão de arquivo/bucket público por engano.

## S12 — Integridade de dado
Escrita de dado de negócio sem transação; corrida de "checa e grava" (dois requests ao mesmo tempo); exclusão em cascata que apaga dado de outro dono; migration que destrói dado sem cópia; erro engolido (`catch` vazio) que esconde falha de gravação.
