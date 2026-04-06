Find all `.gd` files under `F:/GreedySnake/Project/` that are missing a companion `.uid` file, and generate one for each.

Steps:
1. Find missing .uid files:
```bash
find F:/GreedySnake/Project -name "*.gd" ! -name "*.gd.uid" | while read f; do [ ! -f "${f}.uid" ] && echo "$f"; done
```

2. For each missing file, generate a uid using:
```bash
python3 -c "import random,string; print('uid://' + ''.join(random.choice(string.ascii_lowercase+string.digits) for _ in range(13)))"
```

3. Write the uid to `{script_path}.uid` (with trailing newline).

4. Report how many .uid files were created. If none missing, say "All .gd files have .uid companions."
