/**
 * 기존 시민제보 주소 업데이트 스크립트
 * 좌표 형식의 주소를 역지오코딩을 통해 실제 주소로 변환합니다.
 * Kakao API를 사용합니다.
 *
 * 사용법:
 *   cd api_server
 *   node scripts/updateCitizenReportAddresses.js
 *
 * 옵션:
 *   --dry-run    : 실제 업데이트 없이 미리보기만 수행
 *   --limit=N    : 처리할 최대 레코드 수 지정
 */

require('dotenv').config();
const { Pool } = require('pg');
const axios = require('axios');

// 데이터베이스 연결 설정
const pool = new Pool({
  host: process.env.DB_HOST,
  port: process.env.DB_PORT,
  database: process.env.DB_NAME,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
});

// 명령줄 인수 파싱
const args = process.argv.slice(2);
const isDryRun = args.includes('--dry-run');
const limitArg = args.find(arg => arg.startsWith('--limit='));
const limit = limitArg ? parseInt(limitArg.split('=')[1], 10) : null;

// 통계
const stats = {
  total: 0,
  updated: 0,
  failed: 0,
  skipped: 0,
};

/**
 * Kakao 역지오코딩 API 호출
 */
async function reverseGeocode(latitude, longitude) {
  const apiKey = process.env.KAKAO_REST_API_KEY;

  if (!apiKey) {
    throw new Error('KAKAO_REST_API_KEY가 설정되지 않았습니다.');
  }

  try {
    const response = await axios.get('https://dapi.kakao.com/v2/local/geo/coord2address.json', {
      params: {
        x: longitude, // 경도
        y: latitude,  // 위도
      },
      headers: {
        Authorization: `KakaoAK ${apiKey}`,
      },
      timeout: 5000,
    });

    const documents = response.data.documents;
    if (!documents || documents.length === 0) {
      return null;
    }

    const result = documents[0];

    // 도로명주소 우선, 없으면 지번주소
    if (result.road_address) {
      return result.road_address.address_name;
    } else if (result.address) {
      return result.address.address_name;
    }

    return null;
  } catch (error) {
    console.error(`  ❌ API 오류: ${error.message}`);
    if (error.response) {
      console.error(`     상태 코드: ${error.response.status}`);
      console.error(`     응답: ${JSON.stringify(error.response.data)}`);
    }
    return null;
  }
}

/**
 * 좌표 형식의 주소인지 확인
 * 예: "서울특별시 (37.5553, 126.9098)"
 */
function isCoordinateAddress(address) {
  if (!address) return false;
  // 괄호 안에 좌표가 있는 패턴 감지
  return /\(\d+\.\d+,?\s*\d+\.\d+\)/.test(address);
}

/**
 * 메인 실행 함수
 */
async function main() {
  console.log('='.repeat(60));
  console.log('📍 시민제보 주소 역지오코딩 업데이트 스크립트 (Kakao API)');
  console.log('='.repeat(60));

  if (isDryRun) {
    console.log('🔍 [DRY RUN 모드] 실제 업데이트는 수행되지 않습니다.\n');
  }

  // API 키 확인
  if (!process.env.KAKAO_REST_API_KEY) {
    console.error('❌ 오류: KAKAO_REST_API_KEY가 .env 파일에 설정되지 않았습니다.');
    process.exit(1);
  }

  try {
    // 시민제보 데이터 조회 (좌표 형식 주소만)
    let queryText = `
      SELECT id, address, latitude, longitude, submitted_category, status
      FROM smoking_areas
      WHERE category = '시민제보'
        AND address LIKE '%(%'
      ORDER BY id
    `;

    if (limit) {
      queryText += ` LIMIT ${limit}`;
    }

    const result = await pool.query(queryText);
    const records = result.rows;

    console.log(`📊 총 ${records.length}개의 시민제보 레코드를 찾았습니다.\n`);
    stats.total = records.length;

    if (records.length === 0) {
      console.log('✅ 업데이트할 레코드가 없습니다.');
      return;
    }

    // 각 레코드 처리
    for (let i = 0; i < records.length; i++) {
      const record = records[i];
      console.log(`[${i + 1}/${records.length}] ID: ${record.id}`);
      console.log(`  현재 주소: ${record.address}`);
      console.log(`  좌표: (${record.latitude}, ${record.longitude})`);
      console.log(`  카테고리: ${record.submitted_category || '없음'}`);
      console.log(`  상태: ${record.status}`);

      // 이미 실제 주소인 경우 건너뛰기
      if (!isCoordinateAddress(record.address)) {
        console.log(`  ⏭️ 이미 실제 주소입니다. 건너뜁니다.\n`);
        stats.skipped++;
        continue;
      }

      // 역지오코딩 수행
      console.log(`  🔄 역지오코딩 중...`);
      const newAddress = await reverseGeocode(record.latitude, record.longitude);

      if (!newAddress) {
        console.log(`  ❌ 역지오코딩 실패. 건너뜁니다.\n`);
        stats.failed++;
        continue;
      }

      console.log(`  ✅ 새 주소: ${newAddress}`);

      // 실제 업데이트 수행 (dry-run이 아닌 경우)
      if (!isDryRun) {
        await pool.query(
          `UPDATE smoking_areas SET address = $1, updated_at = NOW() WHERE id = $2`,
          [newAddress, record.id]
        );
        console.log(`  💾 데이터베이스 업데이트 완료\n`);
      } else {
        console.log(`  [DRY RUN] 업데이트 건너뜀\n`);
      }

      stats.updated++;

      // API 요청 간격 조절 (Rate limiting 방지)
      await new Promise(resolve => setTimeout(resolve, 200));
    }

    // 결과 요약
    console.log('='.repeat(60));
    console.log('📊 처리 결과 요약');
    console.log('='.repeat(60));
    console.log(`  전체: ${stats.total}개`);
    console.log(`  업데이트: ${stats.updated}개`);
    console.log(`  실패: ${stats.failed}개`);
    console.log(`  건너뜀: ${stats.skipped}개`);

    if (isDryRun) {
      console.log('\n⚠️ DRY RUN 모드였습니다. 실제 업데이트를 수행하려면 --dry-run 옵션을 제거하세요.');
    }

  } catch (error) {
    console.error('❌ 오류 발생:', error.message);
    process.exit(1);
  } finally {
    await pool.end();
    console.log('\n✅ 스크립트 완료');
  }
}

// 실행
main();
