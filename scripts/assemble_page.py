#!/usr/bin/env python3
"""assemble_page.py — build the final sales page: inject NOTICE.md (rendered to minimal HTML)
into the staged index.html's {{NOTICE_HTML}} slot. The claims section of the live page is
thereby GENERATED from the scorecard-derived NOTICE — never hand-written (house law).
Output: dist/page/index.html (what tank serves at /backstage)."""
import html, pathlib, re

root = pathlib.Path.home() / "dev/backstage"
staged = pathlib.Path.home() / "Desktop/lore/deliverables/2026-08-31/backstage-site/index.html"
notice = (root / "NOTICE.md").read_text()
out_dir = root / "dist/page"
out_dir.mkdir(parents=True, exist_ok=True)

def md_to_html(md: str) -> str:
    lines, out, in_ul, in_code = md.split("\n"), [], False, False
    for ln in lines:
        if ln.startswith("```"):
            out.append("</ul>" if in_ul else "")
            in_ul = False
            out.append("</pre>" if in_code else "<pre>")
            in_code = not in_code
            continue
        if in_code:
            out.append(html.escape(ln))
            continue
        esc = html.escape(ln)
        esc = re.sub(r"\*\*(.+?)\*\*", r"<strong>\1</strong>", esc)
        esc = re.sub(r"_\((.+?)\)_", r"<em>(\1)</em>", esc)
        esc = re.sub(r"`(.+?)`", r"<code>\1</code>", esc)
        if esc.startswith("# "):
            if in_ul: out.append("</ul>"); in_ul = False
            out.append(f"<h3>{esc[2:]}</h3>")
        elif esc.startswith("## "):
            if in_ul: out.append("</ul>"); in_ul = False
            out.append(f"<h4>{esc[3:]}</h4>")
        elif esc.startswith("- "):
            if not in_ul: out.append("<ul>"); in_ul = True
            out.append(f"<li>{esc[2:]}</li>")
        elif esc.strip() == "":
            if in_ul: out.append("</ul>"); in_ul = False
        else:
            if in_ul: out.append("</ul>"); in_ul = False
            out.append(f"<p>{esc}</p>")
    if in_ul: out.append("</ul>")
    return "\n".join(x for x in out if x)

page = staged.read_text()
assert "{{NOTICE_HTML}}" in page, "staged page missing NOTICE_HTML slot"
page = page.replace("{{NOTICE_HTML}}", md_to_html(notice))
assert "{{" not in page, "unresolved placeholder remains: " + ",".join(set(re.findall(r"{{\w+}}", page)))
(out_dir / "index.html").write_text(page)
print(f"page assembled → {out_dir/'index.html'} ({len(page.encode())/1024:.1f}KB)")
