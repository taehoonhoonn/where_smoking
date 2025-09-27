#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pandas as pd
import requests
import os
from datetime import datetime

class PreviewAndTest:
    def __init__(self, input_file="data/total_smoking_place.csv"):
        self.input_file = input_file
        self.postcodify_url = "https://api.poesis.kr/post/search.php"

    def check_file_exists(self):
        """파일 존재 여부 확인"""
        if os.path.exists(self.input_file):
            print(f"✅ 파일 존재: {self.input_file}")
            return True
        else:
            print(f"❌ 파일 없음: {self.input_file}")
            print(f"📍 현재 작업 디렉토리: {os.getcwd()}")
            print(f"📁 data 폴더 내용:")

            data_dir = "data"
            if os.path.exists(data_dir):
                files = os.listdir(data_dir)
                for file in files:
                    print(f"  - {file}")
            else:
                print(f"  data 폴더가 존재하지 않습니다.")

            return False

    def preview_file_structure(self):
        """파일 구조 미리보기"""
        if not self.check_file_exists():
            return None

        try:
            # 다양한 인코딩으로 시도
            encodings = ['utf-8', 'cp949', 'euc-kr', 'utf-8-sig']
            df = None

            for encoding in encodings:
                try:
                    df = pd.read_csv(self.input_file, encoding=encoding)
                    print(f"✅ 파일 로드 성공 (인코딩: {encoding})")
                    break
                except UnicodeDecodeError:
                    print(f"❌ {encoding} 인코딩 실패")
                    continue
                except Exception as e:
                    print(f"❌ {encoding} 인코딩 오류: {e}")
                    continue

            if df is None:
                print("❌ 모든 인코딩 시도 실패")
                return None

            print(f"\n📊 파일 정보:")
            print(f"  - 파일 크기: {os.path.getsize(self.input_file):,} bytes")
            print(f"  - 총 행 수: {len(df):,}개")
            print(f"  - 총 컬럼 수: {len(df.columns)}개")
            print(f"  - 컬럼명: {list(df.columns)}")

            # 필수 컬럼 확인
            required_columns = ['주소', '원본파일명']
            print(f"\n🔍 필수 컬럼 확인:")
            for col in required_columns:
                if col in df.columns:
                    print(f"  ✅ '{col}' 컬럼 존재")
                else:
                    print(f"  ❌ '{col}' 컬럼 없음")

            # 우편번호 컬럼 확인
            if '우편번호' in df.columns:
                print(f"  ✅ '우편번호' 컬럼 존재")
                empty_count = df['우편번호'].isna().sum()
                print(f"    - 빈 값: {empty_count}개 / {len(df)}개")
            else:
                print(f"  ⚠️ '우편번호' 컬럼 없음 (자동 생성됩니다)")

            # 데이터 샘플 출력
            print(f"\n📋 데이터 샘플 (첫 5개 행):")
            print("="*80)
            for idx, row in df.head(5).iterrows():
                print(f"{idx+1}. 주소: {row.get('주소', 'N/A')}")
                print(f"   원본파일: {row.get('원본파일명', 'N/A')}")
                if '우편번호' in df.columns:
                    print(f"   우편번호: {row.get('우편번호', 'N/A')}")
                print("-" * 60)

            # 주소 데이터 품질 체크
            print(f"\n🔍 주소 데이터 품질 체크:")
            if '주소' in df.columns:
                null_count = df['주소'].isna().sum()
                empty_count = (df['주소'] == '').sum()
                short_count = (df['주소'].str.len() < 10).sum()

                print(f"  - NULL 값: {null_count}개")
                print(f"  - 빈 문자열: {empty_count}개")
                print(f"  - 10자 미만 주소: {short_count}개")
                print(f"  - 유효한 주소: {len(df) - null_count - empty_count}개")

            return df

        except Exception as e:
            print(f"❌ 파일 미리보기 실패: {e}")
            return None

    def test_api_connection(self):
        """API 연결 테스트"""
        print(f"\n🔌 Postcodify API 연결 테스트")
        print("="*50)

        test_addresses = [
            "서울특별시 강남구 테헤란로 152",
            "경기도 성남시 분당구 판교역로 166",
            "부산광역시 해운대구 센텀중앙로 79"
        ]

        for i, address in enumerate(test_addresses, 1):
            print(f"\n{i}. 테스트 주소: {address}")

            try:
                params = {
                    'q': address,
                    'v': '3.0.0-smoking-app',
                    'ref': 'localhost'
                }

                response = requests.get(self.postcodify_url, params=params, timeout=10)

                if response.status_code == 200:
                    data = response.json()

                    if isinstance(data, dict) and 'count' in data:
                        if data.get('count', 0) > 0:
                            result = data['results'][0]
                            print(f"   ✅ API 성공")
                            print(f"   📮 우편번호: {result.get('postcode5', 'N/A')}")
                            print(f"   📍 표준화주소: {result.get('ko_common', '')} {result.get('ko_doro', '')}")
                        else:
                            print(f"   ⚠️ 검색 결과 없음")
                    else:
                        print(f"   ⚠️ 예상과 다른 응답 형식")
                else:
                    print(f"   ❌ HTTP 오류: {response.status_code}")

            except Exception as e:
                print(f"   ❌ API 호출 실패: {e}")

    def test_sample_validation(self, df, sample_count=3):
        """샘플 데이터로 검증 테스트"""
        if df is None or '주소' not in df.columns:
            print(f"\n❌ 샘플 테스트 불가: 유효한 데이터프레임이나 주소 컬럼이 없습니다.")
            return

        print(f"\n🧪 샘플 {sample_count}개 주소 검증 테스트")
        print("="*60)

        # 유효한 주소만 필터링
        valid_addresses = df[df['주소'].notna() & (df['주소'] != '')]

        if len(valid_addresses) == 0:
            print(f"❌ 유효한 주소가 없습니다.")
            return

        sample_size = min(sample_count, len(valid_addresses))
        samples = valid_addresses.head(sample_size)

        for idx, row in samples.iterrows():
            address = str(row['주소']).strip()
            original_file = str(row.get('원본파일명', 'N/A'))

            print(f"\n📍 [{idx+1}] 주소: {address}")
            print(f"    원본파일: {original_file}")

            try:
                params = {
                    'q': address,
                    'v': '3.0.0-smoking-app',
                    'ref': 'localhost'
                }

                response = requests.get(self.postcodify_url, params=params, timeout=10)

                if response.status_code == 200:
                    data = response.json()

                    if isinstance(data, dict) and 'count' in data:
                        if data.get('count', 0) > 0:
                            result = data['results'][0]
                            print(f"    ✅ 검증 성공")
                            print(f"    📮 우편번호: {result.get('postcode5', 'N/A')}")
                            print(f"    📍 표준화주소: {result.get('ko_common', '')} {result.get('ko_doro', '')}")
                            print(f"    🏠 지번주소: {result.get('ko_common', '')} {result.get('ko_jibeon', '')}")
                        else:
                            print(f"    ❌ 검증 실패: 검색 결과 없음")
                    else:
                        print(f"    ❌ 검증 실패: 예상과 다른 응답 형식")
                else:
                    print(f"    ❌ 검증 실패: HTTP {response.status_code}")

            except Exception as e:
                print(f"    ❌ 검증 실패: {e}")

    def run_full_preview(self):
        """전체 미리보기 실행"""
        print("🔍 전처리된 데이터 미리보기 및 테스트")
        print("="*60)
        print(f"📅 실행 시간: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")

        # 1. 파일 구조 미리보기
        df = self.preview_file_structure()

        # 2. API 연결 테스트
        self.test_api_connection()

        # 3. 샘플 검증 테스트
        if df is not None:
            self.test_sample_validation(df)

        print(f"\n🎯 미리보기 완료!")
        print(f"💡 전체 검증을 시작하려면 다음 명령을 실행하세요:")
        print(f"   python3 validate_preprocessed_data.py")

if __name__ == "__main__":
    preview = PreviewAndTest()
    preview.run_full_preview()