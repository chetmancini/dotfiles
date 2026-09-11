#!/usr/bin/env bash
# shellcheck shell=bash

# transactions.sh: Data-only transaction parsing, validation, listing, and metadata helpers.
# This library must NOT mutate HOME or the filesystem merely by being sourced.

DOTFILES_BACKUP_ROOT="${DOTFILES_BACKUP_ROOT:-$HOME/.dotfiles-backup}"

transaction_backup_root() {
    echo "${DOTFILES_BACKUP_ROOT:-$HOME/.dotfiles-backup}"
}

process_start_identity() {
    local pid="$1"
    [[ "$pid" =~ ^[1-9][0-9]*$ ]] || return 1
    LC_ALL=C ps -p "$pid" -o lstart= 2>/dev/null
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

# Copy a directory tree through an archive stream so file metadata, symlinks,
# and hard-link relationships survive on both BSD and GNU userlands.
copy_directory_contents() {
    local source="$1"
    local destination="$2"
    if tar --version 2>/dev/null | grep -q 'GNU tar'; then
        (cd "$source" && tar --acls --xattrs --format=pax -cf - .) |
            (cd "$destination" && tar --acls --xattrs -xpf -) || return 1
    else
        (cd "$source" && tar --format=pax -cf - .) |
            (cd "$destination" && tar -xpf -) || return 1
    fi
    touch -r "$source" "$destination"
}

copy_directory_tree() {
    local source="$1"
    local destination="$2"
    mkdir "$destination" || return 1
    copy_directory_contents "$source" "$destination"
}

copy_file_with_metadata() {
    local source="$1"
    local destination="$2"
    if cp --preserve=all -- "$source" "$destination" 2>/dev/null; then
        return 0
    fi
    cp -p "$source" "$destination"
}

path_identity() {
    local path="$1"
    if stat -f '%d:%i' "$path" >/dev/null 2>&1; then
        stat -f '%d:%i' "$path"
    else
        stat -c '%d:%i' "$path"
    fi
}

path_metadata() {
    local path="$1"
    if stat -f '%Fm' "$path" >/dev/null 2>&1; then
        stat -f '%p|%u|%g|%Fm' "$path"
    else
        stat -c '%f|%u|%g|%y' "$path"
    fi
}

path_xattrs() {
    local path="$1"
    if command -v xattr >/dev/null 2>&1; then
        if [ -L "$path" ]; then
            xattr -lxs "$path"
        else
            xattr -lx "$path"
        fi
    elif command -v getfattr >/dev/null 2>&1; then
        if [ -L "$path" ]; then
            getfattr -h -d -m - -- "$path" 2>/dev/null | sed '1d'
        else
            getfattr -d -m - -- "$path" 2>/dev/null | sed '1d'
        fi
    elif command -v python3 >/dev/null 2>&1; then
        python3 -c 'import os, sys; p = sys.argv[1]; print(repr([(name, os.getxattr(p, name, follow_symlinks=False)) for name in sorted(os.listxattr(p, follow_symlinks=False))]))' "$path"
    fi
}

path_xattrs_match() {
    local source="$1"
    local target="$2"
    local source_xattrs target_xattrs
    source_xattrs="$(path_xattrs "$source")" || return 1
    target_xattrs="$(path_xattrs "$target")" || return 1
    [ "$source_xattrs" = "$target_xattrs" ]
}

directory_python_xattrs_match() {
    python3 - "$1" "$2" <<'PY'
import os
import sys

def tree(path):
    result = []
    for root, dirs, files in os.walk(path, followlinks=False):
        names = [root, *(os.path.join(root, name) for name in dirs + files)]
        for entry in names:
            relative = os.path.relpath(entry, path)
            attrs = tuple(
                (name, os.getxattr(entry, name, follow_symlinks=False))
                for name in sorted(os.listxattr(entry, follow_symlinks=False))
            )
            result.append((relative, attrs))
    return sorted(result)

raise SystemExit(tree(sys.argv[1]) != tree(sys.argv[2]))
PY
}

directory_hardlinks_match() {
    python3 - "$1" "$2" <<'PY'
import os
import stat
import sys

def topology(path):
    groups = {}
    def fail(error):
        raise error

    for root, _, files in os.walk(path, followlinks=False, onerror=fail):
        for name in files:
            entry = os.path.join(root, name)
            metadata = os.lstat(entry)
            if stat.S_ISREG(metadata.st_mode):
                relative = os.path.relpath(entry, path)
                groups.setdefault((metadata.st_dev, metadata.st_ino), []).append(relative)

    topology_by_path = {}
    for paths in groups.values():
        if len(paths) > 1:
            representative = min(paths)
            topology_by_path.update((relative, representative) for relative in paths)
    return topology_by_path

raise SystemExit(topology(sys.argv[1]) != topology(sys.argv[2]))
PY
}

paths_match() {
    local source="$1"
    local target="$2"
    local kind="$3"
    local relative source_metadata target_metadata source_link target_link
    local source_inode target_inode source_group target_group group_index
    local source_count=0 target_count=0
    local -a source_inodes=() target_inodes=() source_groups=() target_groups=()
    local batch_python_xattrs=false
    local batch_python_hardlinks=false

    if [ "$kind" = directory ] && ! command -v xattr >/dev/null 2>&1 && ! command -v getfattr >/dev/null 2>&1 && command -v python3 >/dev/null 2>&1; then
        directory_python_xattrs_match "$source" "$target" || return 1
        batch_python_xattrs=true
    fi
    if [ "$kind" = directory ] && command -v python3 >/dev/null 2>&1; then
        directory_hardlinks_match "$source" "$target" || return 1
        batch_python_hardlinks=true
    fi

    source_metadata="$(path_metadata "$source")" || return 1
    target_metadata="$(path_metadata "$target")" || return 1
    [ "$source_metadata" = "$target_metadata" ] || return 1
    [ "$batch_python_xattrs" = true ] || path_xattrs_match "$source" "$target" || return 1
    case "$kind" in
        file) cmp -s "$source" "$target" ;;
        directory)
            while IFS= read -r -d '' relative; do
                source_count=$((source_count + 1))
                relative="${relative#./}"
                source_metadata="$(path_metadata "$source/$relative")" || return 1
                target_metadata="$(path_metadata "$target/$relative")" || return 1
                [ "$source_metadata" = "$target_metadata" ] || return 1
                [ "$batch_python_xattrs" = true ] || path_xattrs_match "$source/$relative" "$target/$relative" || return 1
                if [ -L "$source/$relative" ] || [ -L "$target/$relative" ]; then
                    [ -L "$source/$relative" ] && [ -L "$target/$relative" ] || return 1
                    source_link="$(
                        readlink -n "$source/$relative" || exit 1
                        printf x
                    )" || return 1
                    target_link="$(
                        readlink -n "$target/$relative" || exit 1
                        printf x
                    )" || return 1
                    [ "$source_link" = "$target_link" ] || return 1
                elif [ -f "$source/$relative" ]; then
                    [ -f "$target/$relative" ] && cmp -s "$source/$relative" "$target/$relative" || return 1
                    if [ "$batch_python_hardlinks" = false ] && { [ "$(path_link_count "$source/$relative")" -gt 1 ] || [ "$(path_link_count "$target/$relative")" -gt 1 ]; }; then
                        source_inode="$(path_identity "$source/$relative")" || return 1
                        target_inode="$(path_identity "$target/$relative")" || return 1
                        source_group="$relative"
                        target_group="$relative"
                        for group_index in "${!source_inodes[@]}"; do
                            if [ "${source_inodes[$group_index]}" = "$source_inode" ]; then
                                source_group="${source_groups[$group_index]}"
                                break
                            fi
                        done
                        if [ "$source_group" = "$relative" ]; then
                            source_inodes+=("$source_inode")
                            source_groups+=("$relative")
                        fi
                        for group_index in "${!target_inodes[@]}"; do
                            if [ "${target_inodes[$group_index]}" = "$target_inode" ]; then
                                target_group="${target_groups[$group_index]}"
                                break
                            fi
                        done
                        if [ "$target_group" = "$relative" ]; then
                            target_inodes+=("$target_inode")
                            target_groups+=("$relative")
                        fi
                        [ "$source_group" = "$target_group" ] || return 1
                    fi
                elif [ -d "$source/$relative" ]; then
                    [ -d "$target/$relative" ] || return 1
                fi
            done < <(cd "$source" && find . -mindepth 1 -print0)
            while IFS= read -r -d '' _; do
                target_count=$((target_count + 1))
            done < <(cd "$target" && find . -mindepth 1 -print0)
            [ "$source_count" -eq "$target_count" ]
            ;;
        *) return 1 ;;
    esac
}

sync_file_and_parent() {
    local path="$1"
    if command -v python3 >/dev/null 2>&1; then
        python3 - "$path" <<'PY'
import os
import sys

path = sys.argv[1]
with open(path, "rb") as handle:
    os.fsync(handle.fileno())
directory = os.open(os.path.dirname(path), os.O_RDONLY)
try:
    os.fsync(directory)
finally:
    os.close(directory)
PY
    else
        sync
    fi
}

sync_parent_directory() {
    local path="$1"
    if command -v python3 >/dev/null 2>&1; then
        python3 - "$path" <<'PY'
import os
import sys

parent = os.path.dirname(sys.argv[1]) or "."
directory = os.open(parent, os.O_RDONLY)
try:
    os.fsync(directory)
finally:
    os.close(directory)
PY
    else
        sync
    fi
}

sync_tree_and_parent() {
    local path="$1"
    if command -v python3 >/dev/null 2>&1; then
        python3 - "$path" <<'PY'
import os
import stat
import sys

path = sys.argv[1]

def flush(entry):
    metadata = os.lstat(entry)
    if not (stat.S_ISREG(metadata.st_mode) or stat.S_ISDIR(metadata.st_mode)):
        return

    flags = os.O_RDONLY | getattr(os, "O_NONBLOCK", 0) | getattr(os, "O_NOFOLLOW", 0)
    descriptor = os.open(entry, flags)
    try:
        opened = os.fstat(descriptor)
        if (opened.st_dev, opened.st_ino) != (metadata.st_dev, metadata.st_ino):
            raise RuntimeError(f"path changed while syncing: {entry}")
        os.fsync(descriptor)
    finally:
        os.close(descriptor)

if os.path.isdir(path) and not os.path.islink(path):
    def fail(error):
        raise error

    for root, dirs, files in os.walk(path, topdown=False, followlinks=False, onerror=fail):
        for name in files:
            flush(os.path.join(root, name))
        for name in dirs:
            flush(os.path.join(root, name))
        flush(root)
else:
    flush(path)
flush(os.path.dirname(path))
PY
    else
        sync
    fi
}

path_link_count() {
    local path="$1"
    if stat -f '%l' "$path" >/dev/null 2>&1; then
        stat -f '%l' "$path"
    else
        stat -c '%h' "$path"
    fi
}

symlink_matches_raw_target() {
    local path="$1"
    local expected="$2"
    local actual
    [ -L "$path" ] || return 1
    actual="$(
        readlink -n "$path" || exit 1
        printf x
    )" || return 1
    [ "${actual%x}" = "$expected" ]
}

recover_moved_path() {
    local moved="$1" original="$2"
    [ ! -e "$original" ] && [ ! -L "$original" ] || return 1
    if ! mv -n -T "$moved" "$original" 2>/dev/null; then
        [ ! -e "$original" ] && [ ! -L "$original" ] || return 1
        mv -n "$moved" "$original" || return 1
    fi
    [ ! -e "$moved" ] && [ ! -L "$moved" ]
}

move_path_no_clobber_exact() {
    local source="$1" destination="$2"
    local source_identity nested
    source_identity="$(path_identity "$source")" || return 1
    nested="$destination/$(basename "$source")"

    if mv -n -T "$source" "$destination" 2>/dev/null; then
        :
    elif [ ! -e "$destination" ] && [ ! -L "$destination" ] &&
        [ "$(path_identity "$source" 2>/dev/null)" = "$source_identity" ]; then
        mv -n "$source" "$destination" || return 1
    else
        return 1
    fi

    if [ ! -e "$source" ] && [ ! -L "$source" ] &&
        [ "$(path_identity "$destination" 2>/dev/null)" = "$source_identity" ]; then
        return 0
    fi
    if [ ! -e "$source" ] && [ ! -L "$source" ] &&
        [ "$(path_identity "$nested" 2>/dev/null)" = "$source_identity" ]; then
        recover_moved_path "$nested" "$source" || return 1
    elif [ ! -e "$source" ] && [ ! -L "$source" ] && { [ -e "$destination" ] || [ -L "$destination" ]; }; then
        recover_moved_path "$destination" "$source" || return 1
    fi
    return 1
}

# Place a symlink without replacing a filesystem object that races into the
# destination. If a directory consumes the staged link, remove only that link.
place_symlink_no_clobber() {
    local raw_target="$1"
    local destination="$2"
    local label="$3"
    local parent stage_dir stage_name stage_item result=1
    parent="$(dirname "$destination")"
    stage_dir="$(mktemp -d "$parent/.${label}.stage.XXXXXX")" || return 1
    stage_name="$(basename "$stage_dir")"
    stage_item="$stage_dir/$stage_name"

    if ln -s -- "$raw_target" "$stage_item" &&
        move_path_no_clobber_exact "$stage_item" "$destination" &&
        symlink_matches_raw_target "$destination" "$raw_target"; then
        result=0
    fi

    if symlink_matches_raw_target "$stage_item" "$raw_target"; then
        rm -f "$stage_item" || return 1
    fi
    rmdir "$stage_dir" 2>/dev/null || return 1
    return "$result"
}

# Atomically quarantine the current destination, verify that the quarantined
# object is the one the journal describes, then remove only that object.
guarded_remove_path() {
    local target="$1"
    local kind="$2"
    local expected="$3"
    local label="$4"
    local parent stage_dir stage_name stage_item matches=false cleanup_failed=false
    parent="$(dirname "$target")"
    stage_dir="$(mktemp -d "$parent/.${label}.remove.XXXXXX")" || return 1
    stage_name="$(basename "$stage_dir")"
    stage_item="$stage_dir/$stage_name"
    if ! move_path_no_clobber_exact "$target" "$stage_item"; then
        rmdir "$stage_item" 2>/dev/null || true
        rmdir "$stage_dir" 2>/dev/null || true
        return 1
    fi
    case "$kind" in
        file | directory) paths_match "$expected" "$stage_item" "$kind" && matches=true ;;
        symlink) symlink_matches_raw_target "$stage_item" "$expected" && matches=true ;;
        managed) is_managed_symlink "$stage_item" "$expected" && matches=true ;;
        *) return 1 ;;
    esac

    if [ "$matches" = true ]; then
        case "$kind" in
            directory) rm -rf "$stage_item" || cleanup_failed=true ;;
            *) rm -f "$stage_item" || matches=false ;;
        esac
        if [ "$cleanup_failed" = true ]; then
            return 1
        fi
        if [ "$matches" = true ]; then
            rmdir "$stage_dir" 2>/dev/null || return 1
            [ ! -e "$target" ] && [ ! -L "$target" ]
            return
        fi
    fi

    if [ ! -e "$target" ] && [ ! -L "$target" ]; then
        move_path_no_clobber_exact "$stage_item" "$target" || true
    fi
    rmdir "$stage_dir" 2>/dev/null || true
    return 1
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
# Only allowlisted keys are accepted.
# Never sources or evals metadata. Outputs key=value on stdout on success.
read_transaction_metadata() {
    local meta_file="$1"
    local tx_dir
    tx_dir="$(dirname "$meta_file")"
    [ -d "$tx_dir" ] && [ ! -L "$tx_dir" ] || return 1
    [ -f "$meta_file" ] && [ ! -L "$meta_file" ] || return 1

    local key val
    local m_version="" m_id="" m_created_at="" m_repo_revision="" m_repo_root="" m_owner_pid="" m_owner_started_at="" m_state="" m_entry_count=""
    local seen_version=false seen_id=false seen_created_at=false seen_repo_rev=false seen_repo_root=false seen_owner_pid=false seen_owner_started_at=false seen_state=false seen_entry_count=false

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
            repo_root)
                [ "$seen_repo_root" = false ] || return 1
                seen_repo_root=true
                [[ "$val" = /* ]] || return 1
                m_repo_root="$val"
                ;;
            owner_pid)
                [ "$seen_owner_pid" = false ] || return 1
                seen_owner_pid=true
                [[ "$val" =~ ^[1-9][0-9]*$ ]] || return 1
                m_owner_pid="$val"
                ;;
            owner_started_at)
                [ "$seen_owner_started_at" = false ] || return 1
                seen_owner_started_at=true
                [ -n "$val" ] || return 1
                m_owner_started_at="$val"
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
        in_progress | complete | failed | restoring | restored) ;;
        *) return 1 ;;
    esac

    printf "version=%s\nid=%s\ncreated_at=%s\nrepo_revision=%s\nstate=%s\n" \
        "$m_version" "$m_id" "$m_created_at" "$m_repo_revision" "$m_state"
    if [ -n "$m_repo_root" ]; then
        printf "repo_root=%s\n" "$m_repo_root"
    fi
    if [ -n "$m_owner_pid" ]; then
        printf "owner_pid=%s\n" "$m_owner_pid"
    fi
    if [ -n "$m_owner_started_at" ]; then
        printf "owner_started_at=%s\n" "$m_owner_started_at"
    fi
    if [ -n "$m_entry_count" ]; then
        printf "entry_count=%s\n" "$m_entry_count"
    fi
    return 0
}

append_transaction_metadata_field() {
    local tmp_file="$1"
    local key="$2"
    local value="$3"
    if ! printf "%s=%s\n" "$key" "$value" >>"$tmp_file"; then
        rm -f "$tmp_file" 2>/dev/null || true
        return 1
    fi
}

# Write a new transaction metadata file. Always sets version=1.
write_transaction_metadata() {
    local tx_dir="$1"
    local id="$2"
    local created_at="$3"
    local repo_rev="$4"
    local state="$5"
    local entry_count="${6:-}"
    local repo_root="${7:-}"
    local owner_pid="${8:-}"
    local owner_started_at="${9:-}"

    validate_transaction_id "$id" || return 1
    case "$state" in
        in_progress | complete | failed | restoring | restored) ;;
        *) return 1 ;;
    esac
    [ -n "$created_at" ] || return 1
    [ -n "$repo_rev" ] || return 1
    if [ -n "$repo_root" ]; then
        [[ "$repo_root" = /* ]] || return 1
        [[ "$repo_root" != *$'\n'* && "$repo_root" != *$'\r'* && "$repo_root" != *"|"* ]] || return 1
    fi
    if [ -n "$owner_pid" ]; then
        [[ "$owner_pid" =~ ^[1-9][0-9]*$ ]] || return 1
    fi
    if [ -n "$owner_started_at" ]; then
        [[ "$owner_started_at" != *$'\n'* && "$owner_started_at" != *$'\r'* && "$owner_started_at" != *"|"* ]] || return 1
    fi

    local meta_file="$tx_dir/metadata"
    local tmp_file
    tmp_file="$(mktemp "$tx_dir/metadata.tmp.XXXXXX")" || return 1

    append_transaction_metadata_field "$tmp_file" version 1 || return 1
    append_transaction_metadata_field "$tmp_file" id "$id" || return 1
    append_transaction_metadata_field "$tmp_file" created_at "$created_at" || return 1
    append_transaction_metadata_field "$tmp_file" repo_revision "$repo_rev" || return 1
    append_transaction_metadata_field "$tmp_file" state "$state" || return 1
    if [ -n "$repo_root" ]; then
        append_transaction_metadata_field "$tmp_file" repo_root "$repo_root" || return 1
    fi
    if [ -n "$owner_pid" ]; then
        append_transaction_metadata_field "$tmp_file" owner_pid "$owner_pid" || return 1
    fi
    if [ -n "$owner_started_at" ]; then
        append_transaction_metadata_field "$tmp_file" owner_started_at "$owner_started_at" || return 1
    fi
    if [ -n "$entry_count" ]; then
        append_transaction_metadata_field "$tmp_file" entry_count "$entry_count" || return 1
    fi
    if ! mv -f "$tmp_file" "$meta_file"; then
        rm -f "$tmp_file" 2>/dev/null || true
        return 1
    fi
    sync_file_and_parent "$meta_file"
}

# Update state in metadata by rewriting through a temporary file in the same directory.
update_transaction_state() {
    local tx_dir="$1"
    local new_state="$2"
    local entry_count="${3:-}"

    [ -d "$tx_dir" ] && [ ! -L "$tx_dir" ] || return 1

    case "$new_state" in
        in_progress | complete | failed | restoring | restored) ;;
        *) return 1 ;;
    esac

    local meta_file="$tx_dir/metadata"
    [ -f "$meta_file" ] && [ ! -L "$meta_file" ] || return 1

    # Verify current metadata validity first
    read_transaction_metadata "$meta_file" >/dev/null || return 1

    local tmp_file
    tmp_file="$(mktemp "$tx_dir/metadata.tmp.XXXXXX")" || return 1
    local key val
    local wrote_entry_count=false
    while IFS='=' read -r key val || [ -n "$key" ]; do
        [ -z "$key" ] && continue
        if [ "$key" = "state" ]; then
            append_transaction_metadata_field "$tmp_file" state "$new_state" || return 1
        elif [ "$key" = "entry_count" ]; then
            if [ -n "$entry_count" ]; then
                append_transaction_metadata_field "$tmp_file" entry_count "$entry_count" || return 1
            else
                append_transaction_metadata_field "$tmp_file" entry_count "$val" || return 1
            fi
            wrote_entry_count=true
        else
            append_transaction_metadata_field "$tmp_file" "$key" "$val" || return 1
        fi
    done <"$meta_file"
    if [ "$wrote_entry_count" = false ] && [ -n "$entry_count" ]; then
        append_transaction_metadata_field "$tmp_file" entry_count "$entry_count" || return 1
    fi

    if ! mv -f "$tmp_file" "$meta_file"; then
        rm -f "$tmp_file" 2>/dev/null || true
        return 1
    fi
    sync_file_and_parent "$meta_file"
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
    local entries_file="$tx_dir/entries"
    local tmp_file
    [ ! -L "$entries_file" ] && { [ ! -e "$entries_file" ] || [ -f "$entries_file" ]; } || return 1
    validate_journal_entry "$seq" "$target" "$kind" "$val" "$installed" || return 1
    tmp_file="$(mktemp "$tx_dir/entries.tmp.XXXXXX")" || return 1
    if { [ ! -e "$entries_file" ] || cat "$entries_file"; } >"$tmp_file" &&
        printf "%s|%s|%s|%s|%s\n" "$seq" "$target" "$kind" "$val" "$installed" >>"$tmp_file" &&
        sync_file_and_parent "$tmp_file" &&
        mv -f "$tmp_file" "$entries_file"; then
        sync_file_and_parent "$entries_file"
        return
    fi
    rm -f "$tmp_file" 2>/dev/null || true
    return 1
}

# Resolve a transaction ID from 'latest' or an explicit ID.
# Checks that the directory exists under DOTFILES_BACKUP_ROOT and metadata is valid.
# If 'latest' is given, verifies the transaction ID points to a transaction
# that is ready to restore, being restored, or already restored.
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
        case "$state" in
            in_progress | complete | restoring | restored) ;;
            *) return 1 ;;
        esac
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
