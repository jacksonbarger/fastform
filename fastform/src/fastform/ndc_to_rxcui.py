from __future__ import annotations
import time, json, hashlib
from pathlib import Path
from typing import Optional
import urllib.request

_CACHE = Path("data/.rxnorm_ndc_cache.json")
_CACHE.parent.mkdir(parents=True, exist_ok=True)
_cache = {}
if _CACHE.exists():
    try:
        _cache = json.loads(_CACHE.read_text())
    except Exception:
        _cache = {}

def _save():
    try:
        _CACHE.write_text(json.dumps(_cache))
    except Exception:
        pass

def ndc_to_rxcui(ndc: str) -> Optional[str]:
    """Return RxCUI for NDC (11-digit with or without dashes)."""
    key = ndc.replace("-", "").strip()
    if not key:
        return None
    if key in _cache:
        return _cache[key] or None
    url = f"https://rxnav.nlm.nih.gov/REST/rxcui.json?idtype=NDC&id={key}"
    for _ in range(3):
        try:
            with urllib.request.urlopen(url, timeout=10) as resp:
                data = json.loads(resp.read().decode("utf-8"))
            rxcui = data.get("idGroup", {}).get("rxnormId")
            val = rxcui[0] if isinstance(rxcui, list) and rxcui else None
            _cache[key] = val
            _save()
            return val
        except Exception:
            time.sleep(0.5)
    _cache[key] = None
    _save()
    return None
