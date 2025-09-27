#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import psycopg2
import os
from dotenv import load_dotenv

def fix_postal_codes():
    """데이터베이스의 우편번호 형식 수정 (4자리 -> 5자리)"""
    print("🔧 우편번호 형식 수정 시작")

    # .env 파일 로드
    load_dotenv()

    # 데이터베이스 연결 설정
    db_config = {
        'host': os.getenv('DB_HOST', 'localhost'),
        'port': os.getenv('DB_PORT', '5432'),
        'database': os.getenv('DB_NAME', 'smoking_areas_db'),
        'user': os.getenv('DB_USER', 'postgres'),
        'password': os.getenv('DB_PASSWORD', '')
    }

    try:
        # 데이터베이스 연결
        connection = psycopg2.connect(**db_config)
        cursor = connection.cursor()

        # 현재 우편번호 상태 확인
        cursor.execute("""
            SELECT
                postal_code,
                LENGTH(postal_code) as length,
                COUNT(*) as count
            FROM smoking_areas
            WHERE postal_code IS NOT NULL
            GROUP BY postal_code, LENGTH(postal_code)
            ORDER BY LENGTH(postal_code), postal_code
        """)

        postal_stats = cursor.fetchall()
        print("📊 현재 우편번호 상태:")
        for postal, length, count in postal_stats:
            print(f"  {postal} (길이: {length}) - {count}개")

        # 4자리 우편번호를 5자리로 수정
        update_sql = """
            UPDATE smoking_areas
            SET postal_code = '0' || postal_code
            WHERE LENGTH(postal_code) = 4
              AND postal_code ~ '^[0-9]+$'
        """

        cursor.execute(update_sql)
        updated_count = cursor.rowcount

        connection.commit()
        print(f"✅ {updated_count}개 우편번호 수정 완료")

        # 수정 후 상태 확인
        cursor.execute("""
            SELECT
                postal_code,
                LENGTH(postal_code) as length,
                COUNT(*) as count
            FROM smoking_areas
            WHERE postal_code IS NOT NULL
            GROUP BY postal_code, LENGTH(postal_code)
            ORDER BY LENGTH(postal_code), postal_code
        """)

        postal_stats_after = cursor.fetchall()
        print("\n📊 수정 후 우편번호 상태:")
        for postal, length, count in postal_stats_after:
            print(f"  {postal} (길이: {length}) - {count}개")

        cursor.close()
        connection.close()
        print("\n🎉 우편번호 형식 수정 완료!")

    except Exception as e:
        print(f"❌ 우편번호 수정 실패: {e}")

if __name__ == "__main__":
    fix_postal_codes()