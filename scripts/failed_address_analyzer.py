#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pandas as pd
import json
import re
from collections import defaultdict

class FailedAddressAnalyzer:
    def __init__(self, validation_results_file="validated_addresses.json"):
        self.validation_results_file = validation_results_file
        self.data_dir = "../data"

    def load_validation_results(self):
        """검증 결과 로드"""
        with open(self.validation_results_file, 'r', encoding='utf-8') as f:
            return json.load(f)

    def analyze_failed_addresses(self):
        """검증 실패한 주소들 분석"""
        results = self.load_validation_results()
        failed_addresses = results['invalid_addresses']

        print(f"🔍 검증 실패한 주소 {len(failed_addresses)}개 분석")
        print("="*60)

        # 실패 유형별 분류
        failure_types = defaultdict(list)

        for failed in failed_addresses:
            address = failed['original_address']
            file_name = failed['file']

            # 실패 유형 분석
            failure_type = self.categorize_failure_type(address)
            failure_types[failure_type].append({
                'address': address,
                'file': file_name,
                'row_data': failed.get('row_data', {})
            })

        # 유형별 출력
        for failure_type, addresses in failure_types.items():
            print(f"\n📋 {failure_type} ({len(addresses)}개)")
            print("-" * 40)
            for addr in addresses:
                print(f"  📍 {addr['address']}")
                print(f"     파일: {addr['file']}")

                # 해당 CSV 파일에서 원본 데이터 확인
                self.examine_original_data(addr['file'], addr['address'])
                print()

    def categorize_failure_type(self, address):
        """주소 실패 유형 분류"""
        if '동 ' in address and re.search(r'\d+-\d+$', address):
            return "지번주소 (동-번지)"
        elif '본관' in address or '옆' in address or '앞' in address:
            return "상세설명 포함 주소"
        elif len(address.split()) < 3:
            return "축약된 주소"
        elif address.count('도') > 1 or address.count('시') > 1:
            return "중복 지역명"
        else:
            return "기타 형태"

    def examine_original_data(self, file_name, target_address):
        """원본 CSV 파일에서 해당 주소의 전체 데이터 확인"""
        try:
            df = pd.read_csv(f"{self.data_dir}/{file_name}", encoding='cp949')

            # 해당 주소가 포함된 행 찾기
            for idx, row in df.iterrows():
                for col in df.columns:
                    if pd.notna(row[col]) and target_address in str(row[col]):
                        print(f"     컬럼명: {list(df.columns)}")

                        # 주소 관련 컬럼들만 출력
                        address_cols = [col for col in df.columns if any(keyword in col for keyword in
                                      ['주소', '위치', '소재지', '설치', '도로명', '지번'])]

                        if address_cols:
                            print(f"     주소 관련 데이터:")
                            for col in address_cols:
                                print(f"       {col}: {row[col]}")

                        # 좌표 정보가 있는지 확인
                        coord_cols = [col for col in df.columns if any(keyword in col for keyword in
                                    ['위도', '경도', 'latitude', 'longitude'])]

                        if coord_cols:
                            print(f"     좌표 정보:")
                            for col in coord_cols:
                                print(f"       {col}: {row[col]}")

                        return

        except Exception as e:
            print(f"     ❌ 파일 읽기 실패: {e}")

    def suggest_parsing_strategies(self):
        """실패 케이스별 파싱 전략 제안"""
        results = self.load_validation_results()
        failed_addresses = results['invalid_addresses']

        print(f"\n🔧 실패 케이스별 파싱 전략 제안")
        print("="*60)

        strategies = {
            "지번주소 (동-번지)": [
                "1. 도로명 주소 컬럼이 별도로 있는지 확인",
                "2. 지번 주소를 도로명 주소로 변환하는 API 사용",
                "3. 동명 + 번지를 '동' 제거 후 재시도"
            ],
            "상세설명 포함 주소": [
                "1. '본관', '옆', '앞' 등 키워드 제거 후 재시도",
                "2. 정규식으로 핵심 주소만 추출",
                "3. 건물명이 별도 컬럼에 있는지 확인"
            ],
            "축약된 주소": [
                "1. 시도명 보완 (예: '경북' → '경상북도')",
                "2. 다른 컬럼에서 완전한 주소 정보 찾기",
                "3. 파일명에서 지역 정보 추출하여 보완"
            ]
        }

        for strategy_type, methods in strategies.items():
            print(f"\n📋 {strategy_type}")
            for method in methods:
                print(f"  {method}")

if __name__ == "__main__":
    analyzer = FailedAddressAnalyzer()
    analyzer.analyze_failed_addresses()
    analyzer.suggest_parsing_strategies()