#!/bin/false

color() {
    if [ -n "$TERM" ]; then
        tput -T "$TERM" "$@"
    fi
}

COLOR_BOLD=$(color bold)
COLOR_RED=$(color setaf 1)
COLOR_GREEN=$(color setaf 2)
COLOR_BLUE=$(color setaf 4)
COLOR_YELLOW=$(color setaf 3)
COLOR_RESET=$(color sgr0)

LOCAL_RSYNC="rsync"
REMOTE_RSYNC="rsync -e ssh"

pkgname() {
    echo "$COLOR_BOLD$COLOR_GREEN$*$COLOR_RESET"
}

prefix() {
    echo "$COLOR_BOLD$COLOR_YELLOW$*$COLOR_RESET"
}

alert() {
    echo "$COLOR_BOLD$COLOR_BLUE$*$COLOR_RESET"
}

install_pkg() {
    local PKG=$(cd $1; pwd -P)
    local PREFIX=${2-}

    local REPO=$(cd "$PKG/.."; pwd -P)
    local REPO_NAME=$(basename "$REPO")
    local PKG_NAME=$(basename "$PKG")
    
    echo "$(prefix "$PREFIX>>>") $(pkgname "$REPO_NAME/$PKG_NAME")"

    if [ -d "$PKG/inherit" ]; then
        for INHERIT_PKG in "$PKG/inherit"/*; do
            install_pkg "$INHERIT_PKG" "$PREFIX    "
        done
    fi

    echo "$(prefix "$PREFIX>>>") $(pkgname "$REPO_NAME/$PKG_NAME") in progress..."

    if [ -x "$PKG/preinst" ]; then
        pushd "$FAKE_ROOT" >/dev/null
        "$PKG/preinst"
        popd >/dev/null
    fi

    if [ -d "$PKG/files" ]; then
        mkdir -p "$FAKE_FILES_DIR/$REPO_NAME/$PKG_NAME"
        $LOCAL_RSYNC -av "$PKG/files/" "$FAKE_FILES_DIR/$REPO_NAME/$PKG_NAME/"
        create_symlinks_for_pkg_files "$REPO_NAME/$PKG_NAME"
    fi

    if [ -x "$PKG/postinst" ]; then
        pushd "$FAKE_ROOT" >/dev/null
        "$PKG/postinst"
        popd >/dev/null
    fi

    echo "$(prefix "$PREFIX>>>") $(pkgname "$REPO_NAME/$PKG_NAME") done"
}

create_symlinks_for_pkg_files() {
    local REPO_AND_PKG_NAME=$1

    while IFS= read -r -d $'\0' file; do
        mkdir -p "$(dirname "$FAKE_ROOT/${file#./}")"
        ln -s "$REAL_FILES_DIR/$REPO_AND_PKG_NAME/${file#./}" "$FAKE_ROOT/${file#./}"
        printf "%s\0" "$REAL_ROOT/${file#./}" >>"$FAKE_INDEX"
    done < <(cd "$FAKE_FILES_DIR/$REPO_AND_PKG_NAME"; find . -not -type d -print0)
}

create_symlinks_for_all_pkg_files() {
    pushd "$FAKE_FILES_DIR" >/dev/null
    REPO_AND_PKG_ARRAY=(*/*)
    popd >/dev/null

    for REPO_AND_PKG_NAME in "${REPO_AND_PKG_ARRAY[@]}"; do
        create_symlinks_for_pkg_files "$REPO_AND_PKG_NAME"
    done
}

self_content() {
    cat hm-funcs.bash
}

real_state() {
    echo "# real_state dump"
    for REAL_VAR in "${!REAL_@}"; do
        printf '%s=%q\n' "$REAL_VAR" "${!REAL_VAR}"
    done
    echo
}

real_bash() {
    if [ -n "${REAL_HOST:-}" ]; then
        ssh -T "$REAL_HOST" bash
    else
        bash
    fi
}

rsync_real_prefix() {
    if [ -n "${REAL_HOST:-}" ]; then
        echo "${REAL_HOST:-}:"
    fi
}

rsync_files_dir() {
    echo "$(prefix ">>>") $(alert "merging hm-files into real system ($REAL_FILES_DIR, backup: $REAL_BACKUP_FILES_DIR)")"
    (
real_state
self_content
cat <<-EOF
create_backup_files_dir
EOF
    ) | real_bash

    $REMOTE_RSYNC --backup-dir="$REAL_BACKUP_FILES_DIR" --backup -av --delete "$FAKE_FILES_DIR/" "$(rsync_real_prefix)$REAL_FILES_DIR/"
    (
real_state
self_content
cat <<-EOF
remove_backup_files_dir_if_empty
EOF
    ) | real_bash
}

rsync_root() {
    echo "$(prefix ">>>") $(alert "merging packages into real system ($REAL_ROOT, backup: $REAL_BACKUP_ROOT)")"
    (
real_state
self_content
cat <<EOF
create_backup_root
EOF
    ) | real_bash

    $REMOTE_RSYNC --backup-dir="$REAL_BACKUP_ROOT" --backup -av "$FAKE_ROOT/" "$(rsync_real_prefix)$REAL_ROOT/"

    echo "$(prefix ">>>") $(alert "searching for broken links")"
    (
real_state
self_content
cat <<-EOF
remove_broken_links
remove_backup_root_if_empty
EOF
    ) | real_bash
}

rsync_index() {
    $REMOTE_RSYNC -a "$FAKE_INDEX" "$(rsync_real_prefix)$REAL_INDEX"
}

create_backup_files_dir() {
    mkdir -p "$REAL_BACKUP_FILES_DIR"
}

remove_backup_files_dir_if_empty() {
    [ $(ls -1A "$REAL_BACKUP_FILES_DIR" | wc -l) -eq 0 ] && echo "removing empty backup directory $REAL_BACKUP_FILES_DIR" && rmdir "$REAL_BACKUP_FILES_DIR"
}

create_backup_root() {
    mkdir -p "$REAL_BACKUP_ROOT"
}

remove_broken_links() {
    while IFS= read -r -d $'\0' file; do
        LINK_TARGET=$(readlink "$file")
        if [[ "x$LINK_TARGET" != "x${LINK_TARGET#$REAL_FILES_DIR/}" ]]; then
            mkdir -p "$(dirname "$REAL_BACKUP_ROOT/${file#$REAL_ROOT/}")"
            mv -vnT "$file" "$REAL_BACKUP_ROOT/${file#$REAL_ROOT/}"
            rmdir -p "$(dirname "$file")" 2>/dev/null || true
        fi
    done < <(test -r "$REAL_INDEX" && xargs -0 -I'{}' -a "$REAL_INDEX" find -L '{}' -type l -print0 || find -L "$REAL_ROOT" -type l -print0 2>/dev/null)
}

remove_backup_root_if_empty() {
    [ $(ls -1A "$REAL_BACKUP_ROOT" | wc -l) -eq 0 ] && echo "removing empty backup directory $REAL_BACKUP_ROOT" && rmdir "$REAL_BACKUP_ROOT"
}

cleanup() {
    rm -rf "$FAKE_ROOT"
    rm -rf "$FAKE_FILES_DIR"
    rm -f "$FAKE_INDEX"
    rmdir "$FAKE_TMP_DIR"
}
