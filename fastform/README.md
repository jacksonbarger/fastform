# fastform

Tiny FastAPI service that answers: “given a drug query, what are the formulary rules for this plan?”
- Lexical search baseline
- AI parser for messy strings → `{drug_name,strength,route}`
- Semantic search via embeddings + scikit-learn NearestNeighbors

## Quickstart
```bash
poetry install
cp .env.example .env  # add your OPENAI_API_KEY
poetry run uvicorn fastform.main:app --reload

