import re

files_to_clean = [
    'lib/features/client/presentation/pages/client_personal_details_page.dart',
    'lib/features/calendar/ui/widgets/schedule_sessions_sheet.dart',
]

for file in files_to_clean:
    with open(file, 'r') as f:
        content = f.read()
    
    # Remove duplicates
    lines = content.split('\n')
    seen_imports = set()
    cleaned_lines = []
    for line in lines:
        if line.startswith('import '):
            if line in seen_imports:
                continue
            seen_imports.add(line)
        cleaned_lines.append(line)
        
    with open(file, 'w') as f:
        f.write('\n'.join(cleaned_lines))

