import sys
import re

def fix_patch(input_file, output_file):
    with open(input_file, 'r') as f:
        lines = f.readlines()

    out = open(output_file, 'w')
    
    i = 0
    while i < len(lines):
        line = lines[i]
        if line.startswith('@@'):
            # Hunk header found
            header_match = re.match(r'^@@ -(\d+),?\d* \+(\d+),?\d* @@(.*)', line)
            if not header_match:
                out.write(line)
                i += 1
                continue
            
            orig_start = header_match.group(1)
            new_start = header_match.group(2)
            suffix = header_match.group(3)
            
            hunk_lines = []
            j = i + 1
            while j < len(lines):
                if lines[j].startswith('@@') or lines[j].startswith('diff --git'):
                    break
                hunk_lines.append(lines[j])
                j += 1
            
            # Now calculate counts for this hunk and ensure leading spaces
            orig_count = 0
            new_count = 0
            fixed_hunk_lines = []
            for hl in hunk_lines:
                if hl.startswith('+'):
                    new_count += 1
                    fixed_hunk_lines.append(hl)
                elif hl.startswith('-'):
                    orig_count += 1
                    fixed_hunk_lines.append(hl)
                elif hl.startswith(' '):
                    orig_count += 1
                    new_count += 1
                    fixed_hunk_lines.append(hl)
                elif hl == '\n':
                    # Special case for empty context lines that lost their leading space
                    orig_count += 1
                    new_count += 1
                    fixed_hunk_lines.append(' \n')
                else:
                    # Missing leading space for context line
                    orig_count += 1
                    new_count += 1
                    fixed_hunk_lines.append(' ' + hl)
            
            new_header = f"@@ -{orig_start},{orig_count} +{new_start},{new_count} @@{suffix}\n"
            out.write(new_header)
            for fhl in fixed_hunk_lines:
                out.write(fhl)
            
            i = j
        else:
            out.write(line)
            i += 1
    
    out.close()

if __name__ == "__main__":
    fix_patch(sys.argv[1], sys.argv[2])
