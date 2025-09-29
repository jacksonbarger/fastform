from __future__ import annotations
import csv, io, zipfile, sys
from pathlib import Path
from typing import Dict, Iterable, Tuple, Optional
from .ndc_to_rxcui import ndc_to_rxcui

"""
Input: CMS Monthly/Quarterly PUF ZIP or a single Formulary CSV.
We expect the Formulary table to include at least:
- CONTRACT_ID, PLAN_ID, FORMULARY_ID (identifies plan)
- NDC
- TIER
- PRIOR_AUTHORIZATION_FLAG, STEP_THERAPY_FLAG, QUANTITY_LIMIT_FLAG
Optional helpful columns if present:
- QL_DAYS, QL_QTY
"""

def _open_formulary_rows(path: Path) -> Iterable[Dict[str,str]]:
    if path.suffix.lower() == ".zip":
        with zipfile.ZipFile(path, "r") as z:
            # Find the file that looks like a formulary table (name varies by year)
            cand = [n for n in z.namelist() if "formulary" in n.lower() and n.lower().endswith(".csv")]
            if not cand:
                raise RuntimeError("No *formulary*.csv found inside ZIP")
            with z.open(cand[0]) as f:
                text = io.TextIOWrapper(f, encoding="utf-8", errors="replace")
                reader = csv.DictReader(text)
                for row in reader:
                    yield {k.strip(): (v.strip() if isinstance(v, str) else v) for k,v in row.items()}
    else:
        with path.open("r", encoding="utf-8", errors="replace") as f:
            reader = csv.DictReader(f)
            for row in reader:
                yield {k.strip(): (v.strip() if isinstance(v, str) else v) for k,v in row.items()}

def _norm_bool(v: str) -> bool:
    return str(v).strip().upper() in {"Y","YES","TRUE","T","1"}

def ingest_to_rules(input_path: Path, out_path: Path) -> Tuple[int,int]:
    out_path.parent.mkdir(parents=True, exist_ok=True)
    rows = _open_formulary_rows(input_path)

    with out_path.open("w", newline="", encoding="utf-8") as out:
        writer = csv.writer(out)
        writer.writerow(["plan_id","rxcui","drug_name","strength","route","tier",
                         "pa","st","ql","ql_max_qty","ql_per_days","alt_rxcui","notes"])
        n_in = n_out = 0
        for r in rows:
            n_in += 1
            contract = r.get("CONTRACT_ID") or r.get("PARENT_ORGANIZATION_CONTRACT_ID")
            plan = r.get("PLAN_ID") or r.get("PBP")
            ndc = (r.get("NDC") or r.get("NDC_11") or "").replace("-", "")
            tier = r.get("TIER") or r.get("FORMULARY_TIER")
            pa = _norm_bool(r.get("PRIOR_AUTHORIZATION_FLAG","N"))
            st = _norm_bool(r.get("STEP_THERAPY_FLAG","N"))
            ql = _norm_bool(r.get("QUANTITY_LIMIT_FLAG","N"))
            ql_qty = r.get("QL_QTY") or ""
            ql_days = r.get("QL_DAYS") or ""

            if not contract or not plan or not ndc or not tier:
                continue

            rxcui = ndc_to_rxcui(ndc)
            if not rxcui:
                # skip unmapped NDCs for now
                continue

            # We can resolve human-readable name/strength/route later from RxNorm if needed;
            # for MVP we leave blank and let your search work by RxCUI/tier/flags.
            drug_name = ""
            strength = ""
            route = ""
            plan_key = f"{contract}-{plan}"

            writer.writerow([plan_key, rxcui, drug_name, strength, route, tier, pa, st, ql, ql_qty, ql_days, "", "CMS-PUF"])
            n_out += 1

    return n_in, n_out

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: poetry run python -m fastform.ingest_cms <input_zip_or_csv> <output_csv>")
        sys.exit(2)
    inp = Path(sys.argv[1]).resolve()
    out = Path(sys.argv[2]).resolve()
    n_in, n_out = ingest_to_rules(inp, out)
    print(f"Parsed {n_in} rows, wrote {n_out} rules to {out}")
