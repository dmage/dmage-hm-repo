import sublime
import sublime_plugin
import os
import time
import subprocess
from threading import Thread


def _tm_script(path, filename, code, script, success_message):
    p = subprocess.Popen(["/bin/sh", "-s", path, filename],
                         stdin=subprocess.PIPE,
                         stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                         universal_newlines=True)
    (out, err) = p.communicate("""
        DISABLE=
        WORKDIR=$1
        FILENAME=$2
        . "$WORKDIR/.tm_sync.config"

        if [[ -n "$DISABLE" ]]; then
            exit
        fi

        : ${REMOTE_USER:=$(whoami)}
        : ${REMOTE_PORT:=22}
        : ${RSYNC_OPTIONS:=}
    """ + script)

    retcode = p.returncode
    if retcode is None:
        sublime.error_message("RemoteSync: unexpected error, " + code +
                              " still running.\n" + err)
        return False
    elif retcode != 0:
        sublime.error_message("RemoteSync: " + code + " failed.\n" + err)
        return False

    def done():
        sublime.status_message(success_message)
    sublime.set_timeout(done, 0)
    return True


class TmSyncThread(Thread):
    def __init__(self, path, filename):
        Thread.__init__(self)
        self.path = path
        self.filename = filename

    def run(self):
        done = _tm_script(self.path, self.filename, "rsync", """
            REMOTE_MACHINE="$REMOTE_USER@$REMOTE_HOST"
            FILE=${FILENAME/$WORKDIR\//}
            DIR=`dirname "$REMOTE_PATH/$FILE"`

            RSYNC_CMD="rsync -av --exclude=.tm_sync.config $RSYNC_OPTIONS"
            ssh -n -p "$REMOTE_PORT" "$REMOTE_MACHINE" mkdir -p "$DIR"
            $RSYNC_CMD -e "ssh -p $REMOTE_PORT" \\
                "$WORKDIR/$FILE" "$REMOTE_MACHINE:$REMOTE_PATH/$FILE"
            RSYNC_RETCODE=$?

            exit $RSYNC_RETCODE
        """, "File " + self.filename + " synced")
        if not done:
            return

        done = _tm_script(self.path, self.filename, "local command", """
            if [[ -n "$LOCAL_POST_COMMAND" ]]; then
                cd "$WORKDIR"
                eval "$LOCAL_POST_COMMAND"
            fi
        """, "Local command completed successfully")
        if not done:
            return

        done = _tm_script(self.path, self.filename, "remote command", """
            if [[ -n "$REMOTE_POST_COMMAND" ]]; then
                ssh -f -p "$REMOTE_PORT" "$REMOTE_USER@$REMOTE_HOST" -- \
                    "cd \"$REMOTE_PATH\" && $REMOTE_POST_COMMAND"
            fi
        """, "Remote command completed successfully")
        if not done:
            return


class RsyncOnSave(sublime_plugin.EventListener):
    def run_tm_sync(self, view, path):
        thread = TmSyncThread(path, view.file_name())
        thread.start()

    def on_post_save(self, view):
        filename = view.file_name()
        if filename is None:
            return

        dirname = os.path.dirname(filename)
        while True:
            if os.path.exists(os.path.join(dirname, '.tm_sync.config')):
                self.run_tm_sync(view, dirname)
                return

            next_dirname = os.path.dirname(dirname)
            if next_dirname == dirname:
                break
            dirname = next_dirname
