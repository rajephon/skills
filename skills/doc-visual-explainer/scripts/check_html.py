#!/usr/bin/env python3
"""Structural checks for a single-file visual explainer page.

Usage: python3 check_html.py <file.html>

Checks
  - unclosed / mismatched tags (HTML + inline SVG)
  - duplicate id attributes
  - <title> present
  - CSS var() inside SVG presentation attributes (fill="var(--x)") - unreliable across browsers
  - marker ids referenced by url(#...) actually exist
  - inline <script> syntax via `node --check` when node is available
  - external resources other than Google Fonts or a version-pinned CDN
  - number of fill-in placeholders (class="todo" inside <main>, as the page counts them) and file size

Exit code 1 when an error is found; warnings alone exit 0.
"""
import html.parser
import os
import re
import shutil
import subprocess
import sys
import tempfile
from urllib.parse import urlparse

VOID = {
    "area", "base", "br", "col", "embed", "hr", "img", "input", "link", "meta",
    "source", "track", "wbr",
}
# tags whose src/href/data loads something into the page (<a href> is navigation, not a load)
RESOURCE_TAGS = {"script", "link", "img", "iframe", "source", "video", "audio", "embed", "object", "track", "image", "use"}
FONT_HOSTS = {"fonts.googleapis.com", "fonts.gstatic.com"}
CDN_HOSTS = {"cdnjs.cloudflare.com", "cdn.jsdelivr.net", "unpkg.com"}
PINNED = re.compile(r"@\d+\.\d+|/\d+\.\d+\.\d+/")
EXTERNAL = re.compile(r"(https?:)?//", re.I)


class Checker(html.parser.HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.stack = []
        self.errors = []
        self.ids = {}
        self.external = []  # (line, tag, url)
        self.main_depth = 0
        self.has_main = False
        self.todos_main = 0
        self.todos_all = 0

    def _attrs(self, tag, attrs):
        line = self.getpos()[0]
        for k, v in attrs:
            if k == "id" and v:
                self.ids.setdefault(v, []).append(line)
            if tag in RESOURCE_TAGS and k in ("src", "href", "xlink:href", "data") and v and EXTERNAL.match(v):
                self.external.append((line, tag, v))
        if "todo" in (dict(attrs).get("class") or "").split():
            self.todos_all += 1
            if self.main_depth:
                self.todos_main += 1

    def handle_starttag(self, tag, attrs):
        self._attrs(tag, attrs)
        if tag == "main":
            self.main_depth += 1
            self.has_main = True
        if tag not in VOID:
            self.stack.append((tag, self.getpos()[0]))

    def handle_startendtag(self, tag, attrs):
        self._attrs(tag, attrs)

    def handle_endtag(self, tag):
        if tag in VOID:
            return
        if tag == "main" and self.main_depth:
            self.main_depth -= 1
        if self.stack and self.stack[-1][0] == tag:
            self.stack.pop()
            return
        # look for a matching open tag further down to report what was left open
        for i in range(len(self.stack) - 1, -1, -1):
            if self.stack[i][0] == tag:
                for t, line in self.stack[i + 1:]:
                    self.errors.append(f"line {line}: <{t}> not closed before </{tag}> (line {self.getpos()[0]})")
                del self.stack[i:]
                return
        self.errors.append(f"line {self.getpos()[0]}: stray </{tag}>")


def external_ok(url):
    host = (urlparse("https:" + url if url.startswith("//") else url).hostname or "").lower()
    if host in FONT_HOSTS:
        return True
    return host in CDN_HOSTS and bool(PINNED.search(url))


def main():
    if len(sys.argv) != 2:
        print(__doc__)
        return 2
    path = sys.argv[1]
    src = open(path, encoding="utf-8").read()
    errors, warnings = [], []

    def line_of(pos):
        return src.count("\n", 0, pos) + 1

    c = Checker()
    c.feed(src)
    errors += c.errors
    for t, line in c.stack:
        if t not in ("html", "body", "head"):
            errors.append(f"line {line}: <{t}> never closed")
    for i, lines in c.ids.items():
        if len(lines) > 1:
            errors.append(f'duplicate id="{i}" on lines {lines}')

    if not re.search(r"<title>[^<]+</title>", src):
        errors.append("missing <title>")

    for m in re.finditer(r'\b(fill|stroke|stop-color|color)="var\(', src):
        warnings.append(f'line {line_of(m.start())}: {m.group(1)}="var(...)" in an attribute; use class or style="{m.group(1)}:var(...)"')

    defined = set(c.ids)
    for m in re.finditer(r"url\(#([^)]+)\)", src):
        if m.group(1) not in defined:
            errors.append(f"line {line_of(m.start())}: url(#{m.group(1)}) references a missing id")

    for line, tag, url in c.external:
        if not external_ok(url):
            warnings.append(f"line {line}: external <{tag}> {url} - allowed: Google Fonts, or a version-pinned CDN if really needed")
    for m in re.finditer(r"""(?:url\(\s*['"]?|@import\s+['"])((?:https?:)?//[^'")\s]+)""", src, re.I):
        if not external_ok(m.group(1)):
            warnings.append(f"line {line_of(m.start())}: external CSS resource {m.group(1)} - allowed: Google Fonts only")

    scripts = re.findall(r"<script(?![^>]*\bsrc=)[^>]*>(.*?)</script>", src, re.S)
    node = shutil.which("node")
    if scripts and node:
        for n, body in enumerate(scripts, 1):
            with tempfile.NamedTemporaryFile("w", suffix=".js", delete=False, encoding="utf-8") as f:
                f.write(body)
                tmp = f.name
            try:
                r = subprocess.run([node, "--check", tmp], capture_output=True, text=True)
                if r.returncode != 0:
                    errors.append(f"script #{n} syntax error:\n{r.stderr.strip()}")
            finally:
                os.unlink(tmp)
    elif scripts:
        warnings.append("node not found; skipped script syntax check")

    todos = c.todos_main if c.has_main else c.todos_all
    where = "inside <main>" if c.has_main else "whole page"
    size_kb = len(src.encode("utf-8")) // 1024

    for e in errors:
        print("ERROR  ", e)
    for w in warnings:
        print("WARN   ", w)
    print(f"INFO    fill-in placeholders (.todo, {where}): {todos}")
    print(f"INFO    size: {size_kb} KB, ids: {len(c.ids)}, inline scripts: {len(scripts)}")
    print("RESULT ", "FAIL" if errors else "OK")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
