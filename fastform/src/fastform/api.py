
from fastapi import HTTPException
from .ingest_cms import ingest_to_rules
from pathlib import Path

@app.post("/v1/admin/ingest_local")
def ingest_local(file_path: str, x_admin_key: str = Header(None, alias="X-Admin-Key")):
    if x_admin_key != (settings.admin_key or "dev"):
        raise HTTPException(status_code=401, detail="unauthorized")
    inp = Path(file_path).expanduser().resolve()
    if not inp.exists():
        raise HTTPException(status_code=400, detail="file not found")
    outp = settings.data_path  # your rules.csv path
    n_in, n_out = ingest_to_rules(inp, outp)
    return reindex() | {"ingested_rows": n_in, "kept_rows": n_out}
