#!/bin/bash

# 카카오 API 키 동기화 스크립트
# 사용법: ./sync-kakao-key.sh 새_API_키

if [ -z "$1" ]; then
  echo "📘 사용법: ./sync-kakao-key.sh 새_API_키"
  echo ""
  echo "현재 설정된 API 키:"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  # API 서버 키 확인
  if [ -f "api_server/.env" ]; then
    echo "🔧 API 서버: $(grep KAKAO_REST_API_KEY api_server/.env | cut -d'=' -f2 | tr -d '"')"
  else
    echo "❌ API 서버: .env 파일이 없습니다"
  fi

  # 스크립트 키 확인
  if [ -f "scripts/.env" ]; then
    echo "🐍 스크립트: $(grep KAKAO_API_KEY scripts/.env | cut -d'=' -f2 | tr -d '"')"
  else
    echo "❌ 스크립트: .env 파일이 없습니다"
  fi

  echo ""
  echo "💡 새 키로 업데이트하려면 키를 인수로 제공하세요"
  exit 1
fi

NEW_KEY="$1"

echo "🔄 카카오 API 키 동기화 중..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# API 서버 .env 업데이트
if [ -f "api_server/.env" ]; then
  # 백업 생성
  cp api_server/.env api_server/.env.backup.$(date +%Y%m%d_%H%M%S)

  # 키 업데이트
  sed -i "s/KAKAO_REST_API_KEY=.*/KAKAO_REST_API_KEY=\"$NEW_KEY\"/" api_server/.env
  echo "✅ API 서버 .env 업데이트 완료"
else
  echo "❌ API 서버 .env 파일을 찾을 수 없습니다"
fi

# 스크립트 .env 업데이트
if [ -f "scripts/.env" ]; then
  # 백업 생성
  cp scripts/.env scripts/.env.backup.$(date +%Y%m%d_%H%M%S)

  # 키 업데이트
  sed -i "s/KAKAO_API_KEY=.*/KAKAO_API_KEY=\"$NEW_KEY\"/" scripts/.env
  echo "✅ 스크립트 .env 업데이트 완료"
else
  echo "❌ 스크립트 .env 파일을 찾을 수 없습니다"
fi

echo ""
echo "🎉 카카오 API 키 동기화 완료!"
echo "🔑 새 키: $NEW_KEY"
echo ""
echo "📋 다음 단계:"
echo "  1. API 서버 재시작: cd api_server && npm start"
echo "  2. 검색 기능 테스트: 브라우저에서 지도 검색 확인"
echo "  3. 스크립트 테스트: cd scripts && python3 add_coordinates.py test"