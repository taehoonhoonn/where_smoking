#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pandas as pd
import requests
import time
import os
import glob
from urllib.parse import quote
import json

class FullAddressValidator:
    def __init__(self):
        self.postcodify_url = "https://api.poesis.kr/post/search.php"
        self.data_dir = "../data"
        self.results = []

    def get_csv_files(self):
        """data 폴더의 모든 CSV 파일 목록 가져오기"""
        csv_files = glob.glob(os.path.join(self.data_dir, "*.csv"))
        csv_files = [f for f in csv_files if not f.endswith('.xlsx')]
        return csv_files

    def read_csv_with_encoding(self, filepath):
        """다양한 인코딩으로 CSV 읽기 시도"""
        encodings = ['cp949', 'euc-kr', 'utf-8', 'utf-8-sig']

        for encoding in encodings:
            try:
                df = pd.read_csv(filepath, encoding=encoding)
                return df, encoding
            except:
                continue
        return None, None

    def find_address_fields(self, columns):
        """컬럼명에서 주소 관련 필드 찾기"""
        address_keywords = [
            '주소', '위치', '소재지', '설치위치', '설치 위치', '위치정보',
            '설치장소', '장소', '지번주소', '도로명주소', '상세주소',
            '소재지주소', '소재지도로명주소', '소재지지번주소', '소재지(도로명)',
            '흡연시설 설치위치', '흡연시설 위치', '설치위치', '영업소소재지(도로 명)',
            '시설주소(도로명)', '설치도로명주소', '도로명주소'
        ]

        address_fields = []
        for col in columns:
            for keyword in address_keywords:
                if keyword in col:
                    address_fields.append(col)
                    break

        return address_fields

    def extract_address_from_row(self, row, address_fields):
        """행에서 주소 추출"""
        for field in address_fields:
            if pd.notna(row[field]):
                address = str(row[field]).strip()
                if len(address) > 5:  # 최소 길이 체크
                    return address, field
        return None, None

    def validate_address_with_postcodify(self, address):
        """Postcodify API로 주소 검증"""
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
                    if data.get('count', 0) > 0 and 'results' in data:
                        return True, data['results'][0]
                    else:
                        return False, None
                elif isinstance(data, list) and len(data) > 0:
                    return True, data[0]
                else:
                    return False, None
            else:
                return False, None

        except Exception as e:
            return False, None

    def process_all_files(self, max_files=None):
        """모든 CSV 파일 처리"""
        csv_files = self.get_csv_files()
        if max_files:
            csv_files = csv_files[:max_files]

        print(f"🔍 총 {len(csv_files)}개 파일 처리 시작\n")

        all_results = {
            'valid_addresses': [],
            'invalid_addresses': [],
            'file_stats': []
        }

        for i, filepath in enumerate(csv_files, 1):
            print(f"📁 [{i}/{len(csv_files)}] 처리 중: {os.path.basename(filepath)}")

            df, encoding = self.read_csv_with_encoding(filepath)
            if df is None:
                print("  ❌ 파일 읽기 실패\n")
                continue

            # 주소 관련 필드 찾기
            address_fields = self.find_address_fields(df.columns)

            if not address_fields:
                print("  ⚠️ 주소 필드 없음\n")
                continue

            print(f"  주소 필드: {address_fields}")
            print(f"  총 {len(df)}개 행 처리")

            valid_count = 0
            invalid_count = 0

            # 각 행 처리
            for idx, row in df.iterrows():
                address, field_used = self.extract_address_from_row(row, address_fields)

                if address:
                    # API 호출 제한을 위한 지연
                    time.sleep(0.2)

                    is_valid, result = self.validate_address_with_postcodify(address)

                    if is_valid:
                        valid_count += 1

                        # 위도/경도 정보 추가
                        lat_fields = [col for col in df.columns if '위도' in col or 'latitude' in col.lower()]
                        lng_fields = [col for col in df.columns if '경도' in col or 'longitude' in col.lower()]

                        validated_address = {
                            'file': os.path.basename(filepath),
                            'row_index': idx,
                            'original_address': address,
                            'field_used': field_used,
                            'postcode': result.get('postcode5', ''),
                            'validated_address': f"{result.get('ko_common', '')} {result.get('ko_doro', '')}".strip(),
                            'jibeon_address': f"{result.get('ko_common', '')} {result.get('ko_jibeon', '')}".strip(),
                            'building_name': result.get('building_name', ''),
                            'other_addresses': result.get('other_addresses', ''),
                            'row_data': row.to_dict()
                        }

                        # 기존 좌표 정보가 있다면 추가
                        if lat_fields and lng_fields:
                            try:
                                validated_address['original_latitude'] = float(row[lat_fields[0]])
                                validated_address['original_longitude'] = float(row[lng_fields[0]])
                            except (ValueError, TypeError):
                                pass

                        all_results['valid_addresses'].append(validated_address)
                    else:
                        invalid_count += 1
                        all_results['invalid_addresses'].append({
                            'file': os.path.basename(filepath),
                            'row_index': idx,
                            'original_address': address,
                            'field_used': field_used,
                            'row_data': row.to_dict()
                        })

            print(f"  ✅ 유효: {valid_count}개, ❌ 무효: {invalid_count}개")

            all_results['file_stats'].append({
                'file': os.path.basename(filepath),
                'total_rows': len(df),
                'valid_addresses': valid_count,
                'invalid_addresses': invalid_count,
                'success_rate': (valid_count / (valid_count + invalid_count) * 100) if (valid_count + invalid_count) > 0 else 0
            })

            print()

        return all_results

    def save_results(self, results, output_file="validated_addresses.json"):
        """결과를 JSON 파일로 저장"""
        with open(output_file, 'w', encoding='utf-8') as f:
            json.dump(results, f, ensure_ascii=False, indent=2)

        print(f"💾 결과 저장: {output_file}")

    def print_summary(self, results):
        """결과 요약 출력"""
        print("\n" + "="*60)
        print("📊 주소 검증 최종 결과")
        print("="*60)

        total_valid = len(results['valid_addresses'])
        total_invalid = len(results['invalid_addresses'])
        total_addresses = total_valid + total_invalid

        if total_addresses > 0:
            success_rate = (total_valid / total_addresses) * 100
        else:
            success_rate = 0

        print(f"처리된 파일: {len(results['file_stats'])}개")
        print(f"총 검증 주소: {total_addresses}개")
        print(f"✅ 검증 성공: {total_valid}개 ({success_rate:.1f}%)")
        print(f"❌ 검증 실패: {total_invalid}개 ({100-success_rate:.1f}%)")

        # 파일별 상세 통계
        print(f"\n📁 파일별 검증 결과:")
        for stat in results['file_stats']:
            print(f"  {stat['file']}: {stat['valid_addresses']}/{stat['valid_addresses']+stat['invalid_addresses']} ({stat['success_rate']:.1f}%)")

        # 검증 실패한 주소들 (일부만)
        if total_invalid > 0:
            print(f"\n❌ 검증 실패 주소 샘플 (총 {total_invalid}개 중 10개):")
            for invalid in results['invalid_addresses'][:10]:
                print(f"  - {invalid['original_address']} ({invalid['file']})")

if __name__ == "__main__":
    validator = FullAddressValidator()

    # 전체 파일 처리
    print("🚀 전체 51개 파일에 대해 주소 검증을 시작합니다.")
    print("⏰ 예상 소요 시간: 20-30분 (API 호출 제한 고려)")

    results = validator.process_all_files(max_files=None)

    validator.print_summary(results)
    validator.save_results(results)