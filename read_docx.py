import zipfile
import xml.etree.ElementTree as ET
import sys
import os

docx_path = os.path.expanduser('~/Downloads/tables.docx')
if not os.path.exists(docx_path):
    print("File not found")
    sys.exit(1)

with zipfile.ZipFile(docx_path) as docx:
    xml_content = docx.read('word/document.xml')
    tree = ET.XML(xml_content)
    
    # The namespace for Word XML
    ns = {'w': 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'}
    
    # Extract all text from paragraphs
    paragraphs = []
    for p in tree.iterfind('.//w:p', ns):
        texts = [t.text for t in p.iterfind('.//w:t', ns) if t.text]
        if texts:
            paragraphs.append(''.join(texts))
            
    print('\n'.join(paragraphs))

