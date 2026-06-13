import os
import glob
import re

directories = [
    '/Users/mauritsdehaan/Documents/VSC/GMT_thesis/writing/generated/',
    '/Users/mauritsdehaan/Documents/VSC/GMT_thesis/writing/generated/results_tables/'
]

pattern = re.compile(r'\s*Source files?:.*?(\.rds|\.csv).*?\.', re.IGNORECASE)

for directory in directories:
    for filepath in glob.glob(os.path.join(directory, '*.tex')):
        with open(filepath, 'r') as f:
            content = f.read()
        
        # Replace occurrences of Source file: ...
        # The pattern matches " Source file: ..." up to the first period after .rds or .csv, or just the end of the line.
        # Let's use a simpler pattern:
        # Match "Source file:" or "Source files:" and everything up to the end of the line.
        # Wait, sometimes it's "Source files: ... .rds." and the line ends with \end{minipage}.
        
        # A safer regex: find "Source file(s):" and replace until the end of the sentence (which ends with . or we just replace till the end of the line before the newline or end of the note).
        # Typically the line looks like:
        # ... observations. Source file: data/processed/stage1\_bilateral\_panel.rds.
        
        new_content = re.sub(r'\s*Source files?:.*?\.rds\.', '', content, flags=re.IGNORECASE)
        new_content = re.sub(r'\s*Source files?:.*?\.csv\.', '', new_content, flags=re.IGNORECASE)
        # Some might just end without the final dot, or have both
        new_content = re.sub(r'\s*Source files?:.*?(?:rds|csv).*?(?=$|\n|\\end)', '', new_content, flags=re.IGNORECASE)
        
        # Clean up any trailing spaces before a period if the removal left something like "observations. ."
        # Actually, since we matched the leading space, "observations. Source file: ..." becomes "observations."
        # If there are leftovers like "\.csv; data/processed/...", the above regex handles it by matching .*?(rds|csv).*?
        # Let's just do: match "Source file(s):" up to the end of the line
        
        if new_content != content:
            with open(filepath, 'w') as f:
                f.write(new_content)
            print(f"Cleaned {filepath}")

