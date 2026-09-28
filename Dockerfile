# 햇들농산 ML 콘솔 API 이미지 (2026-09-28 · GCP 배포용)
#
# 메인 backend 가 ML_CONSOLE_ORIGIN(http://ml-backend:8102) 으로 부른다.
# 화면이 직접 부르지 않으므로 외부에 포트를 열 필요가 없다.
#
# ★ 학습된 모델(ops_auc·ops_whsl·ops_rtl)은 이미지에 없다 — .gitignore 대상이다.
#   서버 디스크에 두고 compose 가 볼륨으로 끼운다 (haetdeul/deploy/gcp/README.md).
FROM python:3.11-slim

# lightgbm 이 OpenMP 런타임을 필요로 한다
RUN apt-get update \
    && apt-get install -y --no-install-recommends libgomp1 \
    && rm -rf /var/lib/apt/lists/*

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONIOENCODING=utf-8 \
    PYTHONUTF8=1

WORKDIR /app

COPY ops/requirements-server.txt ./ops/requirements-server.txt
RUN pip install --no-cache-dir -r ops/requirements-server.txt

COPY . .

# 운영 중 쌓이는 자리(agent 로그 · 재학습 sqlite 체크포인트)는 볼륨으로 받는다.
# 미리 만들고 소유자를 맞춰 두어야 빈 named volume 이 이 권한을 물려받는다.
RUN useradd --create-home --uid 10001 appuser \
    && mkdir -p "진행기록/agent_logs" ops/logs \
    && chown -R appuser:appuser /app
USER appuser

EXPOSE 8102

# /health 는 DB 까지 붙어 보므로 DB 가 없으면 503 이다. 컨테이너 헬스체크는
# 프로세스 생존만 본다 — DB 문제로 컨테이너가 재시작 루프에 빠지지 않게.
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8102/openapi.json').read()"

CMD ["uvicorn", "backend.main:app", "--host", "0.0.0.0", "--port", "8102"]
