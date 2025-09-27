#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import psycopg2
import pandas as pd
import json
from datetime import datetime
import os
from dotenv import load_dotenv

class DatabaseManager:
    def __init__(self):
        # .env 파일 로드
        load_dotenv()

        # 데이터베이스 연결 설정
        self.db_config = {
            'host': os.getenv('DB_HOST', 'localhost'),
            'port': os.getenv('DB_PORT', '5432'),
            'database': os.getenv('DB_NAME', 'smoking_areas_db'),
            'user': os.getenv('DB_USER', 'postgres'),
            'password': os.getenv('DB_PASSWORD', '')
        }
        self.connection = None

    def connect(self):
        """데이터베이스 연결"""
        try:
            self.connection = psycopg2.connect(**self.db_config)
            print(f"✅ PostgreSQL 연결 성공: {self.db_config['database']}")
            return True
        except Exception as e:
            print(f"❌ 데이터베이스 연결 실패: {e}")
            return False

    def disconnect(self):
        """데이터베이스 연결 해제"""
        if self.connection:
            self.connection.close()
            print("📪 데이터베이스 연결 해제")

    def create_tables(self):
        """흡연구역 테이블 생성"""
        print("🔧 흡연구역 테이블 생성 중...")

        create_table_sql = """
        CREATE TABLE IF NOT EXISTS smoking_areas (
            id SERIAL PRIMARY KEY,
            category VARCHAR(20) NOT NULL,
            address TEXT NOT NULL,
            detail TEXT,
            postal_code VARCHAR(10),
            longitude DECIMAL(10, 7) NOT NULL,
            latitude DECIMAL(10, 7) NOT NULL,
            status VARCHAR(10) DEFAULT 'active',
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );
        """

        # 인덱스 생성
        create_indexes_sql = """
        CREATE INDEX IF NOT EXISTS idx_smoking_areas_location ON smoking_areas(latitude, longitude);
        CREATE INDEX IF NOT EXISTS idx_smoking_areas_category ON smoking_areas(category);
        CREATE INDEX IF NOT EXISTS idx_smoking_areas_status ON smoking_areas(status);
        """

        # 업데이트 트리거 함수
        create_trigger_sql = """
        CREATE OR REPLACE FUNCTION update_updated_at_column()
        RETURNS TRIGGER AS $$
        BEGIN
            NEW.updated_at = CURRENT_TIMESTAMP;
            RETURN NEW;
        END;
        $$ language 'plpgsql';

        DROP TRIGGER IF EXISTS update_smoking_areas_updated_at ON smoking_areas;
        CREATE TRIGGER update_smoking_areas_updated_at
            BEFORE UPDATE ON smoking_areas
            FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
        """

        # 뷰 생성
        create_view_sql = """
        CREATE OR REPLACE VIEW active_smoking_areas AS
        SELECT
            id,
            category,
            address,
            detail,
            postal_code,
            longitude,
            latitude,
            created_at
        FROM smoking_areas
        WHERE status = 'active';
        """

        try:
            cursor = self.connection.cursor()

            cursor.execute(create_table_sql)
            print("  ✅ smoking_areas 테이블 생성")

            cursor.execute(create_indexes_sql)
            print("  ✅ 인덱스 생성")

            cursor.execute(create_trigger_sql)
            print("  ✅ 업데이트 트리거 생성")

            cursor.execute(create_view_sql)
            print("  ✅ active_smoking_areas 뷰 생성")

            self.connection.commit()
            cursor.close()
            print("🎉 테이블 생성 완료")
            return True

        except Exception as e:
            print(f"❌ 테이블 생성 실패: {e}")
            self.connection.rollback()
            return False

    def import_csv_data(self, csv_file="final_smoking_places_with_coordinates_20250920_192227.csv"):
        """CSV 데이터를 데이터베이스로 임포트"""
        print(f"📊 CSV 데이터 임포트 시작: {csv_file}")

        try:
            # CSV 파일 로드
            df = pd.read_csv(csv_file, encoding='utf-8-sig')
            print(f"  📄 CSV 파일 로드: {len(df)}개 행")

            # 성공한 데이터만 필터링
            valid_data = df[
                (df['좌표변환상태'] == '성공') &
                (df['kakao_longitude'].notna()) &
                (df['kakao_latitude'].notna()) &
                (df['카테고리'].notna())
            ].copy()

            print(f"  ✅ 유효한 데이터: {len(valid_data)}개")

            # 우편번호 형식 수정 (앞에 0 추가)
            def fix_postal_code(postal_code):
                if pd.isna(postal_code):
                    return None
                postal_str = str(postal_code).strip()
                # 4자리면 앞에 0 추가
                if len(postal_str) == 4 and postal_str.isdigit():
                    return f"0{postal_str}"
                return postal_str

            valid_data['우편번호_수정'] = valid_data['우편번호'].apply(fix_postal_code)
            print("  🔧 우편번호 형식 수정 완료")

            # 기존 데이터 삭제
            cursor = self.connection.cursor()
            cursor.execute("DELETE FROM smoking_areas")
            print("  🗑️ 기존 데이터 삭제")

            # 데이터 삽입
            insert_count = 0
            for _, row in valid_data.iterrows():
                insert_sql = """
                INSERT INTO smoking_areas (
                    category, address, detail, postal_code,
                    longitude, latitude, status
                ) VALUES (%s, %s, %s, %s, %s, %s, %s)
                """

                cursor.execute(insert_sql, (
                    row['카테고리'],
                    row['주소'],
                    row['상세'],
                    row['우편번호_수정'],
                    float(row['kakao_longitude']),
                    float(row['kakao_latitude']),
                    'active'
                ))
                insert_count += 1

            self.connection.commit()
            cursor.close()
            print(f"  ✅ 데이터 삽입 완료: {insert_count}개")
            return True

        except Exception as e:
            print(f"❌ 데이터 임포트 실패: {e}")
            self.connection.rollback()
            return False

    def get_statistics(self):
        """데이터베이스 통계 조회"""
        print("📊 데이터베이스 통계 조회")

        try:
            cursor = self.connection.cursor()

            # 전체 통계
            cursor.execute("""
                SELECT
                    COUNT(*) as total_count,
                    COUNT(CASE WHEN category = '부분 개방형' THEN 1 END) as partial_open,
                    COUNT(CASE WHEN category = '완전 폐쇄형' THEN 1 END) as fully_closed
                FROM smoking_areas
                WHERE status = 'active'
            """)

            stats = cursor.fetchone()
            print(f"  📋 총 흡연구역: {stats[0]}개")
            print(f"  🌬️ 부분 개방형: {stats[1]}개")
            print(f"  🏢 완전 폐쇄형: {stats[2]}개")

            # 지역별 통계
            cursor.execute("""
                SELECT
                    CASE
                        WHEN address LIKE '%중구%' THEN '중구'
                        WHEN address LIKE '%용산구%' THEN '용산구'
                        WHEN address LIKE '%성동구%' THEN '성동구'
                        WHEN address LIKE '%광진구%' THEN '광진구'
                        WHEN address LIKE '%동대문구%' THEN '동대문구'
                        WHEN address LIKE '%노원구%' THEN '노원구'
                        WHEN address LIKE '%강서구%' THEN '강서구'
                        ELSE '기타'
                    END as district,
                    COUNT(*) as count
                FROM smoking_areas
                WHERE status = 'active'
                GROUP BY district
                ORDER BY count DESC
            """)

            districts = cursor.fetchall()
            print("\\n  🗺️ 지역별 분포:")
            for district, count in districts:
                print(f"    {district}: {count}개")

            cursor.close()
            return True

        except Exception as e:
            print(f"❌ 통계 조회 실패: {e}")
            return False

    def get_sample_data(self, limit=5):
        """샘플 데이터 조회"""
        print(f"📋 샘플 데이터 조회 (최대 {limit}개)")

        try:
            cursor = self.connection.cursor()
            cursor.execute("""
                SELECT id, category, address, detail, longitude, latitude
                FROM active_smoking_areas
                ORDER BY id
                LIMIT %s
            """, (limit,))

            rows = cursor.fetchall()
            for row in rows:
                print(f"  [{row[0]}] {row[1]} - {row[2]}")
                print(f"      📍 {row[3]}")
                print(f"      🗺️ ({row[5]}, {row[4]})")

            cursor.close()
            return rows

        except Exception as e:
            print(f"❌ 샘플 데이터 조회 실패: {e}")
            return []

    def export_json(self, output_file="smoking_areas_export.json"):
        """JSON 형태로 데이터 내보내기"""
        print(f"📤 JSON 내보내기: {output_file}")

        try:
            cursor = self.connection.cursor()
            cursor.execute("""
                SELECT
                    id, category, address, detail, postal_code,
                    longitude, latitude, created_at
                FROM active_smoking_areas
                ORDER BY id
            """)

            rows = cursor.fetchall()

            # JSON 데이터 구성
            export_data = {
                'metadata': {
                    'export_date': datetime.now().isoformat(),
                    'total_count': len(rows),
                    'database': self.db_config['database']
                },
                'smoking_areas': []
            }

            for row in rows:
                area_data = {
                    'id': row[0],
                    'category': row[1],
                    'address': row[2],
                    'detail': row[3],
                    'postal_code': row[4],
                    'coordinates': {
                        'longitude': float(row[5]),
                        'latitude': float(row[6])
                    },
                    'created_at': row[7].isoformat() if row[7] else None
                }
                export_data['smoking_areas'].append(area_data)

            # JSON 파일 저장
            with open(output_file, 'w', encoding='utf-8') as f:
                json.dump(export_data, f, ensure_ascii=False, indent=2)

            cursor.close()
            print(f"  ✅ {len(rows)}개 데이터 내보내기 완료")
            return True

        except Exception as e:
            print(f"❌ JSON 내보내기 실패: {e}")
            return False

    def run_full_setup(self, csv_file=None):
        """전체 설정 실행"""
        print("🚀 흡연구역 데이터베이스 전체 설정 시작")
        print("="*60)

        # 1. 연결
        if not self.connect():
            return False

        # 2. 테이블 생성
        if not self.create_tables():
            return False

        # 3. 데이터 임포트
        if csv_file:
            if not self.import_csv_data(csv_file):
                return False

        # 4. 통계 조회
        self.get_statistics()

        # 5. 샘플 데이터 확인
        print("\\n")
        self.get_sample_data(3)

        # 6. JSON 내보내기
        print("\\n")
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        self.export_json(f"smoking_areas_api_data_{timestamp}.json")

        print("\\n🎉 데이터베이스 설정 완료!")
        print("🔗 다음 단계: API 서버 개발 또는 모바일 앱 연동")

        return True

def main():
    """메인 실행 함수"""
    import sys

    # CSV 파일 경로 설정
    csv_file = "final_smoking_places_with_coordinates_20250920_192227.csv"

    if len(sys.argv) > 1:
        if sys.argv[1] == "setup":
            # 전체 설정 실행
            db_manager = DatabaseManager()
            success = db_manager.run_full_setup(csv_file)
            db_manager.disconnect()
            return success
        elif sys.argv[1] == "stats":
            # 통계만 조회
            db_manager = DatabaseManager()
            if db_manager.connect():
                db_manager.get_statistics()
                db_manager.get_sample_data(5)
                db_manager.disconnect()
        elif sys.argv[1] == "export":
            # JSON 내보내기만 실행
            db_manager = DatabaseManager()
            if db_manager.connect():
                timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
                db_manager.export_json(f"smoking_areas_api_data_{timestamp}.json")
                db_manager.disconnect()
    else:
        print("사용법:")
        print("  python3 database_manager.py setup   # 전체 설정 실행")
        print("  python3 database_manager.py stats   # 통계 조회")
        print("  python3 database_manager.py export  # JSON 내보내기")

if __name__ == "__main__":
    main()