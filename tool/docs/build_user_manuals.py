"""Build both compact user manuals from docs/_data/guide.yml.

Development dependencies: reportlab, PyYAML, Pillow. No network access at runtime.
Run from any directory: python tool/docs/build_user_manuals.py
"""

from pathlib import Path
import html

import yaml
from PIL import Image as PillowImage
from reportlab.lib import colors
from reportlab.lib.enums import TA_LEFT
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import mm
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import (
    Image,
    KeepTogether,
    PageBreak,
    Paragraph,
    SimpleDocTemplate,
    Spacer,
    Table,
    TableStyle,
)

ROOT = Path(__file__).resolve().parents[2]
GREEN = colors.HexColor('#124D3A')
INK = colors.HexColor('#20372D')
MUTED = colors.HexColor('#52645C')
PALE = colors.HexColor('#EDF4EF')
FONT = ROOT / 'assets/fonts/NotoSans-Regular.ttf'
pdfmetrics.registerFont(TTFont('Manual', str(FONT)))
# The bundled font keeps the result independent of system fonts.
pdfmetrics.registerFontFamily('Manual', normal='Manual', bold='Manual', italic='Manual', boldItalic='Manual')


def text(value):
    value = str(value).replace('–', '-').replace('—', '-')
    value = value.replace('<strong>', '<b>').replace('</strong>', '</b>')
    return value.replace('<br>', '<br/>')


def build(language, data):
    german = language == 'de'
    filename = 'TerraManager-Handbuch.pdf' if german else 'TerraManager-User-Manual.pdf'
    destination = ROOT / 'docs/guide' / filename
    title = 'Kurzhandbuch' if german else 'Compact user manual'
    page_names = (
        ['Bestand und Bilder', 'QR und Pflege', 'Archiv und Sicherung', 'Shared Care']
        if german else ['Collection and pictures', 'QR and care', 'Archive and backup', 'Shared Care']
    )
    sheet = getSampleStyleSheet()
    body = ParagraphStyle('Body', fontName='Manual', fontSize=10, leading=14.4,
                          textColor=INK, spaceAfter=5, alignment=TA_LEFT)
    note = ParagraphStyle('Note', parent=body, fontSize=8.8, leading=12.4,
                          textColor=MUTED, backColor=PALE, borderPadding=6,
                          spaceBefore=3, spaceAfter=8)
    heading = ParagraphStyle('Section', parent=sheet['Heading2'], fontName='Manual',
                             fontSize=13, leading=17, textColor=GREEN,
                             spaceBefore=9, spaceAfter=5, keepWithNext=True)
    subheading = ParagraphStyle('Step', parent=heading, fontSize=10, leading=14,
                                spaceBefore=6, spaceAfter=2)
    caption = ParagraphStyle('Caption', parent=body, fontSize=7.3, leading=10,
                              textColor=MUTED)
    doc = SimpleDocTemplate(str(destination), pagesize=A4, rightMargin=18 * mm,
                            leftMargin=18 * mm, topMargin=23 * mm, bottomMargin=20 * mm,
                            title=f'TerraManager - {title}', author='Codefrog',
                            subject=data['description'], pageCompression=1)
    sections = {section['id']: section for section in data['sections']}
    groups = [('start',), ('qr', 'feeding', 'reminders'), ('archive', 'backup')]
    assert {item for group in groups for item in group} == set(sections), 'Update manual page groups for new sections.'
    story = []

    def add_step(step):
        story.append(Paragraph(text(f'{step["number"]}. {step["heading"]}'), subheading))
        story.append(Paragraph(text(step['body_html']), body))
        if step.get('note_html'):
            story.append(Paragraph(text(step['note_html']), note))

    for group_index, group in enumerate(groups):
        if group_index:
            story.append(PageBreak())
        if group_index == 0:
            story.append(Paragraph(f'TerraManager - {title}', ParagraphStyle(
                'Title', parent=heading, fontSize=21, leading=27, spaceBefore=0, spaceAfter=8)))
        for section_id in group:
            section = sections[section_id]
            story.append(Paragraph(text(section['eyebrow']), heading))
            story.append(Paragraph(text(section['lead']), body))
            for step in section['steps']:
                add_step(step)
        if group_index == 0:
            # Representative screenshots support recognition without repeating
            # every image from the visual Web guide.
            images = []
            for name in ['boxes-overview.webp', 'animal-details.webp']:
                file = ROOT / 'docs/guide/assets/images' / name
                with PillowImage.open(file) as image:
                    width, height = image.size
                display_height = 64 * mm
                images.append(Image(str(file), width=display_height * width / height,
                                    height=display_height, kind='proportional'))
            table = Table([images], colWidths=[82 * mm, 82 * mm])
            table.setStyle(TableStyle([('VALIGN', (0, 0), (-1, -1), 'TOP'),
                                       ('ALIGN', (0, 0), (-1, -1), 'CENTER')]))
            story.append(Spacer(1, 3 * mm))
            story.append(KeepTogether([table, Paragraph(
                'Beispielansichten; Beschriftungen können je nach Sprache abweichen.' if german
                else 'Example views; labels may differ with the selected language.', caption)]))
    story.append(PageBreak())
    shared = data['shared_care']
    story.append(Paragraph(text(shared['heading']), heading))
    story.append(Paragraph(text(shared['lead']), body))
    for item in shared['items']:
        story.append(Paragraph(text(item['title']), subheading))
        story.append(Paragraph(text(item['body']), body))
    story.append(Paragraph(text(shared['note']), note))
    story.append(Spacer(1, 5 * mm))
    story.append(Paragraph('Weitere Hilfe' if german else 'Further help', heading))
    url = f'https://codefrogcf.github.io/TerraManager/guide/{"" if german else "en/"}'
    label = 'Visuelle Anleitung und aktuelle Informationen' if german else 'Visual guide and current information'
    story.append(Paragraph(f'<link href="{html.escape(url)}" color="#124D3A">{label}</link>', body))
    support = 'https://github.com/CodefrogCF/TerraManager/issues'
    story.append(Paragraph(f'<link href="{support}" color="#124D3A">Support / GitHub Issues</link>', body))

    def decorate(canvas, document):
        canvas.saveState()
        width, height = A4
        canvas.setStrokeColor(colors.HexColor('#C9D9CD'))
        canvas.setLineWidth(0.6)
        canvas.line(18 * mm, height - 17 * mm, width - 18 * mm, height - 17 * mm)
        canvas.setFont('Manual', 8)
        canvas.setFillColor(GREEN)
        canvas.drawString(18 * mm, height - 13 * mm, 'TerraManager')
        index = document.page - 1
        canvas.setFillColor(MUTED)
        if index < len(page_names):
            canvas.drawRightString(width - 18 * mm, height - 13 * mm, page_names[index])
        canvas.drawString(18 * mm, 12 * mm, 'codefrogcf.github.io/TerraManager')
        canvas.drawRightString(width - 18 * mm, 12 * mm, str(document.page))
        canvas.restoreState()

    doc.build(story, onFirstPage=decorate, onLaterPages=decorate)
    print(destination)


if __name__ == '__main__':
    guide = yaml.safe_load((ROOT / 'docs/_data/guide.yml').read_text(encoding='utf-8'))
    for language in ['de', 'en']:
        build(language, guide[language])
