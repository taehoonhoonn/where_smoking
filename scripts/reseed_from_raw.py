#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import argparse
import os
import time
import json
from datetime import datetime

import pandas as pd
import requests
import psycopg2
from psycopg2.extras import execute_values
from dotenv import load_dotenv


RAW_CSV_PATH = os.path.join('old', 'data', 'smoking_place_raw.csv')


class RawSmokingAreaSeeder:
    def __init__(self, csv_path: str = RAW_CSV_PATH, mode: str = 'replace'):
        load_dotenv()

        self.csv_path = csv_path
        self.mode = mode if mode in {'replace', 'append'} else 'replace'
        self.kakao_api_key = os.getenv('KAKAO_API_KEY')
        self.kakao_api_url = os.getenv('KAKAO_API_URL', 'https://dapi.kakao.com/v2/local/search/address.json')
        self.api_delay = float(os.getenv('API_DELAY', 0.2))

        self.db_config = {
            'host': os.getenv('DB_HOST', 'localhost').strip('"'),
            'port': int(os.getenv('DB_PORT', '5432').strip('"')),
            'dbname': os.getenv('DB_NAME', 'smoking_areas_db').strip('"'),
            'user': os.getenv('DB_USER', 'postgres').strip('"'),
            'password': os.getenv('DB_PASSWORD', '').strip('"'),
        }

        if not self.kakao_api_key:
            raise RuntimeError('KAKAO_API_KEY 환경 변수를 설정해주세요.')

    def load_dataframe(self) -> pd.DataFrame:
        df = pd.read_csv(self.csv_path, encoding='utf-8-sig')
        # 기본 컬럼 보정
        for column in ['카테고리', '주소', '상세']:
            if column not in df.columns:
                df[column] = ''
        return df

    @staticmethod
    def _clean_str(value) -> str:
        if isinstance(value, float) and pd.isna(value):
            return ''
        text = str(value or '').strip()
        return '' if text.lower() == 'nan' else text

    def _build_query(self, row: pd.Series) -> str | None:
        address = self._clean_str(row.get('주소'))
        detail = self._clean_str(row.get('상세'))

        if address:
            return address
        if detail:
            return detail
        return None

    def _extract_existing_coord(self, row: pd.Series) -> tuple[float | None, float | None]:
        latitude_candidates = ['latitude', '위도', 'y', 'lat']
        longitude_candidates = ['longitude', '경도', 'x', 'lon', 'longitutde']

        lat = self._pick_numeric(row, latitude_candidates)
        lon = self._pick_numeric(row, longitude_candidates)
        return lat, lon

    @staticmethod
    def _pick_numeric(row: pd.Series, columns: list[str]) -> float | None:
        for column in columns:
            if column not in row:
                continue
            value = row[column]
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

    def _geocode_with_kakao(self, query: str) -> tuple[float | None, float | None, dict]:
        headers = {'Authorization': f'KakaoAK {self.kakao_api_key}'}
        params = {
            'query': query,
            'analyze_type': 'similar',
        }

        response = requests.get(self.kakao_api_url, headers=headers, params=params, timeout=10)
        meta = {'status_code': response.status_code}

        if response.status_code != 200:
            meta['error'] = response.text
            return None, None, meta

        data = response.json()
        meta['response_meta'] = data.get('meta', {})

        documents = data.get('documents') or []
        if not documents:
            return None, None, meta

        document = documents[0]
        try:
            lon = float(document['x'])
            lat = float(document['y'])
            meta['matched_address'] = document.get('address_name') or document.get('road_address', {}).get('address_name')
            return lat, lon, meta
        except (KeyError, TypeError, ValueError):
            meta['error'] = 'invalid coordinate format in response'
            return None, None, meta

    def _insert_records(self, records: list[tuple]):
        conn = psycopg2.connect(**self.db_config)
        try:
            with conn:
                with conn.cursor() as cur:
                    self._ensure_table_shape(cur)
                    if self.mode == 'replace':
                        cur.execute('TRUNCATE TABLE smoking_areas RESTART IDENTITY CASCADE;')
                        execute_values(
                            cur,
                            'INSERT INTO smoking_areas (category, submitted_category, address, detail, postal_code, longitude, latitude, status, report_count, created_at, updated_at) VALUES %s',
                            records,
                        )
                        print(f'  ↳ {len(records)}개 레코드로 테이블을 재구성했습니다.')
                        return

                    # append 모드: 기존 레코드와 중복을 피하며 신규만 추가
                    cur.execute(
                        """
                        SELECT LOWER(TRIM(address)), LOWER(COALESCE(detail, ''))
                        FROM smoking_areas
                        """
                    )
                    existing_keys = {tuple(row) for row in cur.fetchall()}

                    new_records: list[tuple] = []
                    for record in records:
                        address_key = (record[2] or '').strip().lower()
                        detail_key = (record[3] or '').strip().lower()
                        key = (address_key, detail_key)

                        if key in existing_keys:
                            continue

                        existing_keys.add(key)
                        new_records.append(record)

                    if not new_records:
                        print('  ↳ 추가할 신규 레코드가 없어 데이터베이스는 변경되지 않았습니다.')
                        return

                    execute_values(
                        cur,
                        'INSERT INTO smoking_areas (category, submitted_category, address, detail, postal_code, longitude, latitude, status, report_count, created_at, updated_at) VALUES %s',
                        new_records,
                    )
                    print(f'  ↳ 신규 {len(new_records)}개 레코드를 데이터베이스에 추가했습니다.')
        finally:
            conn.close()

    @staticmethod
    def _ensure_table_shape(cursor):
        cursor.execute(
            """
            SELECT column_name FROM information_schema.columns
            WHERE table_name = 'smoking_areas'
            """
        )
        existing_columns = {row[0] for row in cursor.fetchall()}

        migrations: list[tuple[str, str]] = [
            (
                'submitted_category',
                "ALTER TABLE smoking_areas ADD COLUMN IF NOT EXISTS submitted_category VARCHAR(20);",
            ),
            (
                'detail',
                "ALTER TABLE smoking_areas ADD COLUMN IF NOT EXISTS detail TEXT;",
            ),
            (
                'postal_code',
                "ALTER TABLE smoking_areas ADD COLUMN IF NOT EXISTS postal_code VARCHAR(10);",
            ),
            (
                'status',
                "ALTER TABLE smoking_areas ADD COLUMN IF NOT EXISTS status VARCHAR(10) DEFAULT 'active';",
            ),
            (
                'report_count',
                "ALTER TABLE smoking_areas ADD COLUMN IF NOT EXISTS report_count INTEGER DEFAULT 0;",
            ),
            (
                'created_at',
                "ALTER TABLE smoking_areas ADD COLUMN IF NOT EXISTS created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP;",
            ),
            (
                'updated_at',
                "ALTER TABLE smoking_areas ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP;",
            ),
        ]

        for column, statement in migrations:
            if column not in existing_columns:
                cursor.execute(statement)

        # 기존 행에 상태/리포트 카운트 기본값 채우기 (없을 경우만)
        if 'status' not in existing_columns:
            cursor.execute("UPDATE smoking_areas SET status = COALESCE(status, 'active');")
        if 'report_count' not in existing_columns:
            cursor.execute("UPDATE smoking_areas SET report_count = COALESCE(report_count, 0);")

    def run(self):
        df = self.load_dataframe()
        total_rows = len(df)
        print(f'총 {total_rows}개 행 로드')

        records = []
        successes = 0
        reused = 0
        api_calls = 0
        failures: list[dict] = []

        for idx, row in df.iterrows():
            query = self._build_query(row)
            category = self._clean_str(row.get('카테고리')) or '공공데이타'
            if category != '시민제보':
                category = '공공데이타'
            raw_address = self._clean_str(row.get('주소'))
            detail = self._clean_str(row.get('상세')) or None
            address = raw_address or query or ''

            lat, lon = self._extract_existing_coord(row)

            meta: dict[str, object] = {}

            if lat is not None and lon is not None:
                reused += 1
            else:
                if not query:
                    failures.append({'index': idx, 'reason': '주소/상세 미존재'})
                    continue

                lat, lon, meta = self._geocode_with_kakao(query)
                api_calls += 1
                # 속도 제한
                time.sleep(self.api_delay)

            if lat is None or lon is None:
                failures.append({'index': idx, 'query': query, 'meta': meta})
                continue

            records.append((
                category,
                None,  # submitted_category
                address,
                detail,
                None,
                lon,
                lat,
                'active',
                0,
                datetime.utcnow(),
                datetime.utcnow(),
            ))
            successes += 1

            if successes % 25 == 0:
                print(f'  진행 상황: {successes}/{total_rows} (API 호출 {api_calls}회, 기존 좌표 재사용 {reused}개)')

        if not records:
            raise RuntimeError('삽입할 데이터가 없습니다. 원본 CSV와 카카오 응답을 확인하세요.')

        print(f'좌표 확보 완료: 총 {successes}개, API 호출 {api_calls}회, 기존 좌표 재사용 {reused}개, 실패 {len(failures)}개')

        if failures:
            failure_log = {
                'timestamp': datetime.utcnow().isoformat(),
                'total_rows': total_rows,
                'successes': successes,
                'api_calls': api_calls,
                'reused_coordinates': reused,
                'failures': failures,
            }
            failure_path = f'failed_geocoding_{datetime.utcnow().strftime("%Y%m%d_%H%M%S")}.json'
            with open(failure_path, 'w', encoding='utf-8') as fp:
                json.dump(failure_log, fp, ensure_ascii=False, indent=2)
            print(f'  실패 내역 저장: {failure_path}')

        print('데이터베이스 업데이트 시작')
        self._insert_records(records)
        print('데이터베이스 업데이트 완료')


def main():
    parser = argparse.ArgumentParser(description='Seed smoking area data into PostgreSQL.')
    parser.add_argument(
        '--csv',
        dest='csv_path',
        default=RAW_CSV_PATH,
        help='Path to source CSV (default: old/data/smoking_place_raw.csv)',
    )
    parser.add_argument(
        '--mode',
        choices=['replace', 'append'],
        default='replace',
        help='Insertion mode: replace truncates the table, append adds only new rows.',
    )

    args = parser.parse_args()

    seeder = RawSmokingAreaSeeder(csv_path=args.csv_path, mode=args.mode)
    seeder.run()


if __name__ == '__main__':
    main()
