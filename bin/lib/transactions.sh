#!/usr/bin/env bash
# shellcheck shell=bash

# transactions.sh: Data-only transaction parsing, validation, listing, and metadata helpers.
# This library must NOT mutate HOME or the filesystem merely by being sourced.

DOTFILES_BACKUP_ROOT="${DOTFILES_BACKUP_ROOT:-$HOME/.dotfiles-backup}"

transaction_backup_root() {
    echo "${DOTFILES_BACKUP_ROOT:-$HOME/.dotfiles-backup}"
}

# Validate transaction ID against strict allowlist: digits, 'T', and '-' only.
validate_transaction_id() {
    local id="$1"
    [ -n "$id" ] || return 1
    if [[ ! "$id" =~ ^[0-9T-]+$ ]]; then
        return 1
    fi
    return 0
}

# Generate a collision-resistant transaction ID in UTC: YYYYMMDDTHHMMSS-<pid>-<random>
# Refuses to reuse an existing transaction directory.
generate_transaction_id() {
    local root
    root="$(transaction_backup_root)"
    local ts pid rnd candidate attempts=0

    ts="$(date -u +%Y%m%dT%H%M%S)"
    pid="$$"

    while [ "$attempts" -lt 10 ]; do
        rnd="$(printf "%04d" "$((RANDOM % 10000))")"
        candidate="${ts}-${pid}-${rnd}"
        if [ ! -e "$root/$candidate" ]; then
            echo "$candidate"
            return 0
        fi
        attempts=$((attempts + 1))
    done
    return 1
}

# Validate relative path: cannot be empty, absolute, or contain newline/CR/pipe or '..' components.
validate_relative_path() {
    local path="$1"
    [ -n "$path" ] || return 1

    # Reject newlines, carriage returns, and pipe characters
    if [[ "$path" == *$'\n'* || "$path" == *$'\r'* || "$path" == *"|"* ]]; then
        return 1
    fi

    # Reject absolute paths
    if [[ "$path" == /* ]]; then
        return 1
    fi

    # Reject any '..' path component
    if [[ "$path" == ".." || "$path" == ../* || "$path" == */.. || "$path" == */../* ]]; then
        return 1
    fi

    return 0
}

# Normalize a relative path by removing leading/trailing slashes, redundant slashes, and '.' segments.
normalize_relative_path() {
    local path="$1"
    local part
    local -a parts=()
    local -a clean_parts=()
    IFS="/" read -r -a parts <<<"$path"
    for part in "${parts[@]}"; do
        if [ -z "$part" ] || [ "$part" = "." ]; then
            continue
        fi
        clean_parts+=("$part")
    done
    (
        IFS="/"
        echo "${clean_parts[*]}"
    )
}

# Validate prior kind
validate_prior_kind() {
    case "$1" in
        absent | file | directory | symlink) return 0 ;;
        *) return 1 ;;
    esac
}

# Validate prior value according to kind and sequence
validate_prior_value() {
    local kind="$1"
    local value="$2"
    local seq="$3"

    case "$kind" in
        absent)
            [ -z "$value" ] || return 1
            ;;
        file | directory)
            [ "$value" = "payload/$seq" ] || return 1
            ;;
        symlink)
            [ -n "$value" ] || return 1
            if [[ "$value" == *$'\n'* || "$value" == *$'\r'* || "$value" == *"|"* ]]; then
                return 1
            fi
            ;;
        *)
            return 1
            ;;
    esac
    return 0
}

# Validate all fields of a single journal entry
validate_journal_entry() {
    local seq="$1"
    local target="$2"
    local kind="$3"
    local val="$4"
    local installed="$5"

    [[ "$seq" =~ ^[0-9]+$ ]] || return 1
    validate_relative_path "$target" || return 1
    validate_prior_kind "$kind" || return 1
    validate_prior_value "$kind" "$val" "$seq" || return 1
    validate_relative_path "$installed" || return 1
    return 0
}

# Validate that all ancestor directories of target_rel under base_dir exist as
# real directories, that none has been redirected via a symlink, and that the
# immediate destination parent directory is writable.
validate_target_ancestors() {
    local target_rel="$1"
    local base_dir="${2:-$HOME}"
    local parent_rel
    parent_rel="$(dirname "$target_rel")"

    [ -d "$base_dir" ] && [ ! -L "$base_dir" ] || return 1

    local curr="$base_dir"
    if [ "$parent_rel" = "." ] || [ -z "$parent_rel" ]; then
        [ -w "$curr" ] || return 1
        return 0
    fi

    local part
    local -a parts=()
    IFS="/" read -r -a parts <<<"$parent_rel"
    for part in "${parts[@]}"; do
        [ -z "$part" ] && continue
        curr="$curr/$part"
        if [ -L "$curr" ] || [ ! -d "$curr" ]; then
            return 1
        fi
    done
    [ -w "$curr" ] || return 1
    return 0
}

# Validate that any existing ancestor directories of target_rel under base_dir
# are real directories and that none has been redirected via a symlink.
validate_target_ancestors_install() {
    local target_rel="$1"
    local base_dir="${2:-$HOME}"
    local parent_rel
    parent_rel="$(dirname "$target_rel")"

    if [ "$parent_rel" = "." ] || [ -z "$parent_rel" ]; then
        return 0
    fi

    [ -d "$base_dir" ] && [ ! -L "$base_dir" ] || return 1

    local curr="$base_dir"
    local part
    local -a parts=()
    IFS="/" read -r -a parts <<<"$parent_rel"
    for part in "${parts[@]}"; do
        [ -z "$part" ] && continue
        curr="$curr/$part"
        if [ -L "$curr" ] || { [ -e "$curr" ] && [ ! -d "$curr" ]; }; then
            return 1
        fi
    done
    return 0
}

# Validate that the backup root, transaction directory, and all payload ancestor
# directories exist as real, writable directories and have not been redirected via symlinks.
validate_payload_ancestors() {
    local tx_dir="$1"
    local prior_val="$2"
    local root="${3:-$(transaction_backup_root)}"

    [ -n "$root" ] && [ -d "$root" ] && [ ! -L "$root" ] || return 1
    [ -n "$tx_dir" ] && [ -d "$tx_dir" ] && [ ! -L "$tx_dir" ] && [ -w "$tx_dir" ] || return 1

    local curr="$tx_dir"
    local part
    local -a parts=()
    local parent_rel
    parent_rel="$(dirname "$prior_val")"
    if [ "$parent_rel" != "." ] && [ -n "$parent_rel" ]; then
        IFS="/" read -r -a parts <<<"$parent_rel"
        for part in "${parts[@]}"; do
            [ -z "$part" ] && continue
            curr="$curr/$part"
            if [ -L "$curr" ] || [ ! -d "$curr" ] || [ ! -w "$curr" ]; then
                return 1
            fi
        done
    fi

    return 0
}

# Validate that the backup root, transaction directory, and metadata file exist,
# are not symlinks, and are writable so metadata state updates can succeed.
validate_transaction_metadata_writable() {
    local tx_dir="$1"
    local root="${2:-$(transaction_backup_root)}"

    [ -n "$root" ] && [ -d "$root" ] && [ ! -L "$root" ] || return 1
    [ -n "$tx_dir" ] && [ -d "$tx_dir" ] && [ ! -L "$tx_dir" ] && [ -w "$tx_dir" ] || return 1

    local meta_file="$tx_dir/metadata"
    [ -f "$meta_file" ] && [ ! -L "$meta_file" ] && [ -w "$meta_file" ] || return 1
    return 0
}

# Check whether target is a symlink pointing to expected_source, either literally
# or via canonical physical paths.
is_managed_symlink() {
    local target="$1"
    local expected="$2"
    [ -L "$target" ] || return 1

    local raw_link_dest link_dest
    raw_link_dest="$(
        readlink -n "$target"
        printf 'x'
    )" || return 1
    link_dest="${raw_link_dest%x}"

    # If the symlink contains newlines or CRs, it is not a valid managed dotfiles link
    if [[ "$link_dest" == *$'\n'* || "$link_dest" == *$'\r'* ]]; then
        return 1
    fi

    if [ "$link_dest" = "$expected" ]; then
        return 0
    fi

    # Fallback to canonical physical path comparison if both exist
    local link_abs="$link_dest"
    if [[ "$link_abs" != /* ]]; then
        link_abs="$(dirname "$target")/$link_abs"
    fi

    if [ -d "$link_abs" ] && [ -d "$expected" ]; then
        local can_link can_expected
        can_link="$(cd -P "$link_abs" 2>/dev/null && pwd)" || return 1
        can_expected="$(cd -P "$expected" 2>/dev/null && pwd)" || return 1
        [ "$can_link" = "$can_expected" ] && return 0
    elif [ -e "$link_abs" ] && [ -e "$expected" ]; then
        local can_link_dir can_exp_dir
        can_link_dir="$(cd -P "$(dirname "$link_abs")" 2>/dev/null && pwd)" || return 1
        can_exp_dir="$(cd -P "$(dirname "$expected")" 2>/dev/null && pwd)" || return 1
        [ "$can_link_dir/$(basename "$link_abs")" = "$can_exp_dir/$(basename "$expected")" ] && return 0
    fi

    return 1
}

# Read and strictly validate metadata from a transaction directory.
# Only allowlisted keys (version, id, created_at, repo_revision, state) are accepted.
# Never sources or evals metadata. Outputs key=value on stdout on success.
read_transaction_metadata() {
    local meta_file="$1"
    local tx_dir
    tx_dir="$(dirname "$meta_file")"
    [ -d "$tx_dir" ] && [ ! -L "$tx_dir" ] || return 1
    [ -f "$meta_file" ] && [ ! -L "$meta_file" ] || return 1

    local key val
    local m_version="" m_id="" m_created_at="" m_repo_revision="" m_state="" m_entry_count=""
    local seen_version=false seen_id=false seen_created_at=false seen_repo_rev=false seen_state=false seen_entry_count=false

    while IFS='=' read -r key val || [ -n "$key" ]; do
        [ -z "$key" ] && continue

        # Reject keys or values containing newline, CR, or pipe
        if [[ "$key" == *$'\n'* || "$key" == *$'\r'* || "$key" == *"|"* ]] ||
            [[ "$val" == *$'\n'* || "$val" == *$'\r'* || "$val" == *"|"* ]]; then
            return 1
        fi

        case "$key" in
            version)
                [ "$seen_version" = false ] || return 1
                seen_version=true
                m_version="$val"
                ;;
            id)
                [ "$seen_id" = false ] || return 1
                seen_id=true
                m_id="$val"
                ;;
            created_at)
                [ "$seen_created_at" = false ] || return 1
                seen_created_at=true
                m_created_at="$val"
                ;;
            repo_revision)
                [ "$seen_repo_rev" = false ] || return 1
                seen_repo_rev=true
                m_repo_revision="$val"
                ;;
            state)
                [ "$seen_state" = false ] || return 1
                seen_state=true
                m_state="$val"
                ;;
            entry_count)
                [ "$seen_entry_count" = false ] || return 1
                seen_entry_count=true
                case "$val" in
                    *[!0-9]* | "") return 1 ;;
                    *) m_entry_count="$val" ;;
                esac
                ;;
            *)
                # Reject any non-allowlisted key
                return 1
                ;;
        esac
    done <"$meta_file"

    # Validate required keys and values
    [ "$m_version" = "1" ] || return 1
    validate_transaction_id "$m_id" || return 1
    [ -n "$m_created_at" ] || return 1
    [ -n "$m_repo_revision" ] || return 1
    case "$m_state" in
        in_progress | complete | failed | restored) ;;
        *) return 1 ;;
    esac

    printf "version=%s\nid=%s\ncreated_at=%s\nrepo_revision=%s\nstate=%s\n" \
        "$m_version" "$m_id" "$m_created_at" "$m_repo_revision" "$m_state"
    if [ -n "$m_entry_count" ]; then
        printf "entry_count=%s\n" "$m_entry_count"
    fi
    return 0
}

# Fetch a single metadata field from a transaction directory.
get_transaction_metadata_field() {
    local tx_dir="$1"
    local field="$2"
    local meta
    meta="$(read_transaction_metadata "$tx_dir/metadata")" || return 1
    echo "$meta" | grep "^${field}=" | cut -d'=' -f2-
}

# Write a new transaction metadata file. Always sets version=1.
write_transaction_metadata() {
    local tx_dir="$1"
    local id="$2"
    local created_at="$3"
    local repo_rev="$4"
    local state="$5"
    local entry_count="${6:-}"

    validate_transaction_id "$id" || return 1
    case "$state" in
        in_progress | complete | failed | restored) ;;
        *) return 1 ;;
    esac
    [ -n "$created_at" ] || return 1
    [ -n "$repo_rev" ] || return 1

    local meta_file="$tx_dir/metadata"
    local tmp_file
    tmp_file="$(mktemp "$tx_dir/metadata.tmp.XXXXXX")"

    cat <<EOF >"$tmp_file"
version=1
id=$id
created_at=$created_at
repo_revision=$repo_rev
state=$state
EOF
    if [ -n "$entry_count" ]; then
        printf "entry_count=%s\n" "$entry_count" >>"$tmp_file"
    fi
    mv -f "$tmp_file" "$meta_file"
}

# Update state in metadata by rewriting through a temporary file in the same directory.
update_transaction_state() {
    local tx_dir="$1"
    local new_state="$2"
    local entry_count="${3:-}"

    [ -d "$tx_dir" ] && [ ! -L "$tx_dir" ] || return 1

    case "$new_state" in
        in_progress | complete | failed | restored) ;;
        *) return 1 ;;
    esac

    local meta_file="$tx_dir/metadata"
    [ -f "$meta_file" ] && [ ! -L "$meta_file" ] || return 1

    # Verify current metadata validity first
    read_transaction_metadata "$meta_file" >/dev/null || return 1

    local tmp_file
    tmp_file="$(mktemp "$tx_dir/metadata.tmp.XXXXXX")"
    local key val
    local wrote_entry_count=false
    while IFS='=' read -r key val || [ -n "$key" ]; do
        [ -z "$key" ] && continue
        if [ "$key" = "state" ]; then
            printf "state=%s\n" "$new_state" >>"$tmp_file"
        elif [ "$key" = "entry_count" ]; then
            if [ -n "$entry_count" ]; then
                printf "entry_count=%s\n" "$entry_count" >>"$tmp_file"
            else
                printf "entry_count=%s\n" "$val" >>"$tmp_file"
            fi
            wrote_entry_count=true
        else
            printf "%s=%s\n" "$key" "$val" >>"$tmp_file"
        fi
    done <"$meta_file"
    if [ "$wrote_entry_count" = false ] && [ -n "$entry_count" ]; then
        printf "entry_count=%s\n" "$entry_count" >>"$tmp_file"
    fi

    mv -f "$tmp_file" "$meta_file"
}

# Append a validated journal entry to the transaction's entries file.
append_journal_entry() {
    local tx_dir="$1"
    local seq="$2"
    local target="$3"
    local kind="$4"
    local val="$5"
    local installed="$6"

    [ -d "$tx_dir" ] && [ ! -L "$tx_dir" ] || return 1
    [ ! -L "$tx_dir/entries" ] || return 1
    validate_journal_entry "$seq" "$target" "$kind" "$val" "$installed" || return 1
    printf "%s|%s|%s|%s|%s\n" "$seq" "$target" "$kind" "$val" "$installed" >>"$tx_dir/entries"
}

# Resolve a transaction ID from 'latest' or an explicit ID.
# Checks that the directory exists under DOTFILES_BACKUP_ROOT and metadata is valid.
# If 'latest' is given, verifies the transaction ID points to a valid complete or restored transaction.
resolve_transaction() {
    local input="$1"
    local root
    root="$(transaction_backup_root)"

    [ -d "$root" ] && [ ! -L "$root" ] || return 1

    local resolved_id=""
    if [ "$input" = "latest" ] || [ -z "$input" ]; then
        local latest_file="$root/latest"
        [ -f "$latest_file" ] && [ ! -L "$latest_file" ] || return 1
        resolved_id="$(head -n 1 "$latest_file" | tr -d '[:space:]')"
        validate_transaction_id "$resolved_id" || return 1
        local tx_dir="$root/$resolved_id"
        [ -d "$tx_dir" ] && [ ! -L "$tx_dir" ] || return 1
        local meta
        meta="$(read_transaction_metadata "$tx_dir/metadata")" || return 1
        local state
        state="$(echo "$meta" | grep '^state=' | cut -d'=' -f2)"
        # 'latest' resolves only a validated complete transaction ID (complete or restored)
        if [ "$state" != "complete" ] && [ "$state" != "restored" ]; then
            return 1
        fi
    else
        resolved_id="$input"
        validate_transaction_id "$resolved_id" || return 1
        local tx_dir="$root/$resolved_id"
        [ -d "$tx_dir" ] && [ ! -L "$tx_dir" ] || return 1
        read_transaction_metadata "$tx_dir/metadata" >/dev/null || return 1
    fi

    echo "$resolved_id"
    return 0
}

# Enumerate all valid transaction directories under DOTFILES_BACKUP_ROOT.
# Outputs transaction directory paths, sorted lexicographically (which sorts chronologically by ID).
list_transaction_dirs() {
    local root
    root="$(transaction_backup_root)"
    [ -d "$root" ] && [ ! -L "$root" ] || return 0

    local entry
    for entry in "$root"/*; do
        [ -d "$entry" ] && [ ! -L "$entry" ] || continue
        local id
        id="$(basename "$entry")"
        validate_transaction_id "$id" || continue
        [ -f "$entry/metadata" ] && [ ! -L "$entry/metadata" ] || continue
        echo "$entry"
    done
}
