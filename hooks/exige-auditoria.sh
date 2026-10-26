#!/bin/bash
# PreToolUse (Bash|PowerShell): abrir PR, mesclar PR e push direto numa branch base só com auditoria APROVADA do commit que sobe.
# Só age em repositório com o arquivo .auditoria-pre-subida na raiz; os demais projetos da máquina ficam livres.
in=$(cat)
cmd=$(printf '%s' "$in" | grep -oE '"command"[[:space:]]*:[[:space:]]*"([^"\\]|\\.)*"' | head -1 \
    | sed -E 's/^"command"[[:space:]]*:[[:space:]]*"//; s/"$//; s/\\"/"/g; s/\\\\/\\/g')
[ -n "$cmd" ] || exit 0
printf '%s' "$cmd" | grep -qE '(^|[^[:alnum:]_-])(git(\.exe)?([[:space:]].*)?[[:space:]]push|gh(\.exe)?[[:space:]]+pr[[:space:]]+(create|merge))([[:space:]]|$)' || exit 0
wd=$(printf '%s' "$in" | grep -oE '"cwd"[[:space:]]*:[[:space:]]*"([^"\\]|\\.)*"' | head -1 \
    | sed -E 's/^"cwd"[[:space:]]*:[[:space:]]*"//; s/"$//; s/\\\\/\//g')
[ -n "$wd" ] || wd=$PWD

bloqueia() {
    echo "Subida bloqueada: $1 Rode a skill /auditoria-pre-subida:auditar neste repositório e suba depois do VEREDITO: APROVADO." >&2
    exit 2
}
ativo() { # dir
    local raiz; raiz=$(git -C "$1" rev-parse --show-toplevel 2>/dev/null) && [ -f "$raiz/.auditoria-pre-subida" ]
}
aprovado() { # dir sha → veredito local em <git-common-dir>/auditoria/<sha>/veredito.md
    local comum
    comum=$(git -C "$1" rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || return 1
    [ -n "$2" ] && head -1 "$comum/auditoria/$2/veredito.md" 2>/dev/null | grep -q '^VEREDITO: APROVADO'
}
aprovado_ou_merge() { # dir sha; shortcut: merge na base vale pelo segundo pai auditado, sem auditar a resolução de conflito
    aprovado "$1" "$2" && return 0
    local p2; p2=$(git -C "$1" rev-parse -q --verify "$2^2" 2>/dev/null) && aprovado "$1" "$p2"
}
eh_base() {
    local b padrao
    padrao=$(git -C "$wd" symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null); padrao=${padrao#origin/}
    for b in ${AUDITORIA_BASES:-main master homologacao desenvolvimento develop production producao staging} $padrao; do
        [ "$1" = "$b" ] && return 0
    done
    return 1
}

confere_push() { # dir args...
    local dir=$1; shift
    local a remoto="" refs=() pula=0
    for a in "$@"; do
        if [ $pula = 1 ]; then pula=0; continue; fi
        case "$a" in
            -d|--delete|--tags|--dry-run|-n) return 0 ;;
            -o|--push-option|--repo|--receive-pack|--exec) pula=1 ;;
            -*) ;;
            *) if [ -z "$remoto" ]; then remoto=$a; else refs+=("$a"); fi ;;
        esac
    done
    [ ${#refs[@]} = 0 ] && refs=("$(git -C "$dir" symbolic-ref -q --short HEAD 2>/dev/null)")
    local r src dst sha
    for r in "${refs[@]}"; do
        r=${r#+}; src=${r%%:*}; dst=${r#*:}
        dst=${dst#refs/heads/}
        eh_base "$dst" || continue
        sha=$(git -C "$dir" rev-parse -q --verify "${src:-HEAD}^{commit}" 2>/dev/null) || continue
        aprovado_ou_merge "$dir" "$sha" || bloqueia "push direto em '$dst' com ${sha:0:9} sem auditoria aprovada."
    done
}
confere_pr_create() { # dir args...
    local dir=$1; shift
    local a head="" prox=0
    for a in "$@"; do
        [ $prox = 1 ] && { head=$a; prox=0; continue; }
        case "$a" in -H|--head) prox=1 ;; --head=*) head=${a#--head=} ;; esac
    done
    local sha; sha=$(git -C "$dir" rev-parse -q --verify "${head:-HEAD}^{commit}" 2>/dev/null) || return 0
    aprovado "$dir" "$sha" || bloqueia "gh pr create com ${sha:0:9} sem auditoria aprovada."
}
confere_pr_merge() { # dir args...
    local dir=$1; shift
    local a alvo="" pula=0
    for a in "$@"; do
        if [ $pula = 1 ]; then pula=0; continue; fi
        case "$a" in
            -R|--repo|-t|--subject|-b|--body|-F|--body-file|--match-head-commit|--author-email) pula=1 ;;
            -*) ;;
            *) [ -z "$alvo" ] && alvo=$a ;;
        esac
    done
    local info sha
    info=$(cd "$dir" 2>/dev/null && gh pr view $alvo --json headRefOid,body,comments 2>/dev/null) \
        || bloqueia "não consegui ler o PR pelo gh para conferir a auditoria."
    sha=$(printf '%s' "$info" | grep -oE '"headRefOid"[[:space:]]*:[[:space:]]*"[0-9a-f]+"' | grep -oE '[0-9a-f]{40}')
    aprovado "$dir" "$sha" && return 0
    # quem mescla em outra máquina não tem o veredito local: vale o marcador que a skill põe no corpo ou num comentário do PR
    printf '%s' "$info" | grep -q "auditoria-pre-subida: APROVADO $sha" && return 0
    bloqueia "gh pr merge com ${sha:0:9} sem auditoria aprovada (nem local, nem marcador no PR)."
}

set -f
while IFS= read -r seg; do
    # shellcheck disable=SC2086
    set -- $seg
    while [ $# -gt 0 ] && [[ $1 == *=* && $1 != -* ]]; do shift; done
    [ $# -gt 0 ] || continue
    prog=${1##*[/\\]}; prog=${prog%.exe}; shift
    dir=$wd
    case "$prog" in
        git)
            while [ $# -gt 0 ]; do
                case "$1" in
                    -C) dir=$2; shift 2 ;;
                    -c) shift 2 ;;
                    -*) shift ;;
                    *) break ;;
                esac
            done
            [ "${1:-}" = push ] && ativo "$dir" && { shift; confere_push "$dir" "$@"; }
            ;;
        gh)
            [ "${1:-}" = pr ] && ativo "$dir" || continue
            case "${2:-}" in
                create) shift 2; confere_pr_create "$dir" "$@" ;;
                merge) shift 2; confere_pr_merge "$dir" "$@" ;;
            esac
            ;;
    esac
done < <(printf '%s\n' "$cmd" | sed -E 's/\\n/\n/g; s/(&&|\|\||;|\||\(|\))/\n/g; s/["'"'"']//g')
exit 0
