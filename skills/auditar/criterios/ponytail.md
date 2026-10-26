# Critérios — Ponytail (correto, seguro, aguenta carga, testado, rápido, enxuto)

**Íntegra em `ponytail/`** (ao lado deste arquivo): `ponytail.md` (as regras de "a menor mudança completa": precisa existir?, já existe no repositório?, biblioteca padrão, dependência instalada, uma linha, o mínimo; o que nunca cortar) e `ponytail-review.md` (o método de revisão), do [DietrichGebert/ponytail](https://github.com/DietrichGebert/ponytail) v5.2.0 (MIT, `ponytail/LICENSE`), sem alteração. Leia os dois inteiros: o review é o método, o `ponytail.md` é a régua do que "devia ser menor". Ignore o que é do modo interativo (níveis, comandos, formato de resposta ao usuário): a saída segue o formato do auditor.

Esta página é o mapa em pt-BR para citar nos achados (`ponytail § P1`–`P6`). Ordem de importância: **correto, seguro, aguenta a carga, testado, rápido, enxuto**. Enxuto importa: cada linha a mais é lida, testada e corrigida depois.

Antes de apontar: leia o diff **e** o código ligado a ele (chamadores de toda função alterada, o que ela chama, os testes). Mudança de assinatura, retorno ou comportamento: Grep em todos os chamadores. Ache no repositório a carga esperada (README, deploy, filas) e julgue escala contra ela.

## P1 — Bug
Resultado errado, erro, caso de borda esquecido (vazio, zero, nulo, último item, arredondamento, fuso horário, virada de mês), chamador quebrado pela mudança, correção feita num chamador enquanto a função compartilhada continua errada (corrigir a causa uma vez, no código compartilhado).

## P2 — Risco
Brecha de segurança (ver `seguranca.md`), perda de dado: erro engolido, gravação na ordem errada, falta de transação, efeito externo (e-mail, disco, API) antes do commit, código movido ou mesclado que perdeu o tratamento de erro ou a validação que tinha.

## P3 — Escala
Certo para um usuário, errado para muitos: corrida de "checa e grava", o mesmo trabalho feito por todo processo, memória ou lista que só cresce, uma query por item (N+1), O(n²) em entrada grande, estado por processo que devia ser compartilhado, job sem trava de concorrência.

## P4 — Teste faltando
Lógica nova arriscada (ramo, parser, dinheiro, segurança, gravação de dado, correção de bug) sem um teste que falhe quando ela quebrar. Um bom teste, não cobertura. Correção de bug: o teste falharia antes da correção. Teste que só passa por coincidência (dois ids iguais por acaso) não protege.

## P5 — Velocidade
Lentidão grande é problema; ganho pequeno (trabalho repetido num laço quente) é sugestão (P3).

## P6 — Enxuto: código que não devia existir ou devia ser menor
- **apagar**: código morto, opção sem uso, funcionalidade especulativa "para depois";
- **reusar**: o repositório já tem o helper/componente/serviço (cite o caminho);
- **nativo**: a biblioteca padrão, o framework ou uma dependência já instalada resolve; dependência nova para poucas linhas;
- **yagni**: abstração com uma implementação, interface sem segunda classe, config que ninguém muda, wrapper que só repassa;
- **juntar**: quase-cópias que precisam mudar juntas (duas cópias da mesma regra divergem na primeira mudança);
- **separar**: função que faz vários trabalhos sem relação. Separa por trabalho, nunca por número de linhas.
- Comentário só para o porquê que o código não mostra, em uma linha; sem narrativa, data, issue ou "antes era".

## Como reportar
- Todo achado tem caso concreto: "esta entrada/situação leva a este resultado errado". Sem caso, sem achado.
- Releia as linhas e confirme: o chamador existe, o valor pode mesmo ser vazio, o código está mesmo sem uso.
- Atalho marcado com comentário `shortcut:` (ou `ponytail:`) que nomeia o limite é decisão, não achado, salvo se a carga esperada já passou do limite.
- Proponha a menor correção que funciona; prefira a que apaga código. Nunca proponha camada, framework ou config que o problema não pede.
- Sem gosto pessoal de estilo, sem "considere", sem preocupação vaga.
- Nunca proponha cortar validação na fronteira, tratamento de erro que evita perda de dado, segurança ou acessibilidade em nome de enxugar.
