FROM node:18-alpine

# 작업 디렉토리 설정
WORKDIR /app

# 시스템 의존성 설치
RUN apk add --no-cache \
    postgresql-client \
    curl

# package.json과 package-lock.json 복사
COPY package*.json ./

# 의존성 설치
RUN npm ci --only=production && npm cache clean --force

# 개발 의존성 설치 (개발 환경용)
RUN npm install --only=dev

# 앱 소스 코드 복사
COPY . .

# 로그 디렉토리 생성
RUN mkdir -p logs

# 비루트 사용자 생성
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodeuser -u 1001

# 권한 설정
RUN chown -R nodeuser:nodejs /app
USER nodeuser

# 헬스체크 설정
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:${PORT:-8080}/api/v1/health || exit 1

# 포트 노출
EXPOSE 8080

# 개발 모드로 실행
CMD ["npm", "run"]