# 전처리된 흡연구역 데이터 검증 시스템

## 📋 개요
전처리된 흡연구역 주소 데이터를 Postcodify API로 검증하여 우편번호를 추가하는 시스템입니다.

## 📁 파일 구조
```
scripts/
├── validate_preprocessed_data.py    # 메인 검증 스크립트
├── preview_and_test.py              # 미리보기 및 테스트 스크립트
└── README_전처리데이터검증.md       # 이 가이드

data/
└── total_smoking_place.csv          # 전처리된 입력 파일 (사용자 제공)
```

## 📊 입력 파일 형식

### 필수 파일: `data/total_smoking_place.csv`

**필수 컬럼:**
- `주소`: 전처리된 주소 (예: "서울특별시 강남구 테헤란로 152")
- `원본파일명`: 원본 CSV 파일명 (예: "서울특별시_강남구_흡연구역_20250101.csv")
- `우편번호`: 빈 컬럼 (자동으로 생성되며, 비어있어도 됨)

**예시:**
```csv
주소,원본파일명,우편번호
서울특별시 강남구 테헤란로 152,서울특별시_강남구_흡연구역_20250101.csv,
경기도 성남시 분당구 판교역로 166,경기도_성남시_흡연구역_20250101.csv,
부산광역시 해운대구 센텀중앙로 79,부산광역시_해운대구_흡연구역_20250101.csv,
```

## 🚀 사용 방법

### 1단계: 미리보기 및 테스트
```bash
cd scripts
python3 preview_and_test.py
```

**확인 내용:**
- 파일 존재 여부 및 구조
- 데이터 품질 (NULL값, 빈 문자열 등)
- API 연결 테스트
- 샘플 3개 주소 검증 테스트

### 2단계: 전체 검증 실행
```bash
cd scripts
python3 validate_preprocessed_data.py
```

## 📤 출력 파일

### 1. 검증된 CSV 파일
**파일명:** `validated_total_smoking_place_YYYYMMDD_HHMMSS.csv`

**컬럼 구조:**
- `주소`: 원본 주소
- `원본파일명`: 원본 CSV 파일명
- `우편번호`: API에서 받은 우편번호 (예: "06164")
- `표준화주소`: API에서 받은 표준화된 주소
- `지번주소`: API에서 받은 지번 주소
- `검증상태`: "성공" 또는 "실패"
- `검증일시`: 검증 수행 일시

### 2. 상세 리포트 JSON 파일
**파일명:** `validation_report_YYYYMMDD_HHMMSS.json`

**구조:**
```json
{
  "summary": {
    "total_count": 1000,
    "success_count": 850,
    "fail_count": 150,
    "success_rate": 85.0,
    "start_time": "2025-01-01T10:00:00",
    "end_time": "2025-01-01T10:30:00",
    "processing_time": "0:30:00"
  },
  "detailed_results": [
    {
      "index": 0,
      "original_address": "서울특별시 강남구 테헤란로 152",
      "original_file": "서울특별시_강남구_흡연구역.csv",
      "status": "success",
      "postcode": "06164",
      "validated_address": "서울특별시 강남구 테헤란로 152",
      "validation_time": "2025-01-01 10:00:01"
    }
  ]
}
```

## ⏱️ 처리 시간 및 성능

### 예상 처리 시간
- **API 호출 간격**: 0.2초 (API 제한 고려)
- **1,000개 주소**: 약 3-4분
- **5,000개 주소**: 약 17-20분
- **10,000개 주소**: 약 35-40분

### 진행상황 모니터링
- 10개 처리마다 진행률 및 성공률 표시
- 실시간 성공/실패 상태 출력
- 예상 완료 시간 표시

## 🔧 문제 해결

### 파일 관련 오류
```
❌ 파일 없음: data/total_smoking_place.csv
```
**해결방법:** `data/total_smoking_place.csv` 파일을 올바른 위치에 배치

### 인코딩 오류
```
❌ 모든 인코딩 시도 실패
```
**해결방법:** CSV 파일을 UTF-8 인코딩으로 저장하거나 Excel에서 "CSV UTF-8"로 저장

### API 연결 오류
```
❌ API 호출 실패: HTTPSConnectionPool
```
**해결방법:**
- 인터넷 연결 확인
- 방화벽 설정 확인
- 잠시 후 재시도

### 컬럼 누락 오류
```
❌ 필수 컬럼 누락: ['주소']
```
**해결방법:** CSV 파일에 필수 컬럼('주소', '원본파일명') 추가

## 📊 검증 결과 해석

### 성공률 기준
- **90% 이상**: 매우 우수 (데이터 품질 높음)
- **80-90%**: 우수 (일반적인 수준)
- **70-80%**: 보통 (일부 주소 형식 문제)
- **70% 미만**: 주의 (데이터 전처리 재검토 필요)

### 주요 실패 원인
1. **지번주소**: 도로명주소로 변환 필요
2. **불완전한 주소**: 시/구/동 정보 누락
3. **특수문자**: 주소에 포함된 괄호, 하이픈 등
4. **건물명만**: 도로명이나 지번 정보 부족

## 🔄 재처리 방법

### 실패한 주소 재처리
1. `validation_report_*.json`에서 실패한 주소 확인
2. 실패 원인에 따라 주소 수정
3. 수정된 주소로 CSV 파일 업데이트
4. 검증 스크립트 재실행

### 부분 재처리
특정 주소만 재검증하려면 별도 CSV 파일로 분리하여 처리

## 📞 지원

### 로그 파일 위치
- 실행 중 모든 출력이 콘솔에 표시됨
- 필요시 리다이렉션으로 로그 파일 저장:
  ```bash
  python3 validate_preprocessed_data.py > validation.log 2>&1
  ```

### 성능 최적화
- 대용량 데이터의 경우 배치 단위로 나누어 처리
- API 호출 간격 조정 (현재 0.2초)
- 멀티프로세싱 적용 (향후 개선 예정)

## 📈 사용 예시

### 소규모 테스트 (100개 주소)
```bash
# 1. 미리보기
python3 preview_and_test.py

# 2. 검증 실행 (약 20초 소요)
python3 validate_preprocessed_data.py
```

### 대규모 처리 (10,000개 주소)
```bash
# 1. 미리보기로 데이터 품질 확인
python3 preview_and_test.py

# 2. 백그라운드에서 실행 (약 35분 소요)
nohup python3 validate_preprocessed_data.py > validation.log 2>&1 &

# 3. 진행상황 모니터링
tail -f validation.log
```