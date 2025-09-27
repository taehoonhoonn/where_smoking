#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pandas as pd
import requests
import re
from urllib.parse import quote

class AddressFixer:
    def __init__(self):
        self.postcodify_url = "https://api.poesis.kr/post/search.php"

    def fix_abbreviated_address(self, address):
        """축약된 주소 보완"""
        # 경북 → 경상북도
        address = address.replace('경북 ', '경상북도 ')
        address = address.replace('경남 ', '경상남도 ')
        address = address.replace('충북 ', '충청북도 ')
        address = address.replace('충남 ', '충청남도 ')
        address = address.replace('전북 ', '전라북도 ')
        address = address.replace('전남 ', '전라남도 ')
        return address

    def fix_detailed_address(self, address):
        """상세설명이 포함된 주소 정리"""
        # 불필요한 키워드 제거
        remove_keywords = ['본관 옆', '본관 앞', '청사 옆', '청사 앞', '건물 옆', '건물 앞']

        for keyword in remove_keywords:
            address = address.replace(keyword, '').strip()

        # 연속된 공백 제거
        address = re.sub(r'\s+', ' ', address)
        return address

    def try_alternative_parsing(self, address, row_data, file_name):
        """대체 파싱 방법 시도"""
        fixed_addresses = []

        # 1. 축약 주소 보완
        fixed_addr1 = self.fix_abbreviated_address(address)
        if fixed_addr1 != address:
            fixed_addresses.append(('축약주소_보완', fixed_addr1))

        # 2. 상세설명 제거
        fixed_addr2 = self.fix_detailed_address(address)
        if fixed_addr2 != address:
            fixed_addresses.append(('상세설명_제거', fixed_addr2))

        # 3. 지번주소에서 도로명 주소 컬럼 찾기
        if '동 ' in address and any(char.isdigit() for char in address):
            # 다른 주소 컬럼이 있는지 확인
            road_address_keywords = ['도로명주소', '소재지도로명주소']
            for keyword in road_address_keywords:
                if keyword in row_data and pd.notna(row_data[keyword]) and str(row_data[keyword]).strip():
                    fixed_addresses.append(('도로명주소_컬럼', str(row_data[keyword]).strip()))

        # 4. 파일명에서 지역 정보 추출하여 보완
        if len(address.split()) < 3:  # 주소가 너무 짧은 경우
            region_from_file = self.extract_region_from_filename(file_name)
            if region_from_file:
                fixed_addr4 = f"{region_from_file} {address}"
                fixed_addresses.append(('파일명_지역보완', fixed_addr4))

        return fixed_addresses

    def extract_region_from_filename(self, file_name):
        """파일명에서 지역 정보 추출"""
        # 파일명에서 시도, 시군구 정보 추출
        patterns = [
            r'(서울특별시|부산광역시|대구광역시|인천광역시|광주광역시|대전광역시|울산광역시|세종특별자치시)',
            r'(경기도|강원특별자치도|충청북도|충청남도|전라북도|전라남도|경상북도|경상남도|제주특별자치도)',
            r'([가-힣]+시|[가-힣]+군|[가-힣]+구)'
        ]

        for pattern in patterns:
            match = re.search(pattern, file_name)
            if match:
                return match.group(1)

        return None

    def validate_fixed_address(self, address):
        """수정된 주소 검증"""
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

    def fix_failed_addresses(self, failed_addresses):
        """실패한 주소들 수정 시도"""
        fixed_results = []

        for failed in failed_addresses:
            address = failed['original_address']
            row_data = failed.get('row_data', {})
            file_name = failed['file']

            print(f"\n🔧 수정 시도: {address}")
            print(f"   파일: {file_name}")

            # 대체 파싱 방법들 시도
            fixed_addresses = self.try_alternative_parsing(address, row_data, file_name)

            success = False
            for method, fixed_addr in fixed_addresses:
                print(f"   📝 {method}: {fixed_addr}")

                # 수정된 주소 검증
                is_valid, result = self.validate_fixed_address(fixed_addr)

                if is_valid:
                    print(f"   ✅ 검증 성공!")

                    fixed_result = {
                        'original_address': address,
                        'fixed_address': fixed_addr,
                        'fix_method': method,
                        'postcode': result.get('postcode5', ''),
                        'validated_address': f"{result.get('ko_common', '')} {result.get('ko_doro', '')}".strip(),
                        'jibeon_address': f"{result.get('ko_common', '')} {result.get('ko_jibeon', '')}".strip(),
                        'file': file_name,
                        'row_data': row_data
                    }

                    # 기존 좌표 정보가 있다면 추가
                    if 'original_latitude' in failed:
                        fixed_result['original_latitude'] = failed['original_latitude']
                        fixed_result['original_longitude'] = failed['original_longitude']

                    fixed_results.append(fixed_result)
                    success = True
                    break
                else:
                    print(f"   ❌ 검증 실패")

            if not success:
                print(f"   💔 모든 수정 방법 실패")
                # 원본 좌표 정보가 있는지 확인
                if any(keyword in str(row_data) for keyword in ['위도', '경도', 'latitude', 'longitude']):
                    print(f"   📍 원본 좌표 정보 있음 - 원본 주소로 보존")

        return fixed_results

if __name__ == "__main__":
    # 테스트용
    import json

    fixer = AddressFixer()

    # 기존 검증 결과 로드
    with open('validated_addresses.json', 'r', encoding='utf-8') as f:
        results = json.load(f)

    failed_addresses = results['invalid_addresses']

    print(f"🔧 {len(failed_addresses)}개 실패 주소 수정 시도")
    fixed_results = fixer.fix_failed_addresses(failed_addresses)

    print(f"\n📊 수정 결과:")
    print(f"✅ 수정 성공: {len(fixed_results)}개")
    print(f"❌ 수정 실패: {len(failed_addresses) - len(fixed_results)}개")

    # 수정 결과 저장
    with open('fixed_addresses.json', 'w', encoding='utf-8') as f:
        json.dump(fixed_results, f, ensure_ascii=False, indent=2)

    print(f"💾 수정 결과 저장: fixed_addresses.json")