#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pandas as pd
import requests
import time
import json
from datetime import datetime
from urllib.parse import quote

class PreprocessedDataValidator:
    def __init__(self, input_file="data/total_smoking_place.csv"):
        self.input_file = input_file
        self.postcodify_url = "https://api.poesis.kr/post/search.php"
        self.validation_results = []
        self.stats = {
            'total_count': 0,
            'success_count': 0,
            'fail_count': 0,
            'start_time': None,
            'end_time': None
        }

    def load_preprocessed_data(self):
        """전처리된 CSV 파일 로드"""
        try:
            # 다양한 인코딩으로 시도
            encodings = ['utf-8', 'cp949', 'euc-kr', 'utf-8-sig']

            for encoding in encodings:
                try:
                    df = pd.read_csv(self.input_file, encoding=encoding)
                    print(f"✅ 파일 로드 성공 (인코딩: {encoding})")
                    break
                except UnicodeDecodeError:
                    continue
            else:
                raise Exception("모든 인코딩 시도 실패")

            # 필수 컬럼 확인
            required_columns = ['주소', '원본파일명']
            missing_columns = [col for col in required_columns if col not in df.columns]

            if missing_columns:
                raise Exception(f"필수 컬럼 누락: {missing_columns}")

            # 우편번호 컬럼이 없으면 추가
            if '우편번호' not in df.columns:
                df['우편번호'] = ''

            print(f"📊 데이터 정보:")
            print(f"  - 총 행 수: {len(df)}개")
            print(f"  - 컬럼: {list(df.columns)}")
            print(f"  - 주소 데이터 샘플:")
            for i, addr in enumerate(df['주소'].head(3)):
                if pd.notna(addr):
                    print(f"    {i+1}. {addr}")

            return df

        except Exception as e:
            print(f"❌ 파일 로드 실패: {e}")
            return None

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
                        result = data['results'][0]
                        return True, {
                            'postcode': result.get('postcode5', ''),
                            'validated_address': f"{result.get('ko_common', '')} {result.get('ko_doro', '')}".strip(),
                            'jibeon_address': f"{result.get('ko_common', '')} {result.get('ko_jibeon', '')}".strip(),
                            'building_name': result.get('building_name', ''),
                            'other_addresses': result.get('other_addresses', '')
                        }
                    else:
                        return False, {'error': 'No results found'}
                elif isinstance(data, list) and len(data) > 0:
                    result = data[0]
                    return True, {
                        'postcode': result.get('postcode5', ''),
                        'validated_address': f"{result.get('ko_common', '')} {result.get('ko_doro', '')}".strip(),
                        'jibeon_address': f"{result.get('ko_common', '')} {result.get('ko_jibeon', '')}".strip(),
                        'building_name': result.get('building_name', ''),
                        'other_addresses': result.get('other_addresses', '')
                    }
                else:
                    return False, {'error': 'Invalid response format'}
            else:
                return False, {'error': f'HTTP {response.status_code}'}

        except Exception as e:
            return False, {'error': str(e)}

    def process_all_addresses(self, df):
        """모든 주소 처리"""
        self.stats['total_count'] = len(df)
        self.stats['start_time'] = datetime.now()

        print(f"\n🚀 {self.stats['total_count']}개 주소 검증 시작")
        print(f"⏰ 시작 시간: {self.stats['start_time'].strftime('%Y-%m-%d %H:%M:%S')}")
        print(f"⏱️ 예상 소요 시간: {self.stats['total_count'] * 0.2 / 60:.1f}분")
        print("="*60)

        # 결과를 저장할 컬럼들 초기화
        df['우편번호'] = ''
        df['표준화주소'] = ''
        df['지번주소'] = ''
        df['검증상태'] = ''
        df['검증일시'] = ''

        for idx, row in df.iterrows():
            address = str(row['주소']).strip()
            original_file = str(row['원본파일명']).strip()

            print(f"\n📍 [{idx+1}/{len(df)}] 검증 중: {address}")
            print(f"   원본파일: {original_file}")

            # API 호출
            is_valid, result = self.validate_address_with_postcodify(address)

            # 결과 저장
            validation_time = datetime.now().strftime('%Y-%m-%d %H:%M:%S')

            if is_valid:
                df.at[idx, '우편번호'] = result['postcode']
                df.at[idx, '표준화주소'] = result['validated_address']
                df.at[idx, '지번주소'] = result['jibeon_address']
                df.at[idx, '검증상태'] = '성공'
                df.at[idx, '검증일시'] = validation_time

                self.stats['success_count'] += 1
                print(f"   ✅ 성공 - 우편번호: {result['postcode']}")
                print(f"   📍 표준화주소: {result['validated_address']}")

                # 상세 결과 저장
                self.validation_results.append({
                    'index': idx,
                    'original_address': address,
                    'original_file': original_file,
                    'status': 'success',
                    'postcode': result['postcode'],
                    'validated_address': result['validated_address'],
                    'jibeon_address': result['jibeon_address'],
                    'building_name': result.get('building_name', ''),
                    'other_addresses': result.get('other_addresses', ''),
                    'validation_time': validation_time
                })
            else:
                df.at[idx, '검증상태'] = '실패'
                df.at[idx, '검증일시'] = validation_time

                self.stats['fail_count'] += 1
                print(f"   ❌ 실패 - {result.get('error', 'Unknown error')}")

                # 실패 결과 저장
                self.validation_results.append({
                    'index': idx,
                    'original_address': address,
                    'original_file': original_file,
                    'status': 'failed',
                    'error': result.get('error', 'Unknown error'),
                    'validation_time': validation_time
                })

            # API 호출 제한 (0.2초 대기)
            time.sleep(0.2)

            # 진행률 표시 (10개마다)
            if (idx + 1) % 10 == 0:
                progress = (idx + 1) / len(df) * 100
                success_rate = self.stats['success_count'] / (idx + 1) * 100
                print(f"\n📊 진행률: {progress:.1f}% | 성공률: {success_rate:.1f}% | 성공: {self.stats['success_count']}, 실패: {self.stats['fail_count']}")

        self.stats['end_time'] = datetime.now()
        return df

    def save_results(self, df):
        """결과 저장"""
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')

        # 1. 검증된 CSV 파일 저장
        output_csv = f"validated_total_smoking_place_{timestamp}.csv"
        df.to_csv(output_csv, index=False, encoding='utf-8-sig')
        print(f"✅ 검증 결과 CSV 저장: {output_csv}")

        # 2. 상세 리포트 JSON 저장
        report = {
            'summary': {
                'total_count': self.stats['total_count'],
                'success_count': self.stats['success_count'],
                'fail_count': self.stats['fail_count'],
                'success_rate': round(self.stats['success_count'] / self.stats['total_count'] * 100, 2),
                'start_time': self.stats['start_time'].isoformat(),
                'end_time': self.stats['end_time'].isoformat(),
                'processing_time': str(self.stats['end_time'] - self.stats['start_time'])
            },
            'detailed_results': self.validation_results
        }

        output_json = f"validation_report_{timestamp}.json"
        with open(output_json, 'w', encoding='utf-8') as f:
            json.dump(report, f, ensure_ascii=False, indent=2)
        print(f"✅ 상세 리포트 JSON 저장: {output_json}")

        return output_csv, output_json

    def print_final_summary(self):
        """최종 요약 출력"""
        duration = self.stats['end_time'] - self.stats['start_time']
        success_rate = self.stats['success_count'] / self.stats['total_count'] * 100

        print("\n" + "="*60)
        print("📊 검증 완료 - 최종 결과")
        print("="*60)
        print(f"🕐 처리 시간: {duration}")
        print(f"📋 총 주소 수: {self.stats['total_count']:,}개")
        print(f"✅ 검증 성공: {self.stats['success_count']:,}개 ({success_rate:.1f}%)")
        print(f"❌ 검증 실패: {self.stats['fail_count']:,}개 ({100-success_rate:.1f}%)")

        if self.stats['fail_count'] > 0:
            print(f"\n❌ 실패한 주소 샘플 (총 {self.stats['fail_count']}개 중 5개):")
            failed_samples = [r for r in self.validation_results if r['status'] == 'failed'][:5]
            for sample in failed_samples:
                print(f"  - {sample['original_address']} ({sample['original_file']})")

    def run(self):
        """메인 실행 함수"""
        print("🚀 전처리된 데이터 검증 시작")
        print("="*60)

        # 1. 데이터 로드
        df = self.load_preprocessed_data()
        if df is None:
            return False

        # 2. 주소 검증 실행
        validated_df = self.process_all_addresses(df)

        # 3. 결과 저장
        csv_file, json_file = self.save_results(validated_df)

        # 4. 최종 요약
        self.print_final_summary()

        print(f"\n🎉 모든 작업 완료!")
        print(f"📄 결과 파일: {csv_file}")
        print(f"📊 리포트 파일: {json_file}")

        return True

if __name__ == "__main__":
    validator = PreprocessedDataValidator()
    validator.run()