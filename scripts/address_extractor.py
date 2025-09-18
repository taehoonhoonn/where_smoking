#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pandas as pd
import os
import glob
import json

class AddressExtractor:
    def __init__(self):
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

    def extract_all_addresses(self):
        """모든 CSV 파일에서 주소 정보 추출"""
        csv_files = self.get_csv_files()
        all_addresses = []

        print(f"🔍 총 {len(csv_files)}개 CSV 파일 처리 시작\n")

        for filepath in csv_files:
            print(f"📁 처리 중: {os.path.basename(filepath)}")

            df, encoding = self.read_csv_with_encoding(filepath)
            if df is None:
                print("  ❌ 파일 읽기 실패\n")
                continue

            print(f"  인코딩: {encoding}")
            print(f"  컬럼들: {list(df.columns)}")
            print(f"  총 {len(df)}개 행")

            # 주소 관련 필드 찾기
            address_fields = self.find_address_fields(df.columns)
            print(f"  주소 필드: {address_fields}")

            if not address_fields:
                print("  ⚠️ 주소 필드 없음\n")
                continue

            # 각 행에서 주소 추출
            for idx, row in df.iterrows():
                address_data = {}

                for field in address_fields:
                    if pd.notna(row[field]):
                        address_data[field] = str(row[field]).strip()

                if address_data:
                    # 기본 정보 추가
                    address_info = {
                        'file': os.path.basename(filepath),
                        'row_index': idx,
                        'addresses': address_data,
                        'all_data': row.to_dict()
                    }

                    # 위도/경도 정보가 있다면 추가
                    lat_fields = [col for col in df.columns if '위도' in col or 'latitude' in col.lower()]
                    lng_fields = [col for col in df.columns if '경도' in col or 'longitude' in col.lower()]

                    if lat_fields and lng_fields:
                        try:
                            address_info['latitude'] = float(row[lat_fields[0]])
                            address_info['longitude'] = float(row[lng_fields[0]])
                        except (ValueError, TypeError):
                            pass

                    all_addresses.append(address_info)

            print(f"  ✅ {len([a for a in all_addresses if a['file'] == os.path.basename(filepath)])}개 주소 추출\n")

        return all_addresses

    def find_address_fields(self, columns):
        """컬럼명에서 주소 관련 필드 찾기"""
        address_keywords = [
            '주소', '위치', '소재지', '설치위치', '설치 위치', '위치정보',
            '설치장소', '장소', '지번주소', '도로명주소', '상세주소',
            '소재지주소', '소재지도로명주소', '소재지지번주소', '소재지(도로명)'
        ]

        address_fields = []
        for col in columns:
            col_lower = str(col).lower()
            for keyword in address_keywords:
                if keyword in col:
                    address_fields.append(col)
                    break

        return address_fields

    def save_results(self, addresses, output_file="extracted_addresses.json"):
        """결과를 JSON 파일로 저장"""
        with open(output_file, 'w', encoding='utf-8') as f:
            json.dump(addresses, f, ensure_ascii=False, indent=2)

        print(f"💾 결과 저장: {output_file}")

    def print_summary(self, addresses):
        """추출 결과 요약 출력"""
        print("\n" + "="*60)
        print("📊 주소 추출 결과 요약")
        print("="*60)

        total_addresses = len(addresses)
        files_processed = len(set(addr['file'] for addr in addresses))
        addresses_with_coords = len([addr for addr in addresses if 'latitude' in addr and 'longitude' in addr])

        print(f"처리된 파일: {files_processed}개")
        print(f"추출된 주소: {total_addresses}개")
        print(f"좌표 정보 있음: {addresses_with_coords}개")
        print(f"좌표 정보 없음: {total_addresses - addresses_with_coords}개")

        # 파일별 통계
        print("\n📁 파일별 추출 현황:")
        file_stats = {}
        for addr in addresses:
            file = addr['file']
            if file not in file_stats:
                file_stats[file] = {'total': 0, 'with_coords': 0}
            file_stats[file]['total'] += 1
            if 'latitude' in addr and 'longitude' in addr:
                file_stats[file]['with_coords'] += 1

        for file, stats in file_stats.items():
            coord_ratio = f"({stats['with_coords']}/{stats['total']} 좌표있음)"
            print(f"  {file}: {stats['total']}개 {coord_ratio}")

        # 샘플 주소 몇 개 출력
        print("\n🏠 추출된 주소 샘플:")
        for addr in addresses[:5]:
            print(f"  📍 {addr['file']}: {list(addr['addresses'].values())[0] if addr['addresses'] else 'N/A'}")
            if 'latitude' in addr:
                print(f"     좌표: ({addr['latitude']}, {addr['longitude']})")

if __name__ == "__main__":
    extractor = AddressExtractor()
    addresses = extractor.extract_all_addresses()

    extractor.print_summary(addresses)
    extractor.save_results(addresses)