#!/bin/bash

echo "🚀 PostgreSQL 15 설정 스크립트"
echo "================================"

# 1. PostgreSQL 서비스 시작
echo "1. PostgreSQL 서비스 시작 중..."
sudo service postgresql start

# 2. 상태 확인
echo "2. PostgreSQL 상태 확인..."
sudo service postgresql status

# 3. 데이터베이스 생성
echo "3. 데이터베이스 생성 중..."
sudo -u postgres psql -c "
CREATE DATABASE IF NOT EXISTS smoking_areas_db;
"

# 4. postgres 사용자 비밀번호 설정
echo "4. postgres 사용자 비밀번호 설정..."
sudo -u postgres psql -c "
ALTER USER postgres PASSWORD 'postgres';
"

# 5. 연결 테스트
echo "5. 연결 테스트..."
sudo -u postgres psql -d smoking_areas_db -c "
SELECT 'Database connection successful!' AS status;
"

echo ""
echo "✅ PostgreSQL 설정 완료!"
echo "📊 연결 정보:"
echo "  Host: localhost"
echo "  Port: 5432"
echo "  Database: smoking_areas_db"
echo "  User: postgres"
echo "  Password: postgres"
echo ""
echo "🧪 다음 명령어로 테스트해보세요:"
echo "  cd api_server && node test-connection.js"