"""Build WORKING_PAPER_rev1.docx from WORKING_PAPER_rev1.md.

Usage: python3 build_working_paper_rev1.py
Needs pandoc. Adds NTIA styling (Times New Roman, dark blue headings), US Letter
pages with 1-inch margins, and DRAFT//PRE-DECISIONAL in every page header and
footer, which pandoc can't carry over from a reference file.
"""
import re
import shutil
import subprocess
import tempfile
import zipfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
SRC = HERE / "WORKING_PAPER_rev1.md"
OUT = HERE / "WORKING_PAPER_rev1.docx"
MARKING = "DRAFT//PRE-DECISIONAL"
DARK_BLUE = "163353"
FONT = "Times New Roman"

# 1) Markdown for pandoc: HTML subscripts become pandoc subscripts, figures
#    fill the text width, and the in-body marking line is dropped because the
#    header and footer carry it.
md = SRC.read_text(encoding="utf-8")
md = re.sub(r"<sub>(.*?)</sub>", lambda m: "~" + m.group(1).replace(" ", "\\ ") + "~", md)
md = re.sub(r"(!\[[^\]]*\]\(figures/[^)]+\.png\))", r"\1{width=6.5in}", md)
md = md.replace(MARKING + "\n\n", "", 1)
# Put each figure title and its image in one paragraph so they can't split.
md = re.sub(r"(\*\*Figure \d+\.[^\n]*\*\*)\n\n(!\[)", r"\1\\\n\2", md)

with tempfile.TemporaryDirectory() as tmp:
    tmp = Path(tmp)
    (tmp / "paper.md").write_text(md, encoding="utf-8")
    raw = tmp / "raw.docx"
    subprocess.run(["pandoc", str(tmp / "paper.md"), "-f", "markdown-implicit_figures+subscript",
                    "-t", "docx", "--resource-path", str(HERE), "-o", str(raw)], check=True)

    # 2) Post-process the package.
    with zipfile.ZipFile(raw) as z:
        parts = {n: z.read(n) for n in z.namelist() if not n.endswith("/")}

    styles = parts["word/styles.xml"].decode("utf-8")
    # Every text font: Times New Roman. Headings and titles: dark blue.
    styles = re.sub(r'<w:rFonts [^>]*/>', f'<w:rFonts w:ascii="{FONT}" w:hAnsi="{FONT}" '
                    f'w:eastAsia="{FONT}" w:cs="{FONT}"/>', styles)
    styles = styles.replace("<w:rPrDefault><w:rPr>",
                            f'<w:rPrDefault><w:rPr><w:rFonts w:ascii="{FONT}" w:hAnsi="{FONT}" '
                            f'w:eastAsia="{FONT}" w:cs="{FONT}"/>', 1)
    # Pandoc 3.1's default template has a stray ">" after one color element.
    styles = re.sub(r'<w:color\b[^>]*/>(?:>|&gt;)?', f'<w:color w:val="{DARK_BLUE}"/>', styles)
    # Table style: light horizontal rules so tables read in print.
    styles = re.sub(
        r'(<w:style w:type="table" w:default="1" w:styleId="Table">.*?<w:tblPr>)',
        r'\1<w:tblBorders><w:top w:val="single" w:sz="4" w:color="8A8D91"/>'
        r'<w:bottom w:val="single" w:sz="4" w:color="8A8D91"/>'
        r'<w:insideH w:val="single" w:sz="2" w:color="E6E6E6"/></w:tblBorders>',
        styles, count=1, flags=re.S)
    parts["word/styles.xml"] = styles.encode("utf-8")

    def marking_part(tag):
        return (f'<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
                f'<w:{tag} xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
                f'<w:p><w:pPr><w:jc w:val="center"/></w:pPr><w:r><w:rPr><w:b/>'
                f'<w:rFonts w:ascii="{FONT}" w:hAnsi="{FONT}"/><w:color w:val="{DARK_BLUE}"/>'
                f'<w:sz w:val="20"/></w:rPr><w:t>{MARKING}</w:t></w:r></w:p>'
                + ('' if tag == "hdr" else
                   f'<w:p><w:pPr><w:jc w:val="center"/></w:pPr><w:r><w:rPr>'
                   f'<w:rFonts w:ascii="{FONT}" w:hAnsi="{FONT}"/><w:color w:val="{DARK_BLUE}"/>'
                   f'<w:sz w:val="18"/></w:rPr><w:t xml:space="preserve">Page </w:t></w:r>'
                   f'<w:r><w:rPr><w:sz w:val="18"/></w:rPr><w:fldChar w:fldCharType="begin"/></w:r>'
                   f'<w:r><w:rPr><w:sz w:val="18"/></w:rPr><w:instrText xml:space="preserve"> PAGE </w:instrText></w:r>'
                   f'<w:r><w:rPr><w:sz w:val="18"/></w:rPr><w:fldChar w:fldCharType="separate"/></w:r>'
                   f'<w:r><w:rPr><w:sz w:val="18"/></w:rPr><w:t>1</w:t></w:r>'
                   f'<w:r><w:rPr><w:sz w:val="18"/></w:rPr><w:fldChar w:fldCharType="end"/></w:r></w:p>')
                + f'</w:{tag}>').encode("utf-8")

    parts["word/header1.xml"] = marking_part("hdr")
    parts["word/footer1.xml"] = marking_part("ftr")

    rels = parts["word/_rels/document.xml.rels"].decode("utf-8")
    rels = rels.replace("</Relationships>",
        '<Relationship Id="rIdMarkHdr" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/header" Target="header1.xml"/>'
        '<Relationship Id="rIdMarkFtr" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/footer" Target="footer1.xml"/>'
        "</Relationships>")
    parts["word/_rels/document.xml.rels"] = rels.encode("utf-8")

    ctypes = parts["[Content_Types].xml"].decode("utf-8")
    if 'Extension="png"' not in ctypes:
        ctypes = ctypes.replace("<Default ", '<Default Extension="png" ContentType="image/png"/><Default ', 1)
    ctypes = ctypes.replace("</Types>",
        '<Override PartName="/word/header1.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.header+xml"/>'
        '<Override PartName="/word/footer1.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.footer+xml"/>'
        "</Types>")
    parts["[Content_Types].xml"] = ctypes.encode("utf-8")

    doc = parts["word/document.xml"].decode("utf-8")
    # Keep each figure title with its image, and each image with its caption.
    def keep_next(par):
        if "<w:keepNext/>" in par:
            return par
        if "<w:pPr>" in par:
            # Schema order: pStyle comes before keepNext.
            if re.search(r"<w:pPr><w:pStyle [^>]*/>", par):
                return re.sub(r"(<w:pPr><w:pStyle [^>]*/>)", r"\1<w:keepNext/>", par, count=1)
            return par.replace("<w:pPr>", "<w:pPr><w:keepNext/>", 1)
        return re.sub(r"^<w:p(\b[^>]*)>", r"<w:p\1><w:pPr><w:keepNext/></w:pPr>", par, count=1)
    def fix_par(m):
        par = m.group(0)
        text = "".join(re.findall(r"<w:t[^>]*>([^<]*)</w:t>", par))
        if re.match(r"Figure \d+\. ", text) or "<w:drawing>" in par:
            return keep_next(par)
        return par
    doc = re.sub(r"<w:p\b[^>]*>.*?</w:p>", fix_par, doc, flags=re.S)
    sect = ('<w:sectPr><w:headerReference w:type="default" r:id="rIdMarkHdr"/>'
            '<w:footerReference w:type="default" r:id="rIdMarkFtr"/>'
            '<w:pgSz w:w="12240" w:h="15840"/>'
            '<w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440" '
            'w:header="720" w:footer="720" w:gutter="0"/></w:sectPr>')
    doc, n = re.subn(r"<w:sectPr\b.*?</w:sectPr>|<w:sectPr\b[^>]*/>", sect, doc, count=1, flags=re.S)
    if n == 0:
        doc = doc.replace("</w:body>", sect + "</w:body>")
    if 'xmlns:r="' not in doc[:2000]:
        raise RuntimeError("document.xml lacks the relationships namespace")
    parts["word/document.xml"] = doc.encode("utf-8")

    tmp_out = tmp / "out.docx"
    with zipfile.ZipFile(tmp_out, "w", zipfile.ZIP_DEFLATED) as z:
        order = ["[Content_Types].xml"] + [n for n in parts if n != "[Content_Types].xml"]
        for n in order:
            z.writestr(n, parts[n])
    shutil.copyfile(tmp_out, OUT)
print(f"Wrote {OUT.name}")
