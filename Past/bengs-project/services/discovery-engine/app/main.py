from fastapi import FastAPI

app = FastAPI(title="BENGS Discovery Engine")


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}
