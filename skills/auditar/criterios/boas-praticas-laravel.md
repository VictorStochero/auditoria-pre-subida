# Critérios — Boas práticas Laravel (PHP, Eloquent, Livewire, Filament, Pest)

Resumo do `laravel-best-practices` do Laravel Boost (MIT, laravel) com o que mais voltou em revisão. Se a skill `laravel-best-practices` estiver instalada no projeto, invoque e leia as `rules/` dos assuntos do diff; ela detalha estes itens. **Consistência primeiro**: o que o projeto já faz (e o guia de arquitetura dele) vence estes padrões; só aponte quando o diff cria um segundo jeito ou não há padrão.

## L1 — Banco e consultas
Eager loading (`with`) contra N+1, `withCount` para contar, só as colunas necessárias, `chunkById`/`lazyById`/`cursor` para lote grande, índice para coluna nova em `WHERE`/`ORDER BY`/`JOIN`, nenhuma query em Blade, `whereIn`+`pluck` em vez de `whereHas` pesado, nome de tabela pelo Model (`(new X)->getTable()`), nunca string solta em SQL cru.

## L2 — Segurança (complementa `seguranca.md`)
`$fillable`/`$guarded` em todo model; Policy/Gate em toda ação; `{{ }}` para saída; `@csrf`; `throttle` em auth e API; upload com MIME, extensão e tamanho; `.env` fora do git; `config()` para segredo; cast `encrypted` para dado sensível.

## L3 — Validação
Form Request em vez de validação inline (ou o padrão do projeto); `$request->validated()`, nunca `all()`; `Rule::when()` para condicional; Livewire: `#[Validate]`/`validate()` antes de gravar.

## L4 — Escrita, transação e concorrência
Regra de negócio numa Action/classe de domínio de propósito único (ou a camada que o guia define), não no controller, componente, Observer ou Command. Transição de estado: `DB::transaction(fn, 3)`, relê o registro com `lockForUpdate()` e decide sobre o registro travado, nunca sobre o objeto da tela. Efeito externo depois do commit (`afterCommit`, `ShouldDispatchAfterCommit`). Autor por parâmetro, não `Auth::user()` dentro da regra (Job e Command não têm sessão). Injeção de dependência em vez de `app()`.

## L5 — Eloquent
Relação com tipo de retorno e generics (`@return BelongsTo<User, $this>`); casts no `casts()`; datas como Carbon; escopo local para filtro reaproveitado; escopo global com parcimônia e documentado; `whereBelongsTo`.

## L6 — Migrations
Criada por `make:migration`; `constrained()` em FK; índice na própria migration; **uma preocupação por migration — nunca DDL e dado juntos**; retomável (guarda `hasTable`/`hasColumn`); não importa classe da aplicação (o Model muda, a migration fica); `down()` reversível ou correção para frente explícita; nunca editar migration que já rodou em produção.

## L7 — Filas, agenda e HTTP
Job com `failed()`, `retry_after` maior que `timeout`, backoff, `ShouldBeUnique` quando duplicar faz mal; agendamento com `withoutOverlapping()`/`onOneServer()`; HTTP externo com `timeout`/`connectTimeout`, `retry()` e `throw()`; `Http::fake()` + `preventStrayRequests()` nos testes.

## L8 — Configuração e erros
`env()` só em `config/`; `app()->isProduction()`; texto em lang/config; exceção com `report()`/`render()` no padrão do projeto; sem `catch` vazio.

## L9 — Livewire e Filament
Livewire: todo método público é entrada (ver `seguranca § S1`); `#[Locked]` em id/estado que o servidor decide; propriedade pública não carrega model inteiro sem necessidade; `wire:model.live` só onde precisa. Filament v4: `->authorize()`/Policy do Resource em ação e página; página custom com `canAccess()`; componente nativo do Filament em vez de HTML à mão; namespaces da v4 (`Filament\Schemas`, `Filament\Actions`).

## L10 — Blade e front
Componentes Blade em vez de `@include` solto; `$attributes->merge()`; sem JS/CSS inline na Blade, sem HTML em classe PHP; sem query nem regra na view.

## L11 — Testes (Pest/PHPUnit)
Factory e seus estados em vez de arranjo à mão; `LazilyRefreshDatabase`; fakes depois do arranjo; `assertModelExists`; teste de autorização com perfil real e os dois lados (pode e não pode), nunca super admin; correção de bug com teste que falhava antes; nada de apagar teste sem decisão.

## L12 — Tipagem e estilo
Tipos de parâmetro e retorno explícitos, constructor property promotion, chaves em todo `if`, PHPDoc com array shape; PHPStan/Larastan sem ignore novo, sem entrada nova no baseline, sem `mixed`/cast só para calar; Pint limpo; helpers do Laravel (`Str`, `Arr`, `Number`) em vez de função crua quando o projeto usa.
