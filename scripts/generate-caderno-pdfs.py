from pathlib import Path
import re

from PIL import Image
from pypdf import PdfReader, PdfWriter
from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER
from reportlab.lib.pagesizes import A4, landscape
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import cm
from reportlab.platypus import PageBreak, Paragraph, SimpleDocTemplate, Spacer, Table, TableStyle


ROOT = Path(__file__).resolve().parents[1]
MD_PATH = ROOT / "content" / "executivo" / "caderno-executivo.md"
PDF_DIR = ROOT / "pdf"
FULL_PDF = PDF_DIR / "caderno-executivo.pdf"
OVERVIEW_PDF = PDF_DIR / "caderno-executivo-visao-geral.pdf"
GOALS_PDF = PDF_DIR / "caderno-executivo-metas.pdf"
LOGO_PATH = ROOT / "assets" / "caixa-logo-sem-fundo.png"
FOOTER_IMG = ROOT / "assets" / "rodape-caixa.png"


def parse_front_matter(text):
    lines = text.splitlines()
    front = {}
    if lines and lines[0].strip() == "---":
        end = next((i for i in range(1, len(lines)) if lines[i].strip() == "---"), None)
        if end is not None:
            for line in lines[1:end]:
                match = re.match(r"([^:]+):\s*(.*)", line)
                if match:
                    front[match.group(1).strip()] = match.group(2).strip().strip('"').strip("'")
            return front, lines[end + 1 :]
    return front, lines


def escape(text):
    return (text or "").replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


def inline(text):
    text = escape(text.strip())
    text = re.sub(r"`([^`]+)`", r'<font name="Courier">\1</font>', text)
    text = re.sub(r"\*\*([^*]+)\*\*", r"<b>\1</b>", text)
    text = re.sub(r"_([^_]+)_", r"<i>\1</i>", text)
    return text


def split_table_row(line):
    text = line.strip()
    if text.startswith("|"):
        text = text[1:]
    if text.endswith("|"):
        text = text[:-1]
    return [cell.strip() for cell in text.split("|")]


def is_table_start(lines, index):
    return (
        index + 1 < len(lines)
        and lines[index].strip().startswith("|")
        and re.match(r"^\s*\|?\s*:?-{3,}", lines[index + 1])
    )


def heading_index(lines, heading):
    target = heading.lower()
    for index, line in enumerate(lines):
        if line.strip().lower() == target:
            return index
    return -1


def next_heading_index(lines, start, level_prefixes=("# ", "## ")):
    for index in range(start + 1, len(lines)):
        stripped = lines[index].strip()
        if any(stripped.startswith(prefix) for prefix in level_prefixes):
            return index
    return len(lines)


def table_after_heading(lines, heading):
    start = heading_index(lines, heading)
    if start < 0:
        return [], []
    for index in range(start + 1, len(lines) - 1):
        if is_table_start(lines, index):
            header = split_table_row(lines[index])
            rows = []
            cursor = index + 2
            while cursor < len(lines) and lines[cursor].strip().startswith("|"):
                rows.append(split_table_row(lines[cursor]))
                cursor += 1
            return header, rows
    return [], []


def bullets_after_heading(lines, heading):
    start = heading_index(lines, heading)
    if start < 0:
        return []
    end = next_heading_index(lines, start, ("# ", "## "))
    bullets = []
    for line in lines[start + 1 : end]:
        stripped = line.strip()
        if stripped.startswith("- "):
            bullets.append(stripped[2:].strip())
    return bullets


def paragraphs_after_heading(lines, heading):
    start = heading_index(lines, heading)
    if start < 0:
        return []
    end = next_heading_index(lines, start, ("# ", "## "))
    paragraphs = []
    current = []
    for line in lines[start + 1 : end]:
        stripped = line.strip()
        if not stripped:
            if current:
                paragraphs.append(" ".join(current))
                current = []
            continue
        if stripped.startswith("|") or stripped.startswith("- ") or stripped.startswith("<div"):
            continue
        current.append(stripped)
    if current:
        paragraphs.append(" ".join(current))
    return paragraphs


def make_table(header, rows, styles, widths, small=False):
    cell_style = styles["TinyCell"] if small else styles["Cell"]
    head_style = styles["TinyHeadCell"] if small else styles["HeadCell"]
    data = [[Paragraph(inline(cell), head_style) for cell in header]]
    data += [[Paragraph(inline(cell), cell_style) for cell in row] for row in rows]
    table = Table(data, colWidths=widths, repeatRows=1, hAlign="LEFT")
    table.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#005CA9")),
                ("TEXTCOLOR", (0, 0), (-1, 0), colors.white),
                ("GRID", (0, 0), (-1, -1), 0.35, colors.HexColor("#C9D3DF")),
                ("VALIGN", (0, 0), (-1, -1), "TOP"),
                ("ROWBACKGROUNDS", (0, 1), (-1, -1), [colors.white, colors.HexColor("#F3F7FA")]),
                ("LEFTPADDING", (0, 0), (-1, -1), 3),
                ("RIGHTPADDING", (0, 0), (-1, -1), 3),
                ("TOPPADDING", (0, 0), (-1, -1), 2),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 2),
            ]
        )
    )
    return table


def build_executive_opening(lines, styles, usable_width):
    story = []

    intro_start = heading_index(lines, "# Apresentação")
    situation_start = heading_index(lines, "## Situação consolidada do painel")
    intro_paragraphs = []
    if intro_start >= 0 and situation_start > intro_start:
        current = []
        for line in lines[intro_start + 1 : situation_start]:
            stripped = line.strip()
            if not stripped:
                if current:
                    intro_paragraphs.append(" ".join(current))
                    current = []
                continue
            if not stripped.startswith("#"):
                current.append(stripped)
        if current:
            intro_paragraphs.append(" ".join(current))

    story.append(Paragraph("Apresentação", styles["H1x"]))
    for paragraph in intro_paragraphs[:2]:
        story.append(Paragraph(inline(paragraph), styles["Bodyx"]))

    situation_header, situation_rows = table_after_heading(lines, "## Situação consolidada do painel")
    delivery_items = bullets_after_heading(lines, "## Principais entregas recentes observadas")
    delivery_header = ["Principais entregas recentes observadas"]
    delivery_rows = [[item] for item in delivery_items]

    left_width = usable_width * 0.46
    right_width = usable_width * 0.50
    situation_table = make_table(situation_header, situation_rows, styles, [left_width * 0.60, left_width * 0.40], small=True)
    delivery_table = make_table(delivery_header, delivery_rows, styles, [right_width], small=True)
    side_by_side = Table(
        [[situation_table, delivery_table]],
        colWidths=[left_width, right_width],
        hAlign="LEFT",
    )
    side_by_side.setStyle(TableStyle([("VALIGN", (0, 0), (-1, -1), "TOP"), ("LEFTPADDING", (0, 0), (-1, -1), 0), ("RIGHTPADDING", (0, 0), (-1, -1), 8)]))
    story.append(side_by_side)
    story.append(Spacer(1, 7))

    vision_header, vision_rows = table_after_heading(lines, "# Visão Geral das Metas")
    story.append(Paragraph("Visão Geral das Metas", styles["H2x"]))
    story.append(
        make_table(
            vision_header,
            vision_rows,
            styles,
            [usable_width * 0.10, usable_width * 0.26, usable_width * 0.18, usable_width * 0.46],
            small=True,
        )
    )
    story.append(PageBreak())
    story.append(Paragraph("Leitura Executiva", styles["H2x"]))
    for paragraph in paragraphs_after_heading(lines, "## Leitura executiva"):
        story.append(Paragraph(inline(paragraph), styles["Bodyx"]))
    story.append(PageBreak())

    story.append(Paragraph("Síntese para Decisão", styles["H1x"]))
    story.append(Paragraph(inline("O Convênio CAIXA-UnB está estruturado em 11 metas complementares que formam uma agenda integrada de governança arquivística digital."), styles["Bodyx"]))
    story.append(Paragraph(inline("A visão executiva permite acompanhar a situação consolidada do projeto, identificar entregas recentes e localizar rapidamente a meta que demanda consulta específica."), styles["Bodyx"]))
    story.append(Paragraph(inline("Para análise detalhada, o segundo documento reúne o material de cada meta individualmente, preservando benefícios, entregas e valor institucional para a CAIXA."), styles["Bodyx"]))
    story.append(PageBreak())
    return story


def meta_lines_only(lines):
    start = heading_index(lines, "# Meta 1 - Gerenciamento do Projeto")
    end = heading_index(lines, "# Pontos de Atenção")
    if start < 0:
        return lines
    if end < 0:
        end = len(lines)
    return lines[start:end]


def closing_lines(lines):
    start = heading_index(lines, "# Pontos de Atenção")
    if start < 0:
        return []
    return lines[start:]


def build_story(lines, styles, usable_width):
    story = []
    paragraph = []

    def flush_paragraph():
        if not paragraph:
            return
        text = " ".join(item.strip() for item in paragraph).strip()
        if text:
            story.append(Paragraph(inline(text), styles["Bodyx"]))
        paragraph.clear()

    index = 0
    while index < len(lines):
        raw = lines[index]
        line = raw.strip()

        if not line:
            flush_paragraph()
            index += 1
            continue

        if line == '<div class="newpage"></div>':
            flush_paragraph()
            if story and not isinstance(story[-1], PageBreak):
                story.append(PageBreak())
            index += 1
            continue

        if line.startswith("# "):
            flush_paragraph()
            title = line[2:].strip()
            if story and not isinstance(story[-1], PageBreak) and not title.lower().startswith("apresentação"):
                story.append(PageBreak())
            story.append(Paragraph(inline(title), styles["H1x"]))
            index += 1
            continue

        if line.startswith("## "):
            flush_paragraph()
            story.append(Paragraph(inline(line[3:].strip()), styles["H2x"]))
            index += 1
            continue

        if line.startswith("- "):
            flush_paragraph()
            story.append(Paragraph(inline(line[2:].strip()), styles["Bulletx"], bulletText="•"))
            index += 1
            continue

        if re.match(r"^\d+\.\s+", line):
            flush_paragraph()
            item = re.sub(r"^\d+\.\s+", "", line)
            story.append(Paragraph(inline(item), styles["Bulletx"], bulletText="•"))
            index += 1
            continue

        if line.startswith(">"):
            flush_paragraph()
            story.append(Paragraph(inline(line.lstrip(">").strip()), styles["Quote"]))
            index += 1
            continue

        if is_table_start(lines, index):
            flush_paragraph()
            header = split_table_row(lines[index])
            index += 2
            rows = []
            while index < len(lines) and lines[index].strip().startswith("|"):
                rows.append(split_table_row(lines[index]))
                index += 1

            max_cols = max([len(header)] + [len(row) for row in rows])
            header += [""] * (max_cols - len(header))
            rows = [row + [""] * (max_cols - len(row)) for row in rows]

            data = [[Paragraph(inline(cell), styles["HeadCell"]) for cell in header]]
            data += [[Paragraph(inline(cell), styles["Cell"]) for cell in row] for row in rows]

            if max_cols == 2:
                widths = [usable_width * 0.38, usable_width * 0.62]
            elif max_cols == 3:
                widths = [usable_width * 0.24, usable_width * 0.36, usable_width * 0.40]
            elif max_cols == 4:
                widths = [usable_width * 0.12, usable_width * 0.27, usable_width * 0.19, usable_width * 0.42]
            else:
                widths = [usable_width / max_cols] * max_cols

            table = Table(data, colWidths=widths, repeatRows=1, hAlign="LEFT")
            table.setStyle(
                TableStyle(
                    [
                        ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#005CA9")),
                        ("TEXTCOLOR", (0, 0), (-1, 0), colors.white),
                        ("GRID", (0, 0), (-1, -1), 0.35, colors.HexColor("#C9D3DF")),
                        ("VALIGN", (0, 0), (-1, -1), "TOP"),
                        ("ROWBACKGROUNDS", (0, 1), (-1, -1), [colors.white, colors.HexColor("#F3F7FA")]),
                        ("LEFTPADDING", (0, 0), (-1, -1), 4),
                        ("RIGHTPADDING", (0, 0), (-1, -1), 4),
                        ("TOPPADDING", (0, 0), (-1, -1), 3),
                        ("BOTTOMPADDING", (0, 0), (-1, -1), 3),
                    ]
                )
            )
            story.append(table)
            story.append(Spacer(1, 7))
            continue

        paragraph.append(raw)
        index += 1

    flush_paragraph()

    clean = []
    for flowable in story:
        if isinstance(flowable, PageBreak) and (not clean or isinstance(clean[-1], PageBreak)):
            continue
        clean.append(flowable)
    if clean and isinstance(clean[-1], PageBreak):
        clean.pop()
    return clean


def split_pdf(source):
    reader = PdfReader(str(source))
    if len(reader.pages) < 4:
        raise RuntimeError(f"Expected at least 4 pages, got {len(reader.pages)}")

    overview = PdfWriter()
    for page in reader.pages[:3]:
        overview.add_page(page)
    with OVERVIEW_PDF.open("wb") as output:
        overview.write(output)

    goals = PdfWriter()
    for page in reader.pages[3:]:
        goals.add_page(page)
    with GOALS_PDF.open("wb") as output:
        goals.write(output)

    return len(reader.pages), len(overview.pages), len(goals.pages)


def main():
    PDF_DIR.mkdir(parents=True, exist_ok=True)
    front, lines = parse_front_matter(MD_PATH.read_text(encoding="utf-8-sig"))

    page_w, page_h = landscape(A4)
    left = right = 1.15 * cm
    header_h = 2.55 * cm
    footer_h = 1.05 * cm
    top = header_h + 0.42 * cm
    bottom = 1.55 * cm
    usable_width = page_w - left - right

    styles = getSampleStyleSheet()
    styles.add(ParagraphStyle("H1x", parent=styles["Heading1"], fontName="Helvetica-Bold", fontSize=18, leading=22, textColor=colors.HexColor("#005CA9"), spaceBefore=8, spaceAfter=10))
    styles.add(ParagraphStyle("H2x", parent=styles["Heading2"], fontName="Helvetica-Bold", fontSize=14, leading=18, textColor=colors.HexColor("#005CA9"), spaceBefore=8, spaceAfter=7))
    styles.add(ParagraphStyle("Bodyx", parent=styles["BodyText"], fontSize=9.6, leading=12.8, textColor=colors.HexColor("#1B2F45"), spaceAfter=6))
    styles.add(ParagraphStyle("Bulletx", parent=styles["BodyText"], fontSize=9.4, leading=12.2, leftIndent=12, firstLineIndent=-8, bulletIndent=0, textColor=colors.HexColor("#1B2F45"), spaceAfter=4))
    styles.add(ParagraphStyle("Cell", parent=styles["BodyText"], fontSize=7.2, leading=8.6, textColor=colors.HexColor("#1B2F45")))
    styles.add(ParagraphStyle("HeadCell", parent=styles["BodyText"], fontName="Helvetica-Bold", fontSize=7.4, leading=8.8, alignment=TA_CENTER, textColor=colors.white))
    styles.add(ParagraphStyle("TinyCell", parent=styles["BodyText"], fontSize=5.9, leading=7.0, textColor=colors.HexColor("#1B2F45")))
    styles.add(ParagraphStyle("TinyHeadCell", parent=styles["BodyText"], fontName="Helvetica-Bold", fontSize=6.2, leading=7.4, alignment=TA_CENTER, textColor=colors.white))
    styles.add(ParagraphStyle("Quote", parent=styles["BodyText"], fontSize=9.4, leading=12.2, leftIndent=12, borderColor=colors.HexColor("#F39200"), borderWidth=1.2, borderPadding=6, textColor=colors.HexColor("#1B2F45"), spaceBefore=6, spaceAfter=8))

    logo_ratio = Image.open(LOGO_PATH).size[0] / Image.open(LOGO_PATH).size[1]
    footer_ratio = Image.open(FOOTER_IMG).size[0] / Image.open(FOOTER_IMG).size[1]

    def on_page(canvas, doc):
        canvas.saveState()
        canvas.setFillColor(colors.HexColor("#005CA9"))
        canvas.rect(0, page_h - header_h, page_w, header_h, fill=1, stroke=0)
        canvas.setFillColor(colors.HexColor("#00A6CE"))
        canvas.rect(0, page_h - header_h, page_w * 0.30, header_h, fill=1, stroke=0)
        canvas.setFillColor(colors.HexColor("#006DB6"))
        path = canvas.beginPath()
        path.moveTo(page_w * 0.43, page_h)
        path.lineTo(page_w * 0.52, page_h - header_h)
        path.lineTo(page_w * 0.30, page_h - header_h)
        path.lineTo(page_w * 0.22, page_h)
        path.close()
        canvas.drawPath(path, fill=1, stroke=0)
        canvas.setFillColor(colors.HexColor("#F39200"))
        canvas.rect(0, page_h - header_h - 0.035 * cm, page_w, 0.035 * cm, fill=1, stroke=0)

        logo_h = 0.58 * cm
        logo_w = logo_h * logo_ratio
        canvas.drawImage(str(LOGO_PATH), page_w - right - logo_w, page_h - 1.48 * cm, width=logo_w, height=logo_h, preserveAspectRatio=True, mask="auto")

        canvas.setFillColor(colors.white)
        canvas.setFont("Helvetica-Bold", 22)
        canvas.drawString(left, page_h - 1.18 * cm, front.get("title", "Caderno Executivo"))
        canvas.setFont("Helvetica", 10.8)
        canvas.drawString(left, page_h - 1.70 * cm, front.get("subtitle", "Síntese Executiva das Metas do Convênio CAIXA-UnB"))
        canvas.roundRect(left, page_h - 0.56 * cm, 3.2 * cm, 0.28 * cm, 0.14 * cm, fill=1, stroke=0)
        canvas.setFillColor(colors.HexColor("#005CA9"))
        canvas.setFont("Helvetica-Bold", 6.8)
        canvas.drawCentredString(left + 1.6 * cm, page_h - 0.48 * cm, "29 DE JUNHO DE 2026")

        canvas.setFillColor(colors.HexColor("#005CA9"))
        canvas.rect(0, 0, page_w, footer_h, fill=1, stroke=0)
        footer_h_img = footer_h
        footer_w_img = footer_h_img * footer_ratio
        canvas.drawImage(str(FOOTER_IMG), page_w - footer_w_img, 0, width=footer_w_img, height=footer_h_img, preserveAspectRatio=True, mask="auto")
        canvas.setFillColor(colors.white)
        canvas.setFont("Helvetica-Bold", 7.6)
        canvas.drawString(left, 0.37 * cm, front.get("footer_left", "#INTERNO.TODOS | CADERNO EXECUTIVO"))
        canvas.drawCentredString(page_w / 2, 0.37 * cm, front.get("footer_center", "Convênio CAIXA-UnB"))
        canvas.drawRightString(page_w - right, 0.37 * cm, str(doc.page))
        canvas.restoreState()

    story = build_executive_opening(lines, styles, usable_width)
    story.extend(build_story(meta_lines_only(lines), styles, usable_width))
    closing = build_story(closing_lines(lines), styles, usable_width)
    if closing:
        if story and not isinstance(story[-1], PageBreak):
            story.append(PageBreak())
        story.extend(closing)
    doc = SimpleDocTemplate(str(FULL_PDF), pagesize=landscape(A4), leftMargin=left, rightMargin=right, topMargin=top, bottomMargin=bottom)
    doc.build(story, onFirstPage=on_page, onLaterPages=on_page)
    counts = split_pdf(FULL_PDF)
    print(f"full={FULL_PDF} pages={counts[0]}")
    print(f"overview={OVERVIEW_PDF} pages={counts[1]}")
    print(f"goals={GOALS_PDF} pages={counts[2]}")


if __name__ == "__main__":
    main()
