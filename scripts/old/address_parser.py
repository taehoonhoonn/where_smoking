#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pandas as pd
import requests
import time
import os
import glob
from urllib.parse import quote
import json

class AddressParser:
    def __init__(self):
        self.postcodify_url = "https://api.poesis.kr/post/search.php"
        self.data_dir = "../data"
        self.results = []

    def get_csv_files(self):
        """data 폴더의 모든 CSV 파일 목록 가져오기"""
        csv_files = glob.glob(os.path.join(self.data_dir, "*.csv"))
        csv_files = [f for f in csv_files if not f.endswith('.xlsx')]  # Excel 파일 제외
        return csv_files

    def read_csv_with_encoding(self, filepath):
        """다양한 인코딩으로 CSV 읽기 시도"""
        encodings = ['cp949', 'euc-kr', 'utf-8', 'utf-8-sig']

        for encoding in encodings:
            try:
                df = pd.read_csv(filepath, encoding=encoding)
                print(f"✅ {os.path.basename(filepath)} - 인코딩: {encoding}")
                return df, encoding
            except UnicodeDecodeError:
                continue
            except Exception as e:
                print(f"❌ {os.path.basename(filepath)} - {encoding}: {str(e)}")
                continue

        print(f"⚠️ {os.path.basename(filepath)} - 모든 인코딩 실패")
        return None, None

    def extract_address_from_row(self, row):
        """행에서 주소로 보이는 필드 추출"""
        address_candidates = []

        # 가능한 주소 필드명들
        address_fields = ['주소', '설치 위치', '위치', '소재지', '설치위치', '위치정보',
                         '설치장소', '장소', '지번주소', '도로명주소', '상세주소',
                         '소재지도로명주소', '소재지지번주소', '소재지(도로명)', '소재지주소']

        for field in address_fields:
            if field in row.index and pd.notna(row[field]):
                address = str(row[field]).strip()
                if len(address) > 5:  # 최소 길이 체크
                    address_candidates.append(address)

        # 가장 긴 주소를 선택 (보통 더 상세함)
        if address_candidates:
            return max(address_candidates, key=len)

        return None

    def validate_address_with_postcodify(self, address):
        """Postcodify API로 주소 검증"""
        try:
            # URL 인코딩
            encoded_address = quote(address, safe='')

            # 올바른 파라미터로 API 호출
            params = {
                'q': address,
                'v': '3.0.0-smoking-app',
                'ref': 'localhost'
            }

            response = requests.get(self.postcodify_url, params=params, timeout=10)

            if response.status_code == 200:
                data = response.json()

                # 응답 구조 확인
                if isinstance(data, dict) and 'count' in data:
                    if data.get('count', 0) > 0 and 'results' in data:
                        return True, data['results'][0]
                    else:
                        return False, None
                elif isinstance(data, list) and len(data) > 0:
                    # 배열 형태로 반환되는 경우
                    return True, data[0]
                else:
                    return False, None
            else:
                print(f"API 오류: {response.status_code} - {response.text}")
                return False, None

        except Exception as e:
            print(f"API 호출 실패: {str(e)}")
            return False, None

    def process_single_csv(self, filepath):
        """단일 CSV 파일 처리"""
        print(f"\n📁 처리 중: {os.path.basename(filepath)}")

        df, encoding = self.read_csv_with_encoding(filepath)
        if df is None:
            return

        print(f"컬럼들: {list(df.columns)}")
        print(f"총 {len(df)}개 행")

        # 주소 추출 및 검증
        valid_addresses = []
        invalid_addresses = []

        for idx, row in df.iterrows():
            address = self.extract_address_from_row(row)

            if address:
                print(f"  주소 추출: {address}")

                # API 호출 제한을 위한 지연
                time.sleep(0.1)

                is_valid, result = self.validate_address_with_postcodify(address)

                if is_valid:
                    print(f"    ✅ 검증 성공")
                    valid_addresses.append({
                        'file': os.path.basename(filepath),
                        'row_index': idx,
                        'original_address': address,
                        'postcode': result.get('postcode', ''),
                        'address': result.get('address', ''),
                        'details': result.get('details', {}),
                        'row_data': row.to_dict()
                    })
                else:
                    print(f"    ❌ 검증 실패")
                    invalid_addresses.append({
                        'file': os.path.basename(filepath),
                        'row_index': idx,
                        'original_address': address,
                        'row_data': row.to_dict()
                    })
            else:
                print(f"  ⚠️ 주소 필드를 찾을 수 없음 (행 {idx})")

        print(f"✅ 유효한 주소: {len(valid_addresses)}개")
        print(f"❌ 무효한 주소: {len(invalid_addresses)}개")

        return {
            'file': filepath,
            'encoding': encoding,
            'valid_addresses': valid_addresses,
            'invalid_addresses': invalid_addresses,
            'total_rows': len(df)
        }

    def run_sample_test(self, max_files=5):
        """샘플 파일들로 테스트 실행"""
        csv_files = self.get_csv_files()[:max_files]

        print(f"🔍 {len(csv_files)}개 파일 샘플 테스트 시작")

        all_results = []

        for filepath in csv_files:
            result = self.process_single_csv(filepath)
            if result:
                all_results.append(result)

        # 결과 요약
        print("\n" + "="*50)
        print("📊 처리 결과 요약")
        print("="*50)

        total_valid = sum(len(r['valid_addresses']) for r in all_results)
        total_invalid = sum(len(r['invalid_addresses']) for r in all_results)
        total_rows = sum(r['total_rows'] for r in all_results)

        print(f"처리된 파일: {len(all_results)}개")
        print(f"총 행 수: {total_rows}개")
        print(f"유효한 주소: {total_valid}개")
        print(f"무효한 주소: {total_invalid}개")
        print(f"성공률: {(total_valid/(total_valid+total_invalid)*100):.1f}%" if (total_valid+total_invalid) > 0 else "0%")

        # 무효한 주소들 상세 출력
        if total_invalid > 0:
            print("\n❌ 검증 실패한 주소들:")
            for result in all_results:
                if result['invalid_addresses']:
                    print(f"\n📁 {result['file']}:")
                    for invalid in result['invalid_addresses']:
                        print(f"  - {invalid['original_address']}")

        return all_results

if __name__ == "__main__":
    parser = AddressParser()
    results = parser.run_sample_test()