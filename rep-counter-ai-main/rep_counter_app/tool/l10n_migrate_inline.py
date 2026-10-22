"""Replace literal context.tr('vi','en') with context.l10n.<key> when an ARB key
has exactly the same VI and EN text. Prints a report; never guesses."""
import json, re, sys, collections, os
root = sys.argv[1]; files = sys.argv[2:]
en = json.load(open(os.path.join(root, 'lib/l10n/app_en.arb')))
vi = json.load(open(os.path.join(root, 'lib/l10n/app_vi.arb')))
pairs = collections.defaultdict(list)
for k, v in en.items():
    if k.startswith('@') or not isinstance(v, str): continue
    meta = en.get('@' + k, {})
    if meta.get('placeholders') or '{' in v or '{' in vi[k]: continue
    pairs[(vi[k], v)].append(k)
pat = re.compile(r"context\.tr\(\s*'((?:[^'\\]|\\.)*)'\s*,\s*'((?:[^'\\]|\\.)*)'\s*,?\s*\)", re.S)
def stem(f):
    base = os.path.splitext(os.path.basename(f))[0]
    return ''.join(p.capitalize() for p in base.split('_'))
total = 0
for f in files:
    s = open(f).read(); st = stem(f); n = 0; missed = []
    def sub(m):
        global total
        nonlocal_n[0] += 1
        a = m.group(1).replace("\\'", "'"); b = m.group(2).replace("\\'", "'")
        keys = pairs.get((a, b))
        if not keys:
            missed.append(b); return m.group(0)
        keys = sorted(keys, key=lambda k: (st.lower() not in k.lower(), not k.startswith('legacy'), k))
        return 'context.l10n.' + keys[0]
    nonlocal_n = [0]
    out = pat.sub(sub, s)
    replaced = nonlocal_n[0] - len(missed)
    total += replaced
    if out != s:
        imp = "import '" + os.path.relpath(os.path.join(root, 'lib/core/i18n/l10n.dart'), os.path.dirname(f)) + "';"
        if imp not in out:
            lines = out.split('\n'); last = max(i for i, l in enumerate(lines) if l.startswith('import '))
            lines.insert(last + 1, imp); out = '\n'.join(lines)
        open(f, 'w').write(out)
    print(f'{replaced:3} replaced, {len(missed):2} kept  {os.path.relpath(f, root)}')
    for b in missed: print('      kept:', b[:70])
print('total replaced', total)
