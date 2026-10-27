#!/bin/bash
# Prova do exige-auditoria.sh: PR, merge e push na base só com veredito APROVADO do commit que sobe.
# Uso: bash tests/hook.sh   (repositório temporário; gh falso no PATH)
raiz=$(cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
falhas=0
ok() { echo "ok   $1"; }
ruim() { echo "FALHA $1"; falhas=$((falhas + 1)); }

repo=$tmp/repo
git init -q -b main "$repo"
git -C "$repo" -c user.name=t -c user.email=t@t commit -q --allow-empty -m base
git init -q --bare "$tmp/remoto.git"
git -C "$repo" remote add origin "$tmp/remoto.git"
git -C "$repo" push -q origin main
git -C "$repo" checkout -q -b feat/x
git -C "$repo" -c user.name=t -c user.email=t@t commit -q --allow-empty -m trabalho
sha=$(git -C "$repo" rev-parse HEAD)
aprova() { mkdir -p "$repo/.git/auditoria/$1"; echo "VEREDITO: $2" > "$repo/.git/auditoria/$1/veredito.md"; }

# gh falso: gh pr view devolve o head e o corpo de $GH_CORPO
mkdir -p "$tmp/bin"
cat > "$tmp/bin/gh" <<EOF
#!/bin/bash
[ "\$1 \$2" = "pr view" ] && printf '{"headRefOid":"$sha","body":"%s","comments":[]}' "\$GH_CORPO"
EOF
chmod +x "$tmp/bin/gh"
export PATH="$tmp/bin:$PATH"

json() { local c=${1//\\/\\\\}; c=${c//\"/\\\"}; printf '{"tool_name":"Bash","cwd":"%s","tool_input":{"command":"%s"}}' "${2:-$repo}" "$c"; }
confere() { # esperado(BLOQ|LIVRE) comando [cwd]
    local r=LIVRE
    json "$2" "${3:-}" | bash "$raiz/hooks/exige-auditoria.sh" 2>/dev/null; [ $? = 2 ] && r=BLOQ
    if [ "$r" = "$1" ]; then ok "$1: $2"; else ruim "esperado $1, veio $r: $2"; fi
}

# Repositório sem o arquivo de ativação: o hook não age.
confere LIVRE 'gh pr create --fill'
confere LIVRE 'git push origin feat/x:main'
confere LIVRE 'gh pr merge 12'
git -C "$repo" checkout -q main
git -C "$repo" -c user.name=t -c user.email=t@t commit -q --allow-empty -m direto-sem-ativacao
confere LIVRE 'git push origin main'
git -C "$repo" reset -q --hard HEAD~1
git -C "$repo" checkout -q feat/x
touch "$repo/.auditoria-pre-subida"

# Fora de PR, merge e push na base: livre.
confere LIVRE 'git status'
confere LIVRE 'git push -u origin feat/x'
confere LIVRE 'git push'
confere LIVRE 'git push origin --delete main'
confere LIVRE 'gh pr view 12'
confere LIVRE 'echo gh pr create'

# Sem auditoria.
confere BLOQ 'gh pr create --base main --title x --body y'
confere BLOQ 'git push origin feat/x:main'
confere BLOQ 'git push origin HEAD:refs/heads/homologacao'
confere BLOQ 'git add . && git commit -m x && gh pr create --fill'
confere BLOQ 'gh pr merge 12 --squash'
confere BLOQ 'cd /tmp; git -C '"$repo"' push origin HEAD:main'

# Reprovado não libera; aprovado libera.
aprova "$sha" REPROVADO
confere BLOQ 'gh pr create --fill'
aprova "$sha" APROVADO
confere LIVRE 'gh pr create --fill'
confere LIVRE 'git push origin feat/x:main'
confere LIVRE 'gh pr merge 12 --squash'

# Commit novo exige auditoria nova.
git -C "$repo" -c user.name=t -c user.email=t@t commit -q --allow-empty -m correcao
confere BLOQ 'gh pr create --fill'
confere LIVRE 'gh pr create --head feat/x~1 --fill'

# Merge em outra máquina: marcador no PR com o head certo.
rm -rf "$repo/.git/auditoria"
confere BLOQ 'gh pr merge 12'
GH_CORPO="auditoria-pre-subida: APROVADO 0000000000000000000000000000000000000000" confere BLOQ 'gh pr merge 12'
GH_CORPO="auditoria-pre-subida: APROVADO $sha" confere LIVRE 'gh pr merge 12'

# Merge local na base vale pelo segundo pai auditado.
aprova "$sha" APROVADO
git -C "$repo" checkout -q main
git -C "$repo" -c user.name=t -c user.email=t@t merge -q --no-ff -m merge "$sha"
confere LIVRE 'git push origin main'
confere LIVRE 'git push'
git -C "$repo" -c user.name=t -c user.email=t@t commit -q --allow-empty -m direto
confere BLOQ 'git push'

# Formas de push na base que não nomeiam a branch, ou levam opção junto.
confere BLOQ 'git push origin HEAD'
confere BLOQ 'git push origin @'
confere BLOQ 'git push origin main --tags'
confere LIVRE 'git push origin --tags'
confere LIVRE 'git push --tags'
git -C "$repo" checkout -q feat/x
confere BLOQ 'git push --all origin'
git -C "$repo" checkout -q main

# cd dentro do comando, com a sessão fora do repositório.
mkdir -p "$tmp/fora"
confere BLOQ "cd $repo && git push origin main" "$tmp/fora"
confere BLOQ "cd $repo && gh pr create --fill" "$tmp/fora"
confere BLOQ "cd $repo && git -C . push origin main" "$tmp/fora"
confere BLOQ "Set-Location -Path $repo; git push origin main" "$tmp/fora"
confere BLOQ "cd repo && git push origin main" "$tmp"

# Merge aprovado por cima de commit direto não auditado não passa; merges aprovados em cadeia passam.
aprova "$(git -C "$repo" rev-parse feat/x)" APROVADO
git -C "$repo" -c user.name=t -c user.email=t@t merge -q --no-ff -m m-direto feat/x
confere BLOQ 'git push origin main'
git -C "$repo" reset -q --hard origin/main
confere LIVRE 'git push origin main'
git -C "$repo" -c user.name=t -c user.email=t@t merge -q --no-ff -m m1 "$sha"
git -C "$repo" -c user.name=t -c user.email=t@t merge -q --no-ff -m m2 feat/x
confere LIVRE 'git push origin main'

# Octopus não passa: os pais além do segundo não seriam conferidos.
git -C "$repo" reset -q --hard origin/main
git -C "$repo" checkout -q -b feat/y
git -C "$repo" -c user.name=t -c user.email=t@t commit -q --allow-empty -m y
aprova "$(git -C "$repo" rev-parse feat/y)" APROVADO
git -C "$repo" checkout -q main
git -C "$repo" -c user.name=t -c user.email=t@t merge -q --no-ff -m octopus feat/x feat/y >/dev/null
confere BLOQ 'git push origin main'

[ "$falhas" = 0 ] && echo "tudo ok" || { echo "$falhas falha(s)"; exit 1; }
