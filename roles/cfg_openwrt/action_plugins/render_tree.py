"""
Render a template tree and copy a static file tree into a destination
directory, all within a single task.

Looping the template/copy/file modules over every file costs a module run per
file and makes rendering all hosts take minutes. This action renders the
templates in-process with the same settings as the template action and writes
the results directly, which only works because the playbook runs with
connection: local.

Options:
  templates: directory of Jinja2 templates; only *.j2 files are rendered and
             written without the .j2 suffix
  files:     directory of static files; *.j2 files are skipped
  dest:      destination directory
  target:    path that dest corresponds to on the device, used when printing
             the changed paths (default: dest)
  modes:     optional {relative dest path: octal mode string} overrides.
             Files default to the mode of their source (following symlinks),
             directories default to 755.

Returns files, the sorted list of all managed files, and changed_files, the
written or chmod'ed paths. All files are also printed with their status, as
the callback only shows the result with -v. Supports --check and --diff
(content diffs like the copy action, mode changes and new directories like
the file module).
"""

from __future__ import annotations

import os
import stat

from ansible import constants as C
from ansible._internal._templating import _template_vars
from ansible.errors import AnsibleActionFail
from ansible.module_utils.common.text.converters import to_text
from ansible.plugins.action import ActionBase
from ansible.template import trust_as_template
from ansible.utils.color import stringc
from ansible.utils.display import Display

display = Display()

# Same Jinja2 settings as the template action
TEMPLATE_OVERRIDES = {
    "trim_blocks": True,
    "lstrip_blocks": False,
    "newline_sequence": "\n",
}


def line_count(before, after):
    """Describe the line count of after, and of before if it differs."""
    if b"\x00" in after:
        return "binary"
    count = len(after.splitlines())
    if before is None:
        return f"{count} lines"
    if b"\x00" in before:
        return f"binary -> {count} lines"
    before_count = len(before.splitlines())
    if before_count == count:
        return f"{count} lines"
    return f"{before_count} -> {count} lines"


def content_diff(path, before, after):
    """Return a content diff in the format of the copy action.

    Unlike the copy action, binary and large files get a placeholder line, as
    the callback's own message for those doesn't name the file and one task
    covers many files here.
    """
    diff = {"before_header": path, "after_header": path}
    for key, data in (("before", before), ("after", after)):
        if data is None:
            diff[key] = ""
        elif 0 < C.MAX_FILE_SIZE_FOR_DIFF < len(data):  # pylint: disable=no-member
            diff[key] = f"(diff skipped, file has {len(data)} bytes)\n"
        elif b"\x00" in data:
            diff[key] = f"(diff skipped, binary file with {len(data)} bytes)\n"
        else:
            diff[key] = to_text(data, errors="surrogate_or_strict")
    return diff


def state_diff(path, before, after):
    """Return a diff of path attributes in the format of the file module."""
    return {"before": {"path": path, **before}, "after": {"path": path, **after}}


class _TreeRenderer:
    """Render templates and copy files into one destination directory."""

    def __init__(self, templar, task_vars, args, check_mode):
        self.templar = templar
        self.task_vars = task_vars
        self.dest = args["dest"]
        self.modes = {
            os.path.normpath(k): int(str(v), 8)
            for k, v in (args.get("modes") or {}).items()
        }
        self.check_mode = check_mode
        # relative path -> {"file", "old_mode", "mode", "lines", "what"}, with
        # what listing the changes ("new", "content", "mode")
        self.entries = {}
        self.diffs = []

    def note(self, rel, what):
        """Record a change of rel."""
        self.entries[rel]["what"].append(what)

    def make_dir(self, rel):
        """Create directory rel if needed and set its mode."""
        path = os.path.join(self.dest, rel)
        mode = self.modes.get(rel, 0o755)
        # templates/ and files/ can share a directory, handle it only once
        if rel in self.entries:
            return
        exists = os.path.isdir(path)
        current = stat.S_IMODE(os.stat(path).st_mode) if exists else None
        self.entries[rel] = {
            "file": False,
            "old_mode": current,
            "mode": mode,
            "lines": "",
            "what": [],
        }
        if not exists:
            self.note(rel, "new")
            self.diffs.append(
                state_diff(
                    path,
                    {"state": "absent"},
                    {"state": "directory", "mode": f"{mode:04o}"},
                )
            )
            if not self.check_mode:
                os.makedirs(path)
                os.chmod(path, mode)
        elif current != mode:
            self.note(rel, "mode")
            self.diffs.append(
                state_diff(path, {"mode": f"{current:04o}"}, {"mode": f"{mode:04o}"})
            )
            if not self.check_mode:
                os.chmod(path, mode)

    def put_file(self, rel, data, src):
        """Write data to file rel if it differs and set its mode."""
        path = os.path.join(self.dest, rel)
        mode = self.modes.get(rel, stat.S_IMODE(os.stat(src).st_mode))
        # A symlink at the destination gets replaced by a regular file, like
        # the copy action does, instead of writing through it.
        is_link = os.path.islink(path)
        try:
            with open(path, "rb") as f:
                before = f.read()
            old_mode = stat.S_IMODE(os.stat(path).st_mode)
        except FileNotFoundError:
            before = old_mode = None
        self.entries[rel] = {
            "file": True,
            "old_mode": old_mode,
            "mode": mode,
            "lines": line_count(before, data),
            "what": [],
        }
        write = before != data or is_link
        if write:
            self.note(rel, "new" if before is None else "content")
            self.diffs.append(content_diff(path, before, data))
        if old_mode is not None and old_mode != mode:
            self.note(rel, "mode")
            self.diffs.append(
                state_diff(path, {"mode": f"{old_mode:04o}"}, {"mode": f"{mode:04o}"})
            )
        if self.check_mode:
            return
        if write:
            # Write atomically, so an interrupted run leaves no partial file
            tmp_path = path + ".render_tree.tmp"
            with open(tmp_path, "wb") as f:
                f.write(data)
            os.chmod(tmp_path, mode)
            os.replace(tmp_path, path)
        elif old_mode != mode:
            os.chmod(path, mode)

    def render(self, src, loader, rel):
        """Render template src like the template action does."""
        temp_vars = self.task_vars.copy()
        temp_vars.update(
            _template_vars.generate_ansible_template_vars(
                path=src,
                fullpath=src,
                dest_path=os.path.join(self.dest, rel),
                include_ansible_managed="ansible_managed" not in temp_vars,
            )
        )
        searchpath = []
        for path in list(self.task_vars.get("ansible_search_path", [])) + [
            loader.get_basedir(),
            os.path.dirname(src),
        ]:
            searchpath.extend([os.path.join(path, "templates"), path])
        templar = self.templar.copy_with_new_env(
            searchpath=searchpath, available_variables=temp_vars
        )
        # Read like the template action, so errors name the template
        template_data = trust_as_template(loader.get_text_file_contents(src))
        resultant = templar.template(
            template_data, escape_backslashes=False, overrides=TEMPLATE_OVERRIDES
        )
        return (resultant or "").encode("utf-8")

    def walk(self, kind, root, loader):
        """Render or copy all files below root."""
        for dirpath, dirnames, filenames in os.walk(root):
            dirnames.sort()
            rel_dir = os.path.normpath(os.path.relpath(dirpath, root))
            if rel_dir != ".":
                self.make_dir(rel_dir)
            for name in sorted(filenames):
                src = os.path.join(dirpath, name)
                rel = os.path.normpath(os.path.join(rel_dir, name))
                if kind == "templates" and name.endswith(".j2"):
                    self.put_file(rel[:-3], self.render(src, loader, rel[:-3]), src)
                elif kind == "files" and not name.endswith(".j2"):
                    with open(src, "rb") as f:
                        self.put_file(rel, f.read(), src)

    def changed_files(self):
        """Return the sorted relative paths that changed."""
        return sorted(rel for rel, entry in self.entries.items() if entry["what"])

    def files(self):
        """Return the sorted relative paths of all managed files."""
        return sorted(rel for rel, entry in self.entries.items() if entry["file"])

    def summary(self, host, target):
        """Return one block per host, so the lines of parallel hosts don't mix."""
        rows = []
        for rel in sorted(self.entries):
            entry = self.entries[rel]
            # A new directory is implied by the paths below it, so only list
            # it when it is empty.
            if (
                not entry["file"]
                and entry["what"] == ["new"]
                and any(
                    other != rel and (rel == "." or other.startswith(rel + os.sep))
                    for other in self.entries
                )
            ):
                continue
            rows.append(self._row(rel, entry, target))
        file_rows = [row for row in rows if row["file"]]
        new = sum(1 for row in file_rows if row["status"] == "new")
        changed = sum(1 for row in file_rows if row["status"] == "changed")
        check = " (check mode)" if self.check_mode else ""
        header = (
            f"{host}: {len(self.files())} files, {new} new, {changed} changed{check}"
        )
        return "\n".join([header] + self._lines(rows))

    @staticmethod
    def _lines(rows):
        """Format the rows as aligned lines, coloured by status."""
        path_width = max((len(row["path"]) for row in rows), default=0)
        mode_width = max((len(row["mode"]) for row in rows), default=0)
        # pylint: disable-next=no-member
        colors = {"ok": C.COLOR_OK, "new": C.COLOR_CHANGED, "changed": C.COLOR_CHANGED}
        lines = []
        for row in rows:
            line = (
                f"  {row['status']:<7}  {row['path']:<{path_width}}"
                f"  {row['mode']:<{mode_width}}  {row['lines']}"
            )
            lines.append(stringc(line.rstrip(), colors[row["status"]]))
        return lines

    @staticmethod
    def _row(rel, entry, target):
        old_mode, mode, what = entry["old_mode"], entry["mode"], entry["what"]
        if old_mode is None or old_mode == mode:
            mode_text = f"{mode:04o}"
        else:
            mode_text = f"{old_mode:04o} -> {mode:04o}"
        if not what:
            status = "ok"
        elif "new" in what:
            status = "new"
        else:
            status = "changed"
        return {
            "status": status,
            "path": os.path.normpath(os.path.join(target, rel)),
            "mode": mode_text,
            "lines": entry["lines"],
            "file": entry["file"],
        }


class ActionModule(ActionBase):  # pylint: disable=too-few-public-methods
    """Render templates and copy static files into dest in a single task."""

    TRANSFERS_FILES = False
    _VALID_ARGS = frozenset(("templates", "files", "dest", "target", "modes"))

    def run(self, tmp=None, task_vars=None):
        """Render the trees and report the changed files."""
        if task_vars is None:
            task_vars = {}

        result = super().run(tmp, task_vars)
        del tmp

        args = self._task.args
        if not args.get("dest"):
            raise AnsibleActionFail("dest is required")
        renderer = _TreeRenderer(self._templar, task_vars, args, self._task.check_mode)

        roots = [
            (kind, args[kind])
            for kind in ("templates", "files")
            if args.get(kind) and os.path.isdir(args[kind])
        ]
        try:
            if roots:
                renderer.make_dir(".")
            for kind, root in roots:
                renderer.walk(kind, root, self._loader)
        except OSError as e:
            raise AnsibleActionFail(f"Failed to render {args['dest']}: {e}") from e

        result["changed_files"] = renderer.changed_files()
        result["changed"] = bool(result["changed_files"])
        result["files"] = renderer.files()
        if renderer.entries:
            display.display(
                renderer.summary(
                    task_vars.get("inventory_hostname"),
                    args.get("target", args["dest"]),
                )
            )
        if self._task.diff and renderer.diffs:
            result["diff"] = renderer.diffs
        return result
