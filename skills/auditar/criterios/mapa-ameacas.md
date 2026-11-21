# Mapa de ameaças do projeto

Descreve **como este projeto se defende e por onde é atacável**, para o auditor saber *quem* ataca (perfis), *por onde* (entradas) e *o que* está em jogo (dados). Fica versionado em `<pasta do guia de arquitetura>/ameacas.md`; sem guia, `docs/ameacas.md`. Gerado por `/auditoria-pre-subida:mapear`; revisado por uma pessoa.

Regras do mapa:
- Formato fixo abaixo, até ~150 linhas. Cada item traz `arquivo:linha`; item sem local no código não entra.
- Descreve o que **está no código**, não o que deveria estar; o que falta vai em 8.
- Sem valor de segredo, chave, token nem dado de produção: só o nome da variável/coluna e onde vive.
- Nome de perfil é o que o código usa (enum, role, guard), nunca "usuário comum".

## Formato

```
# Mapa de ameaças — <projeto> @ <sha curto> · <data>

## 1. Perfis
| Perfil | O que pode | Como o código o identifica (arquivo:linha) |

## 2. Isolamento de dados
- Tenant/dono: <coluna/relação> — aplicado em: <escopo global | Policy | middleware> (arquivo:linha)
- Exceções (consulta que atravessa o isolamento de propósito): <arquivo:linha — por quê>

## 3. Entradas
| Entrada | Tipo | Quem alcança (perfil) | Autorização (arquivo:linha) |
Tipos: rota web, rota/API pública, rota/API autenticada, método público de componente (Livewire/Filament), webhook, job/agendamento disparado por usuário, comando, upload, ferramenta MCP/LLM.

## 4. Dados sensíveis
| Dado | Onde (tabela.coluna, arquivo) | Quem vê | Cifrado? |

## 5. Integrações
- Saída: <serviço> — URL controlada pelo usuário? <sim/não> (arquivo:linha)
- Entrada: <webhook> — assinatura conferida? <sim/não> (arquivo:linha)

## 6. Controles centrais
Middlewares, Gates/Policies, rate limit, exceções de CSRF, CORS, cabeçalhos de segurança: <o que é · onde (arquivo:linha) · o que cobre>

## 7. Suposições de confiança
- <o que o projeto assume> — se falhar: <o que quebra> (arquivo:linha)

## 8. Pontos frágeis conhecidos
- <arquivo:linha — o que é — por que preocupa>
```

## Como mapear
1. Perfis: Grep por roles/permissions/guards/enum de papel, seeders de permissão, `Gate::define`, Policies; abra a Policy de cada modelo principal.
2. Isolamento: escopo global, trait de tenant, `where` por dono nas consultas, middleware de tenant; liste as consultas que o ignoram (`withoutGlobalScopes`, `DB::table`, SQL cru).
3. Entradas: `route:list`/arquivos de rota, métodos públicos de componentes, controllers de webhook, jobs despachados por request, comandos, uploads, ferramentas MCP/LLM. Para cada uma, o perfil que a alcança e onde a autorização acontece (ou "nenhuma").
4. Dados sensíveis: casts `encrypted`, colunas de documento, token, senha, dado pessoal, financeiro; quem os lê em tela, lista, export e API.
5. Integrações: clients HTTP, SDKs, filas de entrada; URL montada com entrada do usuário; assinatura do webhook.
6. Controles centrais: `bootstrap/app.php`/`Kernel`, grupos de middleware, `throttle`, `VerifyCsrfToken::$except`, CORS, cabeçalhos.
7. Suposições e pontos frágeis: o que a segurança toma por certo (proxy confiável, `.env`, fila isolada, e-mail como identidade) e onde o código já destoa do resto.
