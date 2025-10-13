#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pandas as pd
import requests
import time
import json
import os
from datetime import datetime
from dotenv import load_dotenv

class CoordinateAdder:
    def __init__(self, input_csv=None):
        # .env 파일 로드
        load_dotenv()

        self.input_csv = input_csv or os.getenv('INPUT_CSV', "validated_total_smoking_place_20250920_190021.csv")
        self.kakao_api_url = os.getenv('KAKAO_API_URL', "https://dapi.kakao.com/v2/local/search/address.json")
        self.api_key = os.getenv('KAKAO_API_KEY')
        self.api_delay = float(os.getenv('API_DELAY', 0.1))

    def load_data(self):
        """CSV 데이터 로드"""
        try:
            df = pd.read_csv(self.input_csv, encoding='utf-8-sig')
            print(f"✅ 파일 로드 성공: {len(df)}개 행")
            print(f"📊 컬럼: {list(df.columns)}")
            return df
        except Exception as e:
            print(f"❌ 파일 로드 실패: {e}")
            return None

    def fix_postcode_column(self, df):
        """api_우편번호 → 우편번호 컬럼으로 데이터 이동"""
        print("🔄 우편번호 컬럼 정리 중...")

        if 'api_우편번호' in df.columns:
            # 성공한 행의 api_우편번호를 우편번호 컬럼으로 이동
            success_mask = df['검증상태'] == '성공'
            df.loc[success_mask, '우편번호'] = df.loc[success_mask, 'api_우편번호']

            moved_count = success_mask.sum()
            print(f"✅ {moved_count}개 행의 우편번호 이동 완료")

            # api_우편번호 컬럼 제거
            df = df.drop('api_우편번호', axis=1)
            print("🗑️ api_우편번호 컬럼 제거 완료")

        return df

    def get_coordinates_from_kakao(self, address):
        """카카오 API로 주소를 좌표로 변환"""
        if not self.api_key:
            return False, "API 키가 설정되지 않음"

        try:
            headers = {
                'Authorization': f'KakaoAK {self.api_key}'
            }

            params = {
                'query': address,
                'analyze_type': 'similar'
            }

            response = requests.get(self.kakao_api_url, headers=headers, params=params, timeout=10)

            if response.status_code == 200:
                data = response.json()

                if data.get('documents') and len(data['documents']) > 0:
                    result = data['documents'][0]
                    return True, {
                        'longitude': float(result['x']),
                        'latitude': float(result['y']),
                        'address_name': result.get('address_name', ''),
                        'road_address': result.get('road_address', {}).get('address_name', '') if result.get('road_address') else ''
                    }
                else:
                    return False, "검색 결과 없음"
            else:
                return False, f"HTTP {response.status_code}: {response.text}"

        except Exception as e:
            return False, str(e)

    def add_coordinates_to_dataframe(self, df):
        """데이터프레임에 좌표 정보 추가"""
        print("🗺️ 카카오 API로 좌표 변환 시작")

        # API 키 확인
        if not self.api_key or self.api_key == 'your_kakao_rest_api_key_here':
            print("❌ 카카오 API 키가 설정되지 않았습니다.")
            print("💡 .env 파일의 KAKAO_API_KEY 값을 설정하거나")
            print("💡 https://developers.kakao.com/console/app 에서 REST API 키를 발급받으세요.")
            api_key = input("카카오 REST API 키를 입력하세요: ").strip()
            if not api_key:
                print("❌ API 키가 입력되지 않았습니다.")
                return df
            self.api_key = api_key

        print(f"⏰ 시작 시간: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")

        # 좌표 관련 컬럼 초기화 (기존 값이 있으면 유지)
        if 'kakao_longitude' not in df.columns:
            df['kakao_longitude'] = ''
        if 'kakao_latitude' not in df.columns:
            df['kakao_latitude'] = ''
        if '좌표변환상태' not in df.columns:
            df['좌표변환상태'] = ''
        if '좌표변환일시' not in df.columns:
            df['좌표변환일시'] = ''

        # 좌표가 이미 존재하면 Kakao API 호출을 건너뛰기 위한 헬퍼
        longitude_candidates = [
            col for col in [
                'kakao_longitude',
                'longitude',
                'longitutde',  # CSV 오타 대응
                '경도',
                'x',
                'lon'
            ] if col in df.columns
        ]

        latitude_candidates = [
            col for col in [
                'kakao_latitude',
                'latitude',
                '위도',
                'y',
                'lat'
            ] if col in df.columns
        ]

        def pick_coordinate(row, candidates):
            for column in candidates:
                value = row.get(column)
                if pd.isna(value):
                    continue
                if isinstance(value, str):
                    value = value.strip()
                    if value == '':
                        continue
                try:
                    return float(value)
                except (TypeError, ValueError):
                    continue
            return None

        success_count = 0
        fail_count = 0

        # 검증 성공한 주소만 처리
        success_rows = df[df['검증상태'] == '성공']
        total_to_process = len(success_rows)

        print(f"📍 총 {total_to_process}개 성공 주소에 대해 좌표 변환 수행")
        print("="*60)

        for idx, row in success_rows.iterrows():
            address = row['표준화주소'] if pd.notna(row['표준화주소']) and row['표준화주소'] else row['주소']

            print(f"🗺️ [{success_count + fail_count + 1}/{total_to_process}] {address}")

            # 이미 좌표가 있는 경우 재사용
            existing_lon = pick_coordinate(row, longitude_candidates)
            existing_lat = pick_coordinate(row, latitude_candidates)

            if existing_lon is not None and existing_lat is not None:
                df.at[idx, 'kakao_longitude'] = existing_lon
                df.at[idx, 'kakao_latitude'] = existing_lat
                if pd.notna(row.get('좌표변환상태')) and row.get('좌표변환상태'):
                    df.at[idx, '좌표변환상태'] = row['좌표변환상태']
                else:
                    df.at[idx, '좌표변환상태'] = '성공'
                if pd.notna(row.get('좌표변환일시')) and row.get('좌표변환일시'):
                    df.at[idx, '좌표변환일시'] = row['좌표변환일시']
                else:
                    df.at[idx, '좌표변환일시'] = datetime.now().strftime('%Y-%m-%d %H:%M:%S')

                success_count += 1
                print(f"    ↪ 기존 좌표 사용 - ({existing_lat}, {existing_lon})")

                if (success_count + fail_count) % 5 == 0:
                    progress = (success_count + fail_count) / total_to_process * 100
                    coord_success_rate = success_count / (success_count + fail_count) * 100
                    print(f"    📊 진행률: {progress:.1f}% | 좌표변환 성공률: {coord_success_rate:.1f}%")

                continue

            is_success, result = self.get_coordinates_from_kakao(address)
            coord_time = datetime.now().strftime('%Y-%m-%d %H:%M:%S')

            if is_success:
                df.at[idx, 'kakao_longitude'] = result['longitude']
                df.at[idx, 'kakao_latitude'] = result['latitude']
                df.at[idx, '좌표변환상태'] = '성공'
                df.at[idx, '좌표변환일시'] = coord_time

                success_count += 1
                print(f"    ✅ 성공 - 좌표: ({result['latitude']}, {result['longitude']})")
            else:
                df.at[idx, '좌표변환상태'] = '실패'
                df.at[idx, '좌표변환일시'] = coord_time

                fail_count += 1
                print(f"    ❌ 실패 - {result}")

            # 5개마다 진행률 표시
            if (success_count + fail_count) % 5 == 0:
                progress = (success_count + fail_count) / total_to_process * 100
                coord_success_rate = success_count / (success_count + fail_count) * 100 if (success_count + fail_count) > 0 else 0
                print(f"    📊 진행률: {progress:.1f}% | 좌표변환 성공률: {coord_success_rate:.1f}%")

            # API 제한 고려 (카카오는 초당 10회 제한)
            time.sleep(self.api_delay)

        print("\n" + "="*60)
        print("🎉 좌표 변환 완료")
        print("="*60)
        print(f"📍 처리 대상: {total_to_process}개")
        print(f"✅ 좌표변환 성공: {success_count}개")
        print(f"❌ 좌표변환 실패: {fail_count}개")
        print(f"📈 좌표변환 성공률: {success_count/total_to_process*100:.1f}%" if total_to_process > 0 else "0%")

        return df

    def save_final_result(self, df):
        """최종 결과 저장"""
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')

        # 최종 CSV 저장
        output_csv = f"final_smoking_places_with_coordinates_{timestamp}.csv"
        df.to_csv(output_csv, index=False, encoding='utf-8-sig')

        # 요약 통계
        total_count = len(df)
        verified_count = len(df[df['검증상태'] == '성공'])
        coordinate_count = len(df[df['좌표변환상태'] == '성공'])

        # 완전한 데이터 (우편번호 + 좌표 모두 있음)
        complete_data = df[(df['검증상태'] == '성공') & (df['좌표변환상태'] == '성공')]
        complete_count = len(complete_data)

        summary = {
            'timestamp': timestamp,
            'total_addresses': total_count,
            'verified_addresses': verified_count,
            'addresses_with_coordinates': coordinate_count,
            'complete_addresses': complete_count,
            'verification_rate': round(verified_count/total_count*100, 2),
            'coordinate_rate': round(coordinate_count/verified_count*100, 2) if verified_count > 0 else 0,
            'complete_rate': round(complete_count/total_count*100, 2)
        }

        # JSON 요약 저장
        with open(f"final_summary_{timestamp}.json", 'w', encoding='utf-8') as f:
            json.dump(summary, f, ensure_ascii=False, indent=2)

        print(f"\n📄 최종 결과 파일: {output_csv}")
        print(f"📊 요약 리포트: final_summary_{timestamp}.json")
        print(f"\n🎯 최종 통계:")
        print(f"  📋 총 주소: {total_count}개")
        print(f"  ✅ 검증 완료: {verified_count}개 ({verified_count/total_count*100:.1f}%)")
        print(f"  🗺️ 좌표 변환: {coordinate_count}개 ({coordinate_count/verified_count*100:.1f}%)" if verified_count > 0 else "")
        print(f"  🎉 완전한 데이터: {complete_count}개 ({complete_count/total_count*100:.1f}%)")

        return output_csv, complete_count

    def run(self):
        """전체 프로세스 실행"""
        print("🚀 좌표 추가 및 데이터 정리 시작")
        print("="*60)

        # 1. 데이터 로드
        df = self.load_data()
        if df is None:
            return False

        # 2. 우편번호 컬럼 정리
        df = self.fix_postcode_column(df)

        # 3. 좌표 변환
        df = self.add_coordinates_to_dataframe(df)

        # 4. 최종 결과 저장
        output_file, complete_count = self.save_final_result(df)

        print(f"\n🎉 모든 작업 완료!")
        print(f"📍 완전한 흡연구역 데이터 {complete_count}개 준비 완료")
        print(f"🔗 다음 단계: 지도 앱 개발 또는 데이터베이스 구축")

        return True

def test_kakao_api():
    """카카오 API 테스트"""
    print("🧪 카카오 API 연결 테스트")
    print("="*40)

    # .env 파일에서 API 키 로드
    load_dotenv()
    api_key = os.getenv('KAKAO_API_KEY')

    if not api_key or api_key == 'your_kakao_rest_api_key_here':
        print("❌ .env 파일에 KAKAO_API_KEY가 설정되지 않았습니다.")
        print("💡 .env 파일의 KAKAO_API_KEY 값을 실제 API 키로 설정하세요.")
        api_key = input("카카오 REST API 키를 입력하세요: ").strip()
        if not api_key:
            print("❌ API 키가 입력되지 않았습니다.")
            return

    test_address = "서울특별시 중구 을지로 30"

    try:
        headers = {'Authorization': f'KakaoAK {api_key}'}
        params = {'query': test_address}

        kakao_api_url = os.getenv('KAKAO_API_URL', "https://dapi.kakao.com/v2/local/search/address.json")
        response = requests.get(kakao_api_url, headers=headers, params=params, timeout=10)

        if response.status_code == 200:
            data = response.json()
            if data.get('documents'):
                result = data['documents'][0]
                print(f"✅ API 테스트 성공!")
                print(f"📍 주소: {test_address}")
                print(f"🗺️ 좌표: ({result['y']}, {result['x']})")
                print(f"💡 전체 프로세스를 진행하세요.")
            else:
                print(f"⚠️ 검색 결과가 없습니다.")
        else:
            print(f"❌ API 오류: {response.status_code}")
            print(f"💡 API 키를 확인해주세요.")
    except Exception as e:
        print(f"❌ 테스트 실패: {e}")

if __name__ == "__main__":
    import sys

    if len(sys.argv) > 1 and sys.argv[1] == "test":
        test_kakao_api()
    else:
        adder = CoordinateAdder()
        adder.run()
