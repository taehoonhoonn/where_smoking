# 흡연구역 찾기 앱 Docker 관리 스크립트

.PHONY: help build up down logs clean restart db-import test

# 기본 타겟
help:
	@echo "🚬 흡연구역 찾기 앱 Docker 관리 명령어"
	@echo ""
	@echo "📋 주요 명령어:"
	@echo "  make up         - 전체 서비스 시작"
	@echo "  make down       - 전체 서비스 중지"
	@echo "  make restart    - 전체 서비스 재시작"
	@echo "  make logs       - 실시간 로그 확인"
	@echo "  make build      - Docker 이미지 빌드"
	@echo ""
	@echo "💾 데이터베이스:"
	@echo "  make db-import  - 흡연구역 데이터 임포트"
	@echo "  make db-backup  - 데이터베이스 백업"
	@echo "  make db-restore - 데이터베이스 복원"
	@echo ""
	@echo "🧪 테스트 및 관리:"
	@echo "  make test       - API 테스트"
	@echo "  make clean      - 모든 컨테이너/볼륨 제거"
	@echo "  make status     - 서비스 상태 확인"

# Docker Compose 명령어들
up:
	@echo "🚀 흡연구역 찾기 앱 시작 중..."
	docker-compose up -d
	@echo "✅ 서비스 시작 완료!"
	@echo "🌐 API 서버: http://localhost:3000"
	@echo "🗄️  pgAdmin: http://localhost:8080 (admin@smoking-areas.com / admin123)"
	@make status

down:
	@echo "🛑 서비스 중지 중..."
	docker-compose down
	@echo "✅ 서비스 중지 완료!"

restart:
	@echo "🔄 서비스 재시작 중..."
	docker-compose restart
	@echo "✅ 서비스 재시작 완료!"

build:
	@echo "🔨 Docker 이미지 빌드 중..."
	docker-compose build
	@echo "✅ 빌드 완료!"

logs:
	@echo "📋 실시간 로그 확인 (Ctrl+C로 종료)"
	docker-compose logs -f

status:
	@echo "📊 서비스 상태:"
	@docker-compose ps

# 데이터베이스 관리
db-import:
	@echo "💾 흡연구역 데이터 임포트 중..."
	@echo "⏳ PostgreSQL 준비 대기..."
	@sleep 5
	docker exec -it smoking_areas_db psql -U postgres -d smoking_areas_db -c "SELECT 'Database ready' as status;"
	@echo "📊 Python 스크립트로 데이터 임포트..."
	cd scripts && python3 database_manager.py setup
	@echo "✅ 데이터 임포트 완료!"

db-backup:
	@echo "💾 데이터베이스 백업 중..."
	docker exec smoking_areas_db pg_dump -U postgres smoking_areas_db > backup_$(shell date +%Y%m%d_%H%M%S).sql
	@echo "✅ 백업 완료!"

db-restore:
	@echo "📥 데이터베이스 복원 중..."
	@read -p "백업 파일명을 입력하세요: " backup_file; \
	docker exec -i smoking_areas_db psql -U postgres smoking_areas_db < $$backup_file
	@echo "✅ 복원 완료!"

# 테스트 및 디버깅
test:
	@echo "🧪 API 테스트 실행 중..."
	@echo "📡 헬스체크..."
	curl -f http://localhost:3000/api/v1/health || echo "❌ 헬스체크 실패"
	@echo ""
	@echo "📊 통계 조회..."
	curl -f http://localhost:3000/api/v1/smoking-areas/statistics || echo "❌ 통계 조회 실패"
	@echo ""
	@echo "🗺️  주변 검색 테스트..."
	curl -f "http://localhost:3000/api/v1/smoking-areas/nearby?lat=37.5547&lng=126.9707&radius=1000" || echo "❌ 주변 검색 실패"
	@echo ""
	@echo "✅ 테스트 완료!"

# 정리 작업
clean:
	@echo "⚠️  모든 컨테이너와 볼륨을 제거합니다!"
	@read -p "계속하시겠습니까? (y/N): " confirm; \
	if [ "$$confirm" = "y" ] || [ "$$confirm" = "Y" ]; then \
		docker-compose down -v --remove-orphans; \
		docker system prune -f; \
		echo "✅ 정리 완료!"; \
	else \
		echo "❌ 취소됨"; \
	fi

# 개발용 단축 명령어
dev: up db-import
	@echo "🎉 개발 환경 준비 완료!"
	@echo "📝 다음 명령어들을 사용할 수 있습니다:"
	@echo "  make logs    - 로그 확인"
	@echo "  make test    - API 테스트"
	@echo "  make restart - 서비스 재시작"

# 프로덕션 빌드
prod:
	@echo "🏭 프로덕션 환경 빌드 중..."
	docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d --build
	@echo "✅ 프로덕션 환경 시작 완료!"