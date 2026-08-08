from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
CFG = ROOT / 'server.cfg.example'
RESOURCES = ROOT / 'resources' / '[lotb]'
SQL_BASE = ROOT / 'sql' / 'lotb.sql'
SQL_V04 = ROOT / 'sql' / 'lotb_v04.sql'

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

        # Check local .lua/.html/.css/.js paths declared in the manifest exist.
        for quoted in re.findall(r"['\"]([^'\"]+\.(?:lua|html|css|js))['\"]", manifest_text):
            if quoted.startswith('@'):
                continue
            local_path = folder / quoted
            if '*' not in quoted and not local_path.exists():
                errors.append(f'Manifest references missing file: {resource}/{quoted}')

if not SQL_BASE.exists():
    errors.append('sql/lotb.sql is missing')
else:
    sql = SQL_BASE.read_text(encoding='utf-8')
    required_tables = [
        'lotb_audit_log', 'lotb_rumors', 'lotb_character_memory', 'lotb_district_state',
        'lotb_witness_reports', 'lotb_object_legacy', 'lotb_scene_threads', 'lotb_opportunities',
        'lotb_evidence', 'lotb_contracts', 'lotb_businesses', 'lotb_dispatch_calls',
        'lotb_justice_cases', 'lotb_warrants', 'lotb_medical_records', 'lotb_crews'
    ]
    for table in required_tables:
        if f'`{table}`' not in sql:
            errors.append(f'Missing base SQL table definition: {table}')

if not SQL_V04.exists():
    errors.append('sql/lotb_v04.sql is missing')
else:
    sql = SQL_V04.read_text(encoding='utf-8')
    required_v04 = [
        'lotb_wills', 'lotb_will_assets', 'lotb_properties', 'lotb_property_access',
        'lotb_dealership_inventory', 'lotb_vehicle_sales', 'lotb_mechanic_orders',
        'lotb_vehicle_service_history', 'lotb_underworld_profiles', 'lotb_underworld_unlocks',
        'lotb_crime_jobs', 'lotb_crafting_recipes', 'lotb_bank_ledger'
    ]
    for table in required_v04:
        if f'`{table}`' not in sql:
            errors.append(f'Missing v0.4 SQL table definition: {table}')

if errors:
    print('LOTB static check FAILED')
    for error in errors:
        print(f' - {error}')
    sys.exit(1)

print('LOTB static check PASSED')
