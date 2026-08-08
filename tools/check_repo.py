from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
CFG = ROOT / 'server.cfg.example'
RESOURCES = ROOT / 'resources' / '[lotb]'
SQL = ROOT / 'sql' / 'lotb.sql'

errors = []

if not CFG.exists():
    errors.append('server.cfg.example is missing')
else:
    text = CFG.read_text(encoding='utf-8')
    ensures = re.findall(r'^\s*ensure\s+(lotb_[A-Za-z0-9_-]+)\s*$', text, re.MULTILINE)
    if not ensures:
        errors.append('No LOTB ensure lines found')
    for resource in ensures:
        folder = RESOURCES / resource
        manifest = folder / 'fxmanifest.lua'
        if not folder.is_dir():
            errors.append(f'Missing resource folder: {resource}')
            continue
        if not manifest.exists():
            errors.append(f'Missing fxmanifest.lua: {resource}')
            continue
        manifest_text = manifest.read_text(encoding='utf-8')
        if "lua54 'yes'" in manifest_text or 'lua54 "yes"' in manifest_text:
            errors.append(f'Deprecated lua54 flag in {resource}/fxmanifest.lua')

if not SQL.exists():
    errors.append('sql/lotb.sql is missing')
else:
    sql = SQL.read_text(encoding='utf-8')
    required_tables = [
        'lotb_audit_log', 'lotb_rumors', 'lotb_character_memory', 'lotb_district_state',
        'lotb_witness_reports', 'lotb_object_legacy', 'lotb_scene_threads', 'lotb_opportunities',
        'lotb_evidence', 'lotb_contracts', 'lotb_businesses', 'lotb_dispatch_calls',
        'lotb_justice_cases', 'lotb_warrants', 'lotb_medical_records', 'lotb_crews'
    ]
    for table in required_tables:
        if f'`{table}`' not in sql:
            errors.append(f'Missing SQL table definition: {table}')

if errors:
    print('LOTB static check FAILED')
    for error in errors:
        print(f' - {error}')
    sys.exit(1)

print('LOTB static check PASSED')
