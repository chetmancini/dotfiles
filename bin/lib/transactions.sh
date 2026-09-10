#!/usr/bin/env bash

# Data-only helpers for versioned dotfiles install transactions.
# This file intentionally performs no filesystem mutation when sourced.

DOTFILES_BACKUP_ROOT="${DOTFILES_BACKUP_ROOT:-$HOME/.dotfiles-backup}"

transaction_error() {
    echo "transaction: $*" >&2
}

transaction_validate_id() {
    local id="$1"
    [[ "$id" =~ ^[0-9]{8}T[0-9]{6}-[0-9]+-[0-9]+$ ]]
}

transaction_validate_backup_root() {
    transaction_validate_field "$DOTFILES_BACKUP_ROOT" || {
        transaction_error "invalid backup root"
        return 1
    }
    case "$DOTFILES_BACKUP_ROOT" in
        /*) ;;
        *)
            transaction_error "backup root must be absolute: $DOTFILES_BACKUP_ROOT"
            return 1
            ;;
    esac
    if [ -L "$DOTFILES_BACKUP_ROOT" ] || { [ -e "$DOTFILES_BACKUP_ROOT" ] && [ ! -d "$DOTFILES_BACKUP_ROOT" ]; }; then
        transaction_error "backup root must be a directory, not a symlink: $DOTFILES_BACKUP_ROOT"
        return 1
    fi
}

transaction_validate_field() {
    local value="$1"
    case "$value" in
        *$'\n'* | *$'\r'* | *'|'*) return 1 ;;
    esac
    return 0
}

transaction_has_parent_component() {
    local value="$1"
    case "/$value/" in
        */../*) return 0 ;;
    esac
    return 1
}

transaction_validate_relative_path() {
    local value="$1"
    [ -n "$value" ] || return 1
    transaction_validate_field "$value" || return 1
    case "$value" in
        /*) return 1 ;;
    esac
    transaction_has_parent_component "$value" && return 1
    return 0
}

transaction_validate_symlink_value() {
    local value="$1"
    [ -n "$value" ] || return 1
    transaction_validate_field "$value" || return 1
    transaction_has_parent_component "$value" && return 1
    return 0
}

transaction_path_for_id() {
    local id="$1"
    transaction_validate_id "$id" || {
        transaction_error "invalid transaction ID: $id"
        return 1
    }
    printf '%s/%s\n' "$DOTFILES_BACKUP_ROOT" "$id"
}

transaction_generate_id() {
    local timestamp random id
    timestamp="$(date -u +%Y%m%dT%H%M%S)"
    while true; do
        random="${RANDOM}${RANDOM}"
        id="${timestamp}-$$-${random}"
        [ ! -e "$DOTFILES_BACKUP_ROOT/$id" ] && {
            printf '%s\n' "$id"
            return 0
        }
    done
}

transaction_write_metadata() {
    local directory="$1"
    local id="$2"
    local created_at="$3"
    local repo_revision="$4"
    local state="$5"
    local temporary="$directory/.metadata.tmp.$$.$RANDOM"

    transaction_validate_id "$id" || return 1
    transaction_validate_field "$created_at" || return 1
    transaction_validate_field "$repo_revision" || return 1
    case "$state" in
        in_progress | complete | failed | restored) ;;
        *) return 1 ;;
    esac

    {
        printf 'version=1\n'
        printf 'id=%s\n' "$id"
        printf 'created_at=%s\n' "$created_at"
        printf 'repo_revision=%s\n' "$repo_revision"
        printf 'state=%s\n' "$state"
    } >"$temporary"
    mv "$temporary" "$directory/metadata"
}

transaction_begin() {
    local repo_revision="$1"
    local id directory created_at

    transaction_validate_backup_root
    mkdir -p "$DOTFILES_BACKUP_ROOT"
    id="$(transaction_generate_id)"
    directory="$(transaction_path_for_id "$id")"
    created_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

    (umask 077 && mkdir "$directory" && mkdir "$directory/payload" && : >"$directory/entries")
    transaction_write_metadata "$directory" "$id" "$created_at" "$repo_revision" in_progress

    TRANSACTION_ID="$id"
    TRANSACTION_DIR="$directory"
}

transaction_load_metadata() {
    local directory="$1"
    local metadata="$directory/metadata"
    local key value
    local seen_version=false seen_id=false seen_created_at=false seen_repo_revision=false seen_state=false

    TX_VERSION=
    TX_ID=
    TX_CREATED_AT=
    TX_REPO_REVISION=
    TX_STATE=

    [ -f "$metadata" ] && [ ! -L "$metadata" ] || {
        transaction_error "missing regular metadata file: $metadata"
        return 1
    }

    while IFS='=' read -r key value; do
        transaction_validate_field "$key" && transaction_validate_field "$value" || {
            transaction_error "invalid metadata field in $metadata"
            return 1
        }
        case "$key" in
            version)
                [ "$seen_version" = false ] || return 1
                seen_version=true
                TX_VERSION="$value"
                ;;
            id)
                [ "$seen_id" = false ] || return 1
                seen_id=true
                TX_ID="$value"
                ;;
            created_at)
                [ "$seen_created_at" = false ] || return 1
                seen_created_at=true
                TX_CREATED_AT="$value"
                ;;
            repo_revision)
                [ "$seen_repo_revision" = false ] || return 1
                seen_repo_revision=true
                TX_REPO_REVISION="$value"
                ;;
            state)
                [ "$seen_state" = false ] || return 1
                seen_state=true
                TX_STATE="$value"
                ;;
            *)
                transaction_error "unknown metadata key in $metadata: $key"
                return 1
                ;;
        esac
    done <"$metadata"

    [ "$seen_version" = true ] && [ "$seen_id" = true ] && [ "$seen_created_at" = true ] &&
        [ "$seen_repo_revision" = true ] && [ "$seen_state" = true ] || {
        transaction_error "metadata is missing required keys: $metadata"
        return 1
    }
    [ "$TX_VERSION" = 1 ] || {
        transaction_error "unsupported transaction version: $TX_VERSION"
        return 1
    }
    transaction_validate_id "$TX_ID" || {
        transaction_error "invalid transaction ID in metadata: $TX_ID"
        return 1
    }
    [ -n "$TX_CREATED_AT" ] && [ -n "$TX_REPO_REVISION" ] || return 1
    case "$TX_STATE" in
        in_progress | complete | failed | restored) ;;
        *)
            transaction_error "invalid transaction state: $TX_STATE"
            return 1
            ;;
    esac
    [ "$(basename "$directory")" = "$TX_ID" ] || {
        transaction_error "metadata ID does not match transaction directory"
        return 1
    }
}

transaction_update_state() {
    local directory="$1"
    local state="$2"
    transaction_load_metadata "$directory" || return 1
    transaction_write_metadata "$directory" "$TX_ID" "$TX_CREATED_AT" "$TX_REPO_REVISION" "$state"
}

transaction_append_entry() {
    local directory="$1"
    local sequence="$2"
    local target_relative="$3"
    local prior_kind="$4"
    local prior_value="$5"
    local installed_source_relative="$6"

    [[ "$sequence" =~ ^[0-9]{4,}$ ]] || return 1
    transaction_validate_relative_path "$target_relative" || return 1
    transaction_validate_relative_path "$installed_source_relative" || return 1
    case "$prior_kind" in
        absent)
            [ -z "$prior_value" ] || return 1
            ;;
        file | directory)
            [ "$prior_value" = "payload/$sequence" ] || return 1
            ;;
        symlink)
            transaction_validate_symlink_value "$prior_value" || return 1
            ;;
        *) return 1 ;;
    esac

    printf '%s|%s|%s|%s|%s\n' \
        "$sequence" "$target_relative" "$prior_kind" "$prior_value" "$installed_source_relative" \
        >>"$directory/entries"
}

transaction_validate_entries() {
    local directory="$1"
    local entries="$directory/entries"
    local line without_pipes pipe_count sequence target_relative prior_kind prior_value installed_source_relative
    local expected count=0 final_newline_count

    [ -f "$entries" ] && [ ! -L "$entries" ] || {
        transaction_error "missing regular entries file: $entries"
        return 1
    }
    if [ -s "$entries" ]; then
        final_newline_count="$(tail -c 1 "$entries" | wc -l | tr -d ' ')"
        [ "$final_newline_count" = 1 ] || {
            transaction_error "journal must end with a newline"
            return 1
        }
    fi

    while IFS= read -r line; do
        without_pipes="${line//|/}"
        pipe_count=$((${#line} - ${#without_pipes}))
        [ "$pipe_count" -eq 4 ] || {
            transaction_error "malformed journal record"
            return 1
        }
        IFS='|' read -r sequence target_relative prior_kind prior_value installed_source_relative <<<"$line"
        count=$((count + 1))
        printf -v expected '%04d' "$count"
        [ "$sequence" = "$expected" ] || {
            transaction_error "invalid journal sequence: $sequence"
            return 1
        }
        transaction_append_entry_validate_only \
            "$sequence" "$target_relative" "$prior_kind" "$prior_value" "$installed_source_relative" || {
            transaction_error "invalid journal record at sequence $sequence"
            return 1
        }
    done <"$entries"

    # shellcheck disable=SC2034 # Public result for callers sourcing this library.
    TRANSACTION_ENTRY_COUNT="$count"
}

transaction_append_entry_validate_only() {
    local sequence="$1"
    local target_relative="$2"
    local prior_kind="$3"
    local prior_value="$4"
    local installed_source_relative="$5"

    [[ "$sequence" =~ ^[0-9]{4,}$ ]] || return 1
    transaction_validate_relative_path "$target_relative" || return 1
    transaction_validate_relative_path "$installed_source_relative" || return 1
    case "$prior_kind" in
        absent) [ -z "$prior_value" ] ;;
        file | directory) [ "$prior_value" = "payload/$sequence" ] ;;
        symlink) transaction_validate_symlink_value "$prior_value" ;;
        *) return 1 ;;
    esac
}

transaction_resolve_reference() {
    local reference="${1:-latest}"
    local id directory line_count final_newline_count

    transaction_validate_backup_root || return 1
    if [ "$reference" = latest ]; then
        [ -f "$DOTFILES_BACKUP_ROOT/latest" ] && [ ! -L "$DOTFILES_BACKUP_ROOT/latest" ] || {
            transaction_error "latest transaction is not available"
            return 1
        }
        line_count="$(wc -l <"$DOTFILES_BACKUP_ROOT/latest" | tr -d ' ')"
        final_newline_count="$(tail -c 1 "$DOTFILES_BACKUP_ROOT/latest" | wc -l | tr -d ' ')"
        [ "$line_count" = 1 ] && [ "$final_newline_count" = 1 ] || {
            transaction_error "latest transaction file must contain exactly one complete ID"
            return 1
        }
        id="$(<"$DOTFILES_BACKUP_ROOT/latest")"
    else
        id="$reference"
    fi

    transaction_validate_id "$id" || {
        transaction_error "invalid transaction ID: $id"
        return 1
    }
    directory="$(transaction_path_for_id "$id")"
    [ -d "$directory" ] && [ ! -L "$directory" ] || {
        transaction_error "transaction not found: $id"
        return 1
    }

    # shellcheck disable=SC2034 # Public results for callers sourcing this library.
    TRANSACTION_ID="$id"
    # shellcheck disable=SC2034
    TRANSACTION_DIR="$directory"
}

transaction_write_latest() {
    local id="$1"
    local temporary
    transaction_validate_id "$id" || return 1
    transaction_validate_backup_root || return 1
    mkdir -p "$DOTFILES_BACKUP_ROOT"
    temporary="$DOTFILES_BACKUP_ROOT/.latest.tmp.$$.$RANDOM"
    printf '%s\n' "$id" >"$temporary"
    mv "$temporary" "$DOTFILES_BACKUP_ROOT/latest"
}

transaction_list_directories() {
    local directory id
    transaction_validate_backup_root || return 1
    [ -d "$DOTFILES_BACKUP_ROOT" ] || return 0
    for directory in "$DOTFILES_BACKUP_ROOT"/*; do
        [ -d "$directory" ] && [ ! -L "$directory" ] || continue
        id="$(basename "$directory")"
        transaction_validate_id "$id" || continue
        printf '%s\n' "$directory"
    done
}
