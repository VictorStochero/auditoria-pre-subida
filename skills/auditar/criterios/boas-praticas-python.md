# Critérios — Boas práticas Python (Django, DRF, FastAPI, Flask, scripts)

**Consistência primeiro**: o padrão do projeto e o guia de arquitetura dele vencem estes itens; aponte quando o diff cria um segundo jeito. Se houver skill da stack instalada, invoque-a.

## Y1 — Consultas e banco
N+1 (`select_related`/`prefetch_related`, `selectinload`/`joinedload`); `.only()`/colunas necessárias; `iterator()`/`yield_per` em lote grande; índice para filtro novo; `exists()`/`count()` em vez de carregar a lista; nada de query em template ou em laço.

## Y2 — Escrita e concorrência
`transaction.atomic()`/sessão com commit explícito em escrita de negócio; `select_for_update()` em transição de estado, decidindo sobre o registro relido; `F()`/update atômico em contador; efeito externo depois do commit (`transaction.on_commit`); tarefa Celery/RQ idempotente, com `acks_late`/retry e sem depender de estado em memória.

## Y3 — Validação e fronteira
Serializer/Form/Pydantic valida toda entrada; campos de escrita explícitos (nunca `__all__`); tipo estreitado com checagem real, não `cast`/`# type: ignore` para calar.

## Y4 — Onde mora a regra
Regra de negócio na camada que o projeto define (services/domain/use cases), não espalhada em view, serializer, signal ou management command. Signal não decide fluxo nem cria registro relacionado escondido.

## Y5 — Migrations
Uma preocupação por migration; migração de dado separada da de schema, com `RunPython` reversível ou justificado; sem importar model da aplicação (use `apps.get_model`); Alembic com `downgrade`.

## Y6 — Erros, configuração e logs
Sem `except:`/`except Exception: pass`; exceção específica; segredo por variável de ambiente/settings, não no código; `DEBUG` desligado em produção; logging com nível certo, sem dado sensível; `timeout` em toda chamada HTTP (`requests`/`httpx`).

## Y7 — Tipagem e estilo
Type hints em função pública; mypy/pyright sem `ignore` novo; ruff limpo; `pathlib` em vez de concatenação de caminho; f-string fora de SQL; sem mutável como default de parâmetro; `with` para recurso (arquivo, conexão, lock).

## Y8 — Testes
pytest com fixtures/factories (factory_boy, model_bakery) em vez de arranjo à mão; teste de permissão com usuário comum e os dois lados; correção de bug com teste que falhava antes; rede externa mockada (`responses`, `respx`); sem `sleep` para esperar condição.
